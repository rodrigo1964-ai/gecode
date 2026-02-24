program JsonToGraph;

{$mode objfpc}{$H+}

(*
 * JsonToGraph.pas
 *
 * Convierte el JSON de sistema al grafo de restricciones (hipérgrado CSP):
 *
 *   { "variables": [...], "expressions": [...], "functions": [...] }
 *   →
 *   {
 *     "variables":   [{ id, name, type, domain, value }],
 *     "functions":   [{ id, name, inputs, outputs }],
 *     "constraints": [{ id, expr, var_refs:[vid], func_refs:[fid], root, nodes:[...] }],
 *     "adjacency":   [{ var_id, constraint_ids:[cid] }]
 *   }
 *
 * Los nodos de variable son compartidos: si X aparece en tres constraints,
 * el mismo var_id 0 aparece en var_refs de las tres.
 * La sección adjacency es el índice inverso para propagación CSP.
 *
 * Uso:
 *   ./JsonToGraph input.json [output.json]
 *)

uses
  MiniSys, MiniJSON, ExpressionAST, PrattParser;

// ── TASTSerializer (post-order, igual que en JsonToAST) ─────────────────────

type
  TASTSerializer = class
  private
    FNodes: TJSONArray;
    FCount: Integer;
    function TypeName(NT: TASTNodeType): string;
    function Visit(Node: TASTNode): Integer;
  public
    constructor Create;
    destructor  Destroy; override;
    { Serializa expr; devuelve objeto con root+nodes. Caller libera. }
    function Serialize(const Expr: string; out RootId: Integer): TJSONArray;
  end;

constructor TASTSerializer.Create;
begin
  FNodes := TJSONArray.Create;
  FCount := 0;
end;

destructor TASTSerializer.Destroy;
begin
  FNodes.Free;
  inherited;
end;

function TASTSerializer.TypeName(NT: TASTNodeType): string;
begin
  case NT of
    ntNumber:       Result := 'Number';
    ntVariable:     Result := 'Variable';
    ntBoolean:      Result := 'Boolean';
    ntAdd:          Result := 'Add';
    ntSubtract:     Result := 'Subtract';
    ntMultiply:     Result := 'Multiply';
    ntDivide:       Result := 'Divide';
    ntModulo:       Result := 'Modulo';
    ntPower:        Result := 'Power';
    ntNegate:       Result := 'Negate';
    ntAnd:          Result := 'And';
    ntOr:           Result := 'Or';
    ntNot:          Result := 'Not';
    ntEquals:       Result := 'Equals';
    ntNotEquals:    Result := 'NotEquals';
    ntLess:         Result := 'Less';
    ntGreater:      Result := 'Greater';
    ntLessEq:       Result := 'LessEq';
    ntGreaterEq:    Result := 'GreaterEq';
    ntIn:           Result := 'In';
    ntInterval:     Result := 'Interval';
    ntDiscreteSet:  Result := 'Set';
    ntFunctionCall: Result := 'FunctionCall';
  else              Result := 'Unknown';
  end;
end;

function TASTSerializer.Visit(Node: TASTNode): Integer;
var
  Obj:              TJSONObject;
  BinOp:            TBinaryOpNode;
  UnOp:             TUnaryOpNode;
  Intv:             TIntervalNode;
  SetN:             TSetNode;
  FuncN:            TFunctionCallNode;
  LeftId, RightId:  Integer;
  OperandId:        Integer;
  LoId, HiId:       Integer;
  ChildIDs:         array of Integer;
  Arr:              TJSONArray;
  i, MyId:          Integer;
begin
  Obj := TJSONObject.Create;

  case Node.NodeType of

    ntNumber:
    begin
      MyId := FCount; Inc(FCount);
      Obj.AddNum('id',    MyId);
      Obj.AddStr('type',  'Number');
      Obj.AddNum('value', TNumberNode(Node).Value);
    end;

    ntVariable:
    begin
      MyId := FCount; Inc(FCount);
      Obj.AddNum('id',   MyId);
      Obj.AddStr('type', 'Variable');
      Obj.AddStr('name', TVariableNode(Node).Name);
    end;

    ntBoolean:
    begin
      MyId := FCount; Inc(FCount);
      Obj.AddNum( 'id',    MyId);
      Obj.AddStr( 'type',  'Boolean');
      Obj.AddBool('value', TBooleanNode(Node).Value);
    end;

    ntAdd, ntSubtract, ntMultiply, ntDivide, ntModulo, ntPower,
    ntAnd, ntOr,
    ntEquals, ntNotEquals, ntLess, ntGreater, ntLessEq, ntGreaterEq,
    ntIn:
    begin
      BinOp   := TBinaryOpNode(Node);
      LeftId  := Visit(BinOp.Left);
      RightId := Visit(BinOp.Right);
      MyId    := FCount; Inc(FCount);
      Obj.AddNum('id',    MyId);
      Obj.AddStr('type',  TypeName(Node.NodeType));
      Obj.AddNum('left',  LeftId);
      Obj.AddNum('right', RightId);
    end;

    ntNegate, ntNot:
    begin
      UnOp      := TUnaryOpNode(Node);
      OperandId := Visit(UnOp.Operand);
      MyId      := FCount; Inc(FCount);
      Obj.AddNum('id',      MyId);
      Obj.AddStr('type',    TypeName(Node.NodeType));
      Obj.AddNum('operand', OperandId);
    end;

    ntInterval:
    begin
      Intv := TIntervalNode(Node);
      LoId := Visit(Intv.Start);
      HiId := Visit(Intv.Stop);
      MyId := FCount; Inc(FCount);
      Obj.AddNum( 'id',      MyId);
      Obj.AddStr( 'type',    'Interval');
      Obj.AddNum( 'lo',      LoId);
      Obj.AddNum( 'hi',      HiId);
      Obj.AddBool('lo_open', Intv.StartOpen);
      Obj.AddBool('hi_open', Intv.EndOpen);
    end;

    ntDiscreteSet:
    begin
      SetN := TSetNode(Node);
      SetLength(ChildIDs, SetN.Elements.Count);
      for i := 0 to SetN.Elements.Count - 1 do
        ChildIDs[i] := Visit(SetN.Elements[i]);
      MyId := FCount; Inc(FCount);
      Arr  := TJSONArray.Create;
      for i := 0 to High(ChildIDs) do Arr.AddNum(ChildIDs[i]);
      Obj.AddNum('id',       MyId);
      Obj.AddStr('type',     'Set');
      Obj.Add(   'elements', Arr);
    end;

    ntFunctionCall:
    begin
      FuncN := TFunctionCallNode(Node);
      SetLength(ChildIDs, FuncN.Arguments.Count);
      for i := 0 to FuncN.Arguments.Count - 1 do
        ChildIDs[i] := Visit(FuncN.Arguments[i]);
      MyId := FCount; Inc(FCount);
      Arr  := TJSONArray.Create;
      for i := 0 to High(ChildIDs) do Arr.AddNum(ChildIDs[i]);
      Obj.AddNum('id',   MyId);
      Obj.AddStr('type', 'FunctionCall');
      Obj.AddStr('name', FuncN.Name);
      Obj.Add(   'args', Arr);
    end;

  else
    MyId := FCount; Inc(FCount);
    Obj.AddNum('id',   MyId);
    Obj.AddStr('type', 'Unknown');
  end;

  FNodes.Add(Obj);
  Result := MyId;
end;

function TASTSerializer.Serialize(const Expr: string;
                                  out RootId: Integer): TJSONArray;
var
  Parser: TPrattParser;
  AST:    TASTNode;
  NodesJ: TJSONArray;
begin
  FNodes.Free;
  FNodes := TJSONArray.Create;
  FCount := 0;
  RootId := -1;
  Result := nil;

  Parser := TPrattParser.Create(Expr);
  try
    AST := Parser.Parse;
    try
      RootId := Visit(AST);
    finally
      AST.Free;
    end;
    NodesJ := FNodes;
    FNodes := TJSONArray.Create;
    FCount := 0;
    Result := NodesJ;
  finally
    Parser.Free;
  end;
end;

// ── Tablas de símbolos ──────────────────────────────────────────────────────

type
  TSymEntry = record
    Name: string;   { uppercase }
    Id:   Integer;
  end;

var
  VarTab:   array of TSymEntry;
  VarCount: Integer;

  FuncTab:   array of TSymEntry;
  FuncCount: Integer;

  LitTab:   array of string;
  LitCount: Integer;

procedure RegVar(const Name: string; Id: Integer);
begin
  if VarCount >= Length(VarTab) then SetLength(VarTab, VarCount + 64);
  VarTab[VarCount].Name := UpperCase(Name);
  VarTab[VarCount].Id   := Id;
  Inc(VarCount);
end;

function FindVar(const Name: string): Integer;  { -1 si no existe }
var i: Integer;
begin
  Result := -1;
  for i := 0 to VarCount - 1 do
    if VarTab[i].Name = UpperCase(Name) then begin Result := VarTab[i].Id; Exit; end;
end;

procedure RegFunc(const Name: string; Id: Integer);
begin
  if FuncCount >= Length(FuncTab) then SetLength(FuncTab, FuncCount + 64);
  FuncTab[FuncCount].Name := UpperCase(Name);
  FuncTab[FuncCount].Id   := Id;
  Inc(FuncCount);
end;

function FindFunc(const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to FuncCount - 1 do
    if FuncTab[i].Name = UpperCase(Name) then begin Result := FuncTab[i].Id; Exit; end;
end;

procedure RegLit(const S: string);
begin
  if LitCount >= Length(LitTab) then SetLength(LitTab, LitCount + 64);
  LitTab[LitCount] := UpperCase(S);
  Inc(LitCount);
end;

function IsLit(const S: string): Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to LitCount - 1 do
    if LitTab[i] = UpperCase(S) then begin Result := True; Exit; end;
end;

// ── Array de enteros únicos ─────────────────────────────────────────────────

procedure AddUnique(var Arr: array of Integer; var Cnt: Integer; V: Integer);
var i: Integer;
begin
  for i := 0 to Cnt - 1 do if Arr[i] = V then Exit;
  if Cnt >= Length(Arr) then begin end;  { caller garantiza espacio }
  Arr[Cnt] := V; Inc(Cnt);
end;

// ── AST walker — recolecta var_refs y func_refs ─────────────────────────────

procedure WalkRefs(Node: TASTNode;
                   var VRefs: array of Integer; var VCnt: Integer;
                   var FRefs: array of Integer; var FCnt: Integer);
var
  BinOp: TBinaryOpNode;
  UnOp:  TUnaryOpNode;
  FuncN: TFunctionCallNode;
  SetN:  TSetNode;
  Intv:  TIntervalNode;
  vid, fid, i: Integer;
begin
  if Node = nil then Exit;
  case Node.NodeType of

    ntVariable:
    begin
      if IsLit(TVariableNode(Node).Name) then Exit;
      vid := FindVar(TVariableNode(Node).Name);
      if vid >= 0 then AddUnique(VRefs, VCnt, vid);
    end;

    ntFunctionCall:
    begin
      FuncN := TFunctionCallNode(Node);
      fid   := FindFunc(FuncN.Name);
      if fid >= 0 then AddUnique(FRefs, FCnt, fid);
      for i := 0 to FuncN.Arguments.Count - 1 do
        WalkRefs(FuncN.Arguments[i], VRefs, VCnt, FRefs, FCnt);
    end;

    ntAdd, ntSubtract, ntMultiply, ntDivide, ntModulo, ntPower,
    ntAnd, ntOr,
    ntEquals, ntNotEquals, ntLess, ntGreater, ntLessEq, ntGreaterEq,
    ntIn:
    begin
      BinOp := TBinaryOpNode(Node);
      WalkRefs(BinOp.Left,  VRefs, VCnt, FRefs, FCnt);
      WalkRefs(BinOp.Right, VRefs, VCnt, FRefs, FCnt);
    end;

    ntNegate, ntNot:
    begin
      UnOp := TUnaryOpNode(Node);
      WalkRefs(UnOp.Operand, VRefs, VCnt, FRefs, FCnt);
    end;

    ntDiscreteSet:
    begin
      SetN := TSetNode(Node);
      for i := 0 to SetN.Elements.Count - 1 do
        WalkRefs(SetN.Elements[i], VRefs, VCnt, FRefs, FCnt);
    end;

    ntInterval:
    begin
      Intv := TIntervalNode(Node);
      WalkRefs(Intv.Start, VRefs, VCnt, FRefs, FCnt);
      WalkRefs(Intv.Stop,  VRefs, VCnt, FRefs, FCnt);
    end;

  end;
end;

// ── Main ────────────────────────────────────────────────────────────────────

var
  InFile, OutFile: string;
  RawBuf:          array of Byte;
  RawStr:          string;
  F:               file;
  TF:              TextFile;
  FSize:           Int64;
  JData:           TJSONValue;
  JRoot:           TJSONObject;

  VarsJ, FuncsJ, ExprsJ: TJSONValue;
  VarsArr, FuncsArr, ExprsArr, CstrArr: TJSONArray;
  VObj, FObj, EObj: TJSONObject;

  { Salida }
  OutRoot:     TJSONObject;
  OutVars:     TJSONArray;
  OutFuncs:    TJSONArray;
  OutCstrs:    TJSONArray;
  OutAdj:      TJSONArray;
  CstrObj:     TJSONObject;
  AdjObj:      TJSONObject;
  VRefArr:     TJSONArray;
  FRefArr:     TJSONArray;

  Ser:         TASTSerializer;
  Parser:      TPrattParser;
  AST:         TASTNode;
  ASTNodes:    TJSONArray;
  RootId:      Integer;
  ExprStr:     string;

  { refs locales de una constraint }
  VRefs:   array[0..255] of Integer;
  FRefs:   array[0..63]  of Integer;
  VCnt, FCnt: Integer;

  { índice inverso var → constraints }
  VarCstrs:    array of array of Integer;  { VarCstrs[vid][...] = cid }
  VarCstrCnt:  array of Integer;

  VarId, FuncId, CstrId, i, j, k: Integer;
  OutStr: string;

begin
  DefaultFormatSettings.DecimalSeparator := '.';

  if ParamCount < 1 then
  begin
    WriteLn('Uso: JsonToGraph input.json [output.json]');
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

    { ── Fase 1: inicializar tablas ── }
    SetLength(VarTab,  64); VarCount  := 0;
    SetLength(FuncTab, 64); FuncCount := 0;
    SetLength(LitTab,  64); LitCount  := 0;
    RegLit('TRUE'); RegLit('FALSE');

    { ── Fase 1a: cargar variables ── }
    VarsJ   := JRoot.Find('variables');
    OutVars := TJSONArray.Create;
    if (VarsJ <> nil) and (VarsJ is TJSONArray) then
    begin
      VarsArr := TJSONArray(VarsJ);
      for i := 0 to VarsArr.Count - 1 do
      begin
        if not (VarsArr[i] is TJSONObject) then Continue;
        VObj  := TJSONObject(VarsArr[i]);
        VarId := i;
        RegVar(VObj.GetStr('name', ''), VarId);

        { Registrar etiquetas de sets como literales }
        if UpperCase(VObj.GetStr('type','')) = 'SET' then
        begin
          if VObj.Find('domain') is TJSONArray then
            for k := 0 to TJSONArray(VObj.Find('domain')).Count - 1 do
              RegLit(TJSONArray(VObj.Find('domain'))[k].AsString);
        end;

        { Nodo variable en salida: añadir id al objeto }
        VObj  := TJSONObject(VarsArr[i].Clone);
        VObj.AddNum('id', VarId);
        OutVars.Add(VObj);
      end;
    end;

    { ── Fase 1b: cargar funciones ── }
    FuncsJ    := JRoot.Find('functions');
    OutFuncs  := TJSONArray.Create;
    if (FuncsJ <> nil) and (FuncsJ is TJSONArray) then
    begin
      FuncsArr := TJSONArray(FuncsJ);
      for i := 0 to FuncsArr.Count - 1 do
      begin
        if not (FuncsArr[i] is TJSONObject) then Continue;
        FObj    := TJSONObject(FuncsArr[i]);
        FuncId  := i;
        RegFunc(FObj.GetStr('name',''), FuncId);
        FObj := TJSONObject(FuncsArr[i].Clone);
        FObj.AddNum('id', FuncId);
        OutFuncs.Add(FObj);
      end;
    end;

    { ── Inicializar índice inverso [var_id → lista de cids] ── }
    SetLength(VarCstrs,   VarCount);
    SetLength(VarCstrCnt, VarCount);
    for i := 0 to VarCount - 1 do
    begin
      SetLength(VarCstrs[i], 16);
      VarCstrCnt[i] := 0;
    end;

    { ── Fase 2: procesar constraints ── }
    OutCstrs := TJSONArray.Create;
    CstrId   := 0;
    Ser      := TASTSerializer.Create;
    try
      ExprsJ := JRoot.Find('expressions');
      if (ExprsJ <> nil) and (ExprsJ is TJSONArray) then
      begin
        ExprsArr := TJSONArray(ExprsJ);
        for i := 0 to ExprsArr.Count - 1 do
        begin
          if not (ExprsArr[i] is TJSONObject) then Continue;
          EObj := TJSONObject(ExprsArr[i]);
          if not (EObj.Find('constraints') is TJSONArray) then Continue;
          CstrArr := TJSONArray(EObj.Find('constraints'));

          for j := 0 to CstrArr.Count - 1 do
          begin
            if not (CstrArr[j] is TJSONString) then Continue;
            ExprStr := TJSONString(CstrArr[j]).Value;

            { Parsear AST }
            CstrObj := TJSONObject.Create;
            CstrObj.AddNum('id',   CstrId);
            CstrObj.AddStr('expr', ExprStr);

            VCnt := 0; FCnt := 0;
            Parser := TPrattParser.Create(ExprStr);
            try
              try
                AST := Parser.Parse;
                try
                  { Recolectar refs }
                  WalkRefs(AST, VRefs, VCnt, FRefs, FCnt);
                  { Serializar AST }
                  ASTNodes := Ser.Serialize(ExprStr, RootId);
                  CstrObj.AddNum('root',  RootId);
                  CstrObj.Add(   'nodes', ASTNodes);
                finally
                  AST.Free;
                end;
              except
                on E: Exception do
                  CstrObj.AddStr('error', E.Message);
              end;
            finally
              Parser.Free;
            end;

            { var_refs }
            VRefArr := TJSONArray.Create;
            for k := 0 to VCnt - 1 do
            begin
              VRefArr.AddNum(VRefs[k]);
              { actualizar índice inverso }
              if VRefs[k] < VarCount then
              begin
                if VarCstrCnt[VRefs[k]] >= Length(VarCstrs[VRefs[k]]) then
                  SetLength(VarCstrs[VRefs[k]], VarCstrCnt[VRefs[k]] * 2 + 4);
                VarCstrs[VRefs[k]][VarCstrCnt[VRefs[k]]] := CstrId;
                Inc(VarCstrCnt[VRefs[k]]);
              end;
            end;
            CstrObj.Add('var_refs', VRefArr);

            { func_refs }
            FRefArr := TJSONArray.Create;
            for k := 0 to FCnt - 1 do FRefArr.AddNum(FRefs[k]);
            CstrObj.Add('func_refs', FRefArr);

            OutCstrs.Add(CstrObj);
            Inc(CstrId);
          end;
        end;
      end;
    finally
      Ser.Free;
    end;

    { ── Fase 3: construir adjacency (índice inverso) ── }
    OutAdj := TJSONArray.Create;
    for i := 0 to VarCount - 1 do
    begin
      AdjObj := TJSONObject.Create;
      AdjObj.AddNum('var_id', VarTab[i].Id);
      AdjObj.AddStr('name',   VarTab[i].Name);
      VRefArr := TJSONArray.Create;
      for j := 0 to VarCstrCnt[i] - 1 do
        VRefArr.AddNum(VarCstrs[i][j]);
      AdjObj.Add('constraint_ids', VRefArr);
      OutAdj.Add(AdjObj);
    end;

    { ── Ensamblar salida ── }
    OutRoot := TJSONObject.Create;
    OutRoot.Add('variables',   OutVars);
    OutRoot.Add('functions',   OutFuncs);
    OutRoot.Add('constraints', OutCstrs);
    OutRoot.Add('adjacency',   OutAdj);

    OutStr := OutRoot.ToJSON(1);
    OutRoot.Free;

    if OutFile <> '' then
    begin
      AssignFile(TF, OutFile);
      Rewrite(TF);
      Write(TF, OutStr);
      CloseFile(TF);
      WriteLn('Escrito: ', OutFile,
              '  (', VarCount, ' vars, ', CstrId, ' constraints)');
    end
    else
      WriteLn(OutStr);

  finally
    JData.Free;
  end;
end.
