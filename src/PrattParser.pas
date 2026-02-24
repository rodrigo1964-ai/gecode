unit PrattParser;

{$mode objfpc}{$H+}

// Top-Down Operator Precedence (Vaughan Pratt, 1973).
// Reemplaza ASTParser.pas con una sola función Expr(rbp).
//
// Binding powers (precedencias):
//   OR           10
//   AND          20
//   NOT  prefix  25  (NUD, no tiene lbp)
//   IN           40
//   = != < > <=>=50
//   + -          60
//   * / %        70
//   ^ (power)    80  (right-assoc: rbp = 79 en LED)
//   unary -      90  (NUD, no tiene lbp)

interface

uses
  MiniSys, ExpressionAST;

type
  TTokenType = (
    ttNumber, ttVariable,
    ttPlus, ttMinus, ttTimes, ttDivide, ttMod, ttPower,
    ttLParen, ttRParen, ttLBracket, ttRBracket, ttLCurly, ttRCurly,
    ttAnd, ttOr, ttNot, ttIn, ttComma,
    ttEquals, ttNotEquals, ttLess, ttGreater, ttLessEq, ttGreaterEq,
    ttInfinity,
    ttEOF
  );

  TToken = record
    TokenType:  TTokenType;
    Value:      string;
    FloatValue: Double;
  end;

  TLexer = class
  private
    FText:        string;
    FPos:         Integer;
    FCurrentChar: Char;
    procedure Advance;
    procedure SkipWhitespace;
    function  GetNumber: TToken;
    function  GetIdentifier: string;
  public
    constructor Create(const AText: string);
    function GetNextToken: TToken;
  end;

  TPrattParser = class
  private
    FLexer:        TLexer;
    FCurrentToken: TToken;

    procedure Advance;

    // Binding power del token en posición infija
    function  LBP(const T: TToken): Integer;

    // Null denotation: token en posición de prefijo / átomo
    function  NUD(const T: TToken): TASTNode;

    // Left denotation: token en posición de infijo
    function  LED(const T: TToken; Left: TASTNode): TASTNode;

    // Función central del Pratt parser
    function  Expr(RBP: Integer = 0): TASTNode;

    // Parseo especial para conjuntos e intervalos (tras IN)
    function  ParseSetOrInterval: TASTNode;
  public
    constructor Create(const AExpression: string);
    destructor  Destroy; override;
    function    Parse: TASTNode;  // caller owns the returned node
  end;

implementation

type
  { Truco IEEE 754: construye +Inf sin aritmética FPU (evita EInvalidOp en Linux/FPC). }
  TPPQWordDouble = packed record
    case Byte of
      0: (AsDouble: Double);
      1: (AsQWord:  QWord);
  end;

var
  Infinity: Double;

// Convierte una cadena ASCII a mayúsculas sin SysUtils.
function LocalUpperCase(const S: string): string;
var
  i: Integer;
begin
  SetLength(Result, Length(S));
  for i := 1 to Length(S) do
    if (S[i] >= 'a') and (S[i] <= 'z') then
      Result[i] := Char(Ord(S[i]) - 32)
    else
      Result[i] := S[i];
end;

// Convierte S a Double usando PFS; lanza excepción si el formato es inválido.
function LocalStrToFloat(const S: string; const FS: TFormatSettings): Double;
begin
  if not TryStrToFloat(S, Result, FS) then
    raise Exception.CreateFmt('Número inválido: "%s"', [S]);
end;

var
  PFS: TFormatSettings;  // FormatSettings con punto decimal fijo

{ ── Lexer ──────────────────────────────────────────────────────────────── }

constructor TLexer.Create(const AText: string);
begin
  FText := AText;
  FPos  := 1;
  if Length(FText) > 0 then FCurrentChar := FText[1] else FCurrentChar := #0;
end;

procedure TLexer.Advance;
begin
  Inc(FPos);
  if FPos <= Length(FText) then FCurrentChar := FText[FPos] else FCurrentChar := #0;
end;

procedure TLexer.SkipWhitespace;
begin
  while (FCurrentChar <> #0) and (FCurrentChar <= #32) do Advance;
end;

function TLexer.GetNumber: TToken;
var
  S: string;
begin
  S := '';
  while (FCurrentChar <> #0) and (FCurrentChar in ['0'..'9']) do
  begin S := S + FCurrentChar; Advance; end;
  if FCurrentChar = '.' then
  begin
    S := S + '.'; Advance;
    while (FCurrentChar <> #0) and (FCurrentChar in ['0'..'9']) do
    begin S := S + FCurrentChar; Advance; end;
  end;
  if FCurrentChar in ['e','E'] then
  begin
    S := S + 'e'; Advance;
    if FCurrentChar in ['+','-'] then begin S := S + FCurrentChar; Advance; end;
    while (FCurrentChar <> #0) and (FCurrentChar in ['0'..'9']) do
    begin S := S + FCurrentChar; Advance; end;
  end;
  Result.TokenType  := ttNumber;
  Result.Value      := S;
  Result.FloatValue := LocalStrToFloat(S, PFS);
end;

function TLexer.GetIdentifier: string;
begin
  Result := '';
  while (FCurrentChar <> #0) and
        (FCurrentChar in ['a'..'z','A'..'Z','_','0'..'9']) do
  begin Result := Result + FCurrentChar; Advance; end;
end;

function TLexer.GetNextToken: TToken;
var
  ID: string;
begin
  Result.TokenType  := ttEOF;
  Result.Value      := '';
  Result.FloatValue := 0;

  while FCurrentChar <> #0 do
  begin
    if FCurrentChar <= #32 then begin SkipWhitespace; Continue; end;

    if FCurrentChar in ['0'..'9'] then begin Result := GetNumber; Exit; end;

    if FCurrentChar in ['a'..'z','A'..'Z','_'] then
    begin
      ID := LocalUpperCase(GetIdentifier);
      if      ID = 'AND'                       then Result.TokenType := ttAnd
      else if ID = 'OR'                        then Result.TokenType := ttOr
      else if ID = 'NOT'                       then Result.TokenType := ttNot
      else if ID = 'IN'                        then Result.TokenType := ttIn
      else if (ID = 'INF') or (ID = 'INFINITY') then
      begin Result.TokenType := ttInfinity; Result.FloatValue := Infinity; end
      else begin Result.TokenType := ttVariable; Result.Value := ID; end;
      Exit;
    end;

    if FCurrentChar = '<' then
    begin
      Advance;
      if      FCurrentChar = '=' then begin Result.TokenType := ttLessEq;    Advance; end
      else if FCurrentChar = '>' then begin Result.TokenType := ttNotEquals; Advance; end
      else                                   Result.TokenType := ttLess;
      Exit;
    end;
    if FCurrentChar = '>' then
    begin
      Advance;
      if FCurrentChar = '=' then begin Result.TokenType := ttGreaterEq; Advance; end
      else                              Result.TokenType := ttGreater;
      Exit;
    end;
    if FCurrentChar = '=' then
    begin
      Advance;
      if FCurrentChar = '=' then Advance;
      Result.TokenType := ttEquals; Exit;
    end;
    if FCurrentChar = '!' then
    begin
      Advance;
      if FCurrentChar = '=' then begin Result.TokenType := ttNotEquals; Advance; end
      else raise Exception.Create('Se esperaba "!="');
      Exit;
    end;
    if FCurrentChar = '*' then
    begin
      Advance;
      if FCurrentChar = '*' then begin Result.TokenType := ttPower; Advance; end
      else                              Result.TokenType := ttTimes;
      Exit;
    end;

    // Unicode UTF-8 3 bytes (E2 xx xx)
    if (FCurrentChar = #$E2) and (FPos + 2 <= Length(FText)) then
    begin
      if (FText[FPos+1]=#$88)and(FText[FPos+2]=#$88) then  // ∈
        begin Result.TokenType:=ttIn; Inc(FPos,3); if FPos<=Length(FText) then FCurrentChar:=FText[FPos] else FCurrentChar:=#0; Exit; end;
      if (FText[FPos+1]=#$89)and(FText[FPos+2]=#$A0) then  // ≠
        begin Result.TokenType:=ttNotEquals; Inc(FPos,3); if FPos<=Length(FText) then FCurrentChar:=FText[FPos] else FCurrentChar:=#0; Exit; end;
      if (FText[FPos+1]=#$89)and(FText[FPos+2]=#$A4) then  // ≤
        begin Result.TokenType:=ttLessEq; Inc(FPos,3); if FPos<=Length(FText) then FCurrentChar:=FText[FPos] else FCurrentChar:=#0; Exit; end;
      if (FText[FPos+1]=#$89)and(FText[FPos+2]=#$A5) then  // ≥
        begin Result.TokenType:=ttGreaterEq; Inc(FPos,3); if FPos<=Length(FText) then FCurrentChar:=FText[FPos] else FCurrentChar:=#0; Exit; end;
      if (FText[FPos+1]=#$88)and(FText[FPos+2]=#$9E) then  // ∞
        begin Result.TokenType:=ttInfinity; Result.FloatValue:=Infinity; Inc(FPos,3); if FPos<=Length(FText) then FCurrentChar:=FText[FPos] else FCurrentChar:=#0; Exit; end;
    end;

    case FCurrentChar of
      '+': begin Result.TokenType:=ttPlus;     Advance; Exit; end;
      '-': begin Result.TokenType:=ttMinus;    Advance; Exit; end;
      '/': begin Result.TokenType:=ttDivide;   Advance; Exit; end;
      '%': begin Result.TokenType:=ttMod;      Advance; Exit; end;
      '^': begin Result.TokenType:=ttPower;    Advance; Exit; end;
      '(': begin Result.TokenType:=ttLParen;   Advance; Exit; end;
      ')': begin Result.TokenType:=ttRParen;   Advance; Exit; end;
      '[': begin Result.TokenType:=ttLBracket; Advance; Exit; end;
      ']': begin Result.TokenType:=ttRBracket; Advance; Exit; end;
      '{': begin Result.TokenType:=ttLCurly;   Advance; Exit; end;
      '}': begin Result.TokenType:=ttRCurly;   Advance; Exit; end;
      ',': begin Result.TokenType:=ttComma;    Advance; Exit; end;
    end;

    raise Exception.CreateFmt('Carácter desconocido: 0x%02X', [Ord(FCurrentChar)]);
  end;
end;

{ ── TPrattParser ────────────────────────────────────────────────────────── }

constructor TPrattParser.Create(const AExpression: string);
begin
  FLexer        := TLexer.Create(AExpression);
  FCurrentToken := FLexer.GetNextToken;
end;

destructor TPrattParser.Destroy;
begin
  FLexer.Free;
  inherited;
end;

procedure TPrattParser.Advance;
begin
  FCurrentToken := FLexer.GetNextToken;
end;

function TPrattParser.LBP(const T: TToken): Integer;
begin
  case T.TokenType of
    ttOr:                                                      Result := 10;
    ttAnd:                                                     Result := 20;
    // ttNot no tiene lbp (solo aparece en posición de prefijo)
    ttIn:                                                      Result := 40;
    ttEquals, ttNotEquals,
    ttLess, ttGreater, ttLessEq, ttGreaterEq:                  Result := 50;
    ttPlus, ttMinus:                                           Result := 60;
    ttTimes, ttDivide, ttMod:                                  Result := 70;
    ttPower:                                                   Result := 80;
  else                                                         Result :=  0;
  end;
end;

function TPrattParser.NUD(const T: TToken): TASTNode;
var
  Inner: TASTNode;
  FN:   TFunctionCallNode;
begin
  case T.TokenType of
    ttNumber:
      Result := TNumberNode.Create(T.FloatValue);

    ttInfinity:
      Result := TNumberNode.Create(Infinity);

    ttVariable:
    begin
      // Si el identificador va seguido de '(' es una llamada a función
      if FCurrentToken.TokenType = ttLParen then
      begin
        Advance;  // consume (
        FN := TFunctionCallNode.Create(T.Value);
        if FCurrentToken.TokenType <> ttRParen then
        begin
          FN.AddArgument(Expr(0));
          while FCurrentToken.TokenType = ttComma do
          begin
            Advance;  // consume ,
            FN.AddArgument(Expr(0));
          end;
        end;
        if FCurrentToken.TokenType <> ttRParen then
          raise Exception.CreateFmt('Se esperaba ")" al cerrar %s(...)', [T.Value]);
        Advance;  // consume )
        Result := FN;
      end
      else
        Result := TVariableNode.Create(T.Value);
    end;

    ttMinus:
      // Menos unario: rbp alto para capturar solo el átomo inmediato
      Result := TUnaryOpNode.Create(ntNegate, Expr(90));

    ttNot:
      // NOT: rbp 25 → más fuerte que AND/OR, captura comparación completa
      Result := TUnaryOpNode.Create(ntNot, Expr(25));

    ttLParen:
    begin
      // Agrupación: (expr)
      Inner := Expr(0);
      if FCurrentToken.TokenType <> ttRParen then
        raise Exception.Create('Se esperaba ")" para cerrar agrupación');
      Advance;
      Result := Inner;
    end;

  else
    raise Exception.CreateFmt(
      'Token inesperado en posición de prefijo (tipo=%d)', [Ord(T.TokenType)]);
  end;
end;

function TPrattParser.LED(const T: TToken; Left: TASTNode): TASTNode;
begin
  case T.TokenType of
    // ── Aritmética ────────────────────────────────────────────────────────
    ttPlus:      Result := TBinaryOpNode.Create(ntAdd,      Left, Expr(60));
    ttMinus:     Result := TBinaryOpNode.Create(ntSubtract, Left, Expr(60));
    ttTimes:     Result := TBinaryOpNode.Create(ntMultiply, Left, Expr(70));
    ttDivide:    Result := TBinaryOpNode.Create(ntDivide,   Left, Expr(70));
    ttMod:       Result := TBinaryOpNode.Create(ntModulo,   Left, Expr(70));
    // Potencia right-associative: LED llama Expr(lbp-1)
    ttPower:     Result := TBinaryOpNode.Create(ntPower,    Left, Expr(79));

    // ── Comparaciones ─────────────────────────────────────────────────────
    ttEquals:    Result := TBinaryOpNode.Create(ntEquals,    Left, Expr(50));
    ttNotEquals: Result := TBinaryOpNode.Create(ntNotEquals, Left, Expr(50));
    ttLess:      Result := TBinaryOpNode.Create(ntLess,      Left, Expr(50));
    ttGreater:   Result := TBinaryOpNode.Create(ntGreater,   Left, Expr(50));
    ttLessEq:    Result := TBinaryOpNode.Create(ntLessEq,    Left, Expr(50));
    ttGreaterEq: Result := TBinaryOpNode.Create(ntGreaterEq, Left, Expr(50));

    // ── Lógica ────────────────────────────────────────────────────────────
    ttAnd:       Result := TBinaryOpNode.Create(ntAnd, Left, Expr(20));
    ttOr:        Result := TBinaryOpNode.Create(ntOr,  Left, Expr(10));

    // ── Pertenencia ───────────────────────────────────────────────────────
    ttIn:        Result := TBinaryOpNode.Create(ntIn, Left, ParseSetOrInterval);

  else
    raise Exception.CreateFmt(
      'Token inesperado en posición de infijo (tipo=%d)', [Ord(T.TokenType)]);
  end;
end;

// ─── Función central del Pratt parser ───────────────────────────────────────
//
// RBP = Right Binding Power del contexto actual.
// Avanza mientras el siguiente token tenga mayor LBP que RBP.
//
function TPrattParser.Expr(RBP: Integer): TASTNode;
var
  T: TToken;
begin
  T := FCurrentToken;
  Advance;
  Result := NUD(T);           // átomo o prefijo

  while LBP(FCurrentToken) > RBP do
  begin
    T      := FCurrentToken;
    Advance;
    Result := LED(T, Result); // infijo: extiende el árbol por la izquierda
  end;
end;

// ─── Parser especial para conjuntos e intervalos ─────────────────────────────
//
// Llamado desde LED cuando se ve IN.
// Detecta { } para conjuntos y [ ] ( ) para intervalos.
//
function TPrattParser.ParseSetOrInterval: TASTNode;
var
  SN:        TSetNode;
  StartOpen, EndOpen: Boolean;
  StartNode, EndNode: TASTNode;

  // Lee un límite de intervalo: puede ser -inf, +inf o una expresión
  function ReadBound: TASTNode;
  begin
    // Expr(0) con `,` y `]` `)` como terminadores naturales (LBP=0)
    Result := Expr(0);
  end;

begin
  // ── Conjunto discreto {v1, v2, ...} ──────────────────────────────────────
  if FCurrentToken.TokenType = ttLCurly then
  begin
    Advance;  // consume {
    SN := TSetNode.Create;
    if FCurrentToken.TokenType <> ttRCurly then
    begin
      SN.AddElement(Expr(0));
      while FCurrentToken.TokenType = ttComma do
      begin
        Advance;  // consume ,
        SN.AddElement(Expr(0));
      end;
    end;
    if FCurrentToken.TokenType <> ttRCurly then
      raise Exception.Create('Se esperaba "}" para cerrar conjunto');
    Advance;  // consume }
    Result := SN;
    Exit;
  end;

  // ── Intervalo [a,b] (a,b) [a,b) (a,b] ───────────────────────────────────
  if FCurrentToken.TokenType in [ttLBracket, ttLParen] then
  begin
    StartOpen := (FCurrentToken.TokenType = ttLParen);
    Advance;  // consume [ o (

    StartNode := ReadBound;

    if FCurrentToken.TokenType <> ttComma then
      raise Exception.Create('Se esperaba "," dentro del intervalo');
    Advance;  // consume ,

    EndNode := ReadBound;

    EndOpen := (FCurrentToken.TokenType = ttRParen);
    if FCurrentToken.TokenType in [ttRBracket, ttRParen] then
      Advance   // consume ] o )
    else
      raise Exception.Create('Se esperaba "]" o ")" para cerrar intervalo');

    Result := TIntervalNode.Create(StartNode, EndNode, StartOpen, EndOpen);
    Exit;
  end;

  // ── Variable de conjunto: ESTADO IN MICONJUNTO ───────────────────────────
  if FCurrentToken.TokenType = ttVariable then
  begin
    Result := TVariableNode.Create(FCurrentToken.Value);
    Advance;
    Exit;
  end;

  raise Exception.Create('Se esperaba "{...}", "[...]", "(...)" o variable de conjunto');
end;

function TPrattParser.Parse: TASTNode;
begin
  Result := Expr(0);
  if FCurrentToken.TokenType <> ttEOF then
    raise Exception.Create('Se esperaba fin de expresión');
end;

function PPMakePosInf: Double;
var R: TPPQWordDouble;
begin
  R.AsQWord := QWord($7FF0000000000000);
  Result := R.AsDouble;
end;

initialization
  { Build +Inf from IEEE 754 bit pattern — no FPU division, avoids EInvalidOp. }
  Infinity             := PPMakePosInf;
  PFS                  := DefaultFormatSettings;
  PFS.DecimalSeparator := '.';

end.
