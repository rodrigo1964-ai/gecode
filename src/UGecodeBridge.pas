{ ╔════════════════════════════════════════════════════════════════╗
  ║ UGecodeBridge.pas                                            ║
  ║ Bridge Pascal → Gecode (linkeo monolítico estático)          ║
  ║ Autor: Motor Lógico Tipado Multidominio                      ║
  ╚════════════════════════════════════════════════════════════════╝

  ARQUITECTURA: Lado Pascal del bridge FFI
  ──────────────────────────────────────────────────────────────────────────────
  Este unit declara tipos Pascal espejo de los structs C++ definidos en
  gecode_bridge.cpp y expone las funciones csp_* como external cdecl.

  DECISIÓN DE DISEÑO: Records POD vs clases Pascal
  ──────────────────────────────────────────────────────────────────────────────
  - TCSPVar, TCSPConstraint, TCSPSolution son RECORDS (no classes)
  - Layout de memoria compatible-C mediante {$PACKRECORDS C}
  - Arrays de tamaño fijo (no dynamic arrays → evita descriptores RTL)
  - Strings embebidos como char[64] terminados en NULL
  - Esto garantiza que Pascal pueda pasar punteros sin marshalling

  DISCIPLINA DE OWNERSHIP: ¿Quién libera qué?
  ──────────────────────────────────────────────────────────────────────────────
  Pascal (lado cliente) posee:
    - Todas las variables TCSPVar en stack o var global
    - Todas las restricciones TCSPConstraint[] en stack
    - Todas las soluciones TCSPSolution[] en stack
    → NUNCA liberar con csp_free, solo usarlo con puntero de csp_create

  C++ (gecode_bridge.o) posee:
    - CSPModel* devuelto por csp_create → DEBE liberarse con csp_free
    - Copias temporales durante DFS search (autoliberadas)

  PATRÓN DE USO SEGURO:
    1. Model := csp_create(@Vars[0], N);     // C++ new CSPModel
    2. csp_add_constraint(Model, @C);        // múltiples llamadas OK
    3. N := csp_solve_all(Model, @Sols, M);  // Pascal posee array Sols
    4. csp_free(Model);                      // OBLIGATORIO

  REFERENCIAS TÉCNICAS:
  ──────────────────────────────────────────────────────────────────────────────
  [1] FPC C interop: https://www.freepascal.org/docs-html/prog/progch7.html
  [2] $PACKRECORDS C: alineación igual que gcc -std=c++17
  [3] $L directive: linkea .o en tiempo de compilación (static linking)

  Uso: compilar junto a gecode_bridge.o y libgecode*.a
  Ver: build_monolithic.sh para estrategia de linkeo estático }

{$mode objfpc}{$H+}
{$PACKRECORDS C}   { layout de records igual al compilador C/C++ }
{$L ../obj/gecode_bridge.o}   { objeto C++ del bridge }

unit UGecodeBridge;

interface

// ═══════════════════════════════════════════════════════════════
// CONSTANTES — tipos de restricción (espejo de gecode_bridge.cpp)
// ═══════════════════════════════════════════════════════════════
const
  // Básicas: var1 OP (var2 | constante)
  CT_EQ          =  0;
  CT_NEQ         =  1;
  CT_LT          =  2;   // < estricto
  CT_GT          =  3;   // > estricto
  CT_LE          =  4;
  CT_GE          =  5;

  // Dominio
  CT_IN_INTERVAL =  6;   // lo <= var1 <= hi
  CT_IN_SET      =  7;   // var1 IN {v0, v1, ...}

  // Aritmética lineal: sum(coef[i]*var[i]) OP rhs
  CT_LINEAR_EQ   =  8;
  CT_LINEAR_LE   =  9;
  CT_LINEAR_GE   = 10;
  CT_LINEAR_LT   = 11;
  CT_LINEAR_GT   = 12;
  CT_LINEAR_NEQ  = 13;

  // abs(var1) OP constante
  CT_ABS_EQ      = 14;
  CT_ABS_LE      = 15;
  CT_ABS_GE      = 16;

  // |var1 - var2| OP constante  (dist del PDF)
  CT_DIST_EQ     = 17;
  CT_DIST_LE     = 18;
  CT_DIST_GE     = 19;

  // Restricción global
  CT_ALL_DIFF    = 20;

// ═══════════════════════════════════════════════════════════════
// TIPOS — espejo exacto de los structs C en gecode_bridge.cpp
// ═══════════════════════════════════════════════════════════════
type
  { Variable entera con dominio [MinDomain, MaxDomain] }
  TCSPVar = record
    Name      : array[0..63] of Char;
    MinDomain : LongInt;
    MaxDomain : LongInt;
  end;
  PCSPVar = ^TCSPVar;

  { Restricción plana — llenar solo los campos del tipo elegido }
  TCSPConstraint = record
    // Discriminador
    CType    : LongInt;            { CT_* }

    // Básicas / abs / dist
    Var1     : array[0..63] of Char;
    Var2     : array[0..63] of Char;   { vacío si var-constante }
    Constant : LongInt;

    // CT_IN_INTERVAL
    Lo, Hi          : LongInt;
    LoOpen, HiOpen  : ByteBool;        { ByteBool = 1 byte, igual a C++ bool }

    // CT_IN_SET
    SetVals : array[0..99]    of LongInt;
    SetSize : LongInt;

    // CT_LINEAR_*   sum(LinCoefs[i] * LinVars[i]) OP LinRHS
    LinVars  : array[0..19, 0..63] of Char;
    LinCoefs : array[0..19] of LongInt;
    LinNVars : LongInt;
    LinRHS   : LongInt;

    // CT_ALL_DIFF
    ADiffVars  : array[0..49, 0..63] of Char;
    ADiffNVars : LongInt;
  end;
  PCSPConstraint = ^TCSPConstraint;

  { Solución devuelta por el solver }
  TCSPSolution = record
    Names   : array[0..49, 0..63] of Char;
    Values  : array[0..49] of LongInt;
    NumVars : LongInt;
  end;
  PCSPSolution = ^TCSPSolution;

// ═══════════════════════════════════════════════════════════════
// API C — declaraciones externas (linkeadas desde gecode_bridge.o)
// ═══════════════════════════════════════════════════════════════

{ Crear modelo con N variables enteras }
function  csp_create(Vars: PCSPVar; N: LongInt): Pointer;
          cdecl; external;

{ Agregar restricción al modelo; retorna 1 si OK }
function  csp_add_constraint(Model: Pointer; C: PCSPConstraint): LongInt;
          cdecl; external;

{ Primera solución; retorna 1 si encontró, 0 si no hay }
function  csp_solve_first(Model: Pointer; Sol: PCSPSolution): LongInt;
          cdecl; external;

{ Todas las soluciones hasta MaxSols; retorna cantidad encontrada }
function  csp_solve_all(Model: Pointer; Solutions: PCSPSolution;
          MaxSols: LongInt): LongInt;
          cdecl; external;

{ Contar soluciones sin devolverlas }
function  csp_count_solutions(Model: Pointer): LongInt;
          cdecl; external;

{ Liberar memoria del modelo }
procedure csp_free(Model: Pointer);
          cdecl; external;

{ Cuenta soluciones con una restricción adicional sin modificar el modelo }
function  csp_count_with_constraint(Model: Pointer; C: PCSPConstraint): LongInt;
          cdecl; external;

{ Diagnóstico: propaga y reporta dominios por stderr. Retorna 0 si FAILED. }
function  csp_debug_domains(Model: Pointer): LongInt;
          cdecl; external;

// ═══════════════════════════════════════════════════════════════
// HELPERS — constructores de registros
// ═══════════════════════════════════════════════════════════════

{ Crear definición de variable entera }
function CSPMakeVar(const Name: string; MinD, MaxD: Integer): TCSPVar;

{ Básicas: var OP constante }
function CSPEq (const V: string; K: Integer): TCSPConstraint;
function CSPNeq(const V: string; K: Integer): TCSPConstraint;
function CSPLt (const V: string; K: Integer): TCSPConstraint;
function CSPGt (const V: string; K: Integer): TCSPConstraint;
function CSPLe (const V: string; K: Integer): TCSPConstraint;
function CSPGe (const V: string; K: Integer): TCSPConstraint;

{ Básicas: var1 OP var2 }
function CSPEqVar (const V1, V2: string): TCSPConstraint;
function CSPNeqVar(const V1, V2: string): TCSPConstraint;
function CSPLtVar (const V1, V2: string): TCSPConstraint;
function CSPGtVar (const V1, V2: string): TCSPConstraint;
function CSPLeVar (const V1, V2: string): TCSPConstraint;
function CSPGeVar (const V1, V2: string): TCSPConstraint;

{ Dominio }
function CSPInterval(const V: string; Lo, Hi: Integer;
                     LoOpen: Boolean = False;
                     HiOpen: Boolean = False): TCSPConstraint;

function CSPInSet(const V: string;
                  const Vals: array of Integer): TCSPConstraint;

{ Aritmética lineal: sum(Coefs[i] * Vars[i]) OP RHS }
function CSPLinear(CT: Integer;
                   const Vars: array of string;
                   const Coefs: array of Integer;
                   RHS: Integer): TCSPConstraint;

{ Atajos lineales más comunes }
// x + y = K
function CSPAddEq(const V1, V2: string; K: Integer): TCSPConstraint;
// x + y <= K
function CSPAddLe(const V1, V2: string; K: Integer): TCSPConstraint;
// c1*x + c2*y = K
function CSPLinEq2(const V1: string; C1: Integer;
                   const V2: string; C2: Integer;
                   K: Integer): TCSPConstraint;

{ abs(var) OP constante }
function CSPAbsEq(const V: string; K: Integer): TCSPConstraint;
function CSPAbsLe(const V: string; K: Integer): TCSPConstraint;
function CSPAbsGe(const V: string; K: Integer): TCSPConstraint;

{ |var1 - var2| OP constante  (dist del PDF) }
function CSPDistEq(const V1, V2: string; K: Integer): TCSPConstraint;
function CSPDistLe(const V1, V2: string; K: Integer): TCSPConstraint;
function CSPDistGe(const V1, V2: string; K: Integer): TCSPConstraint;

{ all_different([vars]) }
function CSPAllDiff(const Vars: array of string): TCSPConstraint;

{ Copia string a buffer Char[64] — útil para otros módulos }
procedure CSPCopyName(const S: string; var Buf: array of Char);

{ Leer solución }
function CSPSolVarValue(const Sol: TCSPSolution;
                        const Name: string): Integer;
procedure CSPPrintSolution(const Sol: TCSPSolution);

// ═══════════════════════════════════════════════════════════════
implementation
// ═══════════════════════════════════════════════════════════════

{ Copia string a buffer char[64] con truncado seguro }
procedure CopyName(const S: string; var Buf: array of Char);

var
  Len, i: Integer;
begin
  FillChar(Buf, SizeOf(Buf), 0);
  Len := Length(S);
  if Len > 63 then Len := 63;
  for i := 1 to Len do
    Buf[i - 1] := S[i];
  Buf[Len] := #0;
end;

procedure CSPCopyName(const S: string; var Buf: array of Char);
begin
  CopyName(S, Buf);
end;

{ Restricción base con dos vars o var+constante }
function MakeBasic(CT: Integer; const V1, V2: string;
                   K: Integer): TCSPConstraint;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.CType    := CT;
  Result.Constant := K;
  CopyName(V1, Result.Var1);
  CopyName(V2, Result.Var2);
end;

// ── Variable ─────────────────────────────────────────────────

function CSPMakeVar(const Name: string; MinD, MaxD: Integer): TCSPVar;
begin
  FillChar(Result, SizeOf(Result), 0);
  CopyName(Name, Result.Name);
  Result.MinDomain := MinD;
  Result.MaxDomain := MaxD;
end;

// ── Básicas var-constante ─────────────────────────────────────

function CSPEq (const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_EQ,  V, '', K); end;

function CSPNeq(const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_NEQ, V, '', K); end;

function CSPLt (const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_LT,  V, '', K); end;

function CSPGt (const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_GT,  V, '', K); end;

function CSPLe (const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_LE,  V, '', K); end;

function CSPGe (const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_GE,  V, '', K); end;

// ── Básicas var-var ───────────────────────────────────────────

function CSPEqVar (const V1, V2: string): TCSPConstraint;
begin Result := MakeBasic(CT_EQ,  V1, V2, 0); end;

function CSPNeqVar(const V1, V2: string): TCSPConstraint;
begin Result := MakeBasic(CT_NEQ, V1, V2, 0); end;

function CSPLtVar (const V1, V2: string): TCSPConstraint;
begin Result := MakeBasic(CT_LT,  V1, V2, 0); end;

function CSPGtVar (const V1, V2: string): TCSPConstraint;
begin Result := MakeBasic(CT_GT,  V1, V2, 0); end;

function CSPLeVar (const V1, V2: string): TCSPConstraint;
begin Result := MakeBasic(CT_LE,  V1, V2, 0); end;

function CSPGeVar (const V1, V2: string): TCSPConstraint;
begin Result := MakeBasic(CT_GE,  V1, V2, 0); end;

// ── Dominio ───────────────────────────────────────────────────

function CSPInterval(const V: string; Lo, Hi: Integer;
                     LoOpen: Boolean = False;
                     HiOpen: Boolean = False): TCSPConstraint;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.CType  := CT_IN_INTERVAL;
  CopyName(V, Result.Var1);
  Result.Lo     := Lo;
  Result.Hi     := Hi;
  Result.LoOpen := LoOpen;
  Result.HiOpen := HiOpen;
end;

function CSPInSet(const V: string;
                  const Vals: array of Integer): TCSPConstraint;
var
  i, N: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.CType := CT_IN_SET;
  CopyName(V, Result.Var1);
  N := Length(Vals);
  if N > 100 then N := 100;
  for i := 0 to N - 1 do
    Result.SetVals[i] := Vals[i];
  Result.SetSize := N;
end;

// ── Aritmética lineal ─────────────────────────────────────────

function CSPLinear(CT: Integer;
                   const Vars: array of string;
                   const Coefs: array of Integer;
                   RHS: Integer): TCSPConstraint;
var
  i, N: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.CType  := CT;
  Result.LinRHS := RHS;
  N := Length(Vars);
  if N > 20 then N := 20;
  for i := 0 to N - 1 do
  begin
    CopyName(Vars[i], Result.LinVars[i]);
    Result.LinCoefs[i] := Coefs[i];
  end;
  Result.LinNVars := N;
end;

function CSPAddEq(const V1, V2: string; K: Integer): TCSPConstraint;
begin
  Result := CSPLinear(CT_LINEAR_EQ, [V1, V2], [1, 1], K);
end;

function CSPAddLe(const V1, V2: string; K: Integer): TCSPConstraint;
begin
  Result := CSPLinear(CT_LINEAR_LE, [V1, V2], [1, 1], K);
end;

function CSPLinEq2(const V1: string; C1: Integer;
                   const V2: string; C2: Integer;
                   K: Integer): TCSPConstraint;
begin
  Result := CSPLinear(CT_LINEAR_EQ, [V1, V2], [C1, C2], K);
end;

// ── abs ───────────────────────────────────────────────────────

function CSPAbsEq(const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_ABS_EQ, V, '', K); end;

function CSPAbsLe(const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_ABS_LE, V, '', K); end;

function CSPAbsGe(const V: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_ABS_GE, V, '', K); end;

// ── dist ──────────────────────────────────────────────────────

function CSPDistEq(const V1, V2: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_DIST_EQ, V1, V2, K); end;

function CSPDistLe(const V1, V2: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_DIST_LE, V1, V2, K); end;

function CSPDistGe(const V1, V2: string; K: Integer): TCSPConstraint;
begin Result := MakeBasic(CT_DIST_GE, V1, V2, K); end;

// ── all_different ─────────────────────────────────────────────

function CSPAllDiff(const Vars: array of string): TCSPConstraint;
var
  i, N: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.CType := CT_ALL_DIFF;
  N := Length(Vars);
  if N > 50 then N := 50;
  for i := 0 to N - 1 do
    CopyName(Vars[i], Result.ADiffVars[i]);
  Result.ADiffNVars := N;
end;

// ── Lectura de soluciones ─────────────────────────────────────

function CSPSolVarValue(const Sol: TCSPSolution;
                        const Name: string): Integer;
var
  i: Integer;
  BufName: string;
begin
  for i := 0 to Sol.NumVars - 1 do
  begin
    BufName := PChar(@Sol.Names[i]);
    if BufName = Name then
    begin
      CSPSolVarValue := Sol.Values[i];
      Exit;
    end;
  end;
  CSPSolVarValue := 0;  { variable no encontrada }
end;

procedure CSPPrintSolution(const Sol: TCSPSolution);
var
  i: Integer;
begin
  for i := 0 to Sol.NumVars - 1 do
    Write(PChar(@Sol.Names[i]), '=', Sol.Values[i], ' ');
  WriteLn;
end;

end.
