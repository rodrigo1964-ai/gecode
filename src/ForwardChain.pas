program ForwardChain;

{$mode objfpc}{$H+}

(*
 * ForwardChain.pas
 *
 * Forward chaining (encadenamiento hacia adelante) con trazado completo.
 *
 * Entrada : JSON de grafo (salida de JsonToGraph)
 * Salida  : JSON con la secuencia de pasos del razonamiento + dominios finales
 *
 * Estructura de salida:
 * {
 *   "status":     "ok" | "solved" | "contradiction",
 *   "iterations": N,
 *   "steps":      [ { iteration, constraint, variable, action, from, to } ],
 *   "variables":  [ { id, name, solved, empty, domain } ]
 * }
 *
 * Uso:
 *   ./ForwardChain graph.json [output.json]
 *)

uses
  MiniSys, MiniJSON, ExpressionAST, PrattParser, MiniMath;

const
  MAX_ITER = 200;
  BIG      = 1.0e300;

// ── Tipos de variable en tiempo de ejecución ──────────────────────────────────

type
  TVarKind = (vkNumeric, vkInteger, vkBoolean, vkSet, vkUnknown);

  TRTVar = record
    Id:      Integer;
    Name:    string;
    Kind:    TVarKind;
    Lo, Hi:  Double;
    Labels:  array of string;
    LabelN:  Integer;
    Active:  array of Boolean;
    Changed: Boolean;
    Empty:   Boolean;
  end;

// ── Registro de un paso de razonamiento ──────────────────────────────────────

type
  TStepKind = (skNarrowLo, skNarrowHi, skNarrowInterval,
               skRemoveLabel, skEmpty, skNoChange);

  TStep = record
    Iteration: Integer;
    Expr:      string;
    VarName:   string;
    Kind:      TStepKind;
    { Numeric }
    FrLo, FrHi: Double;
    ToLo, ToHi: Double;
    { Discrete }
    FrLabels:   array of string;
    FrLabelN:   Integer;
    ToLabels:   array of string;
    ToLabelN:   Integer;
  end;

// ── Variables globales ────────────────────────────────────────────────────────

var
  Vars:      array of TRTVar;
  VarCount:  Integer;

  CstrExprs: array of string;
  CstrCount: Integer;

  Steps:     array of TStep;
  StepCount: Integer;

  CurrentIter: Integer;

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

function JToLabel(V: TJSONValue): string;
begin
  if V is TJSONBoolean then
  begin
    if TJSONBoolean(V).Value then Result := 'true' else Result := 'false';
  end
  else Result := V.AsString;
end;

// ── Registro de pasos ─────────────────────────────────────────────────────────

procedure AddStep(VIdx: Integer; K: TStepKind; const Expr: string;
                  FrLo, FrHi, TLo, THi: Double);
var S: TStep;
begin
  if StepCount >= Length(Steps) then SetLength(Steps, StepCount + 256);
  S.Iteration := CurrentIter;
  S.Expr      := Expr;
  S.VarName   := Vars[VIdx].Name;
  S.Kind      := K;
  S.FrLo := FrLo; S.FrHi := FrHi;
  S.ToLo := TLo;  S.ToHi := THi;
  S.FrLabelN := 0; S.ToLabelN := 0;
  Steps[StepCount] := S;
  Inc(StepCount);
end;

procedure AddStepDiscrete(VIdx: Integer; K: TStepKind; const Expr: string);
var S: TStep; i, tc: Integer;
begin
  if StepCount >= Length(Steps) then SetLength(Steps, StepCount + 256);
  S.Iteration := CurrentIter;
  S.Expr      := Expr;
  S.VarName   := Vars[VIdx].Name;
  S.Kind      := K;
  S.FrLo := 0; S.FrHi := 0; S.ToLo := 0; S.ToHi := 0;

  { Snapshot de etiquetas activas DESPUÉS del cambio — before fue guardado por el caller }
  tc := 0;
  SetLength(S.ToLabels, Vars[VIdx].LabelN);
  for i := 0 to Vars[VIdx].LabelN - 1 do
    if Vars[VIdx].Active[i] then begin S.ToLabels[tc] := Vars[VIdx].Labels[i]; Inc(tc); end;
  S.ToLabelN := tc;

  { El "from" lo pasamos desde fuera via FrLabels — lo dejamos vacío aquí }
  S.FrLabelN := 0;
  SetLength(S.FrLabels, 0);

  Steps[StepCount] := S;
  Inc(StepCount);
end;

// ── Modificación de dominio ───────────────────────────────────────────────────

procedure MarkEmpty(VIdx: Integer; const Expr: string);
var FrLo, FrHi: Double;
begin
  FrLo := Vars[VIdx].Lo; FrHi := Vars[VIdx].Hi;
  Vars[VIdx].Empty   := True;
  Vars[VIdx].Changed := True;
  AddStep(VIdx, skEmpty, Expr, FrLo, FrHi, FrLo, FrHi);
end;

procedure RefreshIntegerBounds(VIdx: Integer);
var i: Integer; V: Double; first: Boolean;
begin
  first := True;
  for i := 0 to Vars[VIdx].LabelN - 1 do
    if Vars[VIdx].Active[i] then
    begin
      if TryStrToFloat(Vars[VIdx].Labels[i], V, '.') then
      begin
        if first then begin Vars[VIdx].Lo := V; Vars[VIdx].Hi := V; first := False; end
        else begin
          if V < Vars[VIdx].Lo then Vars[VIdx].Lo := V;
          if V > Vars[VIdx].Hi then Vars[VIdx].Hi := V;
        end;
      end;
    end;
end;

function NarrowLo(VIdx: Integer; NewLo: Double; const Expr: string): Boolean;
var FrLo: Double;
begin
  Result := False;
  if Vars[VIdx].Kind = vkUnknown then Exit;
  if NewLo > Vars[VIdx].Lo then
  begin
    FrLo := Vars[VIdx].Lo;
    Vars[VIdx].Lo      := NewLo;
    Vars[VIdx].Changed := True;
    Result             := True;
    if Vars[VIdx].Lo > Vars[VIdx].Hi then
      MarkEmpty(VIdx, Expr)
    else
      AddStep(VIdx, skNarrowLo, Expr, FrLo, Vars[VIdx].Hi, NewLo, Vars[VIdx].Hi);
  end;
end;

function NarrowHi(VIdx: Integer; NewHi: Double; const Expr: string): Boolean;
var FrHi: Double;
begin
  Result := False;
  if Vars[VIdx].Kind = vkUnknown then Exit;
  if NewHi < Vars[VIdx].Hi then
  begin
    FrHi := Vars[VIdx].Hi;
    Vars[VIdx].Hi      := NewHi;
    Vars[VIdx].Changed := True;
    Result             := True;
    if Vars[VIdx].Lo > Vars[VIdx].Hi then
      MarkEmpty(VIdx, Expr)
    else
      AddStep(VIdx, skNarrowHi, Expr, Vars[VIdx].Lo, FrHi, Vars[VIdx].Lo, NewHi);
  end;
end;

procedure NarrowDiscreteToLabel(VIdx: Integer; const TargetUp, Expr: string);
var i: Integer; anyActive, changed: Boolean;
begin
  anyActive := False; changed := False;
  for i := 0 to Vars[VIdx].LabelN - 1 do
    if Vars[VIdx].Active[i] then
    begin
      if UpperCase(Vars[VIdx].Labels[i]) <> TargetUp then
      begin
        Vars[VIdx].Active[i] := False;
        Vars[VIdx].Changed   := True;
        changed              := True;
      end
      else anyActive := True;
    end;
  if changed then
  begin
    if not anyActive then MarkEmpty(VIdx, Expr)
    else AddStepDiscrete(VIdx, skRemoveLabel, Expr);
    if Vars[VIdx].Kind = vkInteger then RefreshIntegerBounds(VIdx);
  end;
end;

procedure NarrowIntegerOp(VIdx: Integer; Op: TASTNodeType;
                          Val: Double; const Expr: string);
var i: Integer; V: Double; anyActive, deactivated: Boolean;
begin
  anyActive := False; deactivated := False;
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
  if deactivated then
  begin
    Vars[VIdx].Changed := True;
    if not anyActive then MarkEmpty(VIdx, Expr)
    else begin AddStepDiscrete(VIdx, skRemoveLabel, Expr); RefreshIntegerBounds(VIdx); end;
  end;
end;

// ── Evaluación de intervalo (forward) ────────────────────────────────────────

function EvalIv(Node: TASTNode): TInterval; forward;

function EvalIv(Node: TASTNode): TInterval;
var vid: Integer; L, R: TInterval;
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
      if vid >= 0 then Result := IvMake(Vars[vid].Lo, Vars[vid].Hi)
      else             Result := IvMake(-BIG, BIG);
    end;
    ntNegate: begin
      L := EvalIv(TUnaryOpNode(Node).Operand);
      Result := IvScale(L, -1.0);
    end;
    ntAdd: begin
      L := EvalIv(TBinaryOpNode(Node).Left);
      R := EvalIv(TBinaryOpNode(Node).Right);
      Result := IvAdd(L, R);
    end;
    ntSubtract: begin
      L := EvalIv(TBinaryOpNode(Node).Left);
      R := EvalIv(TBinaryOpNode(Node).Right);
      Result := IvSub(L, R);
    end;
    ntMultiply: begin
      L := EvalIv(TBinaryOpNode(Node).Left);
      R := EvalIv(TBinaryOpNode(Node).Right);
      Result := IvMul(L, R);
    end;
    ntDivide: begin
      L := EvalIv(TBinaryOpNode(Node).Left);
      R := EvalIv(TBinaryOpNode(Node).Right);
      Result := IvDiv(L, R);
    end;
  else
    Result := IvMake(-BIG, BIG);
  end;
end;

// ── Propagación de una constraint ─────────────────────────────────────────────

procedure ApplyLeft(VIdx: Integer; Op: TASTNodeType;
                    RIv: TInterval; const Expr: string);
begin
  case Vars[VIdx].Kind of
    vkNumeric:
    begin
      case Op of
        ntEquals:    begin NarrowLo(VIdx, RIv.Lo, Expr); NarrowHi(VIdx, RIv.Hi, Expr); end;
        ntGreaterEq: NarrowLo(VIdx, RIv.Lo, Expr);
        ntGreater:   NarrowLo(VIdx, RIv.Lo, Expr);
        ntLessEq:    NarrowHi(VIdx, RIv.Hi, Expr);
        ntLess:      NarrowHi(VIdx, RIv.Hi, Expr);
      end;
    end;
    vkInteger:
      NarrowIntegerOp(VIdx, Op, RIv.Lo, Expr);
  end;
end;

procedure ApplyRight(VIdx: Integer; Op: TASTNodeType;
                     LIv: TInterval; const Expr: string);
var InvOp: TASTNodeType;
begin
  case Op of
    ntGreaterEq: InvOp := ntLessEq;
    ntGreater:   InvOp := ntLess;
    ntLessEq:    InvOp := ntGreaterEq;
    ntLess:      InvOp := ntGreater;
  else           InvOp := Op;
  end;
  ApplyLeft(VIdx, InvOp, LIv, Expr);
end;

procedure PropagateConstraint(const Expr: string);
var
  Parser:     TPrattParser;
  Root, LHS, RHS: TASTNode;
  Op:         TASTNodeType;
  LIv, RIv:   TInterval;
  vidL, vidR: Integer;
begin
  Parser := TPrattParser.Create(Expr);
  try
    try
      Root := Parser.Parse;
      try
        if not (Root.NodeType in [ntEquals, ntNotEquals,
                                  ntLess, ntGreater,
                                  ntLessEq, ntGreaterEq]) then Exit;

        LHS := TBinaryOpNode(Root).Left;
        RHS := TBinaryOpNode(Root).Right;
        Op  := Root.NodeType;

        { Caso discreto: var = literal }
        if (Op = ntEquals) and
           (LHS.NodeType = ntVariable) and
           (RHS.NodeType = ntVariable) then
        begin
          vidL := FindVar(TVariableNode(LHS).Name);
          vidR := FindVar(TVariableNode(RHS).Name);

          if (vidL >= 0) and (vidR < 0) and
             (Vars[vidL].Kind in [vkBoolean, vkSet]) then
          begin
            NarrowDiscreteToLabel(vidL, UpperCase(TVariableNode(RHS).Name), Expr);
            Exit;
          end;
          if (vidR >= 0) and (vidL < 0) and
             (Vars[vidR].Kind in [vkBoolean, vkSet]) then
          begin
            NarrowDiscreteToLabel(vidR, UpperCase(TVariableNode(LHS).Name), Expr);
            Exit;
          end;
        end;

        { Caso numérico/integer }
        LIv := EvalIv(LHS);
        RIv := EvalIv(RHS);

        if LHS.NodeType = ntVariable then
        begin
          vidL := FindVar(TVariableNode(LHS).Name);
          if vidL >= 0 then ApplyLeft(vidL, Op, RIv, Expr);
        end;

        if RHS.NodeType = ntVariable then
        begin
          vidR := FindVar(TVariableNode(RHS).Name);
          if vidR >= 0 then ApplyRight(vidR, Op, LIv, Expr);
        end;

      finally
        Root.Free;
      end;
    except
      { Error de parseo: ignorar }
    end;
  finally
    Parser.Free;
  end;
end;

// ── Carga de datos ────────────────────────────────────────────────────────────

procedure LoadGraph(JRoot: TJSONObject);
var
  VarsJ, CstrsJ: TJSONValue;
  VArr, CArr:    TJSONArray;
  VObj, CObj:    TJSONObject;
  ValJ, DomJ:    TJSONValue;
  ValArr, DomArr: TJSONArray;
  i, k, m:       Integer;
  ValLabel:      string;
  VarD:          Double;
begin
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
      begin Changed := False; Empty := True; Inc(VarCount); Continue; end;
      DomArr := TJSONArray(DomJ);

      case Kind of
        vkNumeric:
        begin
          Lo := -BIG; Hi := BIG;
          if DomArr.Count >= 2 then begin Lo := DomArr[0].AsFloat; Hi := DomArr[1].AsFloat; end;
          if (ValJ <> nil) and (ValJ is TJSONArray) and (TJSONArray(ValJ).Count >= 2) then
          begin Lo := TJSONArray(ValJ)[0].AsFloat; Hi := TJSONArray(ValJ)[1].AsFloat; end;
          Changed := False; Empty := (Lo > Hi);
        end;

        vkInteger, vkBoolean, vkSet:
        begin
          LabelN := DomArr.Count;
          SetLength(Labels, LabelN); SetLength(Active, LabelN);
          for k := 0 to LabelN - 1 do begin Labels[k] := JToLabel(DomArr[k]); Active[k] := False; end;
          if (ValJ <> nil) and (ValJ is TJSONArray) then
          begin
            ValArr := TJSONArray(ValJ);
            for k := 0 to ValArr.Count - 1 do
            begin
              ValLabel := JToLabel(ValArr[k]);
              for m := 0 to LabelN - 1 do
                if UpperCase(Labels[m]) = UpperCase(ValLabel) then Active[m] := True;
            end;
          end
          else
            for k := 0 to LabelN - 1 do Active[k] := True;

          Lo := BIG; Hi := -BIG;
          if Kind = vkInteger then
          begin
            for k := 0 to LabelN - 1 do
              if Active[k] and TryStrToFloat(Labels[k], VarD, '.') then
              begin
                if VarD < Lo then Lo := VarD;
                if VarD > Hi then Hi := VarD;
              end;
            if Lo > Hi then begin Lo := 0; Hi := 0; Empty := True; end;
          end;
          Changed := False; Empty := False;
        end;
      else
        Changed := False; Empty := False; Lo := -BIG; Hi := BIG;
      end;
    end;
    Inc(VarCount);
  end;

  CstrsJ := JRoot.Find('constraints');
  if (CstrsJ = nil) or not (CstrsJ is TJSONArray) then Exit;
  CArr := TJSONArray(CstrsJ);
  SetLength(CstrExprs, CArr.Count + 4); CstrCount := 0;
  for i := 0 to CArr.Count - 1 do
  begin
    if not (CArr[i] is TJSONObject) then Continue;
    CObj := TJSONObject(CArr[i]);
    CstrExprs[CstrCount] := CObj.GetStr('expr', '');
    Inc(CstrCount);
  end;
end;

// ── Estado ────────────────────────────────────────────────────────────────────

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

function StepKindStr(K: TStepKind): string;
begin
  case K of
    skNarrowLo:       Result := 'narrow_lo';
    skNarrowHi:       Result := 'narrow_hi';
    skNarrowInterval: Result := 'narrow_interval';
    skRemoveLabel:    Result := 'remove_label';
    skEmpty:          Result := 'empty';
  else                Result := 'no_change';
  end;
end;

function BuildDomainArray(VIdx: Integer): TJSONArray;
var Arr: TJSONArray; i: Integer;
begin
  Arr := TJSONArray.Create;
  case Vars[VIdx].Kind of
    vkNumeric:
    begin Arr.AddNum(Vars[VIdx].Lo); Arr.AddNum(Vars[VIdx].Hi); end;
    vkInteger, vkBoolean, vkSet:
    begin
      for i := 0 to Vars[VIdx].LabelN - 1 do
        if Vars[VIdx].Active[i] then Arr.AddStr(Vars[VIdx].Labels[i]);
    end;
  end;
  Result := Arr;
end;

function BuildOutput(const Status: string; Iterations: Integer): TJSONObject;
var
  Root, SObj, VObj: TJSONObject;
  StepsArr, VArr:   TJSONArray;
  FromArr, ToArr:   TJSONArray;
  i, k:             Integer;
begin
  Root := TJSONObject.Create;
  Root.AddStr('status',     Status);
  Root.AddNum('iterations', Iterations);

  { ── Trazado de pasos ── }
  StepsArr := TJSONArray.Create;
  for i := 0 to StepCount - 1 do
  begin
    SObj := TJSONObject.Create;
    SObj.AddNum('iteration',  Steps[i].Iteration);
    SObj.AddStr('constraint', Steps[i].Expr);
    SObj.AddStr('variable',   Steps[i].VarName);
    SObj.AddStr('action',     StepKindStr(Steps[i].Kind));

    case Steps[i].Kind of
      skNarrowLo, skNarrowHi, skNarrowInterval, skEmpty:
      begin
        FromArr := TJSONArray.Create;
        FromArr.AddNum(Steps[i].FrLo); FromArr.AddNum(Steps[i].FrHi);
        ToArr   := TJSONArray.Create;
        ToArr.AddNum(Steps[i].ToLo);   ToArr.AddNum(Steps[i].ToHi);
        SObj.Add('from', FromArr);
        SObj.Add('to',   ToArr);
      end;
      skRemoveLabel:
      begin
        ToArr := TJSONArray.Create;
        for k := 0 to Steps[i].ToLabelN - 1 do ToArr.AddStr(Steps[i].ToLabels[k]);
        SObj.Add('to', ToArr);
      end;
    end;

    StepsArr.Add(SObj);
  end;
  Root.Add('steps', StepsArr);

  { ── Estado final de variables ── }
  VArr := TJSONArray.Create;
  for i := 0 to VarCount - 1 do
  begin
    VObj := TJSONObject.Create;
    VObj.AddNum( 'id',     Vars[i].Id);
    VObj.AddStr( 'name',   Vars[i].Name);
    VObj.AddBool('empty',  Vars[i].Empty);
    VObj.AddBool('solved', IsSingleton(i));
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
    WriteLn('Uso: ForwardChain graph.json [output.json]');
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

    LoadGraph(JRoot);

    SetLength(Steps, 256);
    StepCount   := 0;
    CurrentIter := 0;
    Iter        := 0;
    Status      := 'ok';

    repeat
      Inc(Iter);
      CurrentIter := Iter;
      ClearChanged;
      for j := 0 to CstrCount - 1 do
        if CstrExprs[j] <> '' then
          PropagateConstraint(CstrExprs[j]);
      if AnyEmpty then begin Status := 'contradiction'; Break; end;
      if not AnyChanged then Break;
    until Iter >= MAX_ITER;

    if (Status = 'ok') and AllSolved then Status := 'solved';

    OutRoot := BuildOutput(Status, Iter);
    OutStr  := OutRoot.ToJSON(1);
    OutRoot.Free;

    if OutFile <> '' then
    begin
      AssignFile(TF, OutFile);
      Rewrite(TF);
      Write(TF, OutStr);
      CloseFile(TF);
      WriteLn('Escrito: ', OutFile, '  status=', Status,
              '  iter=', Iter, '  steps=', StepCount);
    end
    else
      WriteLn(OutStr);

  finally
    JData.Free;
  end;
end.
