program SyntaxChecker;

{$mode objfpc}{$H+}

(*
 * SyntaxChecker.pas
 *
 * PROPÓSITO: Validador sintáctico/semántico de JSON CSP (Etapa 1 del pipeline)
 * ──────────────────────────────────────────────────────────────────────────────
 * Primer componente del pipeline. Valida JSON de entrada ANTES de construcción
 * de AST, evitando errores costosos en etapas posteriores.
 *
 * DECISIÓN DE DISEÑO: ¿Por qué validación en 2 fases (Syntax → Graph)?
 * ──────────────────────────────────────────────────────────────────────────────
 * Alternativas:
 *   1. Validación única durante construcción AST → errores tardíos
 *   2. Schema JSON (JSON Schema Draft 7) → no valida referencias cruzadas
 *   3. ESTE: SyntaxChecker (reglas) → JsonToGraph (AST)
 *
 * Ventajas del diseño actual:
 *   - Fail-fast: detecta errores antes de parsing complejo
 *   - Reporta TODOS los errores (no solo el primero)
 *   - Valida reglas semánticas (var usada→declarada, etc.)
 *   - Salida JSON estructurada para tooling automático
 *
 * REGLAS DE VALIDACIÓN (9 categorías):
 * ──────────────────────────────────────────────────────────────────────────────
 *   0 - Estructura básica (campos obligatorios, tipos de datos)
 *   1 - Variable declarada → usada en al menos una expresión
 *   2 - Función user-defined declarada → llamada en al menos una expresión
 *   3 - Variable en expresión → declarada en variables
 *   4 - Función en expresión → declarada en functions (o es builtin del motor)
 *   5 - Constraint string → parseable sintácticamente (via PrattParser)
 *   6 - value ⊆ domain (por tipo de variable)
 *   7 - Args de llamada = inputs declarados en función (si arity fija)
 *   8 - Función estándar del motor no puede redeclararse (override no permitido)
 *
 * INTEGRACIÓN CON PIPELINE:
 * ──────────────────────────────────────────────────────────────────────────────
 * Ver pipeline.sh línea ~30:
 *   ./bin/SyntaxChecker input.json || exit 1
 *   ./bin/JsonToGraph input.json graph.json
 *
 * Uso:
 *   ./SyntaxChecker input.json
 *
 * Salida:
 *   JSON con "status": "ok" | "error"  y  "errors": [...]
 *   Exit code: 0 si OK, 1 si errores
 *
 * DISCIPLINA: Separation of concerns
 * ──────────────────────────────────────────────────────────────────────────────
 * SyntaxChecker valida: estructura, referencias, tipos, domains
 * JsonToGraph valida: AST well-formed, operadores compatibles con tipos
 * FunctionChecker valida: archivos .o/.so existen en filesystem
 *
 * REFERENCIAS TÉCNICAS:
 * ──────────────────────────────────────────────────────────────────────────────
 * [1] PrattParser.pas: usado para validar parseabilidad de expresiones (regla 5)
 * [2] MiniJSON.pas: parser JSON para leer estructura de entrada
 *)

uses
  MiniSys, MiniJSON, ExpressionAST, PrattParser;

// ── Tipos internos ──────────────────────────────────────────────────────────

type
  TVarKind = (vkBoolean, vkSet, vkInteger, vkNumeric, vkUnknown);

  TDeclaredVar = record
    Name:    string;
    Kind:    TVarKind;
    VarIdx:  Integer;   { índice en el array JSON de entrada }
    Used:    Boolean;
  end;

  TDeclaredFunc = record
    Name:       string;
    InputCount: Integer;  { -1 = arity variable (p.ej. LOG acepta 1 ó 2 args) }
    FuncIdx:    Integer;  { índice en "functions" del JSON; -1 si es builtin }
    Used:       Boolean;
    IsBuiltin:  Boolean;  { True = función del motor; False = user-defined }
  end;

  TErrorRec = record
    Rule:     Integer;
    Msg:      string;
    Location: string;
  end;

// ── Variables globales ──────────────────────────────────────────────────────

var
  Errors:    array of TErrorRec;
  ErrCount:  Integer;

  VarTable:  array of TDeclaredVar;
  VarCount:  Integer;

  FuncTable: array of TDeclaredFunc;
  FuncCount: Integer;

  { Literales conocidos: true, false, etiquetas de variables tipo set.
    Los identificadores que pertenezcan a esta tabla no se chequean
    contra VarTable (no son variables de usuario). }
  LitTable:  array of string;
  LitCount:  Integer;

// ── Helpers de error ────────────────────────────────────────────────────────

procedure AddError(Rule: Integer; const Msg, Location: string);
begin
  if ErrCount >= Length(Errors) then
    SetLength(Errors, ErrCount + 64);
  Errors[ErrCount].Rule     := Rule;
  Errors[ErrCount].Msg      := Msg;
  Errors[ErrCount].Location := Location;
  Inc(ErrCount);
end;

// ── Tabla de literales ───────────────────────────────────────────────────────

procedure RegLiteral(const S: string);
begin
  if LitCount >= Length(LitTable) then
    SetLength(LitTable, LitCount + 64);
  LitTable[LitCount] := UpperCase(S);
  Inc(LitCount);
end;

function IsLiteral(const S: string): Boolean;
var i: Integer;
begin
  Result := False;
  for i := 0 to LitCount - 1 do
    if LitTable[i] = UpperCase(S) then begin Result := True; Exit; end;
end;

// ── Tabla de variables ──────────────────────────────────────────────────────

procedure RegVar(const Name: string; Kind: TVarKind; Idx: Integer);
begin
  if VarCount >= Length(VarTable) then
    SetLength(VarTable, VarCount + 64);
  VarTable[VarCount].Name   := UpperCase(Name);
  VarTable[VarCount].Kind   := Kind;
  VarTable[VarCount].VarIdx := Idx;
  VarTable[VarCount].Used   := False;
  Inc(VarCount);
end;

function FindVar(const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to VarCount - 1 do
    if VarTable[i].Name = UpperCase(Name) then
    begin
      Result := i; Exit;
    end;
end;

// ── Tabla de funciones ──────────────────────────────────────────────────────

{ Registra una función builtin del motor (no declarable en "functions") }
procedure RegBuiltin(const Name: string; InputCount: Integer);
begin
  if FuncCount >= Length(FuncTable) then
    SetLength(FuncTable, FuncCount + 64);
  FuncTable[FuncCount].Name       := UpperCase(Name);
  FuncTable[FuncCount].InputCount := InputCount;
  FuncTable[FuncCount].FuncIdx    := -1;
  FuncTable[FuncCount].Used       := False;
  FuncTable[FuncCount].IsBuiltin  := True;
  Inc(FuncCount);
end;

{ Registra una función user-defined declarada en "functions" }
procedure RegFunc(const Name: string; InputCount, Idx: Integer);
begin
  if FuncCount >= Length(FuncTable) then
    SetLength(FuncTable, FuncCount + 64);
  FuncTable[FuncCount].Name       := UpperCase(Name);
  FuncTable[FuncCount].InputCount := InputCount;
  FuncTable[FuncCount].FuncIdx    := Idx;
  FuncTable[FuncCount].Used       := False;
  FuncTable[FuncCount].IsBuiltin  := False;
  Inc(FuncCount);
end;

function FindFunc(const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to FuncCount - 1 do
    if FuncTable[i].Name = UpperCase(Name) then
    begin
      Result := i; Exit;
    end;
end;

// ── AST Walker ──────────────────────────────────────────────────────────────

procedure WalkAST(Node: TASTNode; const Loc: string); forward;

procedure WalkAST(Node: TASTNode; const Loc: string);
var
  BinOp: TBinaryOpNode;
  UnOp:  TUnaryOpNode;
  FuncN: TFunctionCallNode;
  SetN:  TSetNode;
  Intv:  TIntervalNode;
  vi, fi, i: Integer;
begin
  if Node = nil then Exit;
  case Node.NodeType of

    ntVariable:
    begin
      { true/false y etiquetas de sets son literales, no variables de usuario }
      if IsLiteral(TVariableNode(Node).Name) then Exit;
      vi := FindVar(TVariableNode(Node).Name);
      if vi < 0 then
        AddError(3,
          'Variable ''' + TVariableNode(Node).Name + ''' no declarada',
          Loc)
      else
        VarTable[vi].Used := True;
    end;

    ntFunctionCall:
    begin
      FuncN := TFunctionCallNode(Node);
      fi    := FindFunc(FuncN.Name);
      if fi < 0 then
        AddError(4,
          'Función ''' + FuncN.Name + ''' no declarada en functions',
          Loc)
      else
      begin
        FuncTable[fi].Used := True;
        { Regla 7: cantidad de argumentos = inputs declarados
          InputCount=-1 significa arity variable → no verificar }
        if (FuncTable[fi].InputCount >= 0) and
           (FuncN.Arguments.Count <> FuncTable[fi].InputCount) then
          AddError(7,
            'Función ''' + FuncN.Name + ''': declarada con ' +
            IntToStr(FuncTable[fi].InputCount) + ' input(s), ' +
            'llamada con ' + IntToStr(FuncN.Arguments.Count) + ' arg(s)',
            Loc);
      end;
      for i := 0 to FuncN.Arguments.Count - 1 do
        WalkAST(FuncN.Arguments[i], Loc);
    end;

    ntAdd, ntSubtract, ntMultiply, ntDivide, ntModulo, ntPower,
    ntAnd, ntOr,
    ntEquals, ntNotEquals, ntLess, ntGreater, ntLessEq, ntGreaterEq,
    ntIn:
    begin
      BinOp := TBinaryOpNode(Node);
      WalkAST(BinOp.Left,  Loc);
      WalkAST(BinOp.Right, Loc);
    end;

    ntNegate, ntNot:
    begin
      UnOp := TUnaryOpNode(Node);
      WalkAST(UnOp.Operand, Loc);
    end;

    ntDiscreteSet:
    begin
      SetN := TSetNode(Node);
      for i := 0 to SetN.Elements.Count - 1 do
        WalkAST(SetN.Elements[i], Loc);
    end;

    ntInterval:
    begin
      Intv := TIntervalNode(Node);
      WalkAST(Intv.Start, Loc);
      WalkAST(Intv.Stop,  Loc);
    end;

    { ntNumber, ntBoolean: hojas — nada que hacer }
  end;
end;

// ── Parse de tipo ───────────────────────────────────────────────────────────

function ParseKind(const S: string): TVarKind;
begin
  case UpperCase(S) of
    'BOOLEAN': Result := vkBoolean;
    'SET':     Result := vkSet;
    'INTEGER': Result := vkInteger;
    'NUMERIC': Result := vkNumeric;
  else         Result := vkUnknown;
  end;
end;

// ── Validación value ⊆ domain (Regla 6) ─────────────────────────────────────

procedure ValidateDomainValue(Kind: TVarKind;
                              DomJ, ValJ: TJSONValue;
                              const Loc: string);
var
  DomArr, ValArr: TJSONArray;
  i, j:           Integer;
  Found:          Boolean;
  DomLo, DomHi:  Double;
  ValLo, ValHi:  Double;
  VS:             string;
  VE:             TJSONValue;
begin
  if not (DomJ is TJSONArray) then
  begin
    AddError(6, 'domain debe ser un array JSON', Loc);
    Exit;
  end;
  if not (ValJ is TJSONArray) then
  begin
    AddError(6, 'value debe ser un array JSON', Loc);
    Exit;
  end;
  DomArr := TJSONArray(DomJ);
  ValArr := TJSONArray(ValJ);

  case Kind of

    vkNumeric:
    begin
      { domain: [lo, hi]  value: [lo, hi] }
      if DomArr.Count <> 2 then
      begin
        AddError(6, 'Numeric domain debe tener exactamente [lo, hi]', Loc);
        Exit;
      end;
      if ValArr.Count <> 2 then
      begin
        AddError(6, 'Numeric value debe tener exactamente [lo, hi]', Loc);
        Exit;
      end;
      DomLo := DomArr[0].AsFloat;
      DomHi := DomArr[1].AsFloat;
      ValLo := ValArr[0].AsFloat;
      ValHi := ValArr[1].AsFloat;
      if ValLo > ValHi then
        AddError(6,
          'Numeric value: lo (' + FloatToStr(ValLo) +
          ') > hi (' + FloatToStr(ValHi) + ')', Loc);
      if (ValLo < DomLo) or (ValHi > DomHi) then
        AddError(6,
          'Numeric value [' + FloatToStr(ValLo) + ', ' + FloatToStr(ValHi) +
          '] fuera del domain [' + FloatToStr(DomLo) + ', ' + FloatToStr(DomHi) + ']',
          Loc);
    end;

    vkBoolean:
    begin
      { value subset de true/false }
      for i := 0 to ValArr.Count - 1 do
      begin
        VE := ValArr[i];
        if not (VE is TJSONBoolean) then
        begin
          AddError(6,
            'Boolean value: elemento ' + IntToStr(i) +
            ' debe ser true o false', Loc);
          Continue;
        end;
        Found := False;
        for j := 0 to DomArr.Count - 1 do
          if (DomArr[j] is TJSONBoolean) and
             (TJSONBoolean(DomArr[j]).Value = TJSONBoolean(VE).Value) then
            Found := True;
        if not Found then
          AddError(6,
            'Boolean value: ' + VE.ToJSON + ' no está en domain', Loc);
      end;
    end;

    vkSet:
    begin
      { value ⊆ domain — comparación por string }
      for i := 0 to ValArr.Count - 1 do
      begin
        VS := ValArr[i].AsString;
        Found := False;
        for j := 0 to DomArr.Count - 1 do
          if DomArr[j].AsString = VS then Found := True;
        if not Found then
          AddError(6,
            'Set value: ''' + VS + ''' no está en domain', Loc);
      end;
    end;

    vkInteger:
    begin
      { value ⊆ domain — comparación numérica }
      for i := 0 to ValArr.Count - 1 do
      begin
        VE := ValArr[i];
        if not (VE is TJSONNumber) then
        begin
          AddError(6,
            'Integer value: elemento ' + IntToStr(i) + ' debe ser número', Loc);
          Continue;
        end;
        ValLo := TJSONNumber(VE).Value;
        Found := False;
        for j := 0 to DomArr.Count - 1 do
          if (DomArr[j] is TJSONNumber) and
             (TJSONNumber(DomArr[j]).Value = ValLo) then
            Found := True;
        if not Found then
          AddError(6,
            'Integer value: ' + FloatToStr(ValLo) + ' no está en domain', Loc);
      end;
    end;

  end; { case }
end;

// ── Carga de variables de un array JSON (global o inputs de función) ─────────

{ WithValue:    True → exige campo "value" y valida value ⊆ domain (Regla 6)
  WithRegister: True → registra la variable en VarTable global (Regla 1/3)
                False → solo valida estructura (para inputs/outputs de funciones) }
procedure LoadVars(Arr: TJSONArray; const Prefix: string;
                   WithValue: Boolean; WithRegister: Boolean = True);
var
  i, k:   Integer;
  VObj:   TJSONObject;
  Loc:    string;
  VName:  string;
  Kind:   TVarKind;
  DomJ, ValJ: TJSONValue;
begin
  for i := 0 to Arr.Count - 1 do
  begin
    if not (Arr[i] is TJSONObject) then Continue;
    VObj := TJSONObject(Arr[i]);
    Loc  := Prefix + '[' + IntToStr(i) + ']';

    VName := VObj.GetStr('name', '');
    if VName = '' then
    begin
      AddError(0, 'Variable sin campo "name"', Loc);
      Continue;
    end;

    Kind := ParseKind(VObj.GetStr('type', ''));
    if Kind = vkUnknown then
      AddError(0,
        'Variable ''' + VName + ''': tipo desconocido "' +
        VObj.GetStr('type', '') + '"', Loc);

    DomJ := VObj.Find('domain');
    if DomJ = nil then
      AddError(0, 'Variable ''' + VName + ''': falta campo "domain"', Loc)
    else if (Kind = vkSet) and (DomJ is TJSONArray) then
    begin
      { Registrar etiquetas del dominio como literales conocidos }
      for k := 0 to TJSONArray(DomJ).Count - 1 do
        RegLiteral(TJSONArray(DomJ)[k].AsString);
    end;

    if WithValue then
    begin
      ValJ := VObj.Find('value');
      if ValJ = nil then
        AddError(0, 'Variable ''' + VName + ''': falta campo "value"', Loc)
      else if DomJ <> nil then
        ValidateDomainValue(Kind, DomJ, ValJ, Loc);
    end;

    if WithRegister then
      RegVar(VName, Kind, i);
  end;
end;

// ── Main ───────────────────────────────────────────────────────────────────

var
  InFile:   string;
  RawBuf:   array of Byte;
  RawStr:   string;
  F:        file;
  FSize:    Int64;

  JData:    TJSONValue;
  JRoot:    TJSONObject;

  VarsJ:    TJSONValue;
  ExprsJ:   TJSONValue;
  FuncsJ:   TJSONValue;

  ExprsArr: TJSONArray;
  FuncsArr: TJSONArray;

  ExprObj:  TJSONObject;
  FuncObj:  TJSONObject;
  CstrArr:  TJSONArray;
  InputsJ:  TJSONValue;
  CstrV:    TJSONValue;

  FName:    string;
  CstrStr:  string;
  Parser:   TPrattParser;
  AST:      TASTNode;
  Loc:      string;

  OutRoot:  TJSONObject;
  OutErrs:  TJSONArray;
  ErrObj:   TJSONObject;
  i, j:    Integer;

begin
  DefaultFormatSettings.DecimalSeparator := '.';

  if ParamCount < 1 then
  begin
    WriteLn('Uso: SyntaxChecker input.json');
    Halt(0);
  end;

  InFile := ParamStr(1);
  if not FileExists(InFile) then
  begin
    WriteLn('{"status":"error","errors":[{"rule":0,"message":"Archivo no encontrado","location":"cli"}]}');
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

  { Parsear JSON }
  JData := ParseJSON(RawStr);
  if not (JData is TJSONObject) then
  begin
    WriteLn('{"status":"error","errors":[{"rule":0,"message":"JSON raiz invalido","location":"root"}]}');
    Halt(1);
  end;
  JRoot := TJSONObject(JData);

  SetLength(Errors,    64);  ErrCount  := 0;
  SetLength(VarTable,  64);  VarCount  := 0;
  SetLength(FuncTable, 128); FuncCount := 0;
  SetLength(LitTable,  32);  LitCount  := 0;

  { Literales booleanos built-in }
  RegLiteral('TRUE');
  RegLiteral('FALSE');

  { ── Funciones estándar del motor (no declarables en "functions") ──
    InputCount = -1 significa arity variable (no se verifica en Regla 7) }
  { Trigonométricas — 1 arg }
  RegBuiltin('SIN',   1);  RegBuiltin('COS',   1);  RegBuiltin('TAN',   1);
  RegBuiltin('ASIN',  1);  RegBuiltin('ACOS',  1);  RegBuiltin('ATAN',  1);
  RegBuiltin('ATAN2', 2);
  { Exponencial / logarítmica }
  RegBuiltin('SQRT',  1);  RegBuiltin('EXP',   1);
  RegBuiltin('LN',    1);  RegBuiltin('LOG10', 1);  RegBuiltin('LOG2',  1);
  RegBuiltin('LOG',  -1);  { acepta 1 ó 2 args }
  RegBuiltin('POW',   2);
  { Redondeo y valor absoluto }
  RegBuiltin('ABS',   1);  RegBuiltin('SIGN',  1);
  RegBuiltin('FLOOR', 1);  RegBuiltin('CEIL',  1);
  RegBuiltin('ROUND', 1);  RegBuiltin('TRUNC', 1);
  { Mín / máx / módulo }
  RegBuiltin('MIN',   2);  RegBuiltin('MAX',   2);  RegBuiltin('MOD',   2);
  RegBuiltin('HYPOT', 2);
  { Operaciones de conjuntos }
  RegBuiltin('UNION',      2);  RegBuiltin('INTER',       2);
  RegBuiltin('DIFF',       2);  RegBuiltin('CARD',        1);
  RegBuiltin('ISSUBSET',   2);  RegBuiltin('ISSUPERSET',  2);
  RegBuiltin('DISJOINT',   2);  RegBuiltin('INTERSECTS',  2);

  { ── Fase 1: cargar variables globales ── }
  VarsJ := JRoot.Find('variables');
  if (VarsJ <> nil) and (VarsJ is TJSONArray) then
    LoadVars(TJSONArray(VarsJ), 'variables', True)
  else
    AddError(0, 'Falta el array "variables"', 'root');

  { ── Fase 1: cargar funciones ── }
  FuncsJ := JRoot.Find('functions');
  if (FuncsJ <> nil) and (FuncsJ is TJSONArray) then
  begin
    FuncsArr := TJSONArray(FuncsJ);
    for i := 0 to FuncsArr.Count - 1 do
    begin
      if not (FuncsArr[i] is TJSONObject) then Continue;
      FuncObj := TJSONObject(FuncsArr[i]);
      Loc     := 'functions[' + IntToStr(i) + ']';

      FName := FuncObj.GetStr('name', '');
      if FName = '' then
      begin
        AddError(0, 'Función sin campo "name"', Loc);
        Continue;
      end;

      { Regla 8: no se permite redeclarar una función estándar del motor }
      j := FindFunc(FName);
      if (j >= 0) and FuncTable[j].IsBuiltin then
      begin
        AddError(8,
          'Override no permitido: "' + UpperCase(FName) +
          '" es una función estándar del motor',
          Loc);
        Continue;
      end;

      InputsJ := FuncObj.Find('inputs');
      j := 0;
      if (InputsJ <> nil) and (InputsJ is TJSONArray) then
      begin
        j := TJSONArray(InputsJ).Count;
        { Validar estructura de inputs — solo domain, sin value, sin registrar en VarTable }
        LoadVars(TJSONArray(InputsJ), Loc + '.inputs', False, False);
      end;

      { También validar outputs }
      InputsJ := FuncObj.Find('outputs');
      if (InputsJ <> nil) and (InputsJ is TJSONArray) then
        LoadVars(TJSONArray(InputsJ), Loc + '.outputs', False, False);

      RegFunc(FName, j, i);
    end;
  end;
  { functions es opcional — no es error si no existe }

  { ── Fase 2+3: parsear constraints y walk AST ── }
  ExprsJ := JRoot.Find('expressions');
  if (ExprsJ <> nil) and (ExprsJ is TJSONArray) then
  begin
    ExprsArr := TJSONArray(ExprsJ);
    for i := 0 to ExprsArr.Count - 1 do
    begin
      if not (ExprsArr[i] is TJSONObject) then Continue;
      ExprObj := TJSONObject(ExprsArr[i]);

      CstrArr := nil;
      if ExprObj.Find('constraints') is TJSONArray then
        CstrArr := TJSONArray(ExprObj.Find('constraints'));
      if CstrArr = nil then Continue;

      for j := 0 to CstrArr.Count - 1 do
      begin
        Loc  := 'expressions[' + IntToStr(i) + '].constraints[' + IntToStr(j) + ']';
        CstrV := CstrArr[j];
        if not (CstrV is TJSONString) then
        begin
          AddError(5, 'Constraint debe ser un string', Loc);
          Continue;
        end;
        CstrStr := TJSONString(CstrV).Value;

        { Regla 5: parseable }
        Parser := TPrattParser.Create(CstrStr);
        try
          try
            AST := Parser.Parse;
            try
              WalkAST(AST, Loc);  { Reglas 3, 4, 7 }
            finally
              AST.Free;
            end;
          except
            on E: Exception do
              AddError(5, 'Sintaxis inválida: ' + E.Message, Loc);
          end;
        finally
          Parser.Free;
        end;
      end;
    end;
  end
  else
    AddError(0, 'Falta el array "expressions"', 'root');

  { ── Fase 4: validación cruzada ── }

  { Regla 1: variable declarada pero no usada }
  for i := 0 to VarCount - 1 do
    if not VarTable[i].Used then
      AddError(1,
        'Variable ''' + VarTable[i].Name +
        ''' declarada pero no usada en ninguna expresión',
        'variables[' + IntToStr(VarTable[i].VarIdx) + ']');

  { Regla 2: función user-defined declarada pero no llamada
    (las builtins no se validan aquí — no necesitan ser "usadas") }
  for i := 0 to FuncCount - 1 do
    if (not FuncTable[i].IsBuiltin) and (not FuncTable[i].Used) then
      AddError(2,
        'Función ''' + FuncTable[i].Name +
        ''' declarada pero no llamada en ninguna expresión',
        'functions[' + IntToStr(FuncTable[i].FuncIdx) + ']');

  { ── Generar salida JSON ── }
  OutRoot := TJSONObject.Create;
  OutErrs := TJSONArray.Create;

  if ErrCount = 0 then
    OutRoot.AddStr('status', 'ok')
  else
    OutRoot.AddStr('status', 'error');

  for i := 0 to ErrCount - 1 do
  begin
    ErrObj := TJSONObject.Create;
    ErrObj.AddNum('rule',     Errors[i].Rule);
    ErrObj.AddStr('message',  Errors[i].Msg);
    ErrObj.AddStr('location', Errors[i].Location);
    OutErrs.Add(ErrObj);
  end;

  OutRoot.Add('errors', OutErrs);
  WriteLn(OutRoot.ToJSON(2));

  OutRoot.Free;
  JData.Free;
end.
