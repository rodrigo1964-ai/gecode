program FwdConsistency;

{$mode objfpc}{$H+}

(*
 * FwdConsistency.pas
 *
 * Verificación de consistencia hacia adelante usando AC-3
 * (Arc Consistency Algorithm 3).
 *
 * Principio:
 *   Un arco (X, C) es consistente si para cada valor posible de X existe
 *   al menos un valor en los dominios de las otras variables de C que
 *   satisface C. AC-3 propaga consistencia mediante una cola de arcos,
 *   re-encola solo los arcos afectados por cada cambio.
 *
 * Entrada : JSON de grafo (salida de JsonToGraph)
 * Salida  : JSON con status, operaciones de cola, reglas disparadas y dominios
 *
 * {
 *   "status":        "arc_consistent" | "inconsistent" | "timeout",
 *   "queue_ops":     N,          -- arcos procesados de la cola
 *   "rule_firings":  N,          -- arcos que produjeron un cambio
 *   "steps": [
 *     {
 *       "op":        N,           -- número de operación de cola
 *       "arc":       "VAR <- C",  -- arco procesado
 *       "constraint": "expr",
 *       "variable":  "name",
 *       "action":    "narrow_lo|narrow_hi|remove_label|empty",
 *       "from":      [...],
 *       "to":        [...]
 *     }
 *   ],
 *   "variables": [ { id, name, solved, empty, domain } ]
 * }
 *
 * Uso:
 *   ./FwdConsistency graph.json [output.json]
 *)

uses
  MiniSys, MiniJSON, ExpressionAST, PrattParser, MiniMath;

const
  MAX_QUEUE = 50000;
  BIG       = 1.0e300;

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

// ── Grafo de restricciones (adjacency) ───────────────────────────────────────

type
  TCstrInfo = record
    Expr:    string;
    VarRefs: array of Integer;  // var_ids que participan
    VarRefN: Integer;
  end;

  TAdjEntry = record
    VarId:    Integer;
    CstrIds:  array of Integer;
    CstrIdN:  Integer;
  end;

// ── Elemento de la cola AC-3 ──────────────────────────────────────────────────

type
  TQueueItem = record
    CstrIdx: Integer;   // índice en CstrList
    VarIdx:  Integer;   // índice en Vars (variable a estrechar)
  end;

// ── Registro de un disparo de regla ──────────────────────────────────────────

type
  TStepKind = (skNarrowLo, skNarrowHi, skRemoveLabel, skEmpty);

  TStep = record
    OpNum:  Integer;
    CstrExpr, VarName: string;
    Kind:   TStepKind;
    FrLo, FrHi, ToLo, ToHi: Double;
    ToLabels: array of string;
    ToLabelN: Integer;
  end;

// ── Variables globales ────────────────────────────────────────────────────────

var
  Vars:     array of TRTVar;
  VarCount: Integer;

  CstrList: array of TCstrInfo;
  CstrCount: Integer;

  AdjList:  array of TAdjEntry;  // indexed by var_id
  AdjCount: Integer;

  Queue:    array of TQueueItem;
  QHead, QTail: Integer;          // circular buffer
  QSize:    Integer;

  Steps:    array of TStep;
  StepCount: Integer;

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

// ── Cola AC-3 ─────────────────────────────────────────────────────────────────

procedure InitQueue;
begin
  SetLength(Queue, MAX_QUEUE);
  QHead := 0; QTail := 0; QSize := 0;
end;

function QueueFull: Boolean;
begin
  Result := (QSize >= MAX_QUEUE);
end;

function QueueEmpty: Boolean;
begin
  Result := (QSize = 0);
end;

procedure Enqueue(CstrIdx, VarIdx: Integer);
var i: Integer;
begin
  { No encolar duplicados exactos }
  i := QHead;
  while i <> QTail do
  begin
    if (Queue[i].CstrIdx = CstrIdx) and (Queue[i].VarIdx = VarIdx) then Exit;
    i := (i + 1) mod MAX_QUEUE;
  end;
  if QueueFull then Exit;
  Queue[QTail].CstrIdx := CstrIdx;
  Queue[QTail].VarIdx  := VarIdx;
  QTail := (QTail + 1) mod MAX_QUEUE;
  Inc(QSize);
end;

function Dequeue(out Item: TQueueItem): Boolean;
begin
  if QueueEmpty then begin Result := False; Exit; end;
  Item  := Queue[QHead];
  QHead := (QHead + 1) mod MAX_QUEUE;
  Dec(QSize);
  Result := True;
end;

procedure EnqueueAffected(ChangedVarIdx: Integer; SkipCstrIdx: Integer);
{ Al cambiar el dominio de ChangedVarIdx, re-encolar todos los arcos
  (C, Y) donde C involucra ChangedVarIdx y Y ≠ ChangedVarIdx }
var k, c, r: Integer;
begin
  { Buscamos la entrada de adjacency para esta variable }
  for k := 0 to AdjCount - 1 do
    if AdjList[k].VarId = Vars[ChangedVarIdx].Id then
    begin
      for c := 0 to AdjList[k].CstrIdN - 1 do
      begin
        if AdjList[k].CstrIds[c] = SkipCstrIdx then Continue;
        { Encolar (constraint, cada otra variable de esa constraint) }
        for r := 0 to CstrList[AdjList[k].CstrIds[c]].VarRefN - 1 do
        begin
          if CstrList[AdjList[k].CstrIds[c]].VarRefs[r] <> Vars[ChangedVarIdx].Id then
            Enqueue(AdjList[k].CstrIds[c],
                    CstrList[AdjList[k].CstrIds[c]].VarRefs[r]);
        end;
      end;
      Break;
    end;
end;

// ── Registro de pasos ─────────────────────────────────────────────────────────

procedure RecordNarrow(OpNum, VIdx: Integer; const Expr: string;
                       K: TStepKind; FrLo, FrHi, ToLo, ToHi: Double);
var S: TStep;
begin
  if StepCount >= Length(Steps) then SetLength(Steps, StepCount + 256);
  S.OpNum    := OpNum;
  S.CstrExpr := Expr;
  S.VarName  := Vars[VIdx].Name;
  S.Kind     := K;
  S.FrLo := FrLo; S.FrHi := FrHi;
  S.ToLo := ToLo; S.ToHi := ToHi;
  S.ToLabelN := 0;
  Steps[StepCount] := S;
  Inc(StepCount);
end;

procedure RecordDiscrete(OpNum, VIdx: Integer; const Expr: string; K: TStepKind);
var S: TStep; i, tc: Integer;
begin
  if StepCount >= Length(Steps) then SetLength(Steps, StepCount + 256);
  S.OpNum    := OpNum;
  S.CstrExpr := Expr;
  S.VarName  := Vars[VIdx].Name;
  S.Kind     := K;
  S.FrLo := 0; S.FrHi := 0; S.ToLo := 0; S.ToHi := 0;
  tc := 0;
  SetLength(S.ToLabels, Vars[VIdx].LabelN);
  for i := 0 to Vars[VIdx].LabelN - 1 do
    if Vars[VIdx].Active[i] then begin S.ToLabels[tc] := Vars[VIdx].Labels[i]; Inc(tc); end;
  S.ToLabelN := tc;
  Steps[StepCount] := S;
  Inc(StepCount);
end;

// ── Modificación de dominio ───────────────────────────────────────────────────

procedure MarkEmpty(VIdx, OpNum: Integer; const Expr: string);
begin
  Vars[VIdx].Empty   := True;
  Vars[VIdx].Changed := True;
  RecordNarrow(OpNum, VIdx, Expr, skEmpty,
               Vars[VIdx].Lo, Vars[VIdx].Hi,
               Vars[VIdx].Lo, Vars[VIdx].Hi);
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

{ Devuelve True si el dominio cambió }
function NarrowLo(VIdx, OpNum: Integer; NewLo: Double; const Expr: string): Boolean;
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
      MarkEmpty(VIdx, OpNum, Expr)
    else
      RecordNarrow(OpNum, VIdx, Expr, skNarrowLo,
                   FrLo, Vars[VIdx].Hi, NewLo, Vars[VIdx].Hi);
  end;
end;

function NarrowHi(VIdx, OpNum: Integer; NewHi: Double; const Expr: string): Boolean;
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
      MarkEmpty(VIdx, OpNum, Expr)
    else
      RecordNarrow(OpNum, VIdx, Expr, skNarrowHi,
                   Vars[VIdx].Lo, FrHi, Vars[VIdx].Lo, NewHi);
  end;
end;

function NarrowDiscreteToLabel(VIdx, OpNum: Integer;
                               const TargetUp, Expr: string): Boolean;
var i: Integer; anyActive, changed: Boolean;
begin
  anyActive := False; changed := False; Result := False;
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
    Result := True;
    if not anyActive then MarkEmpty(VIdx, OpNum, Expr)
    else RecordDiscrete(OpNum, VIdx, Expr, skRemoveLabel);
    if Vars[VIdx].Kind = vkInteger then RefreshIntegerBounds(VIdx);
  end;
end;

function NarrowIntegerOp(VIdx, OpNum: Integer; Op: TASTNodeType;
                         Val: Double; const Expr: string): Boolean;
var i: Integer; V: Double; anyActive, deactivated: Boolean;
begin
  anyActive := False; deactivated := False; Result := False;
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
    Result := True;
    Vars[VIdx].Changed := True;
    if not anyActive then MarkEmpty(VIdx, OpNum, Expr)
    else begin RecordDiscrete(OpNum, VIdx, Expr, skRemoveLabel); RefreshIntegerBounds(VIdx); end;
  end;
end;

// ── Evaluación de intervalo ───────────────────────────────────────────────────

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

// ── Procesamiento de un arco (constraint, variable) ───────────────────────────
{ Devuelve True si el dominio de VarIdx cambió }

function ProcessArc(CstrIdx, VarIdx, OpNum: Integer): Boolean;
var
  Parser:       TPrattParser;
  Root, LHS, RHS: TASTNode;
  Op, InvOp:    TASTNodeType;
  LIv, RIv:    TInterval;
  vidL, vidR:   Integer;
  Expr:         string;
begin
  Result := False;
  Expr   := CstrList[CstrIdx].Expr;
  if Expr = '' then Exit;

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

          if (vidL >= 0) and (vidL = VarIdx) and (vidR < 0) and
             (Vars[vidL].Kind in [vkBoolean, vkSet]) then
          begin
            Result := NarrowDiscreteToLabel(vidL, OpNum,
                        UpperCase(TVariableNode(RHS).Name), Expr);
            Exit;
          end;
          if (vidR >= 0) and (vidR = VarIdx) and (vidL < 0) and
             (Vars[vidR].Kind in [vkBoolean, vkSet]) then
          begin
            Result := NarrowDiscreteToLabel(vidR, OpNum,
                        UpperCase(TVariableNode(LHS).Name), Expr);
            Exit;
          end;
        end;

        { Caso numérico / integer — estrechar solo la variable del arco }
        LIv := EvalIv(LHS);
        RIv := EvalIv(RHS);

        if (LHS.NodeType = ntVariable) then
        begin
          vidL := FindVar(TVariableNode(LHS).Name);
          if (vidL >= 0) and (vidL = VarIdx) then
          begin
            case Vars[vidL].Kind of
              vkNumeric:
              begin
                case Op of
                  ntEquals:    begin
                    Result := NarrowLo(vidL, OpNum, RIv.Lo, Expr) or Result;
                    Result := NarrowHi(vidL, OpNum, RIv.Hi, Expr) or Result;
                  end;
                  ntGreaterEq: Result := NarrowLo(vidL, OpNum, RIv.Lo, Expr) or Result;
                  ntGreater:   Result := NarrowLo(vidL, OpNum, RIv.Lo, Expr) or Result;
                  ntLessEq:    Result := NarrowHi(vidL, OpNum, RIv.Hi, Expr) or Result;
                  ntLess:      Result := NarrowHi(vidL, OpNum, RIv.Hi, Expr) or Result;
                end;
              end;
              vkInteger:
                Result := NarrowIntegerOp(vidL, OpNum, Op, RIv.Lo, Expr) or Result;
            end;
          end;
        end;

        if (RHS.NodeType = ntVariable) then
        begin
          vidR := FindVar(TVariableNode(RHS).Name);
          if (vidR >= 0) and (vidR = VarIdx) then
          begin
            { Operador invertido para estrechar desde la derecha }
            case Op of
              ntGreaterEq: InvOp := ntLessEq;
              ntGreater:   InvOp := ntLess;
              ntLessEq:    InvOp := ntGreaterEq;
              ntLess:      InvOp := ntGreater;
            else           InvOp := Op;
            end;
            case Vars[vidR].Kind of
              vkNumeric:
              begin
                case InvOp of
                  ntEquals:    begin
                    Result := NarrowLo(vidR, OpNum, LIv.Lo, Expr) or Result;
                    Result := NarrowHi(vidR, OpNum, LIv.Hi, Expr) or Result;
                  end;
                  ntGreaterEq: Result := NarrowLo(vidR, OpNum, LIv.Lo, Expr) or Result;
                  ntGreater:   Result := NarrowLo(vidR, OpNum, LIv.Lo, Expr) or Result;
                  ntLessEq:    Result := NarrowHi(vidR, OpNum, LIv.Hi, Expr) or Result;
                  ntLess:      Result := NarrowHi(vidR, OpNum, LIv.Hi, Expr) or Result;
                end;
              end;
              vkInteger:
                Result := NarrowIntegerOp(vidR, OpNum, InvOp, LIv.Lo, Expr) or Result;
            end;
          end;
        end;

      finally
        Root.Free;
      end;
    except
      { Error de parseo: ignorar este arco }
    end;
  finally
    Parser.Free;
  end;
end;

// ── Carga de datos ────────────────────────────────────────────────────────────

procedure LoadGraph(JRoot: TJSONObject);
var
  VarsJ, CstrsJ, AdjJ: TJSONValue;
  VArr, CArr, AArr:    TJSONArray;
  VObj, CObj, AObj:    TJSONObject;
  ValJ, DomJ:          TJSONValue;
  ValArr, DomArr:      TJSONArray;
  RefJ:                TJSONValue;
  RefArr:              TJSONArray;
  i, k, m:             Integer;
  ValLabel:            string;
  VarD:                Double;
begin
  { Variables }
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

  { Constraints }
  CstrsJ := JRoot.Find('constraints');
  if (CstrsJ = nil) or not (CstrsJ is TJSONArray) then Exit;
  CArr := TJSONArray(CstrsJ);
  SetLength(CstrList, CArr.Count + 4);
  CstrCount := 0;
  for i := 0 to CArr.Count - 1 do
  begin
    if not (CArr[i] is TJSONObject) then Continue;
    CObj := TJSONObject(CArr[i]);
    CstrList[CstrCount].Expr := CObj.GetStr('expr', '');
    RefJ := CObj.Find('var_refs');
    CstrList[CstrCount].VarRefN := 0;
    if (RefJ <> nil) and (RefJ is TJSONArray) then
    begin
      RefArr := TJSONArray(RefJ);
      SetLength(CstrList[CstrCount].VarRefs, RefArr.Count);
      for k := 0 to RefArr.Count - 1 do
      begin
        CstrList[CstrCount].VarRefs[k] := Round(RefArr[k].AsFloat);
        Inc(CstrList[CstrCount].VarRefN);
      end;
    end;
    Inc(CstrCount);
  end;

  { Adjacency }
  AdjJ := JRoot.Find('adjacency');
  if (AdjJ = nil) or not (AdjJ is TJSONArray) then Exit;
  AArr := TJSONArray(AdjJ);
  SetLength(AdjList, AArr.Count + 4);
  AdjCount := 0;
  for i := 0 to AArr.Count - 1 do
  begin
    if not (AArr[i] is TJSONObject) then Continue;
    AObj := TJSONObject(AArr[i]);
    AdjList[AdjCount].VarId  := Round(AObj.GetFloat('var_id', -1));
    RefJ := AObj.Find('constraint_ids');
    AdjList[AdjCount].CstrIdN := 0;
    if (RefJ <> nil) and (RefJ is TJSONArray) then
    begin
      RefArr := TJSONArray(RefJ);
      SetLength(AdjList[AdjCount].CstrIds, RefArr.Count);
      for k := 0 to RefArr.Count - 1 do
      begin
        AdjList[AdjCount].CstrIds[k] := Round(RefArr[k].AsFloat);
        Inc(AdjList[AdjCount].CstrIdN);
      end;
    end;
    Inc(AdjCount);
  end;
end;

// ── Auxiliares ────────────────────────────────────────────────────────────────

function AnyEmpty: Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to VarCount - 1 do
    if Vars[i].Empty then begin Result := True; Exit; end;
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

function StepKindStr(K: TStepKind): string;
begin
  case K of
    skNarrowLo:    Result := 'narrow_lo';
    skNarrowHi:    Result := 'narrow_hi';
    skRemoveLabel: Result := 'remove_label';
    skEmpty:       Result := 'empty';
  else             Result := 'unknown';
  end;
end;

// ── Construcción de salida JSON ───────────────────────────────────────────────

function BuildOutput(const Status: string; QOps, Firings: Integer): TJSONObject;
var
  Root, SObj, VObj: TJSONObject;
  StepsArr, VArr:   TJSONArray;
  FromArr, ToArr:   TJSONArray;
  i, k:             Integer;
begin
  Root := TJSONObject.Create;
  Root.AddStr('status',       Status);
  Root.AddNum('queue_ops',    QOps);
  Root.AddNum('rule_firings', Firings);

  StepsArr := TJSONArray.Create;
  for i := 0 to StepCount - 1 do
  begin
    SObj := TJSONObject.Create;
    SObj.AddNum('op',         Steps[i].OpNum);
    SObj.AddStr('arc',        Steps[i].VarName + ' <- ' + Steps[i].CstrExpr);
    SObj.AddStr('constraint', Steps[i].CstrExpr);
    SObj.AddStr('variable',   Steps[i].VarName);
    SObj.AddStr('action',     StepKindStr(Steps[i].Kind));

    case Steps[i].Kind of
      skNarrowLo, skNarrowHi, skEmpty:
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
  RawStr:  string;
  TF:      TextFile;
  JData:   TJSONValue;
  JRoot:   TJSONObject;
  OutRoot: TJSONObject;
  OutStr:  string;
  Item:    TQueueItem;
  QOps, Firings: Integer;
  Status:  string;
  c, r, vi: Integer;

begin
  DefaultFormatSettings.DecimalSeparator := '.';

  { Sin argumento o '-': leer de stdin }
  InFile  := '';
  OutFile := '';
  if ParamCount >= 1 then InFile  := ParamStr(1);
  if ParamCount >= 2 then OutFile := ParamStr(2);

  { Validar solo si es archivo real (no stdin) }
  if (InFile <> '') and (InFile <> '-') and (InFile <> '/dev/stdin') then
    if not FileExists(InFile) then
    begin
      WriteLn('Error: archivo no encontrado: ', InFile);
      Halt(1);
    end;

  RawStr := ReadFileToStr(InFile);

  JData := ParseJSON(RawStr);
  try
    if not (JData is TJSONObject) then
      raise Exception.Create('El JSON raíz debe ser un objeto');
    JRoot := TJSONObject(JData);

    LoadGraph(JRoot);

    { Inicializar cola y trazado }
    InitQueue;
    SetLength(Steps, 256);
    StepCount := 0;
    QOps      := 0;
    Firings   := 0;

    { Cargar cola inicial: todos los arcos (constraint, variable) }
    for c := 0 to CstrCount - 1 do
      for r := 0 to CstrList[c].VarRefN - 1 do
      begin
        { Buscamos el VarIdx (índice en Vars) para el var_id de var_refs }
        vi := 0;
        while (vi < VarCount) and (Vars[vi].Id <> CstrList[c].VarRefs[r]) do Inc(vi);
        if vi < VarCount then Enqueue(c, vi);
      end;

    Status := 'arc_consistent';

    { Bucle AC-3 }
    while Dequeue(Item) do
    begin
      Inc(QOps);
      Vars[Item.VarIdx].Changed := False;
      if ProcessArc(Item.CstrIdx, Item.VarIdx, QOps) then
      begin
        Inc(Firings);
        if Vars[Item.VarIdx].Empty then
        begin
          Status := 'inconsistent';
          Break;
        end;
        { Re-encolar arcos afectados por el cambio en Item.VarIdx }
        EnqueueAffected(Item.VarIdx, Item.CstrIdx);
      end;
    end;

    OutRoot := BuildOutput(Status, QOps, Firings);
    OutStr  := OutRoot.ToJSON(1);
    OutRoot.Free;

    if OutFile <> '' then
    begin
      AssignFile(TF, OutFile);
      Rewrite(TF);
      Write(TF, OutStr);
      CloseFile(TF);
      WriteLn('Escrito: ', OutFile, '  status=', Status,
              '  queue_ops=', QOps, '  rule_firings=', Firings);
    end
    else
      WriteLn(OutStr);

  finally
    JData.Free;
  end;
end.
