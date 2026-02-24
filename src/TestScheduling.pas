{ ╔════════════════════════════════════════════════════════════════╗
  ║ TestScheduling.pas                                           ║
  ║ Planificación de proyecto con ventanas de tiempo            ║
  ║                                                              ║
  ║ 5 tareas, cada una con:                                      ║
  ║   · Ventana horaria [lo, hi] para el inicio                  ║
  ║   · Duración fija                                            ║
  ║   · Precedencias (B no puede empezar hasta que A termine)   ║
  ║                                                              ║
  ║ Restricciones:                                               ║
  ║   interval  → ventana de inicio de cada tarea               ║
  ║   linear_ge → precedencias  (fin_A <= inicio_B)             ║
  ╚════════════════════════════════════════════════════════════════╝ }

{$mode objfpc}{$H+}

program TestScheduling;

uses SysUtils, UGecodeBridge;

// ── Datos del problema ────────────────────────────────────────
//
//  Tareas de construcción de un edificio:
//
//   Nombre       Dur  Ventana inicio
//   Cimientos  C  3h  [0 ,  4]
//   Estructura E  4h  [0 ,  6]
//   Plomería   P  2h  [2 ,  8]
//   Electricid L  2h  [2 ,  8]
//   Pintura    T  3h  [4 , 10]
//
//  Precedencias (la siguiente no puede empezar hasta que la
//  anterior termine):
//    C → E   (E_start >= C_start + 3)
//    E → P   (P_start >= E_start + 4)
//    E → L   (L_start >= E_start + 4)
//    P → T   (T_start >= P_start + 2)
//    L → T   (T_start >= L_start + 2)

const
  DUR_C = 3;
  DUR_E = 4;
  DUR_P = 2;
  DUR_L = 2;
  DUR_T = 3;

// ── helper para agregar restricciones ────────────────────────

procedure Add(Model: Pointer; C: TCSPConstraint);
begin
  if csp_add_constraint(Model, @C) = 0 then
    WriteLn('  [!] Restricción no agregada');
end;

// ── Gantt ASCII ───────────────────────────────────────────────
//
//  Escala: cada caracter = 1 hora, horizonte 0..14

procedure PrintGantt(const Sol: TCSPSolution);
const
  HORIZON = 15;
var
  C, E, P, L, T : Integer;
  Row    : string;
  H, Start, Dur: Integer;

  procedure DrawBar(const Tag: string; St, D: Integer);
  var
    R: string;
    I: Integer;
  begin
    R := '';
    for I := 0 to HORIZON - 1 do
      if (I >= St) and (I < St + D) then R := R + '#'
      else R := R + '.';
    WriteLn(Format('  %-14s |%s|  inicio=%2d  fin=%2d',
                   [Tag, R, St, St+D]));
  end;

begin
  C := CSPSolVarValue(Sol, 'C');
  E := CSPSolVarValue(Sol, 'E');
  P := CSPSolVarValue(Sol, 'P');
  L := CSPSolVarValue(Sol, 'L');
  T := CSPSolVarValue(Sol, 'T');

  // Cabecera de horas
  Write('                 ');
  for H := 0 to HORIZON - 1 do
    if H mod 2 = 0 then Write(Format('%-2d', [H]))
    else Write(' ');
  WriteLn;
  WriteLn('  ─────────────────────────────────────────────────');
  DrawBar('Cimientos  (3h)', C, DUR_C);
  DrawBar('Estructura (4h)', E, DUR_E);
  DrawBar('Plomería   (2h)', P, DUR_P);
  DrawBar('Electricid.(2h)', L, DUR_L);
  DrawBar('Pintura    (3h)', T, DUR_T);
  WriteLn('  ─────────────────────────────────────────────────');
  WriteLn(Format('  Makespan: %d horas  (pintura termina en hora %d)',
                 [T + DUR_T, T + DUR_T]));
end;

// ─────────────────────────────────────────────────────────────

var
  VDefs : array[0..4] of TCSPVar;
  Model : Pointer;
  Sols  : array[0..99] of TCSPSolution;
  N, I  : Integer;

begin
  WriteLn('╔══════════════════════════════════════════════════╗');
  WriteLn('║  Scheduling con ventanas de intervalo           ║');
  WriteLn('║  Proyecto: 5 tareas, precedencias, time windows ║');
  WriteLn('╚══════════════════════════════════════════════════╝');
  WriteLn;
  WriteLn('  Tareas y ventanas de inicio:');
  WriteLn('    Cimientos   (dur=3h)  inicio ∈ [0,  4]');
  WriteLn('    Estructura  (dur=4h)  inicio ∈ [0,  6]');
  WriteLn('    Plomería    (dur=2h)  inicio ∈ [2,  8]');
  WriteLn('    Electricid. (dur=2h)  inicio ∈ [2,  8]');
  WriteLn('    Pintura     (dur=3h)  inicio ∈ [4, 10]');
  WriteLn;
  WriteLn('  Precedencias:');
  WriteLn('    Cimientos  → Estructura');
  WriteLn('    Estructura → Plomería');
  WriteLn('    Estructura → Electricidad');
  WriteLn('    Plomería   → Pintura');
  WriteLn('    Electricid.→ Pintura');

  // ── Variables (dominio amplio; los intervalos lo acotan) ──
  VDefs[0] := CSPMakeVar('C',  0, 10);
  VDefs[1] := CSPMakeVar('E',  0, 10);
  VDefs[2] := CSPMakeVar('P',  0, 10);
  VDefs[3] := CSPMakeVar('L',  0, 10);
  VDefs[4] := CSPMakeVar('T',  0, 13);

  Model := csp_create(@VDefs[0], 5);

  // ── Ventanas de inicio ────────────────────────────────────
  Add(Model, CSPInterval('C',  0,  4));
  Add(Model, CSPInterval('E',  0,  6));
  Add(Model, CSPInterval('P',  2,  8));
  Add(Model, CSPInterval('L',  2,  8));
  Add(Model, CSPInterval('T',  4, 10));

  // ── Precedencias: fin_ant <= inicio_sig ──────────────────
  //   E_start >= C_start + DUR_C  →  E - C >= 3
  Add(Model, CSPLinear(CT_LINEAR_GE, ['E','C'], [ 1,-1], DUR_C));
  //   P_start >= E_start + DUR_E  →  P - E >= 4
  Add(Model, CSPLinear(CT_LINEAR_GE, ['P','E'], [ 1,-1], DUR_E));
  //   L_start >= E_start + DUR_E  →  L - E >= 4
  Add(Model, CSPLinear(CT_LINEAR_GE, ['L','E'], [ 1,-1], DUR_E));
  //   T_start >= P_start + DUR_P  →  T - P >= 2
  Add(Model, CSPLinear(CT_LINEAR_GE, ['T','P'], [ 1,-1], DUR_P));
  //   T_start >= L_start + DUR_L  →  T - L >= 2
  Add(Model, CSPLinear(CT_LINEAR_GE, ['T','L'], [ 1,-1], DUR_L));

  // ── Resolver ─────────────────────────────────────────────
  N := csp_solve_all(Model, @Sols[0], 100);

  WriteLn;
  WriteLn(Format('  Planificaciones factibles encontradas: %d', [N]));

  if N > 0 then
  begin
    WriteLn;
    WriteLn('  ══ Primera solución (makespan mínimo) ══');
    WriteLn;
    PrintGantt(Sols[0]);

    if N > 1 then
    begin
      WriteLn;
      WriteLn('  ══ Todas las planificaciones ══');
      WriteLn;
      for I := 0 to N - 1 do
        WriteLn(Format('  %2d.  C=%d  E=%d  P=%d  L=%d  T=%d  makespan=%d',
          [I+1,
           CSPSolVarValue(Sols[I],'C'),
           CSPSolVarValue(Sols[I],'E'),
           CSPSolVarValue(Sols[I],'P'),
           CSPSolVarValue(Sols[I],'L'),
           CSPSolVarValue(Sols[I],'T'),
           CSPSolVarValue(Sols[I],'T') + DUR_T]));
    end;
  end;

  csp_free(Model);

  WriteLn;
  WriteLn('Fin.');
end.
