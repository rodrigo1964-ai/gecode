#!/bin/bash
# pipeline.sh — procesa JSON de sistema con el pipeline CSP completo
#
# Uso:
#   ./pipeline.sh sistema.json
#   ./pipeline.sh json/Json_input_1.json
#   ./pipeline.sh --db runs.db --tag mi_run sistema.json
#   ./pipeline.sh --persist runs.db sistemas/*.json
#
# Opciones:
#   --db FILE         persiste cada etapa en SQLite (usa JsonSink/JsonSource)
#   --tag TAG         tag para los registros en SQLite (default: nombre del archivo)
#   --path DIRS       path de búsqueda para FunctionChecker (dir1:dir2:...)
#   --verify-bison    activa verificación de soluciones con GNUBison (etapa 7)
#
# Etapas:
#   1. SyntaxChecker    — valida sintaxis del JSON de entrada
#   2. JsonToGraph      — construye grafo AST de restricciones
#   3. FunctionChecker  — verifica objetos de funciones user-defined
#   4. FwdConsistency   — propagación hacia adelante (AC-3)
#   5. BwdConsistency   — proyección inversa
#   6. TestGecodeBridge — resolución CSP completa con Gecode
#   7. VerifyWithBison  — verificación de soluciones con GNUBison (opcional)

# Directorio de binarios (el script está en la raíz del proyecto)
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
BINDIR="$SCRIPTDIR/bin"

# Bibliotecas GeCode locales (para Render u otros entornos sin GeCode instalado)
LIBDIR="$SCRIPTDIR/lib"
if [ -d "$LIBDIR" ]; then
    export LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}"
fi
DB=""
TAG=""
FC_PATH=""
VERIFY_BISON=""

TMPGRAPH=$(mktemp /tmp/csp_graph_XXXXXX.json)
TMPFWD=$(mktemp   /tmp/csp_fwd_XXXXXX.json)
TMPBWD=$(mktemp   /tmp/csp_bwd_XXXXXX.json)
TMPVERIFY=$(mktemp /tmp/csp_verify_XXXXXX.json)
trap "rm -f $TMPGRAPH $TMPFWD $TMPBWD $TMPVERIFY" EXIT

# ── parsear opciones ──────────────────────────────────────────────────────────
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --db)    DB="$2";    shift 2 ;;
        --tag)   TAG="$2";   shift 2 ;;
        --path)  FC_PATH="$2"; shift 2 ;;
        --verify-bison)  VERIFY_BISON="1"; shift ;;
        --db=*)  DB="${1#--db=}";   shift ;;
        --tag=*) TAG="${1#--tag=}"; shift ;;
        --path=*) FC_PATH="${1#--path=}"; shift ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

if [ ${#ARGS[@]} -eq 0 ]; then
    echo "Uso: $0 [--db runs.db] [--tag TAG] sistema.json [...]" >&2
    exit 2
fi

# ── procesar cada archivo ─────────────────────────────────────────────────────
for f in "${ARGS[@]}"; do
    echo "══════════════════════════════════════════"
    echo "  $f"
    echo "══════════════════════════════════════════"

    FILE_TAG="${TAG:-$(basename "$f" .json)}"

    # 1. SyntaxChecker
    if ! "$BINDIR/SyntaxChecker" "$f" > /tmp/sc_out.json 2>&1; then
        echo "  [1] SyntaxChecker FAIL"; cat /tmp/sc_out.json; echo; continue
    fi
    echo "  [1] SyntaxChecker    ok"

    # 2. JsonToGraph
    if ! "$BINDIR/JsonToGraph" "$f" > "$TMPGRAPH" 2>&1; then
        echo "  [2] JsonToGraph FAIL"; cat "$TMPGRAPH"; echo; continue
    fi
    echo "  [2] JsonToGraph      ok"
    [ -n "$DB" ] && "$BINDIR/JsonSink" "$DB" "${FILE_TAG}.graph" < "$TMPGRAPH" >/dev/null

    # 3. FunctionChecker
    FC_ARGS=("$TMPGRAPH")
    [ -n "$FC_PATH" ] && FC_ARGS+=(--path "$FC_PATH")
    FC_EXIT=0
    "$BINDIR/FunctionChecker" "${FC_ARGS[@]}" >/dev/null 2>&1 || FC_EXIT=$?
    if [ $FC_EXIT -eq 2 ]; then
        echo "  [3] FunctionChecker FATAL"; continue
    fi
    echo "  [3] FunctionChecker  ok"

    # 4. FwdConsistency
    if ! "$BINDIR/FwdConsistency" "$TMPGRAPH" > "$TMPFWD" 2>&1; then
        echo "  [4] FwdConsistency FAIL"; cat "$TMPFWD"; echo; continue
    fi
    echo "  [4] FwdConsistency   ok"
    [ -n "$DB" ] && "$BINDIR/JsonSink" "$DB" "${FILE_TAG}.fwd" < "$TMPFWD" >/dev/null

    # 5. BwdConsistency
    if ! "$BINDIR/BwdConsistency" "$TMPGRAPH" > "$TMPBWD" 2>&1; then
        echo "  [5] BwdConsistency FAIL"; cat "$TMPBWD"; echo; continue
    fi
    echo "  [5] BwdConsistency   ok"
    [ -n "$DB" ] && "$BINDIR/JsonSink" "$DB" "${FILE_TAG}.bwd" < "$TMPBWD" >/dev/null

    # 6. TestGecodeBridge — resolución CSP
    echo "  [6] TestGecodeBridge →"
    "$BINDIR/TestGecodeBridge" "$TMPGRAPH"
    [ -n "$DB" ] && "$BINDIR/TestGecodeBridge" "$TMPGRAPH" | \
        "$BINDIR/JsonSink" "$DB" "${FILE_TAG}.csp" >/dev/null

    # 7. VerifyWithBison — verificación opcional con GNUBison
    if [ -n "$VERIFY_BISON" ]; then
        echo "  [7] VerifyWithBison  →"
        "$BINDIR/TestGecodeBridge" "$TMPGRAPH" | \
            "$BINDIR/VerifyWithBison" "$TMPGRAPH" > "$TMPVERIFY" 2>&1

        if [ $? -eq 0 ]; then
            cat "$TMPVERIFY"
            [ -n "$DB" ] && "$BINDIR/JsonSink" "$DB" "${FILE_TAG}.verify" < "$TMPVERIFY" >/dev/null
        else
            echo "  [7] VerifyWithBison FAIL"
            cat "$TMPVERIFY" >&2
        fi
    fi

    echo
done
