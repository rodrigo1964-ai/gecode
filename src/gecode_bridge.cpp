// gecode_bridge.cpp
//
// Bridge C++ → Gecode para el Motor Lógico Tipado Multidominio.
// Recibe restricciones en forma plana desde Pascal y construye el modelo CP.
//
// Visibilidad: solo las funciones csp_* son símbolos públicos.
// Todo lo demás (CSPModel, helpers) queda hidden y es eliminado por --gc-sections.
//
// Incluir en linkeo estático con:
//   libgecodeint, libgecodeminimodel, libgecodesearch,
//   libgecodekernel, libgecodesupport

#pragma GCC visibility push(hidden)

#include <gecode/int.hh>
#include <gecode/minimodel.hh>
#include <gecode/search.hh>
#include <cstring>
#include <iostream>
#include <map>
#include <string>
#include <stdexcept>

using namespace Gecode;

// ============================================================
// ESTRUCTURAS C-COMPATIBLE (layout igual al lado Pascal)
// ============================================================

// Variable entera con dominio [min_domain, max_domain]
struct Variable {
    char name[64];
    int  min_domain;
    int  max_domain;
};

// Tipos de restricción — mapeados desde nodos AST del motor
enum ConstraintType {
    // ── Básicas: var1 OP (var2 | const) ──────────────────────
    CT_EQ          =  0,   // var1  =  var2 | const
    CT_NEQ         =  1,   // var1 <>  var2 | const
    CT_LT          =  2,   // var1  <  var2 | const
    CT_GT          =  3,   // var1  >  var2 | const
    CT_LE          =  4,   // var1 <=  var2 | const
    CT_GE          =  5,   // var1 >=  var2 | const

    // ── Dominio ───────────────────────────────────────────────
    CT_IN_INTERVAL =  6,   // lo <= var1 <= hi  (extremos abiertos opcionales)
    CT_IN_SET      =  7,   // var1 IN {v0, v1, ...}

    // ── Aritmética lineal: sum(coef[i]*var[i]) OP rhs ────────
    // Cubre: x+y=10, 2*x-y>=0, etc. (nodos Add/Sub/Mul del AST)
    CT_LINEAR_EQ   =  8,
    CT_LINEAR_LE   =  9,
    CT_LINEAR_GE   = 10,
    CT_LINEAR_LT   = 11,
    CT_LINEAR_GT   = 12,
    CT_LINEAR_NEQ  = 13,

    // ── abs(var) ──────────────────────────────────────────────
    // Cubre built-in abs() del PDF
    CT_ABS_EQ      = 14,   // abs(var1)  = const
    CT_ABS_LE      = 15,   // abs(var1) <= const
    CT_ABS_GE      = 16,   // abs(var1) >= const

    // ── dist(var1, var2) = |var1 - var2| ─────────────────────
    // Cubre built-in dist() del PDF
    CT_DIST_EQ     = 17,   // |var1 - var2|  = const
    CT_DIST_LE     = 18,   // |var1 - var2| <= const
    CT_DIST_GE     = 19,   // |var1 - var2| >= const

    // ── Global ───────────────────────────────────────────────
    CT_ALL_DIFF    = 20,   // all_different([diff_vars])
};

// Restricción plana (Pascal llena solo los campos relevantes al tipo)
struct Constraint {
    int  type;             // ConstraintType

    // ── Básicas / abs / dist ──
    char var1[64];
    char var2[64];         // vacío ('\0') si es var-constante
    int  constant;

    // ── in_interval ──
    int  lo, hi;
    bool lo_open, hi_open;

    // ── in_set ──
    int  set_vals[100];
    int  set_size;

    // ── linear: sum(coef[i] * lin_vars[i]) OP lin_rhs ──
    char lin_vars[20][64];
    int  lin_coefs[20];
    int  lin_nvars;
    int  lin_rhs;

    // ── all_different ──
    char adiff_vars[50][64];
    int  adiff_nvars;
};

// Solución: valores de cada variable tras resolver
struct Solution {
    char names[50][64];
    int  values[50];
    int  num_vars;
};

// ============================================================
// MODELO CSP (hidden)
// ============================================================

class CSPModel : public Space {
    std::map<std::string, IntVar> vars_;

public:
    CSPModel(Variable* vars, int n) {
        for (int i = 0; i < n; i++)
            vars_[vars[i].name] = IntVar(*this,
                                         vars[i].min_domain,
                                         vars[i].max_domain);

        IntVarArgs all;
        for (auto& p : vars_) all << p.second;
        branch(*this, all, INT_VAR_SIZE_MIN(), INT_VAL_MIN());
    }

    CSPModel(CSPModel& s) : Space(s) {
        for (auto& p : s.vars_) {
            vars_[p.first] = IntVar();
            vars_[p.first].update(*this, p.second);
        }
    }

    virtual Space* copy() { return new CSPModel(*this); }

    // ── diagnóstico: imprime dominios de todas las variables ──
    void debug_domains() {
        for (auto& p : vars_)
            std::cerr << "  DBG " << p.first
                      << " [" << p.second.min() << ", " << p.second.max() << "]"
                      << (p.second.size() == 0 ? " EMPTY" : "") << "\n";
    }

    // ── helpers internos ─────────────────────────────────────

    IntVar& v(const char* name) {
        auto it = vars_.find(name);
        if (it == vars_.end())
            throw std::runtime_error(std::string("variable no existe: ") + name);
        return it->second;
    }

    bool has_v2(const Constraint& c) { return c.var2[0] != '\0'; }

    // Convierte IRT para < / <=  (FIX: CT_LT usaba IRT_LE con const-1 — incorrecto)
    static IntRelType irt(int ct) {
        switch (ct) {
            case CT_EQ:  case CT_LINEAR_EQ:  case CT_ABS_EQ:  case CT_DIST_EQ:  return IRT_EQ;
            case CT_NEQ: case CT_LINEAR_NEQ:                                      return IRT_NQ;
            case CT_LT:  case CT_LINEAR_LT:                                       return IRT_LE; // < estricto
            case CT_GT:  case CT_LINEAR_GT:                                       return IRT_GR;
            case CT_LE:  case CT_LINEAR_LE:  case CT_ABS_LE:  case CT_DIST_LE:  return IRT_LQ;
            case CT_GE:  case CT_LINEAR_GE:  case CT_ABS_GE:  case CT_DIST_GE:  return IRT_GQ;
            default: return IRT_EQ;
        }
    }

    // ── publicar restricción ──────────────────────────────────

    void add(const Constraint& c) {
        switch (c.type) {

        // ─── Básicas ──────────────────────────────────────────
        case CT_EQ: case CT_NEQ: case CT_LT: case CT_GT: case CT_LE: case CT_GE:
            if (has_v2(c))
                rel(*this, v(c.var1), irt(c.type), v(c.var2));
            else
                rel(*this, v(c.var1), irt(c.type), c.constant);
            break;

        // ─── Dominio ──────────────────────────────────────────
        case CT_IN_INTERVAL: {
            int lo = c.lo + (c.lo_open ? 1 : 0);
            int hi = c.hi - (c.hi_open ? 1 : 0);
            dom(*this, v(c.var1), lo, hi);
            break;
        }

        case CT_IN_SET: {
            IntSet s(c.set_vals, c.set_size);
            dom(*this, v(c.var1), s);
            break;
        }

        // ─── Aritmética lineal ────────────────────────────────
        // Cubre: x+y=10 → lin_vars={"x","y"}, lin_coefs={1,1}, lin_rhs=10
        case CT_LINEAR_EQ: case CT_LINEAR_LE: case CT_LINEAR_GE:
        case CT_LINEAR_LT: case CT_LINEAR_GT: case CT_LINEAR_NEQ: {
            IntArgs  coefs(c.lin_nvars);
            IntVarArgs lvars(c.lin_nvars);
            for (int i = 0; i < c.lin_nvars; i++) {
                coefs[i] = c.lin_coefs[i];
                lvars[i] = v(c.lin_vars[i]);
            }
            linear(*this, coefs, lvars, irt(c.type), c.lin_rhs);
            break;
        }

        // ─── abs(var1) OP const ───────────────────────────────
        // Cubre built-in abs() del PDF documento.pdf
        case CT_ABS_EQ: case CT_ABS_LE: case CT_ABS_GE: {
            // Minimodel: rel(*this, abs(x) op const)
            rel(*this, expr(*this, abs(v(c.var1))), irt(c.type), c.constant);
            break;
        }

        // ─── dist(var1, var2) = |var1 - var2| ─────────────────
        // Cubre built-in dist() del PDF documento.pdf
        case CT_DIST_EQ: case CT_DIST_LE: case CT_DIST_GE: {
            rel(*this, expr(*this, abs(v(c.var1) - v(c.var2))), irt(c.type), c.constant);
            break;
        }

        // ─── all_different ────────────────────────────────────
        // Cubre restricción global all_different del PDF
        case CT_ALL_DIFF: {
            IntVarArgs dvars(c.adiff_nvars);
            for (int i = 0; i < c.adiff_nvars; i++)
                dvars[i] = v(c.adiff_vars[i]);
            distinct(*this, dvars);
            break;
        }

        default:
            throw std::runtime_error("tipo de restriccion desconocido");
        }
    }

    void extract(Solution* sol) {
        sol->num_vars = 0;
        for (auto& p : vars_) {
            if (sol->num_vars >= 50) break;
            // FIX: verificar assigned() antes de val()
            if (!p.second.assigned())
                throw std::runtime_error("variable sin asignar: " + p.first);
            // FIX: strncpy en lugar de strcpy
            strncpy(sol->names[sol->num_vars], p.first.c_str(), 63);
            sol->names[sol->num_vars][63] = '\0';
            sol->values[sol->num_vars] = p.second.val();
            sol->num_vars++;
        }
    }
};

#pragma GCC visibility pop

// ============================================================
// API PÚBLICA — solo estas funciones son símbolos exportados
// ============================================================

#define EXPORT __attribute__((visibility("default")))

extern "C" {

EXPORT void* csp_create(Variable* vars, int n) {
    try { return new CSPModel(vars, n); }
    catch (...) { return nullptr; }
}

EXPORT int csp_add_constraint(void* model, Constraint* c) {
    try { static_cast<CSPModel*>(model)->add(*c); return 1; }
    catch (...) { return 0; }
}

EXPORT int csp_solve_first(void* model, Solution* sol) {
    try {
        DFS<CSPModel> search(static_cast<CSPModel*>(model));
        CSPModel* s = search.next();
        if (!s) return 0;
        s->extract(sol);
        delete s;
        return 1;
    } catch (...) { return 0; }
}

EXPORT int csp_solve_all(void* model, Solution* solutions, int max_sols) {
    try {
        DFS<CSPModel> search(static_cast<CSPModel*>(model));
        int count = 0;
        while (CSPModel* s = search.next()) {
            if (count < max_sols)
                s->extract(&solutions[count++]);
            delete s;
            if (count >= max_sols) break;
        }
        return count;
    } catch (...) { return 0; }
}

EXPORT int csp_count_solutions(void* model) {
    if (!model) return 0;
    CSPModel* m = static_cast<CSPModel*>(model);
    // status() estabiliza el espacio antes de clone()
    if (m->status() == SS_FAILED) return 0;
    try {
        CSPModel* tmp = static_cast<CSPModel*>(m->clone());
        DFS<CSPModel> search(tmp);
        int count = 0;
        while (CSPModel* s = search.next()) { count++; delete s; }
        return count;
    } catch (...) { return 0; }
}

EXPORT void csp_free(void* model) {
    delete static_cast<CSPModel*>(model);
}

// Cuenta soluciones con una restricción adicional sin modificar el modelo original.
EXPORT int csp_count_with_constraint(void* model, Constraint* c) {
    if (!model || !c) return -1;
    CSPModel* m = static_cast<CSPModel*>(model);
    if (m->status() == SS_FAILED) return 0;
    try {
        CSPModel* tmp = static_cast<CSPModel*>(m->clone());
        tmp->add(*c);
        if (tmp->status() == SS_FAILED) { delete tmp; return 0; }
        DFS<CSPModel> search(tmp);
        int count = 0;
        while (CSPModel* s = search.next()) { count++; delete s; }
        return count;
    } catch (...) { return -1; }
}

// Diagnóstico: propaga y reporta dominios por stderr. Retorna 0 si FAILED.
EXPORT int csp_debug_domains(void* model) {
    if (!model) return -1;
    CSPModel* m = static_cast<CSPModel*>(model);
    SpaceStatus st = m->status();
    std::cerr << "DBG status: "
              << (st == SS_FAILED ? "FAILED" : st == SS_SOLVED ? "SOLVED" : "BRANCH")
              << "\n";
    m->debug_domains();
    return (st == SS_FAILED) ? 0 : 1;
}

} // extern "C"
