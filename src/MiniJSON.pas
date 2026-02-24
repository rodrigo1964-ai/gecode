unit MiniJSON;

{$mode objfpc}{$H+}

// Parser y serializador JSON mínimo.
// Sin fpjson, sin Classes. Solo MiniSys y System.
//
// Tipos soportados: null, boolean, number, string, array, object.
// Salida: JSON indentado con tabs.

interface

uses MiniSys;

type
  TJSONType = (jtNull, jtBoolean, jtNumber, jtString, jtArray, jtObject);

  // ── Clase base ─────────────────────────────────────────────────────────────
  TJSONValue = class
  private
    FType: TJSONType;
  public
    constructor Create(AType: TJSONType);
    property    JSONType: TJSONType read FType;
    function    AsString: string;   virtual;
    function    AsFloat:  Double;   virtual;
    function    AsBoolean: Boolean; virtual;
    function    ToJSON(Indent: Integer = 0): string; virtual; abstract;
    function    Clone: TJSONValue; virtual; abstract;
  end;

  // ── Null ───────────────────────────────────────────────────────────────────
  TJSONNull = class(TJSONValue)
  public
    constructor Create;
    function    ToJSON(Indent: Integer = 0): string; override;
    function    Clone: TJSONValue; override;
  end;

  // ── Boolean ────────────────────────────────────────────────────────────────
  TJSONBoolean = class(TJSONValue)
  private
    FValue: Boolean;
  public
    constructor Create(AValue: Boolean);
    function    ToJSON(Indent: Integer = 0): string; override;
    function    Clone: TJSONValue; override;
    function    AsBoolean: Boolean; override;
    function    AsFloat:   Double;  override;
    property    Value: Boolean read FValue;
  end;

  // ── Number ─────────────────────────────────────────────────────────────────
  TJSONNumber = class(TJSONValue)
  private
    FValue: Double;
  public
    constructor Create(AValue: Double);
    function    ToJSON(Indent: Integer = 0): string; override;
    function    Clone: TJSONValue; override;
    function    AsFloat:  Double;  override;
    function    AsString: string;  override;
    property    Value: Double read FValue;
  end;

  // ── String ─────────────────────────────────────────────────────────────────
  TJSONString = class(TJSONValue)
  private
    FValue: string;
  public
    constructor Create(const AValue: string);
    function    ToJSON(Indent: Integer = 0): string; override;
    function    Clone: TJSONValue; override;
    function    AsString: string; override;
    property    Value: string read FValue;
  end;

  // ── Array ──────────────────────────────────────────────────────────────────
  TJSONArray = class(TJSONValue)
  private
    FItems: array of TJSONValue;
    FCount: Integer;
    function  GetItem(i: Integer): TJSONValue;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   Add(Item: TJSONValue);
    procedure   AddStr(const V: string);
    procedure   AddNum(V: Double);
    procedure   AddBool(V: Boolean);
    function    ToJSON(Indent: Integer = 0): string; override;
    function    Clone: TJSONValue; override;
    property    Count: Integer read FCount;
    property    Items[i: Integer]: TJSONValue read GetItem; default;
  end;

  // ── Object ─────────────────────────────────────────────────────────────────
  TJSONPair = record
    Key:   string;
    Value: TJSONValue;
  end;

  TJSONObject = class(TJSONValue)
  private
    FPairs: array of TJSONPair;
    FCount: Integer;
    function  GetKey(i: Integer): string;
    function  GetVal(i: Integer): TJSONValue;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   Add(const Key: string; Value: TJSONValue);
    procedure   AddStr(const Key, V: string);
    procedure   AddNum(const Key: string; V: Double);
    procedure   AddBool(const Key: string; V: Boolean);
    procedure   AddNull(const Key: string);
    function    Find(const Key: string): TJSONValue;
    function    GetStr(const Key, Def: string): string;
    function    GetFloat(const Key: string; Def: Double = 0): Double;
    function    GetBool(const Key: string; Def: Boolean = False): Boolean;
    function    ToJSON(Indent: Integer = 0): string; override;
    function    Clone: TJSONValue; override;
    property    Count: Integer read FCount;
    property    Keys[i: Integer]: string     read GetKey;
    property    Values[i: Integer]: TJSONValue read GetVal;
  end;

// ── Parser ─────────────────────────────────────────────────────────────────
function ParseJSON(const S: string): TJSONValue;

// ── Helpers de construcción rápida ─────────────────────────────────────────
function JNull:                TJSONNull;
function JBool(V: Boolean):    TJSONBoolean;
function JNum(V: Double):      TJSONNumber;
function JStr(const V: string):TJSONString;
function JArr:                 TJSONArray;
function JObj:                 TJSONObject;

implementation

// ── Formateo numérico ──────────────────────────────────────────────────────

var
  JSONFS: TFormatSettings;

{ Inspecciona el campo exponente IEEE 754 sin FPU: $7FF = Inf o NaN. }
function NTSExpField(V: Double): LongWord;
type TDR = packed record case Byte of 0:(D:Double); 1:(Lo,Hi:LongWord); end;
var R: TDR;
begin R.D := V; Result := (R.Hi shr 20) and $7FF; end;

function NumToStr(V: Double): string;
begin
  { Frac/Trunc no son seguros para Inf/NaN — detectar antes con bit-pattern. }
  if NTSExpField(V) = $7FF then
    Result := FloatToStrF(V, ffGeneral, 10, 0, JSONFS)
  else if (Frac(V) = 0) and (Abs(V) < 1E15) then
    Result := IntToStr(Trunc(V))
  else
    Result := FloatToStrF(V, ffGeneral, 10, 0, JSONFS);
end;

// ── Escape de strings JSON ─────────────────────────────────────────────────

function EscapeStr(const S: string): string;
var
  i: Integer;
  C: Char;
begin
  Result := '"';
  for i := 1 to Length(S) do
  begin
    C := S[i];
    case C of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #13:  Result := Result + '\r';
      #12:  Result := Result + '\f';
    else
      Result := Result + C;
    end;
  end;
  Result := Result + '"';
end;

function Tabs(N: Integer): string;
begin
  Result := StringOfChar(#9, N);
end;

// ── TJSONValue ─────────────────────────────────────────────────────────────

constructor TJSONValue.Create(AType: TJSONType);
begin
  inherited Create;
  FType := AType;
end;

function TJSONValue.AsString: string;  begin Result := ''; end;
function TJSONValue.AsFloat:  Double;  begin Result := 0;  end;
function TJSONValue.AsBoolean: Boolean;begin Result := False; end;

// ── TJSONNull ──────────────────────────────────────────────────────────────

constructor TJSONNull.Create;
begin inherited Create(jtNull); end;

function TJSONNull.ToJSON(Indent: Integer): string;
begin Result := 'null'; end;

function TJSONNull.Clone: TJSONValue;
begin Result := TJSONNull.Create; end;

// ── TJSONBoolean ───────────────────────────────────────────────────────────

constructor TJSONBoolean.Create(AValue: Boolean);
begin
  inherited Create(jtBoolean);
  FValue := AValue;
end;

function TJSONBoolean.ToJSON(Indent: Integer): string;
begin
  if FValue then Result := 'true' else Result := 'false';
end;

function TJSONBoolean.Clone: TJSONValue;
begin Result := TJSONBoolean.Create(FValue); end;

function TJSONBoolean.AsBoolean: Boolean; begin Result := FValue; end;
function TJSONBoolean.AsFloat:   Double;
begin if FValue then Result := 1 else Result := 0; end;

// ── TJSONNumber ────────────────────────────────────────────────────────────

constructor TJSONNumber.Create(AValue: Double);
begin
  inherited Create(jtNumber);
  FValue := AValue;
end;

function TJSONNumber.ToJSON(Indent: Integer): string;
begin Result := NumToStr(FValue); end;

function TJSONNumber.Clone: TJSONValue;
begin Result := TJSONNumber.Create(FValue); end;

function TJSONNumber.AsFloat:  Double;  begin Result := FValue; end;
function TJSONNumber.AsString: string;  begin Result := NumToStr(FValue); end;

// ── TJSONString ────────────────────────────────────────────────────────────

constructor TJSONString.Create(const AValue: string);
begin
  inherited Create(jtString);
  FValue := AValue;
end;

function TJSONString.ToJSON(Indent: Integer): string;
begin Result := EscapeStr(FValue); end;

function TJSONString.Clone: TJSONValue;
begin Result := TJSONString.Create(FValue); end;

function TJSONString.AsString: string; begin Result := FValue; end;

// ── TJSONArray ─────────────────────────────────────────────────────────────

constructor TJSONArray.Create;
begin
  inherited Create(jtArray);
  FCount := 0;
end;

destructor TJSONArray.Destroy;
var i: Integer;
begin
  for i := 0 to FCount - 1 do FItems[i].Free;
  inherited;
end;

function TJSONArray.GetItem(i: Integer): TJSONValue;
begin Result := FItems[i]; end;

procedure TJSONArray.Add(Item: TJSONValue);
begin
  if FCount >= Length(FItems) then
    SetLength(FItems, FCount + 16);
  FItems[FCount] := Item;
  Inc(FCount);
end;

procedure TJSONArray.AddStr(const V: string);  begin Add(TJSONString.Create(V));  end;
procedure TJSONArray.AddNum(V: Double);         begin Add(TJSONNumber.Create(V));  end;
procedure TJSONArray.AddBool(V: Boolean);       begin Add(TJSONBoolean.Create(V)); end;

function TJSONArray.ToJSON(Indent: Integer): string;
var
  i:    Integer;
  Sep:  string;
begin
  if FCount = 0 then begin Result := '[]'; Exit; end;
  Result := '[';
  Sep := '';
  for i := 0 to FCount - 1 do
  begin
    Result := Result + Sep + #10 + Tabs(Indent + 1) + FItems[i].ToJSON(Indent + 1);
    Sep := ',';
  end;
  Result := Result + #10 + Tabs(Indent) + ']';
end;

function TJSONArray.Clone: TJSONValue;
var
  A: TJSONArray;
  i: Integer;
begin
  A := TJSONArray.Create;
  for i := 0 to FCount - 1 do A.Add(FItems[i].Clone);
  Result := A;
end;

// ── TJSONObject ────────────────────────────────────────────────────────────

constructor TJSONObject.Create;
begin
  inherited Create(jtObject);
  FCount := 0;
end;

destructor TJSONObject.Destroy;
var i: Integer;
begin
  for i := 0 to FCount - 1 do FPairs[i].Value.Free;
  inherited;
end;

function TJSONObject.GetKey(i: Integer): string;     begin Result := FPairs[i].Key;   end;
function TJSONObject.GetVal(i: Integer): TJSONValue; begin Result := FPairs[i].Value; end;

procedure TJSONObject.Add(const Key: string; Value: TJSONValue);
begin
  if FCount >= Length(FPairs) then
    SetLength(FPairs, FCount + 16);
  FPairs[FCount].Key   := Key;
  FPairs[FCount].Value := Value;
  Inc(FCount);
end;

procedure TJSONObject.AddStr(const Key, V: string);
begin Add(Key, TJSONString.Create(V)); end;

procedure TJSONObject.AddNum(const Key: string; V: Double);
begin Add(Key, TJSONNumber.Create(V)); end;

procedure TJSONObject.AddBool(const Key: string; V: Boolean);
begin Add(Key, TJSONBoolean.Create(V)); end;

procedure TJSONObject.AddNull(const Key: string);
begin Add(Key, TJSONNull.Create); end;

function TJSONObject.Find(const Key: string): TJSONValue;
var i: Integer;
begin
  for i := 0 to FCount - 1 do
    if FPairs[i].Key = Key then begin Result := FPairs[i].Value; Exit; end;
  Result := nil;
end;

function TJSONObject.GetStr(const Key, Def: string): string;
var V: TJSONValue;
begin
  V := Find(Key);
  if V <> nil then Result := V.AsString else Result := Def;
end;

function TJSONObject.GetFloat(const Key: string; Def: Double): Double;
var V: TJSONValue;
begin
  V := Find(Key);
  if V <> nil then Result := V.AsFloat else Result := Def;
end;

function TJSONObject.GetBool(const Key: string; Def: Boolean): Boolean;
var V: TJSONValue;
begin
  V := Find(Key);
  if V <> nil then Result := V.AsBoolean else Result := Def;
end;

function TJSONObject.ToJSON(Indent: Integer): string;
var
  i:   Integer;
  Sep: string;
begin
  if FCount = 0 then begin Result := '{}'; Exit; end;
  Result := '{';
  Sep := '';
  for i := 0 to FCount - 1 do
  begin
    Result := Result + Sep + #10 +
              Tabs(Indent + 1) + EscapeStr(FPairs[i].Key) + ': ' +
              FPairs[i].Value.ToJSON(Indent + 1);
    Sep := ',';
  end;
  Result := Result + #10 + Tabs(Indent) + '}';
end;

function TJSONObject.Clone: TJSONValue;
var
  O: TJSONObject;
  i: Integer;
begin
  O := TJSONObject.Create;
  for i := 0 to FCount - 1 do
    O.Add(FPairs[i].Key, FPairs[i].Value.Clone);
  Result := O;
end;

// ── Parser ─────────────────────────────────────────────────────────────────

type
  TParser = record
    S:   string;
    Pos: Integer;
    Len: Integer;
  end;

procedure SkipWS(var P: TParser);
begin
  while (P.Pos <= P.Len) and (P.S[P.Pos] in [' ', #9, #10, #13]) do
    Inc(P.Pos);
end;

function Peek(const P: TParser): Char;
begin
  if P.Pos <= P.Len then Result := P.S[P.Pos] else Result := #0;
end;

procedure Expect(var P: TParser; C: Char);
var Found: string;
begin
  if (P.Pos > P.Len) or (P.S[P.Pos] <> C) then
  begin
    if P.Pos <= P.Len then Found := P.S[P.Pos] else Found := '?';
    raise Exception.CreateFmt('JSON: esperado "%s" en pos %d, encontrado "%s"',
      [C, P.Pos, Found]);
  end;
  Inc(P.Pos);
end;

function ParseValue(var P: TParser): TJSONValue; forward;

function ParseString(var P: TParser): string;
var
  C: Char;
begin
  Expect(P, '"');
  Result := '';
  while P.Pos <= P.Len do
  begin
    C := P.S[P.Pos]; Inc(P.Pos);
    if C = '"' then Exit;
    if C = '\' then
    begin
      if P.Pos > P.Len then Break;
      C := P.S[P.Pos]; Inc(P.Pos);
      case C of
        '"':  Result := Result + '"';
        '\':  Result := Result + '\';
        '/':  Result := Result + '/';
        'b':  Result := Result + #8;
        't':  Result := Result + #9;
        'n':  Result := Result + #10;
        'r':  Result := Result + #13;
        'f':  Result := Result + #12;
      else    Result := Result + C;
      end;
    end
    else
      Result := Result + C;
  end;
  raise Exception.Create('JSON: string sin cerrar');
end;

function ParseNumber(var P: TParser): TJSONNumber;
var
  Start: Integer;
  S:     string;
  V:     Double;
begin
  Start := P.Pos;
  if (P.Pos <= P.Len) and (P.S[P.Pos] = '-') then Inc(P.Pos);
  while (P.Pos <= P.Len) and (P.S[P.Pos] in ['0'..'9']) do Inc(P.Pos);
  if (P.Pos <= P.Len) and (P.S[P.Pos] = '.') then
  begin
    Inc(P.Pos);
    while (P.Pos <= P.Len) and (P.S[P.Pos] in ['0'..'9']) do Inc(P.Pos);
  end;
  if (P.Pos <= P.Len) and (P.S[P.Pos] in ['e', 'E']) then
  begin
    Inc(P.Pos);
    if (P.Pos <= P.Len) and (P.S[P.Pos] in ['+', '-']) then Inc(P.Pos);
    while (P.Pos <= P.Len) and (P.S[P.Pos] in ['0'..'9']) do Inc(P.Pos);
  end;
  S := Copy(P.S, Start, P.Pos - Start);
  if not TryStrToFloat(S, V, JSONFS) then
    raise Exception.CreateFmt('JSON: número inválido "%s"', [S]);
  Result := TJSONNumber.Create(V);
end;

function ParseArray(var P: TParser): TJSONArray;
begin
  Expect(P, '[');
  Result := TJSONArray.Create;
  SkipWS(P);
  if Peek(P) = ']' then begin Inc(P.Pos); Exit; end;
  repeat
    SkipWS(P);
    Result.Add(ParseValue(P));
    SkipWS(P);
    if Peek(P) = ',' then Inc(P.Pos)
    else Break;
  until False;
  SkipWS(P);
  Expect(P, ']');
end;

function ParseObject(var P: TParser): TJSONObject;
var
  Key: string;
begin
  Expect(P, '{');
  Result := TJSONObject.Create;
  SkipWS(P);
  if Peek(P) = '}' then begin Inc(P.Pos); Exit; end;
  repeat
    SkipWS(P);
    Key := ParseString(P);
    SkipWS(P);
    Expect(P, ':');
    SkipWS(P);
    Result.Add(Key, ParseValue(P));
    SkipWS(P);
    if Peek(P) = ',' then Inc(P.Pos)
    else Break;
  until False;
  SkipWS(P);
  Expect(P, '}');
end;

function ParseValue(var P: TParser): TJSONValue;
begin
  SkipWS(P);
  case Peek(P) of
    '{': Result := ParseObject(P);
    '[': Result := ParseArray(P);
    '"': Result := TJSONString.Create(ParseString(P));
    't': begin
           if Copy(P.S, P.Pos, 4) <> 'true' then
             raise Exception.Create('JSON: literal inválido');
           Inc(P.Pos, 4);
           Result := TJSONBoolean.Create(True);
         end;
    'f': begin
           if Copy(P.S, P.Pos, 5) <> 'false' then
             raise Exception.Create('JSON: literal inválido');
           Inc(P.Pos, 5);
           Result := TJSONBoolean.Create(False);
         end;
    'n': begin
           if Copy(P.S, P.Pos, 4) <> 'null' then
             raise Exception.Create('JSON: literal inválido');
           Inc(P.Pos, 4);
           Result := TJSONNull.Create;
         end;
    '-', '0'..'9': Result := ParseNumber(P);
  else
    raise Exception.CreateFmt('JSON: token inesperado "%s" en pos %d',
      [Peek(P), P.Pos]);
  end;
end;

function ParseJSON(const S: string): TJSONValue;
var P: TParser;
begin
  P.S   := S;
  P.Pos := 1;
  P.Len := Length(S);
  Result := ParseValue(P);
end;

// ── Helpers ────────────────────────────────────────────────────────────────

function JNull:                TJSONNull;    begin Result := TJSONNull.Create;       end;
function JBool(V: Boolean):    TJSONBoolean; begin Result := TJSONBoolean.Create(V); end;
function JNum(V: Double):      TJSONNumber;  begin Result := TJSONNumber.Create(V);  end;
function JStr(const V: string):TJSONString;  begin Result := TJSONString.Create(V);  end;
function JArr:                 TJSONArray;   begin Result := TJSONArray.Create;       end;
function JObj:                 TJSONObject;  begin Result := TJSONObject.Create;      end;

initialization
  JSONFS := DefaultFormatSettings;
  JSONFS.DecimalSeparator  := '.';
  JSONFS.ThousandSeparator := #0;

end.
