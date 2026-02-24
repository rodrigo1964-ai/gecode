{ ╔════════════════════════════════════════════════════════════════╗
  ║ TestGecodeBridge.pas                                         ║
  ║ Prueba del bridge Pascal/Gecode leyendo restricciones        ║
  ║ desde archivos JSON.                                         ║
  ║                                                              ║
  ║ Uso: TestGecodeBridge [archivo.json]                         ║
  ║      TestGecodeBridge          (corre todos los tests/)      ║
  ╚════════════════════════════════════════════════════════════════╝ }

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
