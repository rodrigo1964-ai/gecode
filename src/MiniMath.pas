unit MiniMath;

{$mode objfpc}{$H+}

// Reemplazo de FPC Math sin libm.
// Las funciones estan implementadas en minimath_trig.c, minimath_exp.c, minimath_util.c.
// Compilar los .c y linkear los .o con -k"obj/minimath_*.o".

interface

// Trigonometricas
function Sin(X: Double): Double;                 cdecl; external name 'mm_sin';
function Cos(X: Double): Double;                 cdecl; external name 'mm_cos';
function Tan(X: Double): Double;                 cdecl; external name 'mm_tan';
function ArcSin(X: Double): Double;              cdecl; external name 'mm_arcsin';
function ArcCos(X: Double): Double;              cdecl; external name 'mm_arccos';
function ArcTan(X: Double): Double;              cdecl; external name 'mm_arctan';
function ArcTan2(Y, X: Double): Double;          cdecl; external name 'mm_arctan2';
function Hypot(A, B: Double): Double;            cdecl; external name 'mm_hypot';

// Exponenciales / logaritmicas
function Exp(X: Double): Double;                 cdecl; external name 'mm_exp';
function Ln(X: Double): Double;                  cdecl; external name 'mm_ln';
function Log2(X: Double): Double;                cdecl; external name 'mm_log2';
function Log10(X: Double): Double;               cdecl; external name 'mm_log10';
function LogN(Base, X: Double): Double;          cdecl; external name 'mm_logn';
function Power(Base, Exponent: Double): Double;  cdecl; external name 'mm_pow';
function Sqrt(X: Double): Double;                cdecl; external name 'mm_sqrt';

// Utilidades
function Floor(X: Double): Double;               cdecl; external name 'mm_floor';
function Ceil(X: Double): Double;                cdecl; external name 'mm_ceil';
function Sign(X: Double): Double;                cdecl; external name 'mm_sign';
function Max(A, B: Double): Double;              cdecl; external name 'mm_fmax';
function Min(A, B: Double): Double;              cdecl; external name 'mm_fmin';
function IfThen(Cond: Boolean; A, B: Double): Double; inline;


// ── Aritmética de intervalos ─────────────────────────────────────────────────

type
  TInterval = record
    Lo, Hi: Double;
  end;

function IvMake    (Lo, Hi: Double):            TInterval; cdecl; external name 'mi_make';
function IvScale   (Iv: TInterval; K: Double):  TInterval; cdecl; external name 'mi_scale';
function IvAdd     (A, B: TInterval):           TInterval; cdecl; external name 'mi_add';
function IvSub     (A, B: TInterval):           TInterval; cdecl; external name 'mi_sub';
function IvMul     (A, B: TInterval):           TInterval; cdecl; external name 'mi_mul';
function IvDiv     (A, B: TInterval):           TInterval; cdecl; external name 'mi_div';
function IvContains(Iv: TInterval; X: Double):  LongInt;   cdecl; external name 'mi_contains';
function IvIsEmpty (Iv: TInterval):             LongInt;   cdecl; external name 'mi_isempty';
function IvIsValid (Iv: TInterval):             LongInt;   cdecl; external name 'mi_isvalid';
function IvIntersect(A, B: TInterval):          TInterval; cdecl; external name 'mi_intersect';
function IvHull    (A, B: TInterval):           TInterval; cdecl; external name 'mi_hull';
function IvWidth   (Iv: TInterval):             Double;    cdecl; external name 'mi_width';
function IvMidpoint(Iv: TInterval):             Double;    cdecl; external name 'mi_midpoint';

implementation

function IfThen(Cond: Boolean; A, B: Double): Double; inline;
begin
  if Cond then Result := A else Result := B;
end;

end.
