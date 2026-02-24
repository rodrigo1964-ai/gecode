# Estructura del Proyecto GeCode CSP Pipeline

Este documento describe la organización y estructura del proyecto.

## Árbol de Directorios

```
gecode/
├── bin/                    # Ejecutables compilados
│   ├── BwdConsistency     # Propagación backward
│   ├── CSPEval            # Evaluador de expresiones
│   ├── ForwardChain       # Encadenamiento forward
│   ├── FunctionChecker    # Verificador de funciones
│   ├── FwdConsistency     # Propagación forward (AC-3)
│   ├── GecodeInfo         # Información de Gecode
│   ├── JsonSink           # Persistencia a SQLite
│   ├── JsonSource         # Lectura desde SQLite
│   ├── JsonToGraph        # Constructor de grafo AST
│   ├── SyntaxChecker      # Validador de sintaxis
│   ├── TestComplejo       # Test complejo Gecode
│   ├── TestGecodeBridge   # Puente principal a Gecode
│   └── TestIntervalos     # Test de intervalos
│
├── src/                    # Código fuente
│   ├── *.pas              # Programas Pascal
│   │   ├── BwdConsistency.pas
│   │   ├── CSPEval.pas
│   │   ├── ForwardChain.pas
│   │   ├── FunctionChecker.pas
│   │   ├── FwdConsistency.pas
│   │   ├── GecodeInfo.pas
│   │   ├── JsonSink.pas
│   │   ├── JsonSource.pas
│   │   ├── JsonToGraph.pas
│   │   ├── SyntaxChecker.pas
│   │   ├── TestComplejo.pas
│   │   ├── TestGecodeBridge.pas
│   │   └── TestIntervalos.pas
│   │
│   ├── ExpressionAST.pas  # Unit: AST de expresiones
│   ├── MiniJSON.pas       # Unit: Parser JSON
│   ├── MiniMath.pas       # Unit: Funciones matemáticas
│   ├── MiniSys.pas        # Unit: Sistema
│   ├── PrattParser.pas    # Unit: Parser Pratt
│   ├── UCSPJson.pas       # Unit: CSP JSON
│   ├── UGecodeBridge.pas  # Unit: Puente a Gecode
│   │
│   ├── gecode_bridge.cpp  # Puente C++ a Gecode
│   │
│   ├── minimath_*.c       # Biblioteca matemática en C
│   │   ├── minimath_exp.c
│   │   ├── minimath_interval.c
│   │   ├── minimath_trig.c
│   │   └── minimath_util.c
│   └── minimath.h         # Header de MiniMath
│
├── obj/                    # Archivos objeto (compilación)
│   ├── *.o                # Objetos de C/C++
│   ├── *.ppu              # Units compiladas (Pascal)
│   ├── link*.res          # Scripts de linkeo
│   └── libsqlite3.so      # Link simbólico a SQLite
│
├── docs/                   # Documentación
│   ├── *.txt              # Documentos de cada componente
│   ├── estructura_proyecto.md  # Este archivo
│   └── *.md               # Otros documentos markdown
│
├── ejemplos/               # Archivos JSON de ejemplo
│   ├── Json_input_*.json  # Entradas de prueba
│   ├── Json_output_*.json # Salidas esperadas
│   └── README.md          # Descripción de ejemplos
│
├── tests/                  # Tests y casos de prueba
│   └── (archivos de test)
│
├── scripts/                # Scripts auxiliares
│   ├── build_monolithic.sh  # Compilación monolítica
│   └── pipeline.sh         # Pipeline completo
│
├── Makefile               # Sistema de compilación
└── README.md              # Documentación principal

```

## Flujo de Compilación

### 1. Herramientas del Pipeline (Pascal)

El Makefile compila las herramientas Pascal de esta manera:

```makefile
SRC = src
OBJ = obj
BIN = bin

# Herramientas pipeline (Pascal puro)
JsonToGraph → bin/JsonToGraph
SyntaxChecker → bin/SyntaxChecker
FunctionChecker → bin/FunctionChecker

# Herramientas con MiniMath (Pascal + C)
FwdConsistency → bin/FwdConsistency (+ minimath_*.o)
BwdConsistency → bin/BwdConsistency (+ minimath_*.o)
ForwardChain → bin/ForwardChain (+ minimath_*.o)
CSPEval → bin/CSPEval (+ minimath_*.o)

# Herramientas con SQLite (Pascal + SQLite)
JsonSink → bin/JsonSink (+ libsqlite3)
JsonSource → bin/JsonSource (+ libsqlite3)
```

### 2. Herramientas Gecode (build_monolithic.sh)

El script `build_monolithic.sh` genera ejecutables monolíticos:

```bash
# 1. Compilar bridge C++
gecode_bridge.cpp → obj/gecode_bridge.o

# 2. Compilar Pascal
TestGecodeBridge.pas → obj/*.o + obj/*.ppu

# 3. Linkear todo
obj/*.o + libgecode*.a → bin/TestGecodeBridge
```

Modos de compilación:
- **Estático**: Si existe `$GECODE_HOME/lib/*.a`
- **Dinámico**: Si solo hay `/usr/lib/x86_64-linux-gnu/libgecode*.so`

## Dependencias entre Componentes

### Units Pascal Base

```
MiniSys.pas
  └── Funciones básicas del sistema

MiniJSON.pas
  └── Parser y generador JSON

ExpressionAST.pas
  └── Representación de AST de expresiones

PrattParser.pas
  ├── MiniSys
  └── ExpressionAST

MiniMath.pas
  ├── MiniSys
  └── minimath_*.o (C)
```

### Units Específicas de CSP

```
UCSPJson.pas
  ├── MiniJSON
  ├── ExpressionAST
  └── PrattParser

UGecodeBridge.pas
  └── Interface a gecode_bridge.cpp
```

### Programas del Pipeline

```
SyntaxChecker
  ├── UCSPJson
  └── MiniJSON

JsonToGraph
  ├── UCSPJson
  ├── ExpressionAST
  └── MiniJSON

FunctionChecker
  └── UCSPJson

FwdConsistency
  ├── UCSPJson
  ├── MiniMath
  └── ExpressionAST

BwdConsistency
  ├── UCSPJson
  ├── MiniMath
  └── ExpressionAST

ForwardChain
  ├── UCSPJson
  └── MiniMath

CSPEval
  ├── UCSPJson
  └── MiniMath
```

### Programas Gecode

```
TestGecodeBridge
  ├── UGecodeBridge
  ├── UCSPJson
  └── gecode_bridge.o (→ libgecode*.a/so)

TestComplejo
  ├── UGecodeBridge
  └── UCSPJson

TestIntervalos
  └── UGecodeBridge

GecodeInfo
  └── UGecodeBridge
```

## Flujo del Pipeline

```
1. JSON Input
   ↓
2. SyntaxChecker (valida sintaxis)
   ↓
3. JsonToGraph (construye AST)
   ↓
4. FunctionChecker (verifica funciones)
   ↓
5. FwdConsistency (propagación AC-3)
   ↓
6. BwdConsistency (proyección inversa)
   ↓
7. TestGecodeBridge (resolución CSP)
   ↓
8. JSON Output
```

**Con persistencia SQLite:**

```
Input → SyntaxChecker → JsonSink("syntax")
        JsonSource ↓
        JsonToGraph → JsonSink("graph")
        JsonSource ↓
        FunctionChecker
        ↓
        FwdConsistency → JsonSink("fwd")
        JsonSource ↓
        BwdConsistency → JsonSink("bwd")
        JsonSource ↓
        TestGecodeBridge → JsonSink("csp")
```

## Integración con Gecode

### Arquitectura del Puente

```
Pascal (TestGecodeBridge.pas)
  ↓ (external functions)
UGecodeBridge.pas
  ↓ (cdecl interface)
gecode_bridge.cpp
  ↓ (C++ methods)
libgecode (C++ library)
```

### Estructuras Compartidas (C-compatible)

```c
struct Variable {
    char name[64];
    int min_domain;
    int max_domain;
};

struct Constraint {
    int type;  // 0=eq, 1=neq, 2=lt, ...
    char var1[64];
    char var2[64];
    int constant;
    // ... más campos
};

struct Solution {
    char names[50][64];
    int values[50];
    int num_vars;
};
```

### API C Exportada

```c
void* csp_create(Variable* vars, int n);
int csp_add_constraint(void* model, Constraint* constraint);
int csp_solve_first(void* model, Solution* sol);
int csp_solve_all(void* model, Solution* solutions, int max_sols);
int csp_count_solutions(void* model);
void csp_free(void* model);
```

## Comandos Make

```bash
make              # Compilar todo
make pipeline     # Solo herramientas pipeline
make gecode       # Solo herramientas Gecode
make clean        # Limpiar .o y .ppu
make distclean    # Limpiar todo (incluye ejecutables)
```

## Variables de Entorno

- `GECODE_HOME`: Ruta a instalación de Gecode estático (default: `$HOME/gecode-static`)
- `FPC`: Compilador Pascal (default: `fpc`)

## Notas de Diseño

1. **Separación clara**: Código fuente en `src/`, ejecutables en `bin/`, objetos en `obj/`

2. **Units reutilizables**: Las units (MiniSys, MiniJSON, etc.) son compartidas por múltiples programas

3. **Compilación modular**: El Makefile permite compilar componentes individualmente

4. **Puente limpio a C++**: Interface mínima y clara entre Pascal y Gecode

5. **Persistencia opcional**: SQLite es opcional, el pipeline funciona sin él

6. **Portabilidad**: Ejecutables monolíticos sin dependencias externas (excepto libc)
