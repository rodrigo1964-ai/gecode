program CSPEval;

{$mode objfpc}{$H+}

(*
 * CSPEval.pas
 *
 * Evaluador/propagador CSP sobre el grafo generado por JsonToGraph.
 *
 * Entrada : JSON de grafo (salida de JsonToGraph)
 * Salida  : JSON con dominios reducidos y status
 *
 * Algoritmo:
 *   Repetir (max MAX_ITER veces):
 *     Para cada constraint: propagar → reducir dominios
 *     Si algún dominio quedó vacío → "contradiction"
 *     Si no hubo cambios → punto fijo
 *   Si todos los dominios son singleton → "solved"
 *   En otro caso → "ok" (reducción parcial)
 *
 * Tipos de variable:
 *   Numeric  → intervalo [lo, hi], propagación con IvXxx
 *   Integer  → conjunto discreto de números; lo/hi = extremos activos
 *   Boolean  → subconjunto de {true, false}
 *   set      → subconjunto de etiquetas string
 *
 * Uso:
 *   ./CSPEval graph.json [output.json]
 *)

uses
  MiniSys, MiniJSON, ExpressionAST, PrattParser, MiniMath;

const
  MAX_ITER = 200;
  BIG      = 1.0e300;   { ±BIG reemplaza ±Inf en intervalos }

// ── Tipos runtime ────────────────────────────────────────────────────────────

type
  TVarKind = (vkNumeric, vkInteger, vkBoolean, vkSet, vkUnknown);

  TRTVar = record
    Id:      Integer;
    Name:    string;          { uppercase }
    Kind:    TVarKind;
    { Numeric / Integer — intervalo de bounds activos }
    Lo, Hi:  Double;
    { Discrete — etiquetas del dominio declarado + flags activos }
    Labels:  array of string;
    LabelN:  Integer;
    Active:  array of Boolean;
    { Estado }
    Changed: Boolean;
    Empty:   Boolean;
  end;

// ── Variables globales ────────────────────────────────────────────────────────

var
  Vars:     array of TRTVar;
  VarCount: Integer;

  CstrExprs: array of string;   { expr string de cada constraint }
  CstrCount: Integer;

// ── Helper: JSON value → string de etiqueta ──────────────────────────────────
{ TJSONBoolean.AsString no está implementado en MiniJSON (devuelve '').
  Esta función normaliza cualquier valor JSON a una etiqueta string. }
function JToLabel(V: TJSONValue): string;
begin
  if V is TJSONBoolean then
  begin
    if TJSONBoolean(V).Value then Result := 'true'
    else                          Result := 'false';
  end
  else
    Result := V.AsString;
end;

// ── Tabla de variables ────────────────────────────────────────────────────────

function FindVar(const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to VarCount - 1 do
    if Vars[i].Name = UpperCase(Name) then begin Result := i; Exit; end;
end;

function ParseKind(const S: string): TVarKind;
begin
  case UpperCase(S) of
    'NUMERIC': Result := vkNumeric;
    'INTEGER': Result := vkInteger;
    'BOOLEAN': Result := vkBoolean;
    'SET':     Result := vkSet;
  else         Result := vkUnknown;
  end;
end;

// ── Modificación de dominio ───────────────────────────────────────────────────

procedure MarkEmpty(VIdx: Integer);
begin
  Vars[VIdx].Empty   := True;
  Vars[VIdx].Changed := True;
end;

{ Actualiza Lo/Hi a partir de etiquetas activas (para Integer) }
procedure RefreshIntegerBounds(VIdx: Integer);
var i: Integer; V: Double; OK: Boolean; first: Boolean;
begin
  first := True;
  OK    := False;
  for i := 0 to Vars[VIdx].LabelN - 1 do
    if Vars[VIdx].Active[i] then
    begin
      OK := True;
      if TryStrToFloat(Vars[VIdx].Labels[i], V, '.') then
      begin
        if first then begin Vars[VIdx].Lo := V; Vars[VIdx].Hi := V; first := False; end
        else begin
          if V < Vars[VIdx].Lo then Vars[VIdx].Lo := V;
          if V > Vars[VIdx].Hi then Vars[VIdx].Hi := V;
        end;
      end;
    end;
  if not OK then MarkEmpty(VIdx);
end;

{ Narrow Numeric lo — devuelve True si cambió }
function NarrowLo(VIdx: Integer; NewLo: Double): Boolean;
begin
  Result := False;
  if Vars[VIdx].Kind = vkUnknown then Exit;
  if NewLo > Vars[VIdx].Lo then
  begin
    Vars[VIdx].Lo      := NewLo;
    Vars[VIdx].Changed := True;
    Result             := True;
    if Vars[VIdx].Lo > Vars[VIdx].Hi then MarkEmpty(VIdx);
  end;
end;

{ Narrow Numeric hi — devuelve True si cambió }
function NarrowHi(VIdx: Integer; NewHi: Double): Boolean;
begin
  Result := False;
  if Vars[VIdx].Kind = vkUnknown then Exit;
  if NewHi < Vars[VIdx].Hi then
  begin
    Vars[VIdx].Hi      := NewHi;
    Vars[VIdx].Changed := True;
    Result             := True;
    if Vars[VIdx].Lo > Vars[VIdx].Hi then MarkEmpty(VIdx);
  end;
end;

{ Narrow discrete: dejar solo etiquetas cuyo Upper = TargetUp }
procedure NarrowDiscreteToLabel(VIdx: Integer; const TargetUp: string);
var i: Integer; anyActive: Boolean;
begin
  anyActive := False;
  for i := 0 to Vars[VIdx].LabelN - 1 do
    if Vars[VIdx].Active[i] then
    begin
      if UpperCase(Vars[VIdx].Labels[i]) <> TargetUp then
      begin
        Vars[VIdx].Active[i] := False;
        Vars[VIdx].Changed   := True;
      end
      else
        anyActive := True;
    end;
  if not anyActive then MarkEmpty(VIdx);
  if Vars[VIdx].Kind = vkInteger then RefreshIntegerBounds(VIdx);
end;

{ Narrow Integer: desactivar los que no cumplen la comparación con Val }
procedure NarrowIntegerOp(VIdx: Integer; Op: TASTNodeType; Val: Double);
var i: Integer; V: Double; anyActive, deactivated: Boolean;
begin
  anyActive   := False;
  deactivated := False;
  for i := 0 to Vars[VIdx].LabelN - 1 do
    if Vars[VIdx].Active[i] then
    begin
      if not TryStrToFloat(Vars[VIdx].Labels[i], V, '.') then Continue;
      case Op of
        ntGreaterEq: if V < Val  then begin Vars[VIdx].Active[i] := False; deactivated := True; end else anyActive := True;
        ntGreater:   if V <= Val then begin Vars[VIdx].Active[i] := False; deactivated := True; end else anyActive := True;
        ntLessEq:    if V > Val  then begin Vars[VIdx].Active[i] := False; deactivated := True; end else anyActive := True;
        ntLess:      if V >= Val then begin Vars[VIdx].Active[i] := False; deactivated := True; end else anyActive := True;
        ntEquals:    if V <> Val then begin Vars[VIdx].Active[i] := False; deactivated := True; end else anyActive := True;
      else anyActive := True;
      end;
    end;
  if deactivated then Vars[VIdx].Changed := True;
  if not anyActive then MarkEmpty(VIdx)
  else if deactivated then RefreshIntegerBounds(VIdx);
end;

// ── Evaluación de intervalo (forward) ────────────────────────────────────────

function EvalIv(Node: TASTNode): TInterval; forward;

function EvalIv(Node: TASTNode): TInterval;
var
  vid:  Integer;
  L, R: TInterval;
begin
  Result := IvMake(0.0, 0.0);
  if Node = nil then begin Result := IvMake(-BIG, BIG); Exit; end;

  case Node.NodeType of

    ntNumber:
      Result := IvMake(TNumberNode(Node).Value, TNumberNode(Node).Value);

    ntBoolean:
      if TBooleanNode(Node).Value then Result := IvMake(1.0, 1.0)
      else                             Result := IvMake(0.0, 0.0);

    ntVariable:
    begin
      vid := FindVar(TVariableNode(Node).Name);
      if vid >= 0 then
        Result := IvMake(Vars[vid].Lo, Vars[vid].Hi)
      else
        Result := IvMake(-BIG, BIG);   { literal desconocido }
    end;

    ntNegate:
    begin
      L := EvalIv(TUnaryOpNode(Node).Operand);
      Result := IvScale(L, -1.0);
    end;

    ntAdd:
    begin
      L := EvalIv(TBinaryOpNode(Node).Left);
      R := EvalIv(TBinaryOpNode(Node).Right);
      Result := IvAdd(L, R);
    end;

    ntSubtract:
    begin
      L := EvalIv(TBinaryOpNode(Node).Left);
      R := EvalIv(TBinaryOpNode(Node).Right);
      Result := IvSub(L, R);
    end;

    ntMultiply:
    begin
      L := EvalIv(TBinaryOpNode(Node).Left);
      R := EvalIv(TBinaryOpNode(Node).Right);
      Result := IvMul(L, R);
    end;

    ntDivide:
    begin
      L := EvalIv(TBinaryOpNode(Node).Left);
      R := EvalIv(TBinaryOpNode(Node).Right);
      Result := IvDiv(L, R);
    end;

  else
    Result := IvMake(-BIG, BIG);
  end;
end;

// ── Propagación de una constraint ────────────────────────────────────────────

{ Aplica la propagación hacia un Variable en el lado Left de una comparación }
procedure ApplyLeft(VIdx: Integer; Op: TASTNodeType; RIv: TInterval);
begin
  case Vars[VIdx].Kind of

    vkNumeric:
    begin
      case Op of
        ntEquals:    begin NarrowLo(VIdx, RIv.Lo); NarrowHi(VIdx, RIv.Hi); end;
        ntGreaterEq: NarrowLo(VIdx, RIv.Lo);
        ntGreater:   NarrowLo(VIdx, RIv.Lo);
        ntLessEq:    NarrowHi(VIdx, RIv.Hi);
        ntLess:      NarrowHi(VIdx, RIv.Hi);
      end;
    end;

    vkInteger:
      NarrowIntegerOp(VIdx, Op, RIv.Lo);   { RIv.Lo = RIv.Hi si es constante }

  end;
end;

{ Aplica la propagación hacia un Variable en el lado Right (operación invertida) }
procedure ApplyRight(VIdx: Integer; Op: TASTNodeType; LIv: TInterval);
var InvOp: TASTNodeType;
begin
  { Invertir la dirección }
  case Op of
    ntGreaterEq: InvOp := ntLessEq;
    ntGreater:   InvOp := ntLess;
    ntLessEq:    InvOp := ntGreaterEq;
    ntLess:      InvOp := ntGreater;
  else           InvOp := Op;   { Equals / NotEquals son simétricos }
  end;
  ApplyLeft(VIdx, InvOp, LIv);
end;

procedure PropagateConstraint(const Expr: string);
var
  Parser:     TPrattParser;
  Root, LHS, RHS: TASTNode;
  Op:         TASTNodeType;
  LIv, RIv:   TInterval;
  vidL, vidR: Integer;
  LabelUp:    string;
begin
  Parser := TPrattParser.Create(Expr);
  try
    try
      Root := Parser.Parse;
      try
        { Solo procesamos comparaciones binarias en el root }
        if not (Root.NodeType in [ntEquals, ntNotEquals,
                                  ntLess, ntGreater,
                                  ntLessEq, ntGreaterEq]) then Exit;

        LHS := TBinaryOpNode(Root).Left;
        RHS := TBinaryOpNode(Root).Right;
        Op  := Root.NodeType;

        { ── Caso discreto: var = literal (Boolean / set) ── }
        if (Op = ntEquals) and
           (LHS.NodeType = ntVariable) and
           (RHS.NodeType = ntVariable) then
        begin
          vidL := FindVar(TVariableNode(LHS).Name);
          vidR := FindVar(TVariableNode(RHS).Name);

          { Lado izquierdo es variable set/boolean, lado derecho es literal }
          if (vidL >= 0) and (vidR < 0) and
             (Vars[vidL].Kind in [vkBoolean, vkSet]) then
          begin
            LabelUp := UpperCase(TVariableNode(RHS).Name);
            NarrowDiscreteToLabel(vidL, LabelUp);
            Exit;
          end;
          { Lado derecho es variable set/boolean, lado izquierdo es literal }
          if (vidR >= 0) and (vidL < 0) and
             (Vars[vidR].Kind in [vkBoolean, vkSet]) then
          begin
            LabelUp := UpperCase(TVariableNode(LHS).Name);
            NarrowDiscreteToLabel(vidR, LabelUp);
            Exit;
          end;
        end;

        { ── Caso numérico/integer: evaluar ambos lados como intervalos ── }
        LIv := EvalIv(LHS);
        RIv := EvalIv(RHS);

        { Verificar consistencia global }
        if Op = ntEquals then
        begin
          if IvIsEmpty(IvIntersect(LIv, RIv)) = 1 then
          begin
            { Dominios disjuntos: marcar vacío si algún lado es un var simple }
            if LHS.NodeType = ntVariable then
            begin
              vidL := FindVar(TVariableNode(LHS).Name);
              if vidL >= 0 then MarkEmpty(vidL);
            end;
            Exit;
          end;
        end;

        { Propagar al lado izquierdo si es una variable }
        if LHS.NodeType = ntVariable then
        begin
          vidL := FindVar(TVariableNode(LHS).Name);
          if vidL >= 0 then ApplyLeft(vidL, Op, RIv);
        end;

        { Propagar al lado derecho si es una variable }
        if RHS.NodeType = ntVariable then
        begin
          vidR := FindVar(TVariableNode(RHS).Name);
          if vidR >= 0 then ApplyRight(vidR, Op, LIv);
        end;

        { Si LHS es expresión con una sola variable (e.g. x*2), propagamos }
        { hacia esa variable usando la evaluación inversa sobre RIv          }
        { Caso: var = expr  →  ya cubierto con ApplyLeft cuando LHS=Variable }
        { Para expresiones más complejas, se necesitaría HC4 completo. }

      finally
        Root.Free;
      end;
    except
      { Error de parseo: ignorar esta constraint }
    end;
  finally
    Parser.Free;
  end;
end;

// ── Carga de datos desde JSON ─────────────────────────────────────────────────

procedure LoadGraph(JRoot: TJSONObject);
var
  VarsJ, CstrsJ: TJSONValue;
  VArr, CArr:    TJSONArray;
  VObj, CObj:    TJSONObject;
  ValJ, DomJ:    TJSONValue;
  ValArr, DomArr: TJSONArray;
  i, k, m:       Integer;
  ValLabel: string;
  VarD:     Double;
begin
  { ── Variables ── }
  VarsJ := JRoot.Find('variables');
  if (VarsJ = nil) or not (VarsJ is TJSONArray) then Exit;
  VArr := TJSONArray(VarsJ);

  SetLength(Vars, VArr.Count + 4);
  VarCount := 0;

  for i := 0 to VArr.Count - 1 do
  begin
    if not (VArr[i] is TJSONObject) then Continue;
    VObj := TJSONObject(VArr[i]);

    with Vars[VarCount] do
    begin
      Id   := i;
      Name := UpperCase(VObj.GetStr('name', ''));
      Kind := ParseKind(VObj.GetStr('type', ''));

      DomJ := VObj.Find('domain');
      ValJ := VObj.Find('value');

      if (DomJ = nil) or not (DomJ is TJSONArray) then
      begin
        Changed := False; Empty := True; Inc(VarCount); Continue;
      end;
      DomArr := TJSONArray(DomJ);

      case Kind of

        vkNumeric:
        begin
          { domain [lo, hi]; value [lo, hi] }
          Lo := -BIG; Hi := BIG;
          if DomArr.Count >= 2 then
          begin
            Lo := DomArr[0].AsFloat;
            Hi := DomArr[1].AsFloat;
          end;
          if (ValJ <> nil) and (ValJ is TJSONArray) and
             (TJSONArray(ValJ).Count >= 2) then
          begin
            Lo := TJSONArray(ValJ)[0].AsFloat;
            Hi := TJSONArray(ValJ)[1].AsFloat;
          end;
          Changed := False; Empty := (Lo > Hi);
        end;

        vkInteger, vkBoolean, vkSet:
        begin
          { Inicializar labels desde domain }
          LabelN := DomArr.Count;
          SetLength(Labels, LabelN);
          SetLength(Active, LabelN);

          for k := 0 to LabelN - 1 do
          begin
            Labels[k] := JToLabel(DomArr[k]);
            Active[k] := False;  { por defecto inactivo }
          end;

          { Activar los que están en value }
          if (ValJ <> nil) and (ValJ is TJSONArray) then
          begin
            ValArr := TJSONArray(ValJ);
            for k := 0 to ValArr.Count - 1 do
            begin
              ValLabel := JToLabel(ValArr[k]);
              for m := 0 to LabelN - 1 do
                if UpperCase(Labels[m]) = UpperCase(ValLabel) then
                  Active[m] := True;
            end;
          end
          else
          begin
            { Sin value: activar todos }
            for k := 0 to LabelN - 1 do Active[k] := True;
          end;

          { Inicializar Lo/Hi para Integer desde activos }
          Lo := BIG; Hi := -BIG;
          if Kind = vkInteger then
          begin
            for k := 0 to LabelN - 1 do
              if Active[k] then
              begin
                if TryStrToFloat(Labels[k], VarD, '.') then
                begin
                  if VarD < Lo then Lo := VarD;
                  if VarD > Hi then Hi := VarD;
                end;
              end;
            if Lo > Hi then begin Lo := 0; Hi := 0; Empty := True; end;
          end;

          Changed := False;
          Empty   := False;
        end;

      else
        Changed := False; Empty := False;
        Lo := -BIG; Hi := BIG;
      end;
    end;
    Inc(VarCount);
  end;

  { ── Constraints ── }
  CstrsJ := JRoot.Find('constraints');
  if (CstrsJ = nil) or not (CstrsJ is TJSONArray) then Exit;
  CArr := TJSONArray(CstrsJ);

  SetLength(CstrExprs, CArr.Count + 4);
  CstrCount := 0;
  for i := 0 to CArr.Count - 1 do
  begin
    if not (CArr[i] is TJSONObject) then Continue;
    CObj := TJSONObject(CArr[i]);
    CstrExprs[CstrCount] := CObj.GetStr('expr', '');
    Inc(CstrCount);
  end;
end;

// ── Comprobaciones de estado ──────────────────────────────────────────────────

function AnyEmpty: Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to VarCount - 1 do
    if Vars[i].Empty then begin Result := True; Exit; end;
end;

function AnyChanged: Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to VarCount - 1 do
    if Vars[i].Changed then begin Result := True; Exit; end;
end;

procedure ClearChanged;
var i: Integer;
begin
  for i := 0 to VarCount - 1 do Vars[i].Changed := False;
end;

function IsSingleton(VIdx: Integer): Boolean;
var i, cnt: Integer;
begin
  case Vars[VIdx].Kind of
    vkNumeric: Result := (Vars[VIdx].Lo = Vars[VIdx].Hi);
    vkInteger, vkBoolean, vkSet:
    begin
      cnt := 0;
      for i := 0 to Vars[VIdx].LabelN - 1 do
        if Vars[VIdx].Active[i] then Inc(cnt);
      Result := (cnt = 1);
    end;
  else Result := False;
  end;
end;

function AllSolved: Boolean;
var i: Integer;
begin
  Result := True;
  for i := 0 to VarCount - 1 do
    if not IsSingleton(i) then begin Result := False; Exit; end;
end;

// ── Construcción de salida JSON ───────────────────────────────────────────────

function BuildDomainArray(VIdx: Integer): TJSONArray;
var Arr: TJSONArray; i: Integer;
begin
  Arr := TJSONArray.Create;
  case Vars[VIdx].Kind of
    vkNumeric:
    begin
      Arr.AddNum(Vars[VIdx].Lo);
      Arr.AddNum(Vars[VIdx].Hi);
    end;
    vkInteger, vkBoolean, vkSet:
    begin
      for i := 0 to Vars[VIdx].LabelN - 1 do
        if Vars[VIdx].Active[i] then
          Arr.AddStr(Vars[VIdx].Labels[i]);
    end;
  end;
  Result := Arr;
end;

function BuildOutput(const Status: string; Iterations: Integer): TJSONObject;
var
  Root, VObj: TJSONObject;
  VArr:       TJSONArray;
  i:          Integer;
begin
  Root := TJSONObject.Create;
  Root.AddStr('status',     Status);
  Root.AddNum('iterations', Iterations);

  VArr := TJSONArray.Create;
  for i := 0 to VarCount - 1 do
  begin
    VObj := TJSONObject.Create;
    VObj.AddNum('id',       Vars[i].Id);
    VObj.AddStr('name',     Vars[i].Name);
    VObj.AddBool('empty',   Vars[i].Empty);
    VObj.AddBool('solved',  IsSingleton(i));
    VObj.Add('domain', BuildDomainArray(i));
    VArr.Add(VObj);
  end;
  Root.Add('variables', VArr);

  Result := Root;
end;

// ── Main ─────────────────────────────────────────────────────────────────────

var
  InFile, OutFile: string;
  RawBuf:          array of Byte;
  RawStr:          string;
  F:               file;
  TF:              TextFile;
  FSize:           Int64;
  JData:           TJSONValue;
  JRoot:           TJSONObject;
  OutRoot:         TJSONObject;
  OutStr:          string;
  Iter, j:         Integer;
  Status:          string;

begin
  DefaultFormatSettings.DecimalSeparator := '.';

  if ParamCount < 1 then
  begin
    WriteLn('Uso: CSPEval graph.json [output.json]');
    Halt(0);
  end;

  InFile  := ParamStr(1);
  OutFile := '';
  if ParamCount >= 2 then OutFile := ParamStr(2);

  if not FileExists(InFile) then
  begin
    WriteLn('Error: archivo no encontrado: ', InFile);
    Halt(1);
  end;

  { Leer archivo }
  AssignFile(F, InFile);
  Reset(F, 1);
  FSize := FileSize(F);
  SetLength(RawBuf, FSize);
  BlockRead(F, RawBuf[0], FSize);
  CloseFile(F);
  SetLength(RawStr, FSize);
  Move(RawBuf[0], RawStr[1], FSize);

  JData := ParseJSON(RawStr);
  try
    if not (JData is TJSONObject) then
      raise Exception.Create('El JSON raíz debe ser un objeto');
    JRoot := TJSONObject(JData);

    { Cargar variables y constraints }
    LoadGraph(JRoot);

    { ── Bucle de propagación ── }
    Iter   := 0;
    Status := 'ok';

    repeat
      ClearChanged;
      for j := 0 to CstrCount - 1 do
        if CstrExprs[j] <> '' then
          PropagateConstraint(CstrExprs[j]);
      Inc(Iter);
      if AnyEmpty then begin Status := 'contradiction'; Break; end;
      if not AnyChanged then Break;
    until Iter >= MAX_ITER;

    if (Status = 'ok') and AllSolved then
      Status := 'solved';

    { Construir salida }
    OutRoot := BuildOutput(Status, Iter);
    OutStr  := OutRoot.ToJSON(1);
    OutRoot.Free;

    if OutFile <> '' then
    begin
      AssignFile(TF, OutFile);
      Rewrite(TF);
      Write(TF, OutStr);
      CloseFile(TF);
      WriteLn('Escrito: ', OutFile,
              '  status=', Status, '  iter=', Iter);
    end
    else
      WriteLn(OutStr);

  finally
    JData.Free;
  end;
end.
