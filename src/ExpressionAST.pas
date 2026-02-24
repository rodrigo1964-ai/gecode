unit ExpressionAST;

{$mode objfpc}{$H+}

interface

uses
  MiniSys;

type
  TASTNode = class;

  // Lista mínima de nodos — reemplaza specialize TList<TASTNode>
  // sin arrastrar Generics.Collections ni Classes.
  TASTNodeList = class
  private
    FItems: array of TASTNode;
    FCount: Integer;
    function GetItem(Index: Integer): TASTNode;
  public
    procedure Add(ANode: TASTNode);
    property Count: Integer read FCount;
    property Items[Index: Integer]: TASTNode read GetItem; default;
  end;

  TASTNodeType = (
    ntNumber,
    ntVariable,
    ntBoolean,
    ntAdd,
    ntSubtract,
    ntMultiply,
    ntDivide,
    ntModulo,
    ntPower,
    ntNegate,
    ntAnd,
    ntOr,
    ntNot,
    ntEquals,
    ntNotEquals,
    ntLess,
    ntGreater,
    ntLessEq,
    ntGreaterEq,
    ntIn,
    ntInterval,
    ntDiscreteSet,
    ntFunctionCall
  );

  // Clase base abstracta
  TASTNode = class abstract
  private
    FNodeType: TASTNodeType;
  public
    constructor Create(ANodeType: TASTNodeType);
    function    ToString: string; override; abstract;
    procedure   PrintTree(Indent: Integer = 0); virtual;
    property NodeType: TASTNodeType read FNodeType;
  end;

  TNumberNode = class(TASTNode)
  private
    FValue: Double;
  public
    constructor Create(AValue: Double);
    function    ToString: string; override;
    property Value: Double read FValue;
  end;

  TVariableNode = class(TASTNode)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    function    ToString: string; override;
    property Name: string read FName;
  end;

  TBooleanNode = class(TASTNode)
  private
    FValue: Boolean;
  public
    constructor Create(AValue: Boolean);
    function    ToString: string; override;
    property Value: Boolean read FValue;
  end;

  TBinaryOpNode = class(TASTNode)
  private
    FLeft:  TASTNode;
    FRight: TASTNode;
  public
    constructor Create(ANodeType: TASTNodeType; ALeft, ARight: TASTNode);
    destructor  Destroy; override;
    function    ToString: string; override;
    procedure   PrintTree(Indent: Integer = 0); override;
    property Left:  TASTNode read FLeft;
    property Right: TASTNode read FRight;
  end;

  TUnaryOpNode = class(TASTNode)
  private
    FOperand: TASTNode;
  public
    constructor Create(ANodeType: TASTNodeType; AOperand: TASTNode);
    destructor  Destroy; override;
    function    ToString: string; override;
    procedure   PrintTree(Indent: Integer = 0); override;
    property Operand: TASTNode read FOperand;
  end;

  TIntervalNode = class(TASTNode)
  private
    FStart:     TASTNode;
    FEnd:       TASTNode;
    FStartOpen: Boolean;
    FEndOpen:   Boolean;
  public
    constructor Create(AStart, AEnd: TASTNode; AStartOpen, AEndOpen: Boolean);
    destructor  Destroy; override;
    function    ToString: string; override;
    procedure   PrintTree(Indent: Integer = 0); override;
    property Start:     TASTNode read FStart;
    property Stop:      TASTNode read FEnd;
    property StartOpen: Boolean  read FStartOpen;
    property EndOpen:   Boolean  read FEndOpen;
  end;

  TSetNode = class(TASTNode)
  private
    FElements: TASTNodeList;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   AddElement(AElement: TASTNode);
    function    ToString: string; override;
    procedure   PrintTree(Indent: Integer = 0); override;
    property Elements: TASTNodeList read FElements;
  end;

  TFunctionCallNode = class(TASTNode)
  private
    FName:      string;
    FArguments: TASTNodeList;
  public
    constructor Create(const AName: string);
    destructor  Destroy; override;
    procedure   AddArgument(AArg: TASTNode);
    function    ToString: string; override;
    procedure   PrintTree(Indent: Integer = 0); override;
    property Name:      string        read FName;
    property Arguments: TASTNodeList  read FArguments;
  end;

implementation

const
  NodeNames: array[TASTNodeType] of string = (
    'Number', 'Variable', 'Boolean',
    'Add', 'Subtract', 'Multiply', 'Divide', 'Modulo', 'Power', 'Negate',
    'And', 'Or', 'Not',
    'Equals', 'NotEquals', 'Less', 'Greater', 'LessEq', 'GreaterEq',
    'In', 'Interval', 'Set', 'FunctionCall'
  );

{ TASTNodeList }

function TASTNodeList.GetItem(Index: Integer): TASTNode;
begin
  Result := FItems[Index];
end;

procedure TASTNodeList.Add(ANode: TASTNode);
begin
  if FCount >= Length(FItems) then
    SetLength(FItems, FCount * 2 + 4);
  FItems[FCount] := ANode;
  Inc(FCount);
end;

{ TASTNode }

constructor TASTNode.Create(ANodeType: TASTNodeType);
begin
  FNodeType := ANodeType;
end;

procedure TASTNode.PrintTree(Indent: Integer);
begin
  WriteLn(StringOfChar(' ', Indent * 2) + ToString);
end;

{ TNumberNode }

constructor TNumberNode.Create(AValue: Double);
begin
  inherited Create(ntNumber);
  FValue := AValue;
end;

function TNumberNode.ToString: string;
begin
  Result := 'Number(' + FloatToStrF(FValue, ffGeneral, 15, 2) + ')';
end;

{ TVariableNode }

constructor TVariableNode.Create(const AName: string);
begin
  inherited Create(ntVariable);
  FName := AName;
end;

function TVariableNode.ToString: string;
begin
  Result := 'Variable(' + FName + ')';
end;

{ TBooleanNode }

constructor TBooleanNode.Create(AValue: Boolean);
begin
  inherited Create(ntBoolean);
  FValue := AValue;
end;

function TBooleanNode.ToString: string;
begin
  Result := 'Boolean(' + BoolToStr(FValue, True) + ')';
end;

{ TBinaryOpNode }

constructor TBinaryOpNode.Create(ANodeType: TASTNodeType;
  ALeft, ARight: TASTNode);
begin
  inherited Create(ANodeType);
  FLeft  := ALeft;
  FRight := ARight;
end;

destructor TBinaryOpNode.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
end;

function TBinaryOpNode.ToString: string;
begin
  Result := NodeNames[NodeType];
end;

procedure TBinaryOpNode.PrintTree(Indent: Integer);
begin
  WriteLn(StringOfChar(' ', Indent * 2) + ToString);
  if Assigned(FLeft)  then FLeft.PrintTree(Indent + 1);
  if Assigned(FRight) then FRight.PrintTree(Indent + 1);
end;

{ TUnaryOpNode }

constructor TUnaryOpNode.Create(ANodeType: TASTNodeType; AOperand: TASTNode);
begin
  inherited Create(ANodeType);
  FOperand := AOperand;
end;

destructor TUnaryOpNode.Destroy;
begin
  FOperand.Free;
  inherited;
end;

function TUnaryOpNode.ToString: string;
begin
  Result := NodeNames[NodeType];
end;

procedure TUnaryOpNode.PrintTree(Indent: Integer);
begin
  WriteLn(StringOfChar(' ', Indent * 2) + ToString);
  if Assigned(FOperand) then FOperand.PrintTree(Indent + 1);
end;

{ TIntervalNode }

constructor TIntervalNode.Create(AStart, AEnd: TASTNode;
  AStartOpen, AEndOpen: Boolean);
begin
  inherited Create(ntInterval);
  FStart     := AStart;
  FEnd       := AEnd;
  FStartOpen := AStartOpen;
  FEndOpen   := AEndOpen;
end;

destructor TIntervalNode.Destroy;
begin
  FStart.Free;
  FEnd.Free;
  inherited;
end;

function TIntervalNode.ToString: string;
var
  L, R: string;
begin
  if FStartOpen then L := '(' else L := '[';
  if FEndOpen   then R := ')' else R := ']';
  Result := 'Interval' + L + '...' + R;
end;

procedure TIntervalNode.PrintTree(Indent: Integer);
var
  Pad: string;
begin
  Pad := StringOfChar(' ', Indent * 2);
  WriteLn(Pad + ToString);
  WriteLn(Pad + '  Start:');
  if Assigned(FStart) then FStart.PrintTree(Indent + 2);
  WriteLn(Pad + '  End:');
  if Assigned(FEnd)   then FEnd.PrintTree(Indent + 2);
end;

{ TSetNode }

constructor TSetNode.Create;
begin
  inherited Create(ntDiscreteSet);
  FElements := TASTNodeList.Create;
end;

destructor TSetNode.Destroy;
var
  i: Integer;
begin
  for i := 0 to FElements.Count - 1 do FElements[i].Free;
  FElements.Free;
  inherited;
end;

procedure TSetNode.AddElement(AElement: TASTNode);
begin
  FElements.Add(AElement);
end;

function TSetNode.ToString: string;
begin
  Result := 'Set(' + IntToStr(FElements.Count) + ' elements)';
end;

procedure TSetNode.PrintTree(Indent: Integer);
var
  i:   Integer;
  Pad: string;
begin
  Pad := StringOfChar(' ', Indent * 2);
  WriteLn(Pad + ToString);
  for i := 0 to FElements.Count - 1 do
  begin
    WriteLn(Pad + '  Element[' + IntToStr(i) + ']:');
    FElements[i].PrintTree(Indent + 2);
  end;
end;

{ TFunctionCallNode }

constructor TFunctionCallNode.Create(const AName: string);
begin
  inherited Create(ntFunctionCall);
  FName      := AName;
  FArguments := TASTNodeList.Create;
end;

destructor TFunctionCallNode.Destroy;
var
  i: Integer;
begin
  for i := 0 to FArguments.Count - 1 do FArguments[i].Free;
  FArguments.Free;
  inherited;
end;

procedure TFunctionCallNode.AddArgument(AArg: TASTNode);
begin
  FArguments.Add(AArg);
end;

function TFunctionCallNode.ToString: string;
begin
  Result := 'FunctionCall(' + FName + ', ' + IntToStr(FArguments.Count) + ' args)';
end;

procedure TFunctionCallNode.PrintTree(Indent: Integer);
var
  i:   Integer;
  Pad: string;
begin
  Pad := StringOfChar(' ', Indent * 2);
  WriteLn(Pad + ToString);
  for i := 0 to FArguments.Count - 1 do
  begin
    WriteLn(Pad + '  Arg[' + IntToStr(i) + ']:');
    FArguments[i].PrintTree(Indent + 2);
  end;
end;

end.
