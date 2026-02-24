#!/bin/bash
# build_monolithic.sh
#
# Compila gecode_bridge.cpp + Pascal + Gecode en un ejecutable.
#
# Modo estático:  si existe $GECODE_HOME con .a, linkea estático.
# Modo dinámico:  si solo hay .so del sistema, linkea dinámico.
#
# Uso: ./build_monolithic.sh [programa.pas]

set -e

SRC="src"
OBJ="obj"
BIN="bin"

BRIDGE_SRC="$SRC/gecode_bridge.cpp"
BRIDGE_OBJ="$OBJ/gecode_bridge.o"
PASCAL_MAIN="${1:-$SRC/TestGecodeBridge.pas}"
OUTPUT="$BIN/$(basename ${PASCAL_MAIN%.pas})"
GECODE_HOME="${GECODE_HOME:-$HOME/gecode-static}"
DYNAMIC_LINKER="/lib64/ld-linux-x86-64.so.2"

# Detectar modo de linkeo
if ls "$GECODE_HOME"/lib/libgecodeint.a &>/dev/null; then
    GECODE_LIB="$GECODE_HOME/lib"
    GECODE_INC="$GECODE_HOME/include"
    STATIC_MODE=1
else
    GECODE_LIB="/usr/lib/x86_64-linux-gnu"
    GECODE_INC="/usr/include"
    STATIC_MODE=0
fi

# Crear directorio bin si no existe
mkdir -p "$BIN"

echo "╔══════════════════════════════════════════╗"
echo "║  BUILD — Motor Lógico CP + Gecode        ║"
echo "╚══════════════════════════════════════════╝"
echo
echo "  Modo    : $([ $STATIC_MODE -eq 1 ] && echo 'estático' || echo 'dinámico (sistema)')"
echo "  Bridge  : $BRIDGE_SRC"
echo "  Pascal  : $PASCAL_MAIN"
echo "  Output  : $OUTPUT"
echo

# ── 1. Compilar bridge C++ ───────────────────────────────────
echo "[1/3] Compilando $BRIDGE_SRC..."
g++ -c "$BRIDGE_SRC"          \
    -o "$BRIDGE_OBJ"          \
    -I"$GECODE_INC"           \
    -std=c++17                \
    -O2                       \
    -DNDEBUG                  \
    -fvisibility=hidden       \
    -ffunction-sections       \
    -fdata-sections           \
    -fno-stack-protector
echo "    OK → $BRIDGE_OBJ"
echo

# ── 2. Compilar Pascal (sin linkear) ─────────────────────────
echo "[2/3] Compilando Pascal..."
fpc "$PASCAL_MAIN" -O2 -Cn -FU"$OBJ/" -Fu"$OBJ/" -Fu"$SRC/"
# FPC genera link*.res en el directorio actual, no en OBJ
RESFILE=$(ls -t link*.res 2>/dev/null | head -1)
if [ -z "$RESFILE" ]; then
    echo "    ERROR: No se encontró archivo link*.res"
    exit 1
fi
# FPC escribe los .o sin path — reemplazar referencias bare con obj/
sed -i "s|^\([A-Za-z][A-Za-z0-9_]*\.o\)$|$OBJ/\1|g" "$RESFILE"
echo "    OK (link script: $RESFILE)"
echo

# ── 3. Linkeo final ──────────────────────────────────────────
echo "[3/3] Linkeando con Gecode..."

if [ "$STATIC_MODE" -eq 1 ]; then
    /usr/bin/ld.bfd -b elf64-x86-64 -m elf_x86_64 -s \
        -o "$OUTPUT"                        \
        -T "$RESFILE" -e _start             \
        --dynamic-linker "$DYNAMIC_LINKER"  \
        --gc-sections                       \
        -L"$GECODE_LIB"                     \
        -Bstatic                            \
        -lgecodeminimodel                   \
        -lgecodeint                         \
        -lgecodesearch                      \
        -lgecodekernel                      \
        -lgecodesupport                     \
        -Bdynamic                           \
        -lstdc++ -lgcc_s -lc
else
    /usr/bin/ld.bfd -b elf64-x86-64 -m elf_x86_64 -s \
        -o "$OUTPUT"                        \
        -T "$RESFILE" -e _start             \
        --dynamic-linker "$DYNAMIC_LINKER"  \
        --gc-sections                       \
        -L"$GECODE_LIB"                     \
        -lgecodeminimodel                   \
        -lgecodeint                         \
        -lgecodesearch                      \
        -lgecodekernel                      \
        -lgecodesupport                     \
        -lstdc++ -lgcc_s -lc
fi

echo "    OK → $OUTPUT"
echo

# ── Resumen ──────────────────────────────────────────────────
SIZE=$(du -sh "$OUTPUT" 2>/dev/null | cut -f1)
echo "══════════════════════════════════════════════"
echo "  Tamaño : $SIZE"
echo
echo "  Dependencias dinámicas:"
ldd "$OUTPUT" 2>/dev/null | grep -v "linux-vdso\|ld-linux" \
    | sed 's/^/    /' \
    || echo "    (ninguna)"
echo
echo "  Símbolos bridge exportados:"
nm -D "$OUTPUT" 2>/dev/null | grep " T csp_" | sed 's/^/    /' \
    || nm "$BRIDGE_OBJ" | grep " T csp_" | sed 's/^/    /'
echo
echo "══════════════════════════════════════════════"
echo "  Ejecutar: $OUTPUT"
echo "══════════════════════════════════════════════"
