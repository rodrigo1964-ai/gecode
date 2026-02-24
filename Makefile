## Makefile — Pipeline CSP completo: Parser + Gecode
##
## Uso:
##   make                  → compila todo el pipeline
##   make pipeline         → herramientas del pipeline (sin Gecode)
##   make gecode           → herramientas Gecode
##   make clean            → elimina intermedios en obj/
##   make distclean        → elimina intermedios + ejecutables

FPC      = fpc
SRC      = src
OBJ      = obj
BIN      = bin
FLAGS    = -Mobjfpc -Sh -O2 -Fu$(SRC) -FU$(OBJ)
SQLITE   = -Fl$(OBJ) -k"-lsqlite3"

# Objetos C — MiniMath
MINIMATH_OBJS  = $(OBJ)/minimath_trig.o $(OBJ)/minimath_exp.o \
                 $(OBJ)/minimath_util.o  $(OBJ)/minimath_interval.o
MINIMATH_FLAGS = -k"$(OBJ)/minimath_trig.o"    -k"$(OBJ)/minimath_exp.o" \
                 -k"$(OBJ)/minimath_util.o"     -k"$(OBJ)/minimath_interval.o"

# Herramientas pipeline
PIPELINE_BINS = JsonToGraph FwdConsistency BwdConsistency ForwardChain \
                JsonSink JsonSource SyntaxChecker FunctionChecker CSPEval \
                VerifyWithBison

# Herramientas Gecode
GECODE_BINS = TestGecodeBridge TestComplejo TestIntervalos GecodeInfo

.PHONY: all pipeline gecode clean distclean \
        $(PIPELINE_BINS) $(GECODE_BINS)

all: pipeline gecode

pipeline: $(PIPELINE_BINS)

gecode: $(GECODE_BINS)

# ── Pipeline tools ────────────────────────────────────────────────────────

JsonToGraph: $(SRC)/JsonToGraph.pas | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(SRC)/JsonToGraph.pas -o$(BIN)/$@

SyntaxChecker: $(SRC)/SyntaxChecker.pas | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(SRC)/SyntaxChecker.pas -o$(BIN)/$@

FunctionChecker: $(SRC)/FunctionChecker.pas | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(SRC)/FunctionChecker.pas -o$(BIN)/$@

FwdConsistency: $(MINIMATH_OBJS) $(SRC)/FwdConsistency.pas | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(MINIMATH_FLAGS) $(SRC)/FwdConsistency.pas -o$(BIN)/$@

BwdConsistency: $(MINIMATH_OBJS) $(SRC)/BwdConsistency.pas | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(MINIMATH_FLAGS) $(SRC)/BwdConsistency.pas -o$(BIN)/$@

ForwardChain: $(MINIMATH_OBJS) $(SRC)/ForwardChain.pas | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(MINIMATH_FLAGS) $(SRC)/ForwardChain.pas -o$(BIN)/$@

CSPEval: $(MINIMATH_OBJS) $(SRC)/CSPEval.pas | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(MINIMATH_FLAGS) $(SRC)/CSPEval.pas -o$(BIN)/$@

VerifyWithBison: $(SRC)/VerifyWithBison.pas $(SRC)/UCSPJson.pas | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(SRC)/VerifyWithBison.pas -o$(BIN)/$@

JsonSink: $(SRC)/JsonSink.pas $(OBJ)/libsqlite3.so | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(SQLITE) $(SRC)/JsonSink.pas -o$(BIN)/$@

JsonSource: $(SRC)/JsonSource.pas $(OBJ)/libsqlite3.so | $(OBJ) $(BIN)
	$(FPC) $(FLAGS) $(SQLITE) $(SRC)/JsonSource.pas -o$(BIN)/$@

# ── Gecode tools (via build_monolithic.sh) ────────────────────────────────

TestGecodeBridge:
	./scripts/build_monolithic.sh $(SRC)/TestGecodeBridge.pas

TestComplejo:
	./scripts/build_monolithic.sh $(SRC)/TestComplejo.pas

TestIntervalos:
	./scripts/build_monolithic.sh $(SRC)/TestIntervalos.pas

GecodeInfo:
	./scripts/build_monolithic.sh $(SRC)/GecodeInfo.pas

# ── Objetos C ─────────────────────────────────────────────────────────────

$(OBJ)/minimath_trig.o: $(SRC)/minimath_trig.c | $(OBJ)
	gcc -c -O2 -std=c99 $< -o $@

$(OBJ)/minimath_exp.o: $(SRC)/minimath_exp.c | $(OBJ)
	gcc -c -O2 -std=c99 $< -o $@

$(OBJ)/minimath_util.o: $(SRC)/minimath_util.c | $(OBJ)
	gcc -c -O2 -std=c99 $< -o $@

$(OBJ)/minimath_interval.o: $(SRC)/minimath_interval.c | $(OBJ)
	gcc -c -O2 -std=c99 $< -o $@

$(OBJ)/libsqlite3.so:
	ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0.8.6 $(OBJ)/libsqlite3.so

# ── Directorios ──────────────────────────────────────────────────────────

$(OBJ):
	mkdir -p $(OBJ)

$(BIN):
	mkdir -p $(BIN)

# ── Limpieza ──────────────────────────────────────────────────────────────

clean:
	rm -f $(OBJ)/*.o $(OBJ)/*.ppu $(OBJ)/*.res $(OBJ)/ppas.sh

distclean: clean
	rm -f $(addprefix $(BIN)/,$(PIPELINE_BINS) $(GECODE_BINS))
