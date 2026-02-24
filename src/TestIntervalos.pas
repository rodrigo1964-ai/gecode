{ ╔════════════════════════════════════════════════════════════════╗
  ║ TestIntervalos.pas                                           ║
  ║ Sistema lineal con RHS de intervalo, grilla 0.1             ║
  ║                                                              ║
  ║   5x +  3y ∈ [ 1,  3]                                       ║
  ║   6x + 10y ∈ [10, 50]                                       ║
  ║                                                              ║
  ║ Truco: escalamos x10 → trabajamos con enteros X,Y           ║
  ║   X = round(x·10),  Y = round(y·10)                         ║
  ║   5X + 3Y ∈ [10, 30]   (ambos lados ×10)                   ║
  ║   6X + 10Y ∈ [100, 500]                                     ║
  ║                                                              ║
  ║ La solución NO es un punto sino la región de la grilla que  ║
  ║ queda dentro de la intersección de las dos bandas lineales. ║
  ╚════════════════════════════════════════════════════════════════╝ }

{$mode objfpc}{$H+}

program TestIntervalos;

uses SysUtils, UGecodeBridge;

// ── Constantes de escala y display ────────────────────────────
const
  // Dominio de búsqueda (en unidades enteras = décimas)
  X_MIN = -50;   X_MAX = 10;   // x ∈ [-5.0, 1.0]
  Y_MIN =   0;   Y_MAX = 80;   // y ∈ [ 0.0, 8.0]

  MAX_SOLS = 800;

  // Display ASCII: 1 celda = 2 unidades de grilla (= 0.2 en real)
  D_W = 30;   // (X_MAX - X_MIN) div 2
  D_H = 40;   // (Y_MAX - Y_MIN) div 2

// ── Variables globales (Sols es ~2.7 MB, mejor no en stack) ──
var
  Sols : array[0..MAX_SOLS-1] of TCSPSolution;
  Map  : array[0..D_H, 0..D_W] of Boolean;

// ── Helper ────────────────────────────────────────────────────
procedure Add(Model: Pointer; C: TCSPConstraint);
begin
  if csp_add_constraint(Model, @C) = 0 then
    WriteLn('  [!] Restricción no agregada');
end;

// ─────────────────────────────────────────────────────────────

var
  VDefs : array[0..1] of TCSPVar;
  Model : Pointer;
  N, I, Col, Row, XI, YI : Integer;
  Line : string;
  YLbl, XLbl : Double;

begin
  WriteLn('╔══════════════════════════════════════════════════╗');
  WriteLn('║  Sistema lineal con RHS de intervalo            ║');
  WriteLn('║                                                  ║');
  WriteLn('║   5x +  3y  ∈ [ 1,  3]                         ║');
  WriteLn('║   6x + 10y  ∈ [10, 50]                         ║');
  WriteLn('║                                                  ║');
  WriteLn('║  Grilla: paso 0.1 en x e y                      ║');
  WriteLn('╚══════════════════════════════════════════════════╝');
  WriteLn;

  // ── Modelo CP ────────────────────────────────────────────
  VDefs[0] := CSPMakeVar('X', X_MIN, X_MAX);   // X = x·10
  VDefs[1] := CSPMakeVar('Y', Y_MIN, Y_MAX);   // Y = y·10

  Model := csp_create(@VDefs[0], 2);

  //  5x + 3y  ∈ [1,3]    →   5X + 3Y  ∈ [10, 30]
  Add(Model, CSPLinear(CT_LINEAR_GE, ['X','Y'], [5, 3],  10));
  Add(Model, CSPLinear(CT_LINEAR_LE, ['X','Y'], [5, 3],  30));

  //  6x + 10y ∈ [10,50]  →   6X + 10Y ∈ [100, 500]
  Add(Model, CSPLinear(CT_LINEAR_GE, ['X','Y'], [6,10], 100));
  Add(Model, CSPLinear(CT_LINEAR_LE, ['X','Y'], [6,10], 500));

  // ── Resolver ─────────────────────────────────────────────
  WriteLn('  Resolviendo...');
  N := csp_solve_all(Model, @Sols[0], MAX_SOLS);
  WriteLn(Format('  Puntos de la grilla (paso 0.1) en la región: %d', [N]));

  // ── Llenar mapa 2D ───────────────────────────────────────
  //  Cada celda del display cubre 2 unidades de grilla (0.2×0.2 real)
  FillChar(Map, SizeOf(Map), 0);
  for I := 0 to N - 1 do
  begin
    XI := CSPSolVarValue(Sols[I], 'X');    // ∈ [-50, 10]
    YI := CSPSolVarValue(Sols[I], 'Y');    // ∈ [  0, 80]
    Col := (XI - X_MIN) div 2;             // ∈ [0, 30]
    Row := (Y_MAX - YI)  div 2;            // ∈ [0, 40]  (Y invertido: arriba=alto)
    if (Col >= 0) and (Col <= D_W) and (Row >= 0) and (Row <= D_H) then
      Map[Row][Col] := True;
  end;

  // ── Plot ASCII ───────────────────────────────────────────
  WriteLn;
  WriteLn('  Región factible (* = celda 0.2×0.2 con al menos un punto)');
  WriteLn;

  for Row := 0 to D_H do
  begin
    // Etiqueta eje Y cada 5 filas (= 1.0 real)
    YLbl := (Y_MAX - Row * 2) / 10.0;
    if Row mod 5 = 0 then
      Write(Format('%5.1f |', [YLbl]))
    else
      Write('      |');

    // Celdas
    Line := '';
    for Col := 0 to D_W do
      if Map[Row][Col] then Line := Line + '*'
      else Line := Line + ' ';
    WriteLn(Line);
  end;

  // Eje X
  Write('      +');
  for Col := 0 to D_W do Write('-');
  WriteLn;

  // Etiquetas eje X cada 5 columnas (= 1.0 real)
  Write('      ');
  for Col := 0 to D_W do
  begin
    XLbl := (X_MIN + Col * 2) / 10.0;
    if Col mod 5 = 0 then
      Write(Format('%-5.1f', [XLbl]))   // '%-5.1f' ocupa 5 chars → cada etiqueta = 5 cols
    else
      { skip, cubierto por la etiqueta anterior }
  end;
  WriteLn;

  // ── Resumen ──────────────────────────────────────────────
  WriteLn;
  WriteLn('  Las dos bandas lineales forman un paralelogramo.');
  WriteLn('  Banda 1 (estrecha, pendiente -5/3):  5x+3y  ∈ [1,3]');
  WriteLn('  Banda 2 (ancha,   pendiente -3/5):  6x+10y ∈ [10,50]');
  WriteLn('  Intersección = paralelogramo ≈ 2.5 u²  →  ~250 pts en grilla 0.1');

  csp_free(Model);
  WriteLn;
  WriteLn('Fin.');
end.
