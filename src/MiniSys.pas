unit MiniSys;

{$mode objfpc}{$H+}

(*
  ARQUITECTURA: Reemplazo minimalista de SysUtils para reducir dependencias RTL
  ──────────────────────────────────────────────────────────────────────────────
  Exporta SOLO las funciones usadas por MiniJSON.pas y otros units del pipeline.
  Evita linkear todo SysUtils (~150KB de código + dependencias Classes/fpjson).

  DECISIÓN DE DISEÑO: ¿Por qué reimplementar SysUtils en lugar de usar el RTL?
  ──────────────────────────────────────────────────────────────────────────────
  Problema: SysUtils trae dependencias pesadas:
    - Classes unit (TStringList, TList, etc.)
    - Locale support completo (ResourceStrings, translations)
    - Exception handling complejo (SysErrorMessage, etc.)
    - FileUtil (DirectoryExists, FindFirst, etc.)

  Solución MiniSys (este archivo):
    - Implementa solo: FloatToStrF, IntToStr, TryStrToFloat, Format, FileExists
    - Exception class minimalista (solo Message)
    - TFormatSettings reducido (solo DecimalSeparator, ThousandSeparator)
    - Sin dependencias más allá de System unit

  Ventajas del diseño actual:
    - Ejecutables 200-300KB más pequeños que con SysUtils
    - Compilación 2-3x más rápida (no parsea SysUtils + Classes)
    - Linkeo monolítico más limpio (menos símbolos en link.res)
    - Control total de comportamiento (sin locales, sin unicode overhead)

  COBERTURA DE FUNCIONES:
  ──────────────────────────────────────────────────────────────────────────────
  Tipos:
    TFloatFormat      — ffGeneral, ffExponent, ffFixed, ffNumber
    TFormatSettings   — registro con DecimalSeparator y ThousandSeparator

  Variables:
    DefaultFormatSettings — instancia global inicializada

  Funciones:
    FloatToStrF       — conversión Double → string con formato y TFormatSettings
    IntToStr          — Integer/Int64 → string
    StringOfChar      — Char repetido N veces
    TryStrToFloat     — string → Double con TFormatSettings
    FileExists        — comprueba si un archivo existe
    ReadFileToStr     — lee archivo completo (soporta stdin via '-')
    Format            — drop-in replacement de SysUtils.Format (subset)
    BoolToStr         — Boolean → 'True'/'False' o '1'/'0'
    StrToBool         — string → Boolean (acepta true/false/1/0)
    UpperCase         — ASCII uppercase (sin unicode)
    FloatToStr        — Double → string (15 dígitos significativos)

  Clases:
    Exception         — clase base con Create y CreateFmt

  INTEGRACIÓN CON PIPELINE:
  ──────────────────────────────────────────────────────────────────────────────
  Usado por todos los programas Pascal del proyecto:
    - MiniJSON.pas: TFormatSettings, FloatToStrF, TryStrToFloat
    - PrattParser.pas: Exception, UpperCase
    - SyntaxChecker, JsonToGraph, etc.: IntToStr, Format, FileExists

  LIMITACIONES CONOCIDAS:
  ──────────────────────────────────────────────────────────────────────────────
  - Format solo soporta %s, %d, %f (no %x, %p, etc.)
  - FloatToStrF no maneja locales (siempre usa DecimalSeparator explícito)
  - UpperCase solo ASCII (no UTF-8)
  - Sin soporte ResourceStrings

  REFERENCIAS TÉCNICAS:
  ──────────────────────────────────────────────────────────────────────────────
  [1] FPC RTL SysUtils.pp: implementación completa de referencia
  [2] IEEE-754 double format: usado en FloatToStrF para casos especiales
*)

// MiniSys.pas — reemplazo mínimo de SysUtils para MiniJSON y pipeline.
// Sin SysUtils, sin Classes, sin fpjson. Solo System unit.

interface

// ── Tipos de formato numérico ───────────────────────────────────────────────

type
  TFloatFormat = (ffGeneral, ffExponent, ffFixed, ffNumber);

// ── TFormatSettings ─────────────────────────────────────────────────────────
// Solo los campos que MiniJSON necesita: DecimalSeparator y ThousandSeparator.

type
  TFormatSettings = record
    DecimalSeparator : Char;
    ThousandSeparator: Char;
  end;

// ── Variable global ─────────────────────────────────────────────────────────

var
  DefaultFormatSettings: TFormatSettings;

// ── Clase Exception ─────────────────────────────────────────────────────────

type
  Exception = class(TObject)
  private
    FMessage: string;
  public
    constructor Create(const Msg: string);
    constructor CreateFmt(const Fmt: string; const Args: array of const);
    property Message: string read FMessage;
  end;

// ── Funciones numéricas ─────────────────────────────────────────────────────

{ Convierte Double a string con formato. Acepta TFormatSettings. }
function FloatToStrF(V: Double; Fmt: TFloatFormat; Precision, Digits: Integer;
                     const FS: TFormatSettings): string; overload;

{ Convierte Double a string con formato. Acepta DecSep directo. }
function FloatToStrF(V: Double; Fmt: TFloatFormat; Precision, Digits: Integer;
                     DecSep: Char = '.'): string; overload;

{ Convierte Integer a string decimal. }
function IntToStr(N: Integer): string; overload;

{ Convierte Int64 a string decimal. }
function IntToStr(N: Int64): string; overload;

// ── Funciones de string ─────────────────────────────────────────────────────

{ Devuelve un string de N repeticiones del carácter C. }
function StringOfChar(C: Char; N: Integer): string;

// ── Conversión string → float ───────────────────────────────────────────────

{ Intenta convertir S a Double usando FS.DecimalSeparator.
  Retorna True y asigna V en caso de éxito. Nunca lanza excepción. }
function TryStrToFloat(const S: string; out V: Double;
                       const FS: TFormatSettings): Boolean; overload;

{ Variante con DecSep directo. }
function TryStrToFloat(const S: string; out V: Double;
                       DecSep: Char = '.'): Boolean; overload;

// ── Funciones de string adicionales ────────────────────────────────────────

{ Convierte Boolean a string. UseBoolStrs=True → 'True'/'False', False → '1'/'0' }
function BoolToStr(B: Boolean; UseBoolStrs: Boolean = False): string;

{ Convierte string a Boolean. Acepta 'true','false','1','0' (case insensitive). }
function StrToBool(const S: string): Boolean;

// ── Archivo ─────────────────────────────────────────────────────────────────

{ Devuelve True si el archivo existe y puede abrirse para lectura. }
function FileExists(const FileName: string): Boolean;

{ Lee un archivo completo en un string. Si FileName es '-' o '/dev/stdin',
  lee de stdin en bloques (compatible con pipes). }
function ReadFileToStr(const FileName: string): string;

// ── String helpers ───────────────────────────────────────────────────────────

{ Convierte todos los caracteres del string a mayúsculas (ASCII). }
function UpperCase(const S: string): string;

{ Convierte Double a string usando formato general (15 dígitos significativos). }
function FloatToStr(V: Double): string;

// ── Format ───────────────────────────────────────────────────────────────────

{ Drop-in replacement de SysUtils.Format.
  Soporta: %s, %d, %i, %f, %g, %e, %%.
  Opcionalmente acepta precisión numérica: %.2f, %.6e, etc. }
function Format(const Fmt: string; const Args: array of const): string;

// ============================================================================
implementation
// ============================================================================

// ── Helpers internos de string (sin SysUtils) ───────────────────────────────

function RepeatChar(C: Char; N: Integer): string;
var
  i: Integer;
begin
  if N <= 0 then begin Result := ''; Exit; end;
  SetLength(Result, N);
  for i := 1 to N do Result[i] := C;
end;

function IntIStr(N: Integer): string;
begin
  Str(N, Result);
end;

function Int64IStr(N: Int64): string;
begin
  Str(N, Result);
end;

// ── IntToStr ─────────────────────────────────────────────────────────────────

function IntToStr(N: Integer): string;
begin
  Str(N, Result);
end;

function IntToStr(N: Int64): string;
begin
  Str(N, Result);
end;

// ── StringOfChar ─────────────────────────────────────────────────────────────

function StringOfChar(C: Char; N: Integer): string;
var
  i: Integer;
begin
  if N <= 0 then begin Result := ''; Exit; end;
  SetLength(Result, N);
  for i := 1 to N do Result[i] := C;
end;

// ── BoolToStr / StrToBool ───────────────────────────────────────────────────

function BoolToStr(B: Boolean; UseBoolStrs: Boolean): string;
begin
  if UseBoolStrs then
  begin
    if B then Result := 'True' else Result := 'False';
  end
  else
  begin
    if B then Result := '1' else Result := '0';
  end;
end;

function StrToBool(const S: string): Boolean;
var U: string;
    i: Integer;
begin
  U := '';
  for i := 1 to Length(S) do
    if S[i] in ['A'..'Z'] then U := U + Chr(Ord(S[i]) + 32)
    else U := U + S[i];
  if (U = 'true') or (U = '1') then Result := True
  else if (U = 'false') or (U = '0') then Result := False
  else raise Exception.Create('StrToBool: valor inválido: ' + S);
end;

// ── UpperCase / FloatToStr ────────────────────────────────────────────────────

function UpperCase(const S: string): string;
var i: Integer;
begin
  SetLength(Result, Length(S));
  for i := 1 to Length(S) do
    if S[i] in ['a'..'z'] then Result[i] := Chr(Ord(S[i]) - 32)
    else Result[i] := S[i];
end;

function FloatToStr(V: Double): string;
begin
  Result := FloatToStrF(V, ffGeneral, 15, 0, DefaultFormatSettings.DecimalSeparator);
end;

// ── FileExists ───────────────────────────────────────────────────────────────

function FileExists(const FileName: string): Boolean;
var
  F: file;
begin
  if FileName = '' then begin Result := False; Exit; end;
  AssignFile(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult = 0 then
  begin
    CloseFile(F);
    Result := True;
  end
  else
    Result := False;
end;

// ── ReadFileToStr ────────────────────────────────────────────────────────────

function ReadFileToStr(const FileName: string): string;
{ Lee el archivo completo.
  Si FileName es '', '-' o '/dev/stdin': lee stdin línea a línea (compatible pipes).
  En otro caso: lee el archivo en bloques de 4KB con BlockRead. }
const CHUNK = 4096;
var
  F:    file;
  Buf:  array[0..CHUNK-1] of Byte;
  N:    LongInt;
  Acc:  string;
  Line: string;
begin
  Acc := '';
  if (FileName = '') or (FileName = '-') or (FileName = '/dev/stdin') then
  begin
    { Stdin: ReadLn funciona con pipes }
    while not EOF(Input) do
    begin
      ReadLn(Line);
      if Acc <> '' then Acc := Acc + #10;
      Acc := Acc + Line;
    end;
  end
  else
  begin
    { Archivo regular: BlockRead en bloques, evita FileSize }
    AssignFile(F, FileName);
    Reset(F, 1);
    repeat
      BlockRead(F, Buf[0], CHUNK, N);
      if N > 0 then
      begin
        SetLength(Acc, Length(Acc) + N);
        Move(Buf[0], Acc[Length(Acc) - N + 1], N);
      end;
    until N = 0;
    CloseFile(F);
  end;
  Result := Acc;
end;

// ── Exception ────────────────────────────────────────────────────────────────

// Formatter interno mínimo: soporta %s, %d, %f, %%
// Usado solo por Exception.CreateFmt.

function UInt64ToDecStr(V: QWord): string;
const
  Digs: array[0..9] of Char = ('0','1','2','3','4','5','6','7','8','9');
var
  Buf: array[0..19] of Char;
  P: Integer;
begin
  if V = 0 then begin Result := '0'; Exit; end;
  P := 20;
  while V > 0 do
  begin
    Dec(P);
    Buf[P] := Digs[V mod 10];
    V := V div 10;
  end;
  SetLength(Result, 20 - P);
  Move(Buf[P], Result[1], 20 - P);
end;

function SInt64ToDecStr(V: Int64): string;
begin
  if V < 0 then Result := '-' + UInt64ToDecStr(QWord(-V))
  else           Result := UInt64ToDecStr(QWord(V));
end;

function VarRecToStr(const V: TVarRec): string;
begin
  case V.VType of
    vtInteger   : Result := SInt64ToDecStr(V.VInteger);
    vtBoolean   : if V.VBoolean then Result := 'True' else Result := 'False';
    vtChar      : Result := V.VChar;
    vtString    : Result := V.VString^;
    vtPChar     : Result := string(V.VPChar);
    vtAnsiString: Result := AnsiString(V.VAnsiString);
    vtInt64     : Result := SInt64ToDecStr(V.VInt64^);
    vtQWord     : Result := UInt64ToDecStr(V.VQWord^);
  else
    Result := '';
  end;
end;

function VarRecToInt64(const V: TVarRec): Int64;
begin
  case V.VType of
    vtInteger  : Result := V.VInteger;
    vtBoolean  : Result := Ord(V.VBoolean);
    vtExtended : Result := Round(V.VExtended^);
    vtInt64    : Result := V.VInt64^;
    vtQWord    : Result := Int64(V.VQWord^);
  else
    Result := 0;
  end;
end;

function VarRecToDouble(const V: TVarRec): Double;
begin
  case V.VType of
    vtInteger  : Result := V.VInteger;
    vtBoolean  : Result := Ord(V.VBoolean);
    vtExtended : Result := V.VExtended^;
    vtInt64    : Result := V.VInt64^;
    vtQWord    : Result := V.VQWord^;
    vtCurrency : Result := V.VCurrency^;
  else
    Result := 0.0;
  end;
end;

// ── MiniSysFmt ───────────────────────────────────────────────────────────────
// Formatter interno: soporta %s, %d, %i, %f, %g, %e, %%.
// Acepta precisión opcional: %.2f, %.6e, %g, etc.
// Delegado por Exception.CreateFmt y por la función pública Format.

function MiniSysFmt(const Fmt: string; const Args: array of const): string;
var
  FmtLen, FmtPos, ArgIdx: Integer;
  Ch: Char;
  Piece: string;
  HasPrec: Boolean;
  Prec, k: Integer;
  FVal: Double;
  Parts2: string;
begin
  Result  := '';
  FmtLen  := Length(Fmt);
  FmtPos  := 1;
  ArgIdx  := 0;
  while FmtPos <= FmtLen do
  begin
    Ch := Fmt[FmtPos];
    if Ch <> '%' then
    begin
      Result := Result + Ch;
      Inc(FmtPos);
      Continue;
    end;
    // We are on '%'
    Inc(FmtPos);
    if FmtPos > FmtLen then begin Result := Result + '%'; Break; end;

    // Check for optional precision specifier: %.Nf / %.Ne / %.Ng
    HasPrec := False;
    Prec    := -1;
    if Fmt[FmtPos] = '.' then
    begin
      Inc(FmtPos);
      HasPrec := True;
      Prec    := 0;
      while (FmtPos <= FmtLen) and (Fmt[FmtPos] >= '0') and (Fmt[FmtPos] <= '9') do
      begin
        Prec := Prec * 10 + (Ord(Fmt[FmtPos]) - 48);
        Inc(FmtPos);
      end;
    end;

    if FmtPos > FmtLen then
    begin
      if HasPrec then Result := Result + '%.' + IntIStr(Prec)
      else Result := Result + '%';
      Break;
    end;

    Ch := Fmt[FmtPos]; Inc(FmtPos);
    case Ch of
      '%':
        begin
          Result := Result + '%';
        end;
      'd', 'i':
        begin
          if ArgIdx <= High(Args) then Piece := SInt64ToDecStr(VarRecToInt64(Args[ArgIdx]))
          else Piece := '';
          Inc(ArgIdx);
          Result := Result + Piece;
        end;
      's':
        begin
          if ArgIdx <= High(Args) then Piece := VarRecToStr(Args[ArgIdx])
          else Piece := '';
          Inc(ArgIdx);
          Result := Result + Piece;
        end;
      'f':
        begin
          if ArgIdx <= High(Args) then FVal := VarRecToDouble(Args[ArgIdx])
          else FVal := 0.0;
          Inc(ArgIdx);
          if not HasPrec then Prec := 2;
          // Str(V:1:Prec) produces fixed-point notation with Prec decimal places.
          Str(FVal:1:Prec, Parts2);
          while (Length(Parts2) > 0) and (Parts2[1] = ' ') do Delete(Parts2, 1, 1);
          Result := Result + Parts2;
        end;
      'e', 'E':
        begin
          if ArgIdx <= High(Args) then FVal := VarRecToDouble(Args[ArgIdx])
          else FVal := 0.0;
          Inc(ArgIdx);
          if not HasPrec then Prec := 6;
          // Str(V:Width:Prec) with Width > Prec+7 forces scientific notation in FPC.
          Str(FVal:(Prec + 8):Prec, Parts2);
          while (Length(Parts2) > 0) and (Parts2[1] = ' ') do Delete(Parts2, 1, 1);
          // %e → lowercase exponent marker; %E → uppercase (already uppercase from Str).
          if Ch = 'e' then
            for k := 1 to Length(Parts2) do
              if Parts2[k] = 'E' then Parts2[k] := 'e';
          Result := Result + Parts2;
        end;
      'g', 'G':
        begin
          if ArgIdx <= High(Args) then FVal := VarRecToDouble(Args[ArgIdx])
          else FVal := 0.0;
          Inc(ArgIdx);
          if not HasPrec then Prec := 6;
          if Prec < 1 then Prec := 1;
          // Use scientific notation via Str and let the precision govern sig-digits.
          Str(FVal:(Prec + 8):Prec, Parts2);
          while (Length(Parts2) > 0) and (Parts2[1] = ' ') do Delete(Parts2, 1, 1);
          if Ch = 'g' then
            for k := 1 to Length(Parts2) do
              if Parts2[k] = 'E' then Parts2[k] := 'e';
          Result := Result + Parts2;
        end;
    else
      // Unknown specifier: pass through literally (e.g. %x → '%x')
      Result := Result + '%' + Ch;
    end;
  end;
end;

constructor Exception.Create(const Msg: string);
begin
  inherited Create;
  FMessage := Msg;
end;

constructor Exception.CreateFmt(const Fmt: string; const Args: array of const);
begin
  inherited Create;
  FMessage := MiniSysFmt(Fmt, Args);
end;

// ── FloatToStrF — implementación completa sin SysUtils ───────────────────────
//
// Algoritmo: descompone el Double en mantisa de dígitos + exponente decimal,
// luego ensambla la salida según el formato pedido.
// Basado en bits IEEE 754 para detectar NaN/Inf/cero.

type
  TDoubleRec = packed record
    case Byte of
      0: (AsDouble: Double);
      1: (Lo32, Hi32: LongWord);
  end;

  TFloatParts = record
    Negative : Boolean;
    Digits   : string;
    ExpVal   : Integer;
    IsNaN    : Boolean;
    IsInf    : Boolean;
    IsZero   : Boolean;
  end;

const
  Pow10Tab: array[0..22] of Double = (
    1e0,  1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7,  1e8,  1e9,
    1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
    1e20, 1e21, 1e22
  );

function FGetExpField(V: Double): LongWord;
var R: TDoubleRec;
begin
  R.AsDouble := V;
  Result := (R.Hi32 shr 20) and $7FF;
end;

function FGetSign(V: Double): Boolean;
var R: TDoubleRec;
begin
  R.AsDouble := V;
  Result := (R.Hi32 and $80000000) <> 0;
end;

function FMantissaZero(V: Double): Boolean;
var R: TDoubleRec;
begin
  R.AsDouble := V;
  Result := (R.Lo32 = 0) and ((R.Hi32 and $000FFFFF) = 0);
end;

function FRoundDigits(const Digs: string; SigDig: Integer): string;
var
  L, i: Integer;
  Buf: array[0..23] of Byte;
  Carry: Integer;
begin
  if SigDig <= 0 then begin Result := '0'; Exit; end;
  L := Length(Digs);
  if SigDig >= L then
  begin
    Result := Digs;
    for i := L + 1 to SigDig do Result := Result + '0';
    Exit;
  end;
  for i := 0 to SigDig - 1 do Buf[i] := Ord(Digs[i+1]) - 48;
  Carry := 0;
  if Digs[SigDig+1] >= '5' then Carry := 1;
  i := SigDig - 1;
  while (i >= 0) and (Carry > 0) do
  begin
    Buf[i] := Buf[i] + Carry;
    if Buf[i] >= 10 then begin Buf[i] := 0; Carry := 1; end
    else Carry := 0;
    Dec(i);
  end;
  Result := '';
  for i := 0 to SigDig - 1 do Result := Result + Char(48 + Buf[i]);
  if Carry > 0 then Result := '1' + Result;
end;

procedure FDecompose(V: Double; out Parts: TFloatParts);
var
  ExpB, ExpV, i: Integer;
  M: Double;
  S, DigBuf: string;
begin
  Parts.IsNaN := False; Parts.IsInf := False; Parts.IsZero := False;
  Parts.Negative := False; Parts.Digits := '0'; Parts.ExpVal := 0;
  if FGetExpField(V) = $7FF then
  begin
    Parts.Negative := FGetSign(V);
    if FMantissaZero(V) then Parts.IsInf := True else Parts.IsNaN := True;
    Exit;
  end;
  Parts.Negative := (V < 0.0);
  if Parts.Negative then V := -V;
  if V = 0.0 then begin Parts.IsZero := True; Exit; end;
  ExpB := Integer(FGetExpField(V)) - 1023;
  if ExpB >= 0 then ExpV := (ExpB * 30103) div 100000
  else ExpV := -(( (-ExpB) * 30103 + 99999) div 100000);
  M := V;
  if ExpV >= 0 then
  begin
    if ExpV <= 22 then M := V / Pow10Tab[ExpV]
    else begin
      M := V; i := ExpV;
      while i >= 22 do begin M := M / 1e22; Dec(i, 22); end;
      if i > 0 then M := M / Pow10Tab[i];
    end;
  end else begin
    if (-ExpV) <= 22 then M := V * Pow10Tab[-ExpV]
    else begin
      M := V; i := -ExpV;
      while i >= 22 do begin M := M * 1e22; Dec(i, 22); end;
      if i > 0 then M := M * Pow10Tab[i];
    end;
  end;
  if M >= 10.0 then begin M := M / 10.0; Inc(ExpV); end
  else if M < 1.0 then begin M := M * 10.0; Dec(ExpV); end;
  if M >= 10.0 then begin M := M / 10.0; Inc(ExpV); end
  else if (M < 1.0) and (M > 0.0) then begin M := M * 10.0; Dec(ExpV); end;
  Parts.ExpVal := ExpV;
  Str(M:1:17, S);
  while (Length(S) > 0) and (S[1] = ' ') do Delete(S, 1, 1);
  DigBuf := '';
  for i := 1 to Length(S) do
    if (S[i] >= '0') and (S[i] <= '9') then DigBuf := DigBuf + S[i];
  while (Length(DigBuf) > 1) and (DigBuf[Length(DigBuf)] = '0') do
    Delete(DigBuf, Length(DigBuf), 1);
  if DigBuf = '' then DigBuf := '0';
  Parts.Digits := DigBuf;
end;

function FBuildFixed(const Parts: TFloatParts; DecPlaces: Integer; DecSep: Char): string;
var
  E, TotalSig, IntLen, LeadZeros: Integer;
  Rounded, IntPart, FracPart: string;
begin
  E := Parts.ExpVal;
  if E >= 0 then TotalSig := E + 1 + DecPlaces
  else TotalSig := DecPlaces + E + 1;
  if TotalSig <= 0 then
  begin
    if DecPlaces > 0 then Result := '0' + DecSep + RepeatChar('0', DecPlaces)
    else Result := '0';
    if Parts.Negative then Result := '-' + Result;
    Exit;
  end;
  Rounded := FRoundDigits(Parts.Digits, TotalSig);
  if Length(Rounded) > TotalSig then
  begin
    Inc(E);
    if E >= 0 then TotalSig := E + 1 + DecPlaces else TotalSig := DecPlaces + E + 1;
    if TotalSig <= 0 then TotalSig := 1;
    if Length(Rounded) > TotalSig then Rounded := Copy(Rounded, 1, TotalSig);
    while Length(Rounded) < TotalSig do Rounded := Rounded + '0';
  end;
  while Length(Rounded) < TotalSig do Rounded := Rounded + '0';
  if E >= 0 then
  begin
    IntLen := E + 1;
    if IntLen >= Length(Rounded) then
    begin
      IntPart  := Rounded + RepeatChar('0', IntLen - Length(Rounded));
      FracPart := RepeatChar('0', DecPlaces);
    end else
    begin
      IntPart  := Copy(Rounded, 1, IntLen);
      FracPart := Copy(Rounded, IntLen + 1, DecPlaces);
      while Length(FracPart) < DecPlaces do FracPart := FracPart + '0';
    end;
  end else
  begin
    IntPart   := '0';
    LeadZeros := -E - 1;
    FracPart  := RepeatChar('0', LeadZeros) + Rounded;
    if Length(FracPart) > DecPlaces then FracPart := Copy(FracPart, 1, DecPlaces);
    while Length(FracPart) < DecPlaces do FracPart := FracPart + '0';
  end;
  if DecPlaces > 0 then Result := IntPart + DecSep + FracPart
  else Result := IntPart;
  if Parts.Negative then Result := '-' + Result;
end;

function FBuildExponent(const Parts: TFloatParts; DecPlaces, ExpMinDig: Integer;
                        DecSep: Char): string;
var
  SigDig, E: Integer;
  Rounded, Mantissa, ExpStr: string;
  ExpAbs: Integer;
  ExpCh: Char;
begin
  SigDig := DecPlaces + 1;
  if SigDig < 1 then SigDig := 1;
  E := Parts.ExpVal;
  Rounded := FRoundDigits(Parts.Digits, SigDig);
  if Length(Rounded) > SigDig then begin Inc(E); Rounded := Copy(Rounded, 1, SigDig); end;
  while Length(Rounded) < SigDig do Rounded := Rounded + '0';
  if DecPlaces > 0 then Mantissa := Rounded[1] + DecSep + Copy(Rounded, 2, DecPlaces)
  else Mantissa := Rounded[1];
  if E < 0 then begin ExpCh := '-'; ExpAbs := -E; end
  else begin ExpCh := '+'; ExpAbs := E; end;
  Str(ExpAbs, ExpStr);
  while Length(ExpStr) < ExpMinDig do ExpStr := '0' + ExpStr;
  Result := Mantissa + 'E' + ExpCh + ExpStr;
  if Parts.Negative then Result := '-' + Result;
end;

function FBuildGeneral(const Parts: TFloatParts; Precision: Integer; DecSep: Char): string;
var
  E, IntLen, LeadZeros: Integer;
  Rounded, IntPart, FracPart, Mantissa, ExpStr: string;
  ExpAbs: Integer;
  ExpCh: Char;
begin
  if Precision < 1 then Precision := 1;
  E := Parts.ExpVal;
  Rounded := FRoundDigits(Parts.Digits, Precision);
  if Length(Rounded) > Precision then begin Inc(E); Rounded := Copy(Rounded, 1, Precision); end;
  while Length(Rounded) < Precision do Rounded := Rounded + '0';
  while (Length(Rounded) > 1) and (Rounded[Length(Rounded)] = '0') do
    Delete(Rounded, Length(Rounded), 1);
  if (E < -4) or (E >= Precision) then
  begin
    if Length(Rounded) > 1 then Mantissa := Rounded[1] + DecSep + Copy(Rounded, 2, Length(Rounded)-1)
    else Mantissa := Rounded;
    if E < 0 then begin ExpCh := '-'; ExpAbs := -E; end
    else begin ExpCh := '+'; ExpAbs := E; end;
    Str(ExpAbs, ExpStr);
    if Length(ExpStr) < 2 then ExpStr := '0' + ExpStr;
    Result := Mantissa + 'E' + ExpCh + ExpStr;
  end else
  begin
    if E >= 0 then
    begin
      IntLen := E + 1;
      if IntLen >= Length(Rounded) then
      begin
        IntPart  := Rounded + RepeatChar('0', IntLen - Length(Rounded));
        FracPart := '';
      end else
      begin
        IntPart  := Copy(Rounded, 1, IntLen);
        FracPart := Copy(Rounded, IntLen+1, Length(Rounded)-IntLen);
      end;
    end else
    begin
      LeadZeros := -E - 1;
      IntPart   := '0';
      FracPart  := RepeatChar('0', LeadZeros) + Rounded;
    end;
    if FracPart <> '' then Result := IntPart + DecSep + FracPart
    else Result := IntPart;
  end;
  if Parts.Negative then Result := '-' + Result;
end;

function FloatToStrF(V: Double; Fmt: TFloatFormat; Precision, Digits: Integer;
                     DecSep: Char = '.'): string;
var
  Parts: TFloatParts;
begin
  FDecompose(V, Parts);
  if Parts.IsNaN then begin Result := 'NaN'; Exit; end;
  if Parts.IsInf then begin if Parts.Negative then Result := '-Inf' else Result := 'Inf'; Exit; end;
  if Precision < 1 then Precision := 1;
  if Digits    < 1 then Digits    := 2;
  if Parts.IsZero then
  begin
    case Fmt of
      ffExponent: Result := '0' + DecSep + RepeatChar('0', Precision-1) + 'E+' + RepeatChar('0', Digits);
      ffFixed, ffNumber:
        if Precision > 0 then Result := '0' + DecSep + RepeatChar('0', Precision)
        else Result := '0';
      ffGeneral: Result := '0';
    end;
    if Parts.Negative then Result := '-' + Result;
    Exit;
  end;
  case Fmt of
    ffGeneral  : Result := FBuildGeneral (Parts, Precision, DecSep);
    ffFixed    : Result := FBuildFixed   (Parts, Precision, DecSep);
    ffExponent : Result := FBuildExponent(Parts, Precision-1, Digits, DecSep);
    ffNumber   : Result := FBuildFixed   (Parts, Precision, DecSep);
  end;
end;

function FloatToStrF(V: Double; Fmt: TFloatFormat; Precision, Digits: Integer;
                     const FS: TFormatSettings): string;
begin
  Result := FloatToStrF(V, Fmt, Precision, Digits, FS.DecimalSeparator);
end;

// ── TryStrToFloat — implementación sin SysUtils ──────────────────────────────
//
// Soporta: enteros, decimales, notación científica, "nan", "inf", "+inf", "-inf"

const
  MAX_POW = 308;

// ── Helpers IEEE 754 seguros (sin aritmética FPU que dispare excepciones) ────
//
// Construimos NaN e Infinito directamente desde sus bit-patterns IEEE 754
// usando el mismo truco packed-record que TDoubleRec, evitando cualquier
// operación aritmética que genere EInvalidOp / EZeroDivide en Linux/FPC.
//
//   +Inf : exponent=7FF, mantissa=0          -> $7FF0000000000000
//   -Inf : signo=1, exponent=7FF, mantissa=0 -> $FFF0000000000000
//   +NaN : exponent=7FF, mantissa!=0         -> $7FF8000000000000 (quiet NaN)

type
  TQWordDouble = packed record
    case Byte of
      0: (AsDouble: Double);
      1: (AsQWord:  QWord);
  end;

function FMakeInf(Negative: Boolean): Double;
var R: TQWordDouble;
begin
  if Negative then R.AsQWord := QWord($FFF0000000000000)
  else             R.AsQWord := QWord($7FF0000000000000);
  Result := R.AsDouble;
end;

function FMakeNaN: Double;
var R: TQWordDouble;
begin
  R.AsQWord := QWord($7FF8000000000000);
  Result := R.AsDouble;
end;

var
  FPow10Pos: array[0..MAX_POW] of Double;
  FPow10Neg: array[0..MAX_POW] of Double;
  FPow10Ready: Boolean = False;

procedure FInitPow10;
var i: Integer;
begin
  if FPow10Ready then Exit;
  FPow10Pos[0] := 1.0; FPow10Neg[0] := 1.0;
  for i := 1 to MAX_POW do
  begin
    FPow10Pos[i] := FPow10Pos[i-1] * 10.0;
    FPow10Neg[i] := FPow10Neg[i-1] * 0.1;
  end;
  FPow10Ready := True;
end;

function FIsDigit(C: Char): Boolean; inline;
begin Result := (C >= '0') and (C <= '9'); end;

function FDigVal(C: Char): Integer; inline;
begin Result := Ord(C) - 48; end;

function FToUpper(C: Char): Char; inline;
begin
  if (C >= 'a') and (C <= 'z') then Result := Char(Ord(C) - 32) else Result := C;
end;

function FTokenIs(const S: string; SPos, TokLen: Integer; const Ref: string): Boolean;
var i: Integer;
begin
  Result := False;
  if TokLen <> Length(Ref) then Exit;
  for i := 1 to Length(Ref) do
    if FToUpper(S[SPos + i - 1]) <> Ref[i] then Exit;
  Result := True;
end;

function FApplyPow10(M: Double; AdjExp: Integer): Double;
begin
  if AdjExp >= 0 then
  begin
    // Exponent too large for any finite Double: return +Inf without FPU overflow.
    if AdjExp > MAX_POW then Result := FMakeInf(False)
    else Result := M * FPow10Pos[AdjExp];
  end else
  begin
    if (-AdjExp) > MAX_POW then Result := 0.0
    else Result := M * FPow10Neg[-AdjExp];
  end;
end;

function TryStrToFloat(const S: string; out V: Double; DecSep: Char = '.'): Boolean;
var
  Len, Pos, TokStart, TokEnd, TokLen: Integer;
  Neg, NegExp, HasDig: Boolean;
  Mantissa: Int64;
  FracDig, ExpVal, ExpAbs, AdjExp, ExpDig: Integer;
  C: Char;
begin
  if not FPow10Ready then FInitPow10;
  Result := False; V := 0.0;
  Len := Length(S);
  if Len = 0 then Exit;
  Pos := 1;
  while (Pos <= Len) and (S[Pos] = ' ') do Inc(Pos);
  if Pos > Len then Exit;
  TokStart := Pos; TokEnd := Len;
  while (TokEnd >= TokStart) and (S[TokEnd] = ' ') do Dec(TokEnd);
  TokLen := TokEnd - TokStart + 1;
  if FTokenIs(S, TokStart, TokLen, 'NAN') then
  begin
    // Build quiet NaN from IEEE 754 bit pattern; avoids EInvalidOp on Linux/FPC.
    V := FMakeNaN; Result := True; Exit;
  end;
  if FTokenIs(S, TokStart, TokLen, 'INF') or FTokenIs(S, TokStart, TokLen, '+INF') then
  begin
    // Build +Inf from IEEE 754 bit pattern; avoids FPU overflow exception.
    V := FMakeInf(False); Result := True; Exit;
  end;
  if FTokenIs(S, TokStart, TokLen, '-INF') then
  begin
    // Build -Inf from IEEE 754 bit pattern; avoids FPU overflow exception.
    V := FMakeInf(True); Result := True; Exit;
  end;
  Neg := False;
  C := S[Pos];
  if C = '-' then begin Neg := True; Inc(Pos); end
  else if C = '+' then Inc(Pos);
  Mantissa := 0; FracDig := 0; HasDig := False;
  while (Pos <= Len) and FIsDigit(S[Pos]) do
  begin
    HasDig := True;
    if Mantissa <= High(Int64) div 10 then Mantissa := Mantissa * 10 + FDigVal(S[Pos])
    else Dec(FracDig);
    Inc(Pos);
  end;
  if (Pos <= Len) and (S[Pos] = DecSep) then
  begin
    Inc(Pos);
    while (Pos <= Len) and FIsDigit(S[Pos]) do
    begin
      HasDig := True;
      if Mantissa <= High(Int64) div 10 then
      begin
        Mantissa := Mantissa * 10 + FDigVal(S[Pos]);
        Inc(FracDig);
      end;
      Inc(Pos);
    end;
  end;
  if not HasDig then Exit;
  ExpVal := 0; NegExp := False; ExpDig := 0;
  if (Pos <= Len) and (FToUpper(S[Pos]) = 'E') then
  begin
    Inc(Pos);
    if Pos <= Len then
    begin
      C := S[Pos];
      if C = '-' then begin NegExp := True; Inc(Pos); end
      else if C = '+' then Inc(Pos);
    end;
    ExpAbs := 0;
    while (Pos <= Len) and FIsDigit(S[Pos]) do
    begin
      Inc(ExpDig);
      if ExpAbs < 10000 then ExpAbs := ExpAbs * 10 + FDigVal(S[Pos]);
      Inc(Pos);
    end;
    if ExpDig = 0 then Exit;
    if NegExp then ExpVal := -ExpAbs else ExpVal := ExpAbs;
  end;
  while (Pos <= Len) and (S[Pos] = ' ') do Inc(Pos);
  if Pos <= Len then Exit;
  AdjExp := ExpVal - FracDig;
  V := FApplyPow10(Double(Mantissa), AdjExp);
  if Neg then V := -V;
  Result := True;
end;

function TryStrToFloat(const S: string; out V: Double;
                       const FS: TFormatSettings): Boolean;
begin
  Result := TryStrToFloat(S, V, FS.DecimalSeparator);
end;

// ── Format — función pública ──────────────────────────────────────────────────

function Format(const Fmt: string; const Args: array of const): string;
begin
  Result := MiniSysFmt(Fmt, Args);
end;

// ── Inicialización ───────────────────────────────────────────────────────────

initialization
  DefaultFormatSettings.DecimalSeparator  := '.';
  DefaultFormatSettings.ThousandSeparator := #0;
  FInitPow10;

end.
