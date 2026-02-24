{ ╔════════════════════════════════════════════════════════════════╗
  ║ VerifyWithBison.pas                                          ║
  ║ Verifica soluciones CSP usando GNUBison como evaluador       ║
  ║                                                              ║
  ║ Uso: VerifyWithBison grafo.json < soluciones.txt            ║
  ║      TestGecodeBridge grafo.json | VerifyWithBison grafo.json║
  ║                                                              ║
  ║ Lee soluciones en formato "VAR1=val1 VAR2=val2 ..." desde   ║
  ║ stdin, transforma al formato GNUBison, invoca bridge, y     ║
  ║ verifica que todas las expresiones se evalúan correctamente. ║
  ╚════════════════════════════════════════════════════════════════╝ }

{$mode objfpc}{$H+}

program VerifyWithBison;

uses
  SysUtils, Unix;

const
  GNUBISON_BRIDGE = '/home/rodo/GNUBison/bin/bridge';
  SCALE_NUM       = 1000;   { scale factor for numeric variables }
  MAX_VARS        = 50;
  MAX_LABELS      = 512;
  MAX_EXPR        = 300;
  BATCH_SIZE      = 12;     { process solutions in batches of 12 }

type
  TSolutionVars = record
    Names  : array[0..49] of string;
    Values : array[0..49] of Integer;
    Count  : Integer;
  end;

  TBisonResult = record
    Valid         : Boolean;
    TotalExprs    : Integer;
    Errors        : Integer;
    ErrorMessage  : string;
  end;

  TLabelEntry = record
    VarName : string;
    Lbl     : string;
    IntVal  : Integer;
  end;

  TVariable = record
    Name    : string;
    VarType : string;  { boolean, integer, numeric, set }
  end;

var
  GraphFile   : string;
  GraphJSON   : string;  { raw JSON content }
  Variables   : array[0..MAX_VARS-1] of TVariable;
  NVars       : Integer;
  LabelMap    : array[0..MAX_LABELS-1] of TLabelEntry;
  NLabels     : Integer;
  Expressions : array[0..MAX_EXPR-1] of string;
  NExpr       : Integer;
  Solutions   : array[0..999] of TSolutionVars;
  NSols       : Integer;

{ ═══════════════════════════════════════════════════════════════
  Utilities
  ═══════════════════════════════════════════════════════════════ }

function StrUpper(const S: string): string;
var i: Integer;
begin
  Result := S;
  for i := 1 to Length(Result) do
    if Result[i] in ['a'..'z'] then Result[i] := Chr(Ord(Result[i]) - 32);
end;

function Trim(const S: string): string;
var i, j: Integer;
begin
  i := 1;
  while (i <= Length(S)) and (S[i] in [' ', #9, #10, #13]) do Inc(i);
  j := Length(S);
  while (j >= i) and (S[j] in [' ', #9, #10, #13]) do Dec(j);
  if i > j then Result := ''
  else Result := Copy(S, i, j - i + 1);
end;

function FindVarIdx(const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to NVars - 1 do
    if StrUpper(Variables[i].Name) = StrUpper(Name) then
    begin
      Result := i;
      Exit;
    end;
end;

function LabelIntToString(const VarName: string; IntVal: Integer): string;
var i: Integer;
begin
  Result := '';
  for i := 0 to NLabels - 1 do
    if (StrUpper(LabelMap[i].VarName) = StrUpper(VarName)) and
       (LabelMap[i].IntVal = IntVal) then
    begin
      Result := LabelMap[i].Lbl;
      Exit;
    end;
end;

{ ═══════════════════════════════════════════════════════════════
  Solution parser: "VAR1=val1 VAR2=val2 ..." → TSolutionVars
  ═══════════════════════════════════════════════════════════════ }

procedure ParseSolutionLine(const Line: string; var Sol: TSolutionVars);
var
  P, EqPos, VarIdx: Integer;
  Token, Name, ValStr: string;
  IntVal, Code: Integer;
begin
  FillChar(Sol, SizeOf(Sol), 0);
  P := 1;

  while P <= Length(Line) do
  begin
    { Skip whitespace }
    while (P <= Length(Line)) and (Line[P] in [' ', #9]) do Inc(P);
    if P > Length(Line) then Break;

    { Extract token until next space }
    Token := '';
    while (P <= Length(Line)) and not (Line[P] in [' ', #9]) do
    begin
      Token := Token + Line[P];
      Inc(P);
    end;

    { Parse VAR=value }
    EqPos := Pos('=', Token);
    if EqPos > 0 then
    begin
      Name := Copy(Token, 1, EqPos - 1);
      ValStr := Copy(Token, EqPos + 1, Length(Token));

      VarIdx := FindVarIdx(Name);
      if VarIdx >= 0 then
      begin
        Val(ValStr, IntVal, Code);
        if Code = 0 then
        begin
          if Sol.Count < 50 then
          begin
            Sol.Names[Sol.Count] := Name;
            Sol.Values[Sol.Count] := IntVal;
            Inc(Sol.Count);
          end;
        end;
      end;
    end;
  end;
end;

procedure ReadSolutions;
var
  Line: string;
begin
  NSols := 0;
  while not EOF(Input) do
  begin
    ReadLn(Line);
    Line := Trim(Line);
    if (Line <> '') and (NSols < 1000) then
    begin
      ParseSolutionLine(Line, Solutions[NSols]);
      if Solutions[NSols].Count > 0 then
        Inc(NSols);
    end;
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  JSON generation for GNUBison format
  ═══════════════════════════════════════════════════════════════ }

function EscapeJSON(const S: string): string;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
    case S[i] of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #10:  Result := Result + '\n';
      #13:  Result := Result + '\r';
      #9:   Result := Result + '\t';
      else  Result := Result + S[i];
    end;
end;

function TypeToBisonType(const GeType: string): string;
begin
  if GeType = 'boolean' then Result := 'logic'
  else if GeType = 'numeric' then Result := 'float'
  else Result := GeType;  { integer, set }
end;

function GetVarType(const VarName: string): string;
var i: Integer;
begin
  Result := 'integer';  { default }
  for i := 0 to NVars - 1 do
    if StrUpper(Variables[i].Name) = StrUpper(VarName) then
    begin
      Result := Variables[i].VarType;
      Exit;
    end;
end;

function FormatFloatValue(IntVal: Integer): string;
var
  F: Double;
begin
  F := IntVal / SCALE_NUM;
  Result := Format('%.3f', [F]);
end;

function TransformSolutionToGNUBison(const Sol: TSolutionVars): string;
var
  I: Integer;
  JSON, VarType, ValueStr: string;
  IntVal: Integer;
  LabelStr: string;
  FirstVar: Boolean;
begin
  JSON := '{' + LineEnding;
  JSON := JSON + '  "precision": 3,' + LineEnding;
  JSON := JSON + '  "variables": [' + LineEnding;

  { Variables }
  FirstVar := True;
  for I := 0 to Sol.Count - 1 do
  begin
    VarType := GetVarType(Sol.Names[I]);
    IntVal := Sol.Values[I];

    if not FirstVar then JSON := JSON + ',' + LineEnding;
    FirstVar := False;

    JSON := JSON + '    {' + LineEnding;
    JSON := JSON + '      "nombre": "' + Sol.Names[I] + '",' + LineEnding;
    JSON := JSON + '      "tipo": "' + TypeToBisonType(VarType) + '",' + LineEnding;

    { Value transformation by type }
    if VarType = 'boolean' then
    begin
      if IntVal = 1 then ValueStr := 'true'
      else ValueStr := 'false';
      JSON := JSON + '      "value": ' + ValueStr + LineEnding;
    end
    else if VarType = 'numeric' then
    begin
      ValueStr := FormatFloatValue(IntVal);
      JSON := JSON + '      "value": ' + ValueStr + LineEnding;
    end
    else if VarType = 'set' then
    begin
      { Convert integer to label string }
      LabelStr := LabelIntToString(Sol.Names[I], IntVal);
      if LabelStr <> '' then
      begin
        JSON := JSON + '      "value": ["' + EscapeJSON(LabelStr) + '"]' + LineEnding;
      end
      else
      begin
        JSON := JSON + '      "value": []' + LineEnding;
      end;
    end
    else  { integer }
    begin
      JSON := JSON + '      "value": ' + IntToStr(IntVal) + LineEnding;
    end;

    JSON := JSON + '    }';
  end;

  JSON := JSON + LineEnding + '  ],' + LineEnding;

  { Expressions - extract from constraints }
  JSON := JSON + '  "expresiones": [' + LineEnding;
  for I := 0 to NExpr - 1 do
  begin
    if I > 0 then JSON := JSON + ',' + LineEnding;
    JSON := JSON + '    "' + EscapeJSON(Expressions[I]) + '"';
  end;
  JSON := JSON + LineEnding + '  ]' + LineEnding;

  JSON := JSON + '}' + LineEnding;

  Result := JSON;
end;

{ ═══════════════════════════════════════════════════════════════
  GNUBison invocation
  ═══════════════════════════════════════════════════════════════ }

function InvokeGNUBison(const JsonInput: string; var JsonOutput: string): Boolean;
var
  InputFile, OutputFile, CmdLine: string;
  F: TextFile;
  Line: string;
  ExitCode: Integer;
begin
  Result := False;
  JsonOutput := '';

  { Create temp files }
  InputFile := '/tmp/bison_input_' + IntToStr(Random(999999)) + '.json';
  OutputFile := '/tmp/bison_output_' + IntToStr(Random(999999)) + '.json';

  try
    { Write input }
    AssignFile(F, InputFile);
    Rewrite(F);
    Write(F, JsonInput);
    CloseFile(F);

    { Execute bridge using shell command }
    CmdLine := GNUBISON_BRIDGE + ' "' + InputFile + '" "' + OutputFile + '" >/dev/null 2>&1';
    ExitCode := fpSystem(CmdLine);

    if (ExitCode = 0) and FileExists(OutputFile) then
    begin
      { Read output }
      AssignFile(F, OutputFile);
      Reset(F);
      JsonOutput := '';
      while not EOF(F) do
      begin
        ReadLn(F, Line);
        JsonOutput := JsonOutput + Line + LineEnding;
      end;
      CloseFile(F);
      Result := True;
    end;

  finally
    if FileExists(InputFile) then DeleteFile(InputFile);
    if FileExists(OutputFile) then DeleteFile(OutputFile);
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Result parsing
  ═══════════════════════════════════════════════════════════════ }

function ParseBisonResult(const JsonOutput: string; var Res: TBisonResult): Boolean;
var
  P, P2: Integer;

  function FindKeyLocal(const S, Key: string; From: Integer): Integer;
  var Pat: string; P: Integer;
  begin
    Pat := '"' + Key + '":';
    P := Pos(Pat, Copy(S, From, Length(S) - From + 1));
    if P > 0 then
      Result := From + P - 1 + Length(Pat)
    else
      Result := 0;
  end;

  function SkipWS(P: Integer): Integer;
  begin
    while (P <= Length(JsonOutput)) and
          (JsonOutput[P] in [' ', #9, #10, #13]) do Inc(P);
    Result := P;
  end;

  function ReadBool(var P: Integer): Boolean;
  begin
    P := SkipWS(P);
    if Copy(JsonOutput, P, 4) = 'true' then
    begin
      Result := True;
      Inc(P, 4);
    end
    else
    begin
      Result := False;
      Inc(P, 5);  { "false" }
    end;
  end;

  function ReadInt(var P: Integer): Integer;
  var Num: string; Code: Integer;
  begin
    P := SkipWS(P);
    Num := '';
    while (P <= Length(JsonOutput)) and (JsonOutput[P] in ['0'..'9', '-']) do
    begin
      Num := Num + JsonOutput[P];
      Inc(P);
    end;
    Val(Num, Result, Code);
    if Code <> 0 then Result := 0;
  end;

begin
  Result := False;
  FillChar(Res, SizeOf(Res), 0);

  { Find "resumen" section }
  P := Pos('"resumen"', JsonOutput);
  if P = 0 then Exit;

  { Find "valido" }
  P2 := FindKeyLocal(JsonOutput, 'valido', P);
  if P2 > 0 then
  begin
    Res.Valid := ReadBool(P2);
  end;

  { Find "total_expresiones" }
  P2 := FindKeyLocal(JsonOutput, 'total_expresiones', P);
  if P2 > 0 then
  begin
    Res.TotalExprs := ReadInt(P2);
  end;

  { Find "errores" }
  P2 := FindKeyLocal(JsonOutput, 'errores', P);
  if P2 > 0 then
  begin
    Res.Errors := ReadInt(P2);
  end;

  Result := True;
end;

{ ═══════════════════════════════════════════════════════════════
  Main verification loop
  ═══════════════════════════════════════════════════════════════ }

procedure VerifyAllSolutions;
var
  I, BatchStart, BatchEnd, BatchNum, TotalBatches: Integer;
  PassCount, FailCount: Integer;
  BisonJSON, BisonOutput: string;
  BisonRes: TBisonResult;
  Success: Boolean;
begin
  TotalBatches := (NSols + BATCH_SIZE - 1) div BATCH_SIZE;
  WriteLn(StdErr, Format('[VerifyWithBison] Verifying %d solutions in %d batches of %d...',
          [NSols, TotalBatches, BATCH_SIZE]));

  PassCount := 0;
  FailCount := 0;

  BatchNum := 0;
  BatchStart := 0;

  while BatchStart < NSols do
  begin
    Inc(BatchNum);
    BatchEnd := BatchStart + BATCH_SIZE - 1;
    if BatchEnd >= NSols then BatchEnd := NSols - 1;

    WriteLn(StdErr, Format('  Batch %d/%d: Solutions %d-%d',
            [BatchNum, TotalBatches, BatchStart + 1, BatchEnd + 1]));

    { Process this batch }
    for I := BatchStart to BatchEnd do
    begin
      { Transform solution to GNUBison format }
      BisonJSON := TransformSolutionToGNUBison(Solutions[I]);

      { Invoke GNUBison }
      Success := InvokeGNUBison(BisonJSON, BisonOutput);

      if Success then
      begin
        { Parse result }
        if ParseBisonResult(BisonOutput, BisonRes) then
        begin
          if BisonRes.Valid then
          begin
            Inc(PassCount);
            WriteLn(StdErr, Format('    Solution %d: PASS', [I + 1]));
          end
          else
          begin
            Inc(FailCount);
            WriteLn(StdErr, Format('    Solution %d: FAIL (%d errors)',
                    [I + 1, BisonRes.Errors]));
          end;
        end
        else
        begin
          Inc(FailCount);
          WriteLn(StdErr, Format('    Solution %d: ERROR parsing Bison output', [I + 1]));
        end;
      end
      else
      begin
        Inc(FailCount);
        WriteLn(StdErr, Format('    Solution %d: ERROR invoking GNUBison', [I + 1]));
      end;
    end;

    { Report batch progress }
    WriteLn(StdErr, Format('  Batch %d complete: %d passed, %d failed',
            [BatchNum, PassCount, FailCount]));

    BatchStart := BatchEnd + 1;
  end;

  { Output JSON summary }
  WriteLn('{');
  WriteLn('  "input_file": "', EscapeJSON(GraphFile), '",');
  WriteLn('  "gnubison_path": "', GNUBISON_BRIDGE, '",');
  WriteLn('  "solutions_total": ', NSols, ',');
  WriteLn('  "solutions_verified": ', PassCount + FailCount, ',');
  WriteLn('  "solutions_passed": ', PassCount, ',');
  WriteLn('  "solutions_failed": ', FailCount, ',');
  WriteLn('  "summary": {');
  WriteLn('    "all_passed": ', LowerCase(BoolToStr(FailCount = 0, True)), ',');
  if NSols > 0 then
    WriteLn('    "pass_rate": ', Format('%.2f', [PassCount / NSols]))
  else
    WriteLn('    "pass_rate": 0.0');
  WriteLn('  }');
  WriteLn('}');
end;

{ ═══════════════════════════════════════════════════════════════
  Read raw JSON and extract data
  ═══════════════════════════════════════════════════════════════ }

function FindKey(const S, Key: string; From: Integer): Integer;
var Pat: string; P: Integer;
begin
  Pat := '"' + Key + '":';
  P := Pos(Pat, Copy(S, From, Length(S) - From + 1));
  if P > 0 then
    Result := From + P - 1 + Length(Pat)  { position after the pattern }
  else
    Result := 0;
end;

function ExtractString(const S: string; From: Integer): string;
var P: Integer; InEscape: Boolean;
begin
  Result := '';
  P := From;
  while (P <= Length(S)) and (S[P] <> '"') do Inc(P);
  if P > Length(S) then Exit;
  Inc(P);  { skip opening quote }
  InEscape := False;
  while P <= Length(S) do
  begin
    if InEscape then
    begin
      Result := Result + S[P];
      InEscape := False;
    end
    else if S[P] = '\' then
      InEscape := True
    else if S[P] = '"' then
      Break
    else
      Result := Result + S[P];
    Inc(P);
  end;
end;

function SkipWhitespace(const S: string; P: Integer): Integer;
begin
  while (P <= Length(S)) and (S[P] in [' ', #9, #10, #13]) do Inc(P);
  Result := P;
end;

function FindNextChar(const S: string; P: Integer; Ch: Char): Integer;
var Level: Integer;
begin
  Result := 0;
  Level := 0;
  while P <= Length(S) do
  begin
    if S[P] = '{' then Inc(Level)
    else if S[P] = '}' then Dec(Level)
    else if S[P] = '[' then Inc(Level)
    else if S[P] = ']' then Dec(Level)
    else if (S[P] = Ch) and (Level = 0) then
    begin
      Result := P;
      Exit;
    end;
    Inc(P);
  end;
end;

procedure LoadGraphJSON;
var
  F: TextFile;
  Line: string;
  P, PEnd, PName, PType, PDomain, PExpr: Integer;
  VarName, VarType, LabelStr, ExprStr: string;
  VarBlock: string;
  Level, LabelIdx: Integer;
begin
  { Read entire JSON file }
  AssignFile(F, GraphFile);
  Reset(F);
  GraphJSON := '';
  while not EOF(F) do
  begin
    ReadLn(F, Line);
    GraphJSON := GraphJSON + Line + ' ';
  end;
  CloseFile(F);

  { Extract variables }
  NVars := 0;
  NLabels := 0;
  P := Pos('"variables"', GraphJSON);
  if P > 0 then
  begin
    P := Pos('[', Copy(GraphJSON, P, Length(GraphJSON))) + P - 1;
    Inc(P);  { skip [ }

    while (P < Length(GraphJSON)) and (NVars < MAX_VARS) do
    begin
      P := SkipWhitespace(GraphJSON, P);
      if P > Length(GraphJSON) then Break;
      if GraphJSON[P] = ']' then Break;  { end of array }
      if GraphJSON[P] = ',' then begin Inc(P); Continue; end;

      if GraphJSON[P] = '{' then
      begin
        { Find matching close brace }
        Level := 0;
        PEnd := P;
        while PEnd <= Length(GraphJSON) do
        begin
          if GraphJSON[PEnd] = '{' then Inc(Level)
          else if GraphJSON[PEnd] = '}' then
          begin
            Dec(Level);
            if Level = 0 then Break;
          end;
          Inc(PEnd);
        end;

        VarBlock := Copy(GraphJSON, P, PEnd - P + 1);

        { Extract name }
        VarName := '';
        PName := Pos('"name"', VarBlock);
        if PName > 0 then
          VarName := ExtractString(VarBlock, PName + 6);

        { Extract type }
        VarType := 'integer';
        PType := Pos('"type"', VarBlock);
        if PType > 0 then
          VarType := ExtractString(VarBlock, PType + 6);

        if VarName <> '' then
        begin
          Variables[NVars].Name := VarName;
          Variables[NVars].VarType := VarType;
          Inc(NVars);

          { Extract domain labels for set types }
          if VarType = 'set' then
          begin
            PDomain := Pos('"domain"', VarBlock);
            if PDomain > 0 then
            begin
              PDomain := Pos('[', Copy(VarBlock, PDomain, Length(VarBlock))) + PDomain - 1;
              if PDomain > 0 then
              begin
                Inc(PDomain);  { skip [ }
                LabelIdx := 0;
                while PDomain < Length(VarBlock) do
                begin
                  PDomain := SkipWhitespace(VarBlock, PDomain);
                  if (PDomain > Length(VarBlock)) or (VarBlock[PDomain] = ']') then Break;
                  if VarBlock[PDomain] = ',' then begin Inc(PDomain); Continue; end;

                  LabelStr := ExtractString(VarBlock, PDomain);
                  if (LabelStr <> '') and (NLabels < MAX_LABELS) then
                  begin
                    LabelMap[NLabels].VarName := VarName;
                    LabelMap[NLabels].Lbl := LabelStr;
                    LabelMap[NLabels].IntVal := LabelIdx;
                    Inc(NLabels);
                    Inc(LabelIdx);
                  end;

                  { Skip past this string }
                  while (PDomain <= Length(VarBlock)) and (VarBlock[PDomain] <> ',') and (VarBlock[PDomain] <> ']') do
                    Inc(PDomain);
                end;
              end;
            end;
          end;
        end;

        P := PEnd + 1;
      end
      else
        Inc(P);
    end;
  end;

  { Extract expressions from constraints }
  NExpr := 0;
  P := Pos('"constraints"', GraphJSON);
  if P > 0 then
  begin
    while P < Length(GraphJSON) do
    begin
      PExpr := FindKey(GraphJSON, 'expr', P);
      if PExpr = 0 then Break;

      { FindKey returns position after "expr:", so we need to skip to the string value }
      PExpr := SkipWhitespace(GraphJSON, PExpr);
      ExprStr := ExtractString(GraphJSON, PExpr);

      if ExprStr <> '' then
      begin
        if NExpr < MAX_EXPR then
        begin
          Expressions[NExpr] := ExprStr;
          Inc(NExpr);
        end;
      end;

      P := PExpr + Length(ExprStr) + 2;  { move past this expression }
    end;
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Main program
  ═══════════════════════════════════════════════════════════════ }

begin
  Randomize;

  if ParamCount < 1 then
  begin
    WriteLn(StdErr, 'Usage: VerifyWithBison grafo.json < soluciones.txt');
    WriteLn(StdErr, '       TestGecodeBridge grafo.json | VerifyWithBison grafo.json');
    Halt(2);
  end;

  GraphFile := ParamStr(1);

  { Load graph JSON and extract data }
  LoadGraphJSON;

  WriteLn(StdErr, Format('[VerifyWithBison] Loaded %d variables, %d labels, %d expressions',
          [NVars, NLabels, NExpr]));

  { Check GNUBison bridge exists }
  if not FileExists(GNUBISON_BRIDGE) then
  begin
    WriteLn(StdErr, 'ERROR: GNUBison bridge not found at: ', GNUBISON_BRIDGE);
    Halt(2);
  end;

  { Read solutions from stdin }
  ReadSolutions;

  if NSols = 0 then
  begin
    WriteLn(StdErr, '[VerifyWithBison] No solutions to verify');
    WriteLn('{"solutions_total": 0, "solutions_passed": 0, "solutions_failed": 0}');
    Halt(0);
  end;

  { Verify all solutions }
  VerifyAllSolutions;

  Halt(0);
end.
