{ ╔════════════════════════════════════════════════════════════════╗
  ║ TestGecodeBridge.pas                                         ║
  ║ Etapa 6 del pipeline CSP: Resolución completa con Gecode     ║
  ╚════════════════════════════════════════════════════════════════╝

  PROPÓSITO: Resolver CSP completo usando el bridge FFI a Gecode
  ──────────────────────────────────────────────────────────────────────────────
  Este programa lee el JSON procesado por las etapas previas del pipeline
  (SyntaxChecker → JsonToGraph → FunctionChecker → FwdConsistency →
   BwdConsistency) y lo traduce a llamadas del solver Gecode.

  DECISIÓN DE DISEÑO: ¿Por qué UCSPJson en lugar de parser directo?
  ──────────────────────────────────────────────────────────────────────────────
  Alternativas:
    1. Parsear JSON raw y construir model inline
    2. ESTE: unit UCSPJson traduce JSON → TCSPData (records FFI-compatible)

  Ventajas de UCSPJson:
    - Separa parsing de resolución (single responsibility)
    - TCSPData es reutilizable desde otros programas Pascal
    - Permite testing unitario del parser sin invocar Gecode
    - UCSPJson maneja conversión de tipos (boolean→IntVar[0,1], etc.)

  ARQUITECTURA DEL FLUJO:
  ──────────────────────────────────────────────────────────────────────────────
    JSON file → LeerCSPJson → TCSPData (Pascal records)
                            ↓
                    csp_create(@Vars, NVars) → CSPModel* (C++ Gecode)
                            ↓
                    loop: csp_add_constraint(@Cons[i])
                            ↓
                    csp_solve_all(Model, @Sols, MaxSols) → TCSPSolution[]
                            ↓
                    csp_free(Model)
                            ↓
                    Imprimir soluciones por stdout

  DISCIPLINA DE OWNERSHIP: Ver UGecodeBridge.pas
  ──────────────────────────────────────────────────────────────────────────────
  - TCSPData (Datos) es stack-allocated en RunJSON
  - CSPModel* (Model) es heap C++, DEBE liberarse con csp_free
  - Sols[] es array Pascal stack-allocated (hasta 1000 soluciones)

  INTEGRACIÓN CON PIPELINE:
  ──────────────────────────────────────────────────────────────────────────────
  Ver pipeline.sh línea ~60:
    ./bin/TestGecodeBridge graph.json | ./bin/VerifyWithBison graph.json

  Uso:
    TestGecodeBridge [archivo.json]   → corre un archivo
    TestGecodeBridge                  → corre todos los tests/*.json }

{$mode objfpc}{$H+}

program TestGecodeBridge;

uses
  SysUtils, UGecodeBridge, UCSPJson;

// ─────────────────────────────────────────────────────────────

procedure Separador;
begin
  WriteLn('  ──────────────────────────────────────');
end;

// Corre un archivo JSON y muestra todas las soluciones
procedure RunJSON(const Archivo: string);
var
  Datos : TCSPData;
  Model : Pointer;
  Sols  : array[0..999] of TCSPSolution;
  N, I, J : Integer;
  Desc  : string;
begin
  WriteLn;
  WriteLn('╔══════════════════════════════════════╗');
  WriteLn('║  ', Archivo);
  WriteLn('╚══════════════════════════════════════╝');

  if not LeerCSPJson(Archivo, Datos) then
  begin
    WriteLn('  ERROR al leer JSON: ', ObtenerErrorCSPJson);
    Exit;
  end;

  WriteLn(Format('  Variables   : %d', [Datos.NVars]));
  for I := 0 to Datos.NVars - 1 do
    WriteLn(Format('    %s  [%d, %d]',
      [PChar(@Datos.Vars[I].Name),
       Datos.Vars[I].MinDomain,
       Datos.Vars[I].MaxDomain]));

  WriteLn(Format('  Restricciones: %d', [Datos.NCons]));
  Separador;

  // Crear modelo
  Model := csp_create(@Datos.Vars[0], Datos.NVars);
  if Model = nil then
  begin
    WriteLn('  ERROR: csp_create falló');
    Exit;
  end;

  // Agregar restricciones
  for I := 0 to Datos.NCons - 1 do
    if csp_add_constraint(Model, @Datos.Cons[I]) = 0 then
      WriteLn(Format('  ADVERTENCIA: restriccion %d no se pudo agregar', [I]));

  // Resolver
  N := csp_solve_all(Model, @Sols[0], 1000);
  WriteLn(Format('  Soluciones encontradas: %d', [N]));
  Separador;

  for I := 0 to N - 1 do
  begin
    Write(Format('  %3d. ', [I+1]));
    CSPPrintSolution(Sols[I]);
  end;

  csp_free(Model);
end;

// Corre todos los JSON en el directorio tests/
procedure RunAll;
var
  SR  : TSearchRec;
  Dir : string;
begin
  Dir := ExtractFilePath(ParamStr(0));
  if Dir = '' then Dir := './';
  Dir := Dir + 'tests/';

  if FindFirst(Dir + '*.json', faAnyFile, SR) = 0 then
  begin
    repeat
      RunJSON(Dir + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end
  else
    WriteLn('No se encontraron archivos JSON en ', Dir);
end;

// ─────────────────────────────────────────────────────────────
begin
  WriteLn('╔══════════════════════════════════════════╗');
  WriteLn('║  Bridge Pascal/Gecode — Tests desde JSON ║');
  WriteLn('╚══════════════════════════════════════════╝');

  if ParamCount >= 1 then
    RunJSON(ParamStr(1))   // archivo específico por argumento
  else
    RunAll;                // todos los tests/

  WriteLn;
  WriteLn('Fin.');
end.
