{ ╔════════════════════════════════════════════════════════════════╗
  ║ GecodeInfo.pas                                               ║
  ║ Análisis del espacio de soluciones CSP con Gecode            ║
  ║                                                              ║
  ║ Input:  output de JsonToGraph (variables + AST)             ║
  ║ Output: JSON con total de soluciones y análisis if_fixed     ║
  ║         por variable no-determinada.                         ║
  ║                                                              ║
  ║ Variables numéricas: rescaladas a ~20 puntos de malla antes  ║
  ║ de construir el modelo Gecode (evita dominios de 100K vals). ║
  ╚════════════════════════════════════════════════════════════════╝ }

{$mode objfpc}{$H+}

program GecodeInfo;

uses SysUtils, UGecodeBridge, UCSPJson;

const
  NBINS_NUMERIC = 20;

{ ═══════════════════════════════════════════════════════════════
  Helpers de parseo JSON mínimos (solo para leer variables/value)
  ═══════════════════════════════════════════════════════════════ }

function GI_SkipWS(const S: string; P: Integer): Integer;
begin
  while (P <= Length(S)) and (S[P] in [' ',#9,#10,#13]) do Inc(P);
  Result := P;
end;

function GI_ReadStr(const S: string; var P: Integer): string;
begin
  Result := ''; P := GI_SkipWS(S, P);
  if (P > Length(S)) or (S[P] <> '"') then Exit;
  Inc(P);
  while (P <= Length(S)) and (S[P] <> '"') do begin Result := Result + S[P]; Inc(P); end;
  if P <= Length(S) then Inc(P);
end;

function GI_FindKey(const S, Key: string; From: Integer): Integer;
var Pat: string; P: Integer;
begin
  Pat := '"' + Key + '":'; Result := 0; P := From;
  while P <= Length(S) - Length(Pat) + 1 do
  begin
    if Copy(S, P, Length(Pat)) = Pat then begin Result := P + Length(Pat); Exit; end;
    Inc(P);
  end;
end;

function GI_ExtractBlock(const S: string; var P: Integer): string;
var Start, Level: Integer;
begin
  Result := ''; P := GI_SkipWS(S, P);
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

procedure GI_ReadMixedArray(const S: string; var P: Integer;
                             var Arr: array of string; var N: Integer);
var V: string; Ch: Char;
begin
  N := 0; P := GI_SkipWS(S, P);
  if (P > Length(S)) or (S[P] <> '[') then Exit;
  Inc(P);
  while P <= Length(S) do
  begin
    P := GI_SkipWS(S, P);
    if (P > Length(S)) or (S[P] = ']') then Break;
    Ch := S[P];
    if Ch = '"' then
    begin
      V := GI_ReadStr(S, P);
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
  Dominio de análisis por variable
  ═══════════════════════════════════════════════════════════════ }

type
  TVarDomain = record
    Name       : string;
    VarType    : string;
    { boolean/integer: valores enteros a probar con CT_EQ }
    IVals      : array[0..99] of Integer;
    NIVals     : Integer;
    { set: labels y sus códigos enteros }
    SLabels    : array[0..99] of string;
    SIVals     : array[0..99] of Integer;
    NSVals     : Integer;
    { numeric: intervalo reducido en floats + escala efectiva }
    NumLo      : Double;
    NumHi      : Double;
    NumScale   : Integer;   { escala efectiva tras rescalado }
    { true si solo hay un valor posible (no reportar) }
    Determined : Boolean;
  end;

{ ── helpers de índice ──────────────────────────────────────── }

function LMapFind(const Datos: TCSPData; VI: Integer; const Lbl: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to Datos.NLMap - 1 do
    if (Datos.LMap[i].VarIdx = VI) and
       (UpperCase(Datos.LMap[i].Lbl) = UpperCase(Lbl)) then
    begin Result := Datos.LMap[i].IntVal; Exit; end;
end;

function VarIdxByName(const Datos: TCSPData; const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to Datos.NVars - 1 do
    if UpperCase(PChar(@Datos.Vars[i].Name)) = UpperCase(Name) then
    begin Result := i; Exit; end;
end;

{ ═══════════════════════════════════════════════════════════════
  ReadVarDomains — lee el campo "value" de cada variable
  ═══════════════════════════════════════════════════════════════ }

procedure ReadVarDomains(const FileName: string;
                         const Datos: TCSPData;
                         var Doms: array of TVarDomain;
                         var NDoms: Integer);
var
  F: Text;
  Todo, Linea, Bloque, Nombre, TypeStr: string;
  StrArr: array[0..63] of string;
  N, P, PA, I, K, VI, Code: Integer;
  VLo, VHi: Double;
begin
  NDoms := 0;
  Assign(F, FileName);
  {$I-} Reset(F); {$I+}
  if IOResult <> 0 then Exit;
  Todo := '';
  while not EOF(F) do begin ReadLn(F, Linea); Todo := Todo + Linea + ' '; end;
  Close(F);

  P := GI_FindKey(Todo, 'variables', 1);
  if P = 0 then Exit;
  P := GI_SkipWS(Todo, P);
  if (P > Length(Todo)) or (Todo[P] <> '[') then Exit;
  Inc(P);

  while (P <= Length(Todo)) and (Todo[P] <> ']') do
  begin
    P := GI_SkipWS(Todo, P);
    if (P > Length(Todo)) or (Todo[P] = ']') then Break;
    if Todo[P] = ',' then begin Inc(P); Continue; end;
    Bloque := GI_ExtractBlock(Todo, P);
    if Bloque = '' then Break;
    if NDoms >= MAX_CSP_VARS then Break;

    Nombre := ''; TypeStr := '';
    PA := GI_FindKey(Bloque, 'name', 1); if PA > 0 then Nombre  := GI_ReadStr(Bloque, PA);
    PA := GI_FindKey(Bloque, 'type', 1); if PA > 0 then TypeStr := GI_ReadStr(Bloque, PA);
    if Nombre = '' then Continue;

    VI := VarIdxByName(Datos, Nombre);
    if VI < 0 then Continue;

    Doms[NDoms].Name       := Nombre;
    Doms[NDoms].VarType    := TypeStr;
    Doms[NDoms].NIVals     := 0;
    Doms[NDoms].NSVals     := 0;
    Doms[NDoms].NumLo      := 0;
    Doms[NDoms].NumHi      := 0;
    Doms[NDoms].NumScale   := SCALE_NUM;
    Doms[NDoms].Determined := False;

    PA := GI_FindKey(Bloque, 'value', 1);
    N := 0;
    if PA > 0 then GI_ReadMixedArray(Bloque, PA, StrArr, N);

    if TypeStr = 'boolean' then
    begin
      for I := 0 to N - 1 do
        if      StrArr[I] = 'true'  then begin Doms[NDoms].IVals[Doms[NDoms].NIVals] := 1; Inc(Doms[NDoms].NIVals); end
        else if StrArr[I] = 'false' then begin Doms[NDoms].IVals[Doms[NDoms].NIVals] := 0; Inc(Doms[NDoms].NIVals); end;
      Doms[NDoms].Determined := (Doms[NDoms].NIVals <= 1);
    end

    else if TypeStr = 'integer' then
    begin
      for I := 0 to N - 1 do
      begin
        Val(StrArr[I], K, Code);
        if Code = 0 then begin Doms[NDoms].IVals[Doms[NDoms].NIVals] := K; Inc(Doms[NDoms].NIVals); end;
      end;
      Doms[NDoms].Determined := (Doms[NDoms].NIVals <= 1);
    end

    else if TypeStr = 'set' then
    begin
      for I := 0 to N - 1 do
      begin
        K := LMapFind(Datos, VI, StrArr[I]);
        if K >= 0 then
        begin
          Doms[NDoms].SLabels[Doms[NDoms].NSVals] := StrArr[I];
          Doms[NDoms].SIVals[Doms[NDoms].NSVals]  := K;
          Inc(Doms[NDoms].NSVals);
        end;
      end;
      Doms[NDoms].Determined := (Doms[NDoms].NSVals <= 1);
    end

    else if TypeStr = 'numeric' then
    begin
      VLo := 0; VHi := 0;
      if N >= 1 then Val(StrArr[0], VLo, Code);
      if N >= 2 then Val(StrArr[1], VHi, Code);
      Doms[NDoms].NumLo      := VLo;
      Doms[NDoms].NumHi      := VHi;
      Doms[NDoms].Determined := (VLo = VHi);
    end;

    Inc(NDoms);
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  RescaleNumericVars — reduce dominios numéricos a ~20 puntos
  ═══════════════════════════════════════════════════════════════ }

procedure RescaleNumericVars(var Datos: TCSPData;
                              var Doms: array of TVarDomain;
                              NDoms: Integer);
var
  I, J, VI, CoarseScale: Integer;
  Range: Double;
  VarNameBuf: string;
begin
  for I := 0 to NDoms - 1 do
  begin
    if Doms[I].VarType <> 'numeric' then Continue;

    Range := Doms[I].NumHi - Doms[I].NumLo;
    if Range <= 0 then Continue;

    { Escala que da ~NBINS_NUMERIC puntos: CoarseScale ≈ NBINS_NUMERIC / range }
    CoarseScale := Round(NBINS_NUMERIC / Range);
    if CoarseScale < 1 then CoarseScale := 1;

    VI := VarIdxByName(Datos, Doms[I].Name);
    if VI < 0 then Continue;

    { Reemplazar variable Gecode con dominio fino → dominio coarse }
    Datos.Vars[VI] := CSPMakeVar(
      Doms[I].Name,
      Round(Doms[I].NumLo * CoarseScale),
      Round(Doms[I].NumHi * CoarseScale)
    );
    Datos.VarScales[VI] := CoarseScale;

    { Rescalar todas las constraints de esta variable que usan SCALE_NUM }
    VarNameBuf := UpperCase(Doms[I].Name);
    for J := 0 to Datos.NCons - 1 do
    begin
      if UpperCase(PChar(@Datos.Cons[J].Var1)) <> VarNameBuf then Continue;
      case Datos.Cons[J].CType of
        CT_IN_INTERVAL:
        begin
          Datos.Cons[J].Lo := Round(Datos.Cons[J].Lo * CoarseScale / SCALE_NUM);
          Datos.Cons[J].Hi := Round(Datos.Cons[J].Hi * CoarseScale / SCALE_NUM);
        end;
        CT_EQ, CT_NEQ, CT_LT, CT_GT, CT_LE, CT_GE:
          Datos.Cons[J].Constant := Round(Datos.Cons[J].Constant * CoarseScale / SCALE_NUM);
      end;
    end;

    { Guardar escala efectiva para bins en WriteAnalysisJSON }
    Doms[I].NumScale := CoarseScale;
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Helpers de formato
  ═══════════════════════════════════════════════════════════════ }

function FmtFloat(V: Double): string;
var S: string; I: Integer;
begin
  Str(V:0:6, S);
  if Pos('.', S) > 0 then
  begin
    I := Length(S);
    while (I > 1) and (S[I] = '0') do Dec(I);
    if S[I] = '.' then Dec(I);
    S := Copy(S, 1, I);
  end;
  Result := S;
end;

{ ═══════════════════════════════════════════════════════════════
  Generación del JSON de salida
  ═══════════════════════════════════════════════════════════════ }

procedure WriteAnalysisJSON(const Doms: array of TVarDomain; NDoms: Integer;
                             Model: Pointer; Total: LongInt);
var
  I, J, Count: Integer;
  FirstVar, FirstVal: Boolean;
  C: TCSPConstraint;
  BinSizeInt, BinLo, BinHi: Integer;
  BinLoF, BinHiF: Double;
  Scale: Integer;
begin
  WriteLn('{');
  WriteLn('  "status": "ok",');
  WriteLn('  "total_solutions": ', Total, ',');
  WriteLn('  "analysis": [');

  FirstVar := True;

  for I := 0 to NDoms - 1 do
  begin
    if Doms[I].Determined then Continue;

    if not FirstVar then WriteLn(',');
    FirstVar := False;

    WriteLn('    {');
    WriteLn('      "name": "', Doms[I].Name, '",');
    WriteLn('      "type": "', Doms[I].VarType, '",');
    WriteLn('      "if_fixed": [');

    FirstVal := True;

    { ── boolean / integer: CT_EQ por valor ─────────────────── }
    if (Doms[I].VarType = 'boolean') or (Doms[I].VarType = 'integer') then
    begin
      for J := 0 to Doms[I].NIVals - 1 do
      begin
        if not FirstVal then WriteLn(',');
        FirstVal := False;
        FillChar(C, SizeOf(C), 0);
        C.CType    := CT_EQ;
        C.Constant := Doms[I].IVals[J];
        CSPCopyName(Doms[I].Name, C.Var1);
        Count := csp_count_with_constraint(Model, @C);
        Write('        { "value": ', Doms[I].IVals[J],
              ', "solutions": ', Count, ' }');
      end;
    end

    { ── set: CT_EQ por índice, reportar label ──────────────── }
    else if Doms[I].VarType = 'set' then
    begin
      for J := 0 to Doms[I].NSVals - 1 do
      begin
        if not FirstVal then WriteLn(',');
        FirstVal := False;
        FillChar(C, SizeOf(C), 0);
        C.CType    := CT_EQ;
        C.Constant := Doms[I].SIVals[J];
        CSPCopyName(Doms[I].Name, C.Var1);
        Count := csp_count_with_constraint(Model, @C);
        Write('        { "value": "', Doms[I].SLabels[J],
              '", "solutions": ', Count, ' }');
      end;
    end

    { ── numeric: NBINS_NUMERIC bins CT_IN_INTERVAL ─────────── }
    else if Doms[I].VarType = 'numeric' then
    begin
      Scale := Doms[I].NumScale;
      BinSizeInt := Round((Doms[I].NumHi - Doms[I].NumLo) * Scale / NBINS_NUMERIC);
      if BinSizeInt < 1 then BinSizeInt := 1;

      for J := 0 to NBINS_NUMERIC - 1 do
      begin
        BinLo := Round(Doms[I].NumLo * Scale) + J * BinSizeInt;
        BinHi := BinLo + BinSizeInt - 1;
        if J = NBINS_NUMERIC - 1 then
          BinHi := Round(Doms[I].NumHi * Scale);
        if BinLo > Round(Doms[I].NumHi * Scale) then Break;

        FillChar(C, SizeOf(C), 0);
        C.CType := CT_IN_INTERVAL;
        C.Lo    := BinLo;
        C.Hi    := BinHi;
        CSPCopyName(Doms[I].Name, C.Var1);
        Count := csp_count_with_constraint(Model, @C);

        BinLoF := BinLo / Scale;
        BinHiF := BinHi / Scale;

        if not FirstVal then WriteLn(',');
        FirstVal := False;
        Write('        { "lo": ', FmtFloat(BinLoF),
              ', "hi": ', FmtFloat(BinHiF),
              ', "solutions": ', Count, ' }');
      end;
    end;

    WriteLn;
    WriteLn('      ]');
    Write('    }');
  end;

  WriteLn;
  WriteLn('  ]');
  WriteLn('}');
end;

{ ═══════════════════════════════════════════════════════════════
  Main
  ═══════════════════════════════════════════════════════════════ }

var
  Datos : TCSPData;
  Model : Pointer;
  Doms  : array[0..MAX_CSP_VARS - 1] of TVarDomain;
  NDoms : Integer;
  Total : LongInt;
  I     : Integer;

begin
  if ParamCount < 1 then
  begin
    WriteLn(StdErr, 'Uso: GecodeInfo <Json_output_N.json>');
    Halt(2);
  end;

  { Cargar variables y restricciones (escala SCALE_NUM) }
  if not LeerCSPJson(ParamStr(1), Datos) then
  begin
    WriteLn(StdErr, 'Error leyendo JSON: ', ObtenerErrorCSPJson);
    Halt(2);
  end;

  { Leer dominios de análisis desde el JSON }
  ReadVarDomains(ParamStr(1), Datos, Doms, NDoms);

  { Rescalar variables numéricas a ~NBINS_NUMERIC puntos }
  RescaleNumericVars(Datos, Doms, NDoms);

  { Construir modelo Gecode con dominios ya ajustados }
  Model := csp_create(@Datos.Vars[0], Datos.NVars);
  if Model = nil then
  begin
    WriteLn(StdErr, 'Error: csp_create falló');
    Halt(2);
  end;

  for I := 0 to Datos.NCons - 1 do
    csp_add_constraint(Model, @Datos.Cons[I]);

  { Contar total de soluciones }
  Total := csp_count_solutions(Model);

  { Emitir JSON de análisis }
  WriteAnalysisJSON(Doms, NDoms, Model, Total);

  csp_free(Model);
end.
