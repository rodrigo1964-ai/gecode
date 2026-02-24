{ ╔════════════════════════════════════════════════════════════════╗
  ║ UCSPJson.pas  v2 — formato JsonToGraph                       ║
  ║                                                               ║
  ║ Lee la salida de JsonToGraph (JSON con variables tipadas y   ║
  ║ restricciones en forma de árbol AST) y construye TCSPData    ║
  ║ para el bridge Gecode.                                        ║
  ║                                                               ║
  ║ Tipos de variable:                                            ║
  ║   boolean → Gecode IntVar [0,1]  (false=0, true=1)          ║
  ║   integer → Gecode IntVar [min,max] + CT_IN_SET              ║
  ║   set     → Gecode IntVar [0,n-1] + CT_IN_SET (label map)   ║
  ║   numeric → Gecode IntVar * SCALE_NUM=1000                   ║
  ║                                                               ║
  ║ Patrones AST soportados:                                      ║
  ║   AND                  → split                               ║
  ║   var OP num|literal   → CT_EQ/NEQ/LT/GT/LE/GE              ║
  ║   var1 OP var2         → CT_EQ/NEQ/LT/GT/LE/GE              ║
  ║   var IN [lo,hi]       → CT_IN_INTERVAL                      ║
  ║   var IN {labels}      → CT_IN_SET                           ║
  ║   lin_expr OP num      → CT_LINEAR_*                         ║
  ║   abs(V) OP K          → CT_ABS_*                            ║
  ║   abs(V-K) OP T        → CT_IN_INTERVAL [K-T, K+T]          ║
  ║   abs(V1-V2) OP K      → CT_DIST_*                          ║
  ║                                                               ║
  ║ No soportados (skipped): OR, NOT, funciones user-defined,    ║
  ║ sqrt, pow, etc.                                               ║
  ╚════════════════════════════════════════════════════════════════╝ }

{$mode objfpc}{$H+}

unit UCSPJson;

interface

uses SysUtils, UGecodeBridge;

const
  MAX_CSP_VARS = 50;
  MAX_CSP_CONS = 300;
  MAX_LABELS   = 512;
  MAX_NODES    = 512;
  SCALE_NUM    = 1000;   { float → integer scale for numeric vars }

type
  TLabelEntry = record
    VarIdx : Integer;
    Lbl    : string;
    IntVal : Integer;
  end;

  TCSPData = record
    Vars      : array[0..MAX_CSP_VARS-1] of TCSPVar;
    NVars     : Integer;
    Cons      : array[0..MAX_CSP_CONS-1] of TCSPConstraint;
    NCons     : Integer;
    VarTypes  : array[0..MAX_CSP_VARS-1] of string;   { boolean|integer|numeric|set }
    VarScales : array[0..MAX_CSP_VARS-1] of Integer;  { 1 or SCALE_NUM }
    LMap      : array[0..MAX_LABELS-1]   of TLabelEntry;
    NLMap     : Integer;
  end;

function LeerCSPJson(const NombreArchivo: string; var Datos: TCSPData): Boolean;
function ObtenerErrorCSPJson: string;

implementation

{ ── AST node type constants ─────────────────────────────────────────────── }

const
  NT_VARIABLE   =  0;
  NT_NUMBER     =  1;
  NT_EQUALS     =  2;
  NT_NOTEQUALS  =  3;
  NT_LESS       =  4;
  NT_GREATER    =  5;
  NT_LESSEQ     =  6;
  NT_GREATEREQ  =  7;
  NT_AND        =  8;
  NT_OR         =  9;
  NT_NOT        = 10;
  NT_ADD        = 11;
  NT_SUBTRACT   = 12;
  NT_MULTIPLY   = 13;
  NT_DIVIDE     = 14;
  NT_NEGATE     = 15;
  NT_FUNCCALL   = 16;
  NT_IN         = 17;
  NT_SET        = 18;
  NT_INTERVAL   = 19;
  NT_UNKNOWN    = -1;

type
  TCSPNode = record
    Id     : Integer;
    NType  : Integer;
    SName  : string;           { Variable name / FunctionCall name }
    DVal   : Double;           { Number value }
    Left   : Integer;          { left child id, -1 = none }
    Right  : Integer;          { right child id, -1 = none }
    Args   : array[0..9]  of Integer;   { FunctionCall args (node ids) }
    NArgs  : Integer;
    Elems  : array[0..99] of Integer;   { Set element node ids }
    NElem  : Integer;
    LoOpen : Boolean;
    HiOpen : Boolean;
  end;

  TLinTerm = record
    VarName : string;
    Coef    : Integer;
  end;

var
  UltimoError : string;

{ ═══════════════════════════════════════════════════════════════
  Utilidades de parseo
  ═══════════════════════════════════════════════════════════════ }

function StrUpper(const S: string): string;
var i: Integer;
begin
  Result := S;
  for i := 1 to Length(Result) do
    if Result[i] in ['a'..'z'] then Result[i] := Chr(Ord(Result[i]) - 32);
end;

function SkipWS(const S: string; P: Integer): Integer;
begin
  while (P <= Length(S)) and (S[P] in [' ',#9,#10,#13]) do Inc(P);
  Result := P;
end;

function ReadStr(const S: string; var P: Integer): string;
begin
  Result := ''; P := SkipWS(S, P);
  if (P > Length(S)) or (S[P] <> '"') then Exit;
  Inc(P);
  while (P <= Length(S)) and (S[P] <> '"') do begin Result := Result + S[P]; Inc(P); end;
  if P <= Length(S) then Inc(P);
end;

function ReadInt(const S: string; var P: Integer): Integer;
var Neg: Boolean; Num: string; Code: Integer;
begin
  Result := 0; P := SkipWS(S, P); Neg := False;
  if (P <= Length(S)) and (S[P] = '-') then begin Neg := True; Inc(P); end;
  Num := '';
  while (P <= Length(S)) and (S[P] in ['0'..'9']) do begin Num := Num + S[P]; Inc(P); end;
  if Num = '' then Exit;
  Val(Num, Result, Code);
  if Neg then Result := -Result;
end;

function ReadFloat(const S: string; var P: Integer): Double;
var Neg: Boolean; Num: string; Code: Integer; Ch: Char;
begin
  Result := 0; P := SkipWS(S, P); Neg := False;
  if (P <= Length(S)) and (S[P] = '-') then begin Neg := True; Inc(P); end;
  Num := '';
  while P <= Length(S) do
  begin
    Ch := S[P];
    if Ch in ['0'..'9','.'] then begin Num := Num + Ch; Inc(P); end
    else if Ch in ['e','E'] then
    begin
      Num := Num + Ch; Inc(P);
      if (P <= Length(S)) and (S[P] in ['+','-']) then begin Num := Num + S[P]; Inc(P); end;
    end
    else Break;
  end;
  if Num = '' then Exit;
  Val(Num, Result, Code);
  if Code <> 0 then Result := 0;
  if Neg then Result := -Result;
end;

function ReadBoolVal(const S: string; var P: Integer): Boolean;
begin
  Result := False; P := SkipWS(S, P);
  if Copy(S,P,4) = 'true'  then begin Result := True; Inc(P,4); end
  else if Copy(S,P,5) = 'false' then Inc(P,5);
end;

{ Busca "key": y retorna posición justo después de : }
function FindKey(const S, Key: string; From: Integer): Integer;
var Pat: string; P: Integer;
begin
  Pat := '"' + Key + '":'; Result := 0; P := From;
  while P <= Length(S) - Length(Pat) + 1 do
  begin
    if Copy(S, P, Length(Pat)) = Pat then begin Result := P + Length(Pat); Exit; end;
    Inc(P);
  end;
end;

{ Extrae {...} que empieza en P o después; avanza P al siguiente char }
function ExtractBlock(const S: string; var P: Integer): string;
var Start, Level: Integer;
begin
  Result := ''; P := SkipWS(S, P);
  if (P > Length(S)) or (S[P] <> '{') then Exit;
  Start := P; Level := 0;
  while P <= Length(S) do
  begin
    if      S[P] = '{' then Inc(Level)
    else if S[P] = '}' then
    begin
      Dec(Level);
      if Level = 0 then begin Result := Copy(S,Start,P-Start+1); Inc(P); Exit; end;
    end;
    Inc(P);
  end;
end;

{ Lee array mixto (strings, números, booleans) como array de strings }
procedure ReadMixedArray(const S: string; var P: Integer;
                         var Arr: array of string; var N: Integer);
var V: string; Ch: Char;
begin
  N := 0; P := SkipWS(S, P);
  if (P > Length(S)) or (S[P] <> '[') then Exit;
  Inc(P);
  while P <= Length(S) do
  begin
    P := SkipWS(S, P);
    if (P > Length(S)) or (S[P] = ']') then Break;   { salida correcta }
    Ch := S[P];
    if Ch = '"' then
    begin
      V := ReadStr(S, P);
      if N <= High(Arr) then begin Arr[N] := V; Inc(N); end;
    end
    else if Ch in ['0'..'9','-','.'] then
    begin
      V := '';
      while (P <= Length(S)) and (S[P] in ['0'..'9','.','+','e','E','-']) do
      begin
        if (S[P] = '-') and (Length(V) > 0) and not (V[Length(V)] in ['e','E']) then Break;
        V := V + S[P]; Inc(P);
      end;
      if N <= High(Arr) then begin Arr[N] := V; Inc(N); end;
    end
    else if Copy(S,P,4) = 'true'  then begin if N<=High(Arr) then begin Arr[N]:='true';  Inc(N); end; Inc(P,4); end
    else if Copy(S,P,5) = 'false' then begin if N<=High(Arr) then begin Arr[N]:='false'; Inc(N); end; Inc(P,5); end
    else Inc(P);
  end;
  if P <= Length(S) then Inc(P);
end;

{ ═══════════════════════════════════════════════════════════════
  Label map y helpers de variables
  ═══════════════════════════════════════════════════════════════ }

function FindVarIdx(const Datos: TCSPData; const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to Datos.NVars-1 do
    if StrUpper(PChar(@Datos.Vars[i].Name)) = StrUpper(Name) then begin Result := i; Exit; end;
end;

function FindLabelInt(const Datos: TCSPData; VarIdx: Integer; const Lbl: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to Datos.NLMap-1 do
    if (Datos.LMap[i].VarIdx = VarIdx) and
       (StrUpper(Datos.LMap[i].Lbl) = StrUpper(Lbl)) then
    begin Result := Datos.LMap[i].IntVal; Exit; end;
end;

function IsRealVar(const Datos: TCSPData; const Name: string): Boolean;
begin
  Result := FindVarIdx(Datos, Name) >= 0;
end;

function LiteralToInt(const Datos: TCSPData; VarIdx: Integer; const Name: string): Integer;
var U: string;
begin
  U := StrUpper(Name);
  if U = 'TRUE'  then begin Result := 1; Exit; end;
  if U = 'FALSE' then begin Result := 0; Exit; end;
  Result := FindLabelInt(Datos, VarIdx, Name);
  if Result < 0 then Result := 0;
end;

function VarScale(const Datos: TCSPData; VI: Integer): Integer;
begin
  if (VI >= 0) and (VI < Datos.NVars) then Result := Datos.VarScales[VI]
  else Result := 1;
end;

function ScaleF(V: Double; Scale: Integer): Integer;
begin
  Result := Round(V * Scale);
end;

procedure AddCon(var Datos: TCSPData; const C: TCSPConstraint);
begin
  if Datos.NCons < MAX_CSP_CONS then begin Datos.Cons[Datos.NCons] := C; Inc(Datos.NCons); end;
end;

{ ═══════════════════════════════════════════════════════════════
  Parseo de nodos AST
  ═══════════════════════════════════════════════════════════════ }

function StrToNT(const S: string): Integer;
var U: string;
begin
  U := StrUpper(S);
  if      U = 'VARIABLE'    then Result := NT_VARIABLE
  else if U = 'NUMBER'      then Result := NT_NUMBER
  else if U = 'EQUALS'      then Result := NT_EQUALS
  else if U = 'NOTEQUALS'   then Result := NT_NOTEQUALS
  else if U = 'LESS'        then Result := NT_LESS
  else if U = 'GREATER'     then Result := NT_GREATER
  else if U = 'LESSEQ'      then Result := NT_LESSEQ
  else if U = 'GREATEREQ'   then Result := NT_GREATEREQ
  else if U = 'AND'         then Result := NT_AND
  else if U = 'OR'          then Result := NT_OR
  else if U = 'NOT'         then Result := NT_NOT
  else if U = 'ADD'         then Result := NT_ADD
  else if U = 'SUBTRACT'    then Result := NT_SUBTRACT
  else if U = 'MULTIPLY'    then Result := NT_MULTIPLY
  else if U = 'DIVIDE'      then Result := NT_DIVIDE
  else if U = 'NEGATE'      then Result := NT_NEGATE
  else if U = 'FUNCTIONCALL' then Result := NT_FUNCCALL
  else if U = 'IN'          then Result := NT_IN
  else if U = 'SET'         then Result := NT_SET
  else if U = 'INTERVAL'    then Result := NT_INTERVAL
  else Result := NT_UNKNOWN;
end;

function NTtoCT(NT: Integer): Integer;
begin
  case NT of
    NT_EQUALS:    Result := CT_EQ;
    NT_NOTEQUALS: Result := CT_NEQ;
    NT_LESS:      Result := CT_LT;
    NT_GREATER:   Result := CT_GT;
    NT_LESSEQ:    Result := CT_LE;
    NT_GREATEREQ: Result := CT_GE;
    else          Result := -1;
  end;
end;

procedure ParseNodeBlock(const Blk: string; var Node: TCSPNode);
var P, P2: Integer; TypeStr: string;
begin
  FillChar(Node, SizeOf(Node), 0);
  Node.Id := -1; Node.NType := NT_UNKNOWN; Node.Left := -1; Node.Right := -1;

  P := FindKey(Blk,'id',1);    if P>0 then Node.Id    := ReadInt(Blk,P);
  P := FindKey(Blk,'type',1);  if P>0 then begin P2:=P; TypeStr:=ReadStr(Blk,P2); Node.NType:=StrToNT(TypeStr); end;
  P := FindKey(Blk,'name',1);  if P>0 then Node.SName := ReadStr(Blk,P);
  P := FindKey(Blk,'left',1);  if P>0 then Node.Left  := ReadInt(Blk,P);
  P := FindKey(Blk,'right',1); if P>0 then Node.Right := ReadInt(Blk,P);

  P := FindKey(Blk,'value',1);
  if P>0 then
  begin
    P2 := SkipWS(Blk,P);
    if (P2 <= Length(Blk)) and (Blk[P2] in ['0'..'9','-','.']) then
      Node.DVal := ReadFloat(Blk,P2);
  end;

  P := FindKey(Blk,'lo_open',1); if P>0 then Node.LoOpen := ReadBoolVal(Blk,P);
  P := FindKey(Blk,'hi_open',1); if P>0 then Node.HiOpen := ReadBoolVal(Blk,P);

  { Interval nodes usan "lo"/"hi" como IDs de nodo en lugar de "left"/"right" }
  if Node.Left  = -1 then begin P := FindKey(Blk,'lo',1); if P>0 then Node.Left  := ReadInt(Blk,P); end;
  if Node.Right = -1 then begin P := FindKey(Blk,'hi',1); if P>0 then Node.Right := ReadInt(Blk,P); end;

  P := FindKey(Blk,'args',1);
  if P>0 then
  begin
    P2 := SkipWS(Blk,P);
    if (P2<=Length(Blk)) and (Blk[P2]='[') then
    begin
      Inc(P2); Node.NArgs := 0;
      while (P2<=Length(Blk)) and (Blk[P2]<>']') do
      begin
        P2 := SkipWS(Blk,P2);
        if Blk[P2] in ['0'..'9','-'] then
        begin
          if Node.NArgs < 10 then begin Node.Args[Node.NArgs] := ReadInt(Blk,P2); Inc(Node.NArgs); end;
        end else Inc(P2);
      end;
    end;
  end;

  P := FindKey(Blk,'elements',1);
  if P>0 then
  begin
    P2 := SkipWS(Blk,P);
    if (P2<=Length(Blk)) and (Blk[P2]='[') then
    begin
      Inc(P2); Node.NElem := 0;
      while (P2<=Length(Blk)) and (Blk[P2]<>']') do
      begin
        P2 := SkipWS(Blk,P2);
        if Blk[P2] in ['0'..'9','-'] then
        begin
          if Node.NElem < 100 then begin Node.Elems[Node.NElem] := ReadInt(Blk,P2); Inc(Node.NElem); end;
        end else Inc(P2);
      end;
    end;
  end;
end;

procedure ParseNodesArray(const CBlk: string;
                          var Tbl: array of TCSPNode; var NTbl: Integer);
var P: Integer; Blk: string; Node: TCSPNode;
begin
  NTbl := 0;
  P := FindKey(CBlk,'nodes',1);
  if P = 0 then Exit;
  P := SkipWS(CBlk,P);
  if (P>Length(CBlk)) or (CBlk[P]<>'[') then Exit;
  Inc(P);
  while (P<=Length(CBlk)) and (CBlk[P]<>']') do
  begin
    P := SkipWS(CBlk,P);
    if (P>Length(CBlk)) or (CBlk[P]=']') then Break;
    if CBlk[P]=',' then begin Inc(P); Continue; end;
    Blk := ExtractBlock(CBlk,P);
    if Blk = '' then Break;
    if NTbl < MAX_NODES then begin ParseNodeBlock(Blk,Node); Tbl[NTbl]:=Node; Inc(NTbl); end;
  end;
end;

function FindNode(const Tbl: array of TCSPNode; NTbl, Id: Integer;
                  var Found: TCSPNode): Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to NTbl-1 do
    if Tbl[i].Id = Id then begin Found := Tbl[i]; Result := True; Exit; end;
end;

{ ═══════════════════════════════════════════════════════════════
  Extractor de expresiones lineales
  ═══════════════════════════════════════════════════════════════ }

{ Recorre el AST en busca de una combinación lineal de variables.
  CoefMul: multiplicador de signo. Devuelve True si es puramente lineal. }
function ExtractLinear(const Tbl: array of TCSPNode; NTbl, NodeId, CoefMul: Integer;
                       var Terms: array of TLinTerm; var NTerms: Integer): Boolean;
var N, L, R: TCSPNode;
begin
  Result := False;
  if not FindNode(Tbl, NTbl, NodeId, N) then Exit;

  case N.NType of

    NT_VARIABLE:
    begin
      if NTerms > High(Terms) then Exit;
      Terms[NTerms].VarName := N.SName;
      Terms[NTerms].Coef    := CoefMul;
      Inc(NTerms); Result := True;
    end;

    NT_NEGATE:
    begin
      Result := ExtractLinear(Tbl,NTbl,N.Left,-CoefMul,Terms,NTerms);
    end;

    NT_ADD:
    begin
      if not FindNode(Tbl,NTbl,N.Left,L)  then Exit;
      if not FindNode(Tbl,NTbl,N.Right,R) then Exit;
      Result := ExtractLinear(Tbl,NTbl,N.Left, CoefMul,Terms,NTerms) and
                ExtractLinear(Tbl,NTbl,N.Right,CoefMul,Terms,NTerms);
    end;

    NT_SUBTRACT:
    begin
      if not FindNode(Tbl,NTbl,N.Left,L)  then Exit;
      if not FindNode(Tbl,NTbl,N.Right,R) then Exit;
      Result := ExtractLinear(Tbl,NTbl,N.Left,  CoefMul,Terms,NTerms) and
                ExtractLinear(Tbl,NTbl,N.Right,-CoefMul,Terms,NTerms);
    end;

    NT_MULTIPLY:
    begin
      if not FindNode(Tbl,NTbl,N.Left,L)  then Exit;
      if not FindNode(Tbl,NTbl,N.Right,R) then Exit;
      if (L.NType=NT_NUMBER) and (R.NType=NT_VARIABLE) then
      begin
        if NTerms > High(Terms) then Exit;
        Terms[NTerms].VarName := R.SName;
        Terms[NTerms].Coef    := CoefMul * Round(L.DVal);
        Inc(NTerms); Result := True;
      end
      else if (R.NType=NT_NUMBER) and (L.NType=NT_VARIABLE) then
      begin
        if NTerms > High(Terms) then Exit;
        Terms[NTerms].VarName := L.SName;
        Terms[NTerms].Coef    := CoefMul * Round(R.DVal);
        Inc(NTerms); Result := True;
      end;
    end;

  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Walker AST → TCSPConstraint
  ═══════════════════════════════════════════════════════════════ }

procedure WalkAST(const Tbl: array of TCSPNode; NTbl, RootId: Integer;
                  var Datos: TCSPData);
var
  Root, LN, RN, AN, SL, SR: TCSPNode;
  C     : TCSPConstraint;
  CT, VI, Scale, I, K: Integer;
  Terms : array[0..19] of TLinTerm;
  NTerms, SetN: Integer;
  SetVals: array[0..99] of Integer;
begin
  if not FindNode(Tbl,NTbl,RootId,Root) then Exit;

  { ── AND: recursión ──────────────────────────────────────────── }
  if Root.NType = NT_AND then
  begin
    WalkAST(Tbl,NTbl,Root.Left, Datos);
    WalkAST(Tbl,NTbl,Root.Right,Datos);
    Exit;
  end;

  { ── IN: pertenencia a dominio ───────────────────────────────── }
  if Root.NType = NT_IN then
  begin
    if not FindNode(Tbl,NTbl,Root.Left, LN) then Exit;
    if not FindNode(Tbl,NTbl,Root.Right,RN) then Exit;
    if LN.NType <> NT_VARIABLE then Exit;
    VI    := FindVarIdx(Datos, LN.SName);
    if VI < 0 then Exit;
    Scale := VarScale(Datos,VI);
    FillChar(C,SizeOf(C),0);
    CSPCopyName(LN.SName,C.Var1);

    if RN.NType = NT_INTERVAL then
    begin
      C.CType := CT_IN_INTERVAL;
      if FindNode(Tbl,NTbl,RN.Left,AN)  then C.Lo := ScaleF(AN.DVal,Scale);
      if FindNode(Tbl,NTbl,RN.Right,AN) then C.Hi := ScaleF(AN.DVal,Scale);
      C.LoOpen := RN.LoOpen; C.HiOpen := RN.HiOpen;
      AddCon(Datos,C);
    end
    else if RN.NType = NT_SET then
    begin
      C.CType := CT_IN_SET; SetN := 0;
      for I := 0 to RN.NElem-1 do
      begin
        if not FindNode(Tbl,NTbl,RN.Elems[I],AN) then Continue;
        if AN.NType = NT_VARIABLE then
        begin
          K := LiteralToInt(Datos,VI,AN.SName);
          if K >= 0 then begin SetVals[SetN] := K; Inc(SetN); end;
        end
        else if AN.NType = NT_NUMBER then
        begin
          SetVals[SetN] := ScaleF(AN.DVal,Scale); Inc(SetN);
        end;
      end;
      if SetN > 0 then
      begin
        C.SetSize := SetN;
        for I := 0 to SetN-1 do C.SetVals[I] := SetVals[I];
        AddCon(Datos,C);
      end;
    end;
    Exit;
  end;

  { ── Comparaciones ───────────────────────────────────────────── }
  CT := NTtoCT(Root.NType);
  if CT < 0 then Exit;   { raíz no es una comparación }

  if not FindNode(Tbl,NTbl,Root.Left, LN) then Exit;
  if not FindNode(Tbl,NTbl,Root.Right,RN) then Exit;

  { ── Caso 1: Variable OP Number | Literal | Variable ─────────── }
  if LN.NType = NT_VARIABLE then
  begin
    VI    := FindVarIdx(Datos,LN.SName);
    if VI < 0 then Exit;
    Scale := VarScale(Datos,VI);
    FillChar(C,SizeOf(C),0);
    C.CType := CT;
    CSPCopyName(LN.SName,C.Var1);
    if RN.NType = NT_NUMBER then
    begin
      C.Constant := ScaleF(RN.DVal,Scale);
      AddCon(Datos,C);
    end
    else if RN.NType = NT_VARIABLE then
    begin
      if IsRealVar(Datos,RN.SName) then
      begin
        CSPCopyName(RN.SName,C.Var2);
        AddCon(Datos,C);
      end
      else
      begin
        C.Constant := LiteralToInt(Datos,VI,RN.SName);
        AddCon(Datos,C);
      end;
    end;
    Exit;
  end;

  { ── Caso 2: Expresión lineal OP Number ──────────────────────── }
  if RN.NType = NT_NUMBER then
  begin
    NTerms := 0;
    if ExtractLinear(Tbl,NTbl,Root.Left,1,Terms,NTerms) and (NTerms > 0) then
    begin
      Scale := 1;
      for I := 0 to NTerms-1 do
      begin
        VI := FindVarIdx(Datos,Terms[I].VarName);
        if VI < 0 then begin NTerms := 0; Break; end;
        if VarScale(Datos,VI) > Scale then Scale := VarScale(Datos,VI);
      end;
      if NTerms > 0 then
      begin
        FillChar(C,SizeOf(C),0);
        case CT of
          CT_EQ:  C.CType := CT_LINEAR_EQ;
          CT_NEQ: C.CType := CT_LINEAR_NEQ;
          CT_LT:  C.CType := CT_LINEAR_LT;
          CT_GT:  C.CType := CT_LINEAR_GT;
          CT_LE:  C.CType := CT_LINEAR_LE;
          CT_GE:  C.CType := CT_LINEAR_GE;
          else    C.CType := CT_LINEAR_EQ;
        end;
        C.LinNVars := NTerms;
        for I := 0 to NTerms-1 do
        begin
          CSPCopyName(Terms[I].VarName,C.LinVars[I]);
          C.LinCoefs[I] := Terms[I].Coef;
        end;
        C.LinRHS := ScaleF(RN.DVal,Scale);
        AddCon(Datos,C);
        Exit;
      end;
    end;
  end;

  { ── Caso 3: FunctionCall(ABS) OP Number ─────────────────────── }
  if (LN.NType = NT_FUNCCALL) and (StrUpper(LN.SName) = 'ABS') and
     (LN.NArgs = 1) and (RN.NType = NT_NUMBER) then
  begin
    if not FindNode(Tbl,NTbl,LN.Args[0],AN) then Exit;

    { abs(V) OP K }
    if AN.NType = NT_VARIABLE then
    begin
      VI    := FindVarIdx(Datos,AN.SName);
      Scale := VarScale(Datos,VI);
      FillChar(C,SizeOf(C),0);
      CSPCopyName(AN.SName,C.Var1);
      case CT of
        CT_EQ: C.CType := CT_ABS_EQ;
        CT_LE: C.CType := CT_ABS_LE;
        CT_GE: C.CType := CT_ABS_GE;
        else Exit;
      end;
      C.Constant := ScaleF(RN.DVal,Scale);
      AddCon(Datos,C);
      Exit;
    end;

    { abs(Subtract(...)) OP K }
    if AN.NType = NT_SUBTRACT then
    begin
      if not FindNode(Tbl,NTbl,AN.Left, SL) then Exit;
      if not FindNode(Tbl,NTbl,AN.Right,SR) then Exit;

      { abs(V - K_const) OP thresh → CT_IN_INTERVAL [K-thresh, K+thresh] }
      if (SL.NType = NT_VARIABLE) and (SR.NType = NT_NUMBER) then
      begin
        VI    := FindVarIdx(Datos,SL.SName);
        Scale := VarScale(Datos,VI);
        FillChar(C,SizeOf(C),0);
        C.CType := CT_IN_INTERVAL;
        CSPCopyName(SL.SName,C.Var1);
        C.Lo := ScaleF(SR.DVal - RN.DVal, Scale);
        C.Hi := ScaleF(SR.DVal + RN.DVal, Scale);
        AddCon(Datos,C);
        Exit;
      end;

      { abs(V1 - V2) OP K → CT_DIST_* }
      if (SL.NType = NT_VARIABLE) and (SR.NType = NT_VARIABLE) and
         IsRealVar(Datos,SR.SName) then
      begin
        VI    := FindVarIdx(Datos,SL.SName);
        Scale := VarScale(Datos,VI);
        FillChar(C,SizeOf(C),0);
        CSPCopyName(SL.SName,C.Var1);
        CSPCopyName(SR.SName,C.Var2);
        case CT of
          CT_EQ: C.CType := CT_DIST_EQ;
          CT_LE: C.CType := CT_DIST_LE;
          CT_GE: C.CType := CT_DIST_GE;
          else Exit;
        end;
        C.Constant := ScaleF(RN.DVal,Scale);
        AddCon(Datos,C);
        Exit;
      end;
    end;
  end;

  { patrón no reconocido }
  WriteLn(StdErr, '  [UCSPJson] patrón no mapeado (root.NType=', Root.NType,
          ') — skipped');
end;

{ ═══════════════════════════════════════════════════════════════
  API pública
  ═══════════════════════════════════════════════════════════════ }

function ObtenerErrorCSPJson: string;
begin Result := UltimoError; end;

function LeerCSPJson(const NombreArchivo: string; var Datos: TCSPData): Boolean;
var
  F          : Text;
  Todo, Linea, Bloque, Nombre, TypeStr: string;
  StrArr     : array[0..63] of string;
  N, P, PA, I, VI, K: Integer;
  MinI, MaxI, Code: Integer;
  MinF, MaxF, VLo, VHi: Double;
  C          : TCSPConstraint;
  NodeTbl    : array[0..MAX_NODES-1] of TCSPNode;
  NTbl, RootId: Integer;
begin
  Result := False;
  UltimoError := '';
  FillChar(Datos, SizeOf(Datos), 0);

  Assign(F, NombreArchivo);
  {$I-} Reset(F); {$I+}
  if IOResult <> 0 then begin UltimoError := 'No se puede abrir: ' + NombreArchivo; Exit; end;
  Todo := '';
  while not EOF(F) do begin ReadLn(F,Linea); Todo := Todo + Linea + ' '; end;
  Close(F);

  { ── variables ───────────────────────────────────────────────── }
  P := FindKey(Todo,'variables',1);
  if P = 0 then begin UltimoError := '"variables" no encontrado'; Exit; end;
  P := SkipWS(Todo,P);
  if (P > Length(Todo)) or (Todo[P] <> '[') then begin UltimoError := '"variables" debe ser array'; Exit; end;
  Inc(P);

  while (P <= Length(Todo)) and (Todo[P] <> ']') do
  begin
    P := SkipWS(Todo,P);
    if (P > Length(Todo)) or (Todo[P] = ']') then Break;
    if Todo[P] = ',' then begin Inc(P); Continue; end;
    Bloque := ExtractBlock(Todo,P);
    if Bloque = '' then Break;
    if Datos.NVars >= MAX_CSP_VARS then Break;

    Nombre := ''; TypeStr := '';
    PA := FindKey(Bloque,'name',1); if PA>0 then Nombre  := ReadStr(Bloque,PA);
    PA := FindKey(Bloque,'type',1); if PA>0 then TypeStr := ReadStr(Bloque,PA);
    if Nombre = '' then Continue;

    VI := Datos.NVars;
    Datos.VarTypes[VI] := TypeStr;

    if TypeStr = 'boolean' then
    begin
      PA := FindKey(Bloque,'value',1); N := 0;
      if PA > 0 then ReadMixedArray(Bloque,PA,StrArr,N);
      MinI := 1; MaxI := 0;
      for I := 0 to N-1 do
        if StrArr[I] = 'true'  then begin if 1 < MinI then MinI:=1; if 1 > MaxI then MaxI:=1; end
        else if StrArr[I] = 'false' then begin if 0 < MinI then MinI:=0; if 0 > MaxI then MaxI:=0; end;
      if MinI > MaxI then begin MinI := 0; MaxI := 1; end;
      Datos.Vars[VI] := CSPMakeVar(Nombre, MinI, MaxI);
      Datos.VarScales[VI] := 1;

      if N > 0 then
      begin
        FillChar(C,SizeOf(C),0); C.CType := CT_IN_SET;
        CSPCopyName(Nombre,C.Var1); C.SetSize := 0;
        for I := 0 to N-1 do
          if StrArr[I] = 'true'  then begin C.SetVals[C.SetSize] := 1; Inc(C.SetSize); end
          else if StrArr[I] = 'false' then begin C.SetVals[C.SetSize] := 0; Inc(C.SetSize); end;
        if C.SetSize > 0 then AddCon(Datos,C);
      end;
    end

    else if TypeStr = 'integer' then
    begin
      PA := FindKey(Bloque,'domain',1); N := 0;
      if PA > 0 then ReadMixedArray(Bloque,PA,StrArr,N);
      MinI := MaxInt; MaxI := -MaxInt;
      for I := 0 to N-1 do
      begin
        Val(StrArr[I],K,Code);
        if Code = 0 then begin if K < MinI then MinI:=K; if K > MaxI then MaxI:=K; end;
      end;
      if MinI > MaxI then begin MinI := 0; MaxI := 0; end;
      Datos.Vars[VI] := CSPMakeVar(Nombre,MinI,MaxI);
      Datos.VarScales[VI] := 1;

      PA := FindKey(Bloque,'value',1); N := 0;
      if PA > 0 then ReadMixedArray(Bloque,PA,StrArr,N);
      if N > 0 then
      begin
        FillChar(C,SizeOf(C),0); C.CType := CT_IN_SET;
        CSPCopyName(Nombre,C.Var1); C.SetSize := 0;
        for I := 0 to N-1 do
        begin
          Val(StrArr[I],K,Code);
          if Code = 0 then begin C.SetVals[C.SetSize] := K; Inc(C.SetSize); end;
        end;
        if C.SetSize > 0 then AddCon(Datos,C);
      end;
    end

    else if TypeStr = 'set' then
    begin
      PA := FindKey(Bloque,'domain',1); N := 0;
      if PA > 0 then ReadMixedArray(Bloque,PA,StrArr,N);
      for I := 0 to N-1 do
        if Datos.NLMap < MAX_LABELS then
        begin
          Datos.LMap[Datos.NLMap].VarIdx := VI;
          Datos.LMap[Datos.NLMap].Lbl    := StrArr[I];
          Datos.LMap[Datos.NLMap].IntVal := I;
          Inc(Datos.NLMap);
        end;
      Datos.Vars[VI] := CSPMakeVar(Nombre, 0, N-1);
      Datos.VarScales[VI] := 1;

      PA := FindKey(Bloque,'value',1); N := 0;
      if PA > 0 then ReadMixedArray(Bloque,PA,StrArr,N);
      if N > 0 then
      begin
        FillChar(C,SizeOf(C),0); C.CType := CT_IN_SET;
        CSPCopyName(Nombre,C.Var1); C.SetSize := 0;
        for I := 0 to N-1 do
        begin
          K := FindLabelInt(Datos,VI,StrArr[I]);
          if K >= 0 then begin C.SetVals[C.SetSize] := K; Inc(C.SetSize); end;
        end;
        if C.SetSize > 0 then AddCon(Datos,C);
      end;
    end

    else if TypeStr = 'numeric' then
    begin
      Datos.VarScales[VI] := SCALE_NUM;
      PA := FindKey(Bloque,'domain',1); N := 0;
      if PA > 0 then ReadMixedArray(Bloque,PA,StrArr,N);
      MinF := 0; MaxF := 0;
      if N >= 1 then Val(StrArr[0],MinF,Code);
      if N >= 2 then Val(StrArr[1],MaxF,Code);
      Datos.Vars[VI] := CSPMakeVar(Nombre,Round(MinF*SCALE_NUM),Round(MaxF*SCALE_NUM));

      PA := FindKey(Bloque,'value',1); N := 0;
      if PA > 0 then ReadMixedArray(Bloque,PA,StrArr,N);
      if N >= 2 then
      begin
        VLo := 0; VHi := 0;
        Val(StrArr[0],VLo,Code); Val(StrArr[1],VHi,Code);
        FillChar(C,SizeOf(C),0); C.CType := CT_IN_INTERVAL;
        CSPCopyName(Nombre,C.Var1);
        C.Lo := Round(VLo*SCALE_NUM); C.Hi := Round(VHi*SCALE_NUM);
        AddCon(Datos,C);
      end;
    end

    else
    begin
      Datos.Vars[VI] := CSPMakeVar(Nombre,0,0);
      Datos.VarScales[VI] := 1;
    end;

    Inc(Datos.NVars);
  end;

  if Datos.NVars = 0 then begin UltimoError := 'Sin variables'; Exit; end;

  { ── constraints (AST) ───────────────────────────────────────── }
  P := FindKey(Todo,'constraints',1);
  if P = 0 then begin Result := True; Exit; end;
  P := SkipWS(Todo,P);
  if (P > Length(Todo)) or (Todo[P] <> '[') then begin Result := True; Exit; end;
  Inc(P);

  while (P <= Length(Todo)) and (Todo[P] <> ']') do
  begin
    P := SkipWS(Todo,P);
    if (P > Length(Todo)) or (Todo[P] = ']') then Break;
    if Todo[P] = ',' then begin Inc(P); Continue; end;
    Bloque := ExtractBlock(Todo,P);
    if Bloque = '' then Break;

    PA := FindKey(Bloque,'root',1);
    if PA = 0 then Continue;
    RootId := ReadInt(Bloque,PA);

    ParseNodesArray(Bloque,NodeTbl,NTbl);
    if NTbl = 0 then Continue;

    WalkAST(NodeTbl,NTbl,RootId,Datos);
  end;

  Result := True;
end;

end.
