{ ╔════════════════════════════════════════════════════════════════╗
  ║ TestComplejo.pas                                             ║
  ║ Problemas clásicos de CSP resueltos con el bridge Gecode:   ║
  ║   1. SEND + MORE = MONEY  (criptoaritmética)                ║
  ║   2. Cuadrado Mágico 3×3  (suma=15 en filas/cols/diags)     ║
  ╚════════════════════════════════════════════════════════════════╝ }

{$mode objfpc}{$H+}

program TestComplejo;

uses SysUtils, UGecodeBridge;

// ── Helper: agregar restricción con chequeo ───────────────────

procedure Add(Model: Pointer; C: TCSPConstraint);
begin
  if csp_add_constraint(Model, @C) = 0 then
    WriteLn('  [!] Restricción no agregada');
end;

// ─────────────────────────────────────────────────────────────
// Problema 1: SEND + MORE = MONEY
//
// Letras S,E,N,D,M,O,R,Y → dígitos 0-9, todos distintos.
// S≥1, M≥1 (sin ceros iniciales).
//
// SEND + MORE = MONEY se reescribe como restricción lineal:
//
//   1000·S + 100·E + 10·N + D
// +  1000·M + 100·O + 10·R + E
// = 10000·M + 1000·O + 100·N + 10·E + Y
//
// Pasando todo a la izquierda:
//   1000S + 91E − 90N + D − 9000M − 900O + 10R − Y = 0
// ─────────────────────────────────────────────────────────────

procedure ResolverCripto;
var
  VDefs : array[0..7] of TCSPVar;
  Model : Pointer;
  Sol   : TCSPSolution;
  S,E,N,D,M,O,R,Y : Integer;
begin
  WriteLn;
  WriteLn('╔══════════════════════════════════════════════════╗');
  WriteLn('║  Problema 1 — SEND + MORE = MONEY               ║');
  WriteLn('╚══════════════════════════════════════════════════╝');

  VDefs[0] := CSPMakeVar('S', 1, 9);  // sin cero inicial
  VDefs[1] := CSPMakeVar('E', 0, 9);
  VDefs[2] := CSPMakeVar('N', 0, 9);
  VDefs[3] := CSPMakeVar('D', 0, 9);
  VDefs[4] := CSPMakeVar('M', 1, 9);  // sin cero inicial
  VDefs[5] := CSPMakeVar('O', 0, 9);
  VDefs[6] := CSPMakeVar('R', 0, 9);
  VDefs[7] := CSPMakeVar('Y', 0, 9);

  Model := csp_create(@VDefs[0], 8);

  // Todos los dígitos distintos
  Add(Model, CSPAllDiff(['S','E','N','D','M','O','R','Y']));

  // Ecuación: 1000S + 91E − 90N + D − 9000M − 900O + 10R − Y = 0
  Add(Model, CSPLinear(CT_LINEAR_EQ,
    ['S', 'E',  'N',  'D', 'M',    'O',   'R',  'Y'],
    [1000, 91, -90,   1, -9000, -900,   10,   -1],
    0));

  WriteLn('  Buscando solución...');
  if csp_solve_first(Model, @Sol) = 1 then
  begin
    S := CSPSolVarValue(Sol, 'S');
    E := CSPSolVarValue(Sol, 'E');
    N := CSPSolVarValue(Sol, 'N');
    D := CSPSolVarValue(Sol, 'D');
    M := CSPSolVarValue(Sol, 'M');
    O := CSPSolVarValue(Sol, 'O');
    R := CSPSolVarValue(Sol, 'R');
    Y := CSPSolVarValue(Sol, 'Y');

    WriteLn;
    WriteLn(Format('      %d%d%d%d   (SEND)',  [S,E,N,D]));
    WriteLn(Format('   + %d%d%d%d   (MORE)',   [M,O,R,E]));
    WriteLn('   ──────');
    WriteLn(Format('   %d%d%d%d%d   (MONEY)', [M,O,N,E,Y]));
    WriteLn;
    WriteLn(Format('   S=%d  E=%d  N=%d  D=%d  M=%d  O=%d  R=%d  Y=%d',
                   [S,E,N,D,M,O,R,Y]));
    WriteLn;
    WriteLn(Format('   Verificación: %d + %d = %d  →  %s',
      [1000*S+100*E+10*N+D,
       1000*M+100*O+10*R+E,
       10000*M+1000*O+100*N+10*E+Y,
       BoolToStr(1000*S+100*E+10*N+D + 1000*M+100*O+10*R+E =
                 10000*M+1000*O+100*N+10*E+Y, 'OK', 'FALLO')]));
  end
  else
    WriteLn('  Sin solución.');

  csp_free(Model);
end;

// ─────────────────────────────────────────────────────────────
// Problema 2: Cuadrado Mágico 3×3
//
//   a b c       Suma mágica = 15
//   d e f       Filas, columnas y ambas diagonales = 15
//   g h i       Dígitos 1..9, todos distintos.
// ─────────────────────────────────────────────────────────────

procedure ResolverCuadradoMagico;
const
  MAX_SOLS = 8;   // hay exactamente 8 (rotaciones/reflexiones)
var
  VDefs : array[0..8] of TCSPVar;
  Model : Pointer;
  Sols  : array[0..MAX_SOLS-1] of TCSPSolution;
  N, I  : Integer;
  Letras: array[0..8] of string = ('a','b','c','d','e','f','g','h','i');
  Val   : array[0..8] of Integer;
  J     : Integer;
begin
  WriteLn;
  WriteLn('╔══════════════════════════════════════════════════╗');
  WriteLn('║  Problema 2 — Cuadrado Mágico 3×3  (suma = 15) ║');
  WriteLn('╚══════════════════════════════════════════════════╝');

  for J := 0 to 8 do
    VDefs[J] := CSPMakeVar(Letras[J], 1, 9);

  Model := csp_create(@VDefs[0], 9);

  // Todos distintos: usa los 9 dígitos 1..9 exactamente una vez
  Add(Model, CSPAllDiff(['a','b','c','d','e','f','g','h','i']));

  // Tres filas
  Add(Model, CSPLinear(CT_LINEAR_EQ, ['a','b','c'], [1,1,1], 15));
  Add(Model, CSPLinear(CT_LINEAR_EQ, ['d','e','f'], [1,1,1], 15));
  Add(Model, CSPLinear(CT_LINEAR_EQ, ['g','h','i'], [1,1,1], 15));

  // Tres columnas
  Add(Model, CSPLinear(CT_LINEAR_EQ, ['a','d','g'], [1,1,1], 15));
  Add(Model, CSPLinear(CT_LINEAR_EQ, ['b','e','h'], [1,1,1], 15));
  Add(Model, CSPLinear(CT_LINEAR_EQ, ['c','f','i'], [1,1,1], 15));

  // Dos diagonales
  Add(Model, CSPLinear(CT_LINEAR_EQ, ['a','e','i'], [1,1,1], 15));
  Add(Model, CSPLinear(CT_LINEAR_EQ, ['c','e','g'], [1,1,1], 15));

  N := csp_solve_all(Model, @Sols[0], MAX_SOLS);
  WriteLn(Format('  Soluciones encontradas: %d', [N]));

  for I := 0 to N-1 do
  begin
    for J := 0 to 8 do
      Val[J] := CSPSolVarValue(Sols[I], Letras[J]);

    WriteLn;
    WriteLn(Format('  ── Sol. %d ──────────────────────', [I+1]));
    WriteLn(Format('   %d  %d  %d', [Val[0], Val[1], Val[2]]));
    WriteLn(Format('   %d  %d  %d', [Val[3], Val[4], Val[5]]));
    WriteLn(Format('   %d  %d  %d', [Val[6], Val[7], Val[8]]));
  end;

  csp_free(Model);
end;

// ─────────────────────────────────────────────────────────────

begin
  WriteLn('╔══════════════════════════════════════════════════╗');
  WriteLn('║  Tests Complejos — Bridge Pascal/Gecode         ║');
  WriteLn('╚══════════════════════════════════════════════════╝');

  ResolverCripto;
  ResolverCuadradoMagico;

  WriteLn;
  WriteLn('Fin.');
end.
