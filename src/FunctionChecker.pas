program FunctionChecker;

{$mode objfpc}{$H+}

(*
 * FunctionChecker.pas
 *
 * PROPÓSITO: Verificador de funciones user-defined en pipeline CSP
 * ──────────────────────────────────────────────────────────────────────────────
 * Etapa 3 del pipeline (después de JsonToGraph).
 * Valida que las funciones declaradas en el JSON tienen objetos compilados
 * (.o o .so) en el search path ANTES de que el motor intente cargarlas.
 *
 * DECISIÓN DE DISEÑO: ¿Por qué validación ahead-of-time?
 * ──────────────────────────────────────────────────────────────────────────────
 * Alternativas consideradas:
 *   1. Cargar en runtime con dlopen → error tardío durante solving
 *   2. Link estático completo → no permite user-defined functions
 *   3. ESTE: verificar archivos antes de ejecutar solver
 *
 * Ventajas del diseño actual:
 *   - Fail-fast: error antes de computación costosa
 *   - Pipeline validable por pasos: cada etapa reporta status JSON
 *   - Compatible con compilación incremental (make build nuevas .o)
 *   - Reporta TODOS los objetos faltantes (no solo el primero)
 *
 * DISCIPLINA DE OWNERSHIP: Path resolution
 * ──────────────────────────────────────────────────────────────────────────────
 * Search path (en orden de prioridad):
 *   1. --path dir1:dir2:...  (arg explícito)
 *   2. DEFAULT_PATH = ".:./lib:./obj:/usr/local/lib/csp"
 *
 * Orden de búsqueda por archivo:
 *   1. {nombre}.so  (biblioteca dinámica para dlopen)
 *   2. {nombre}.o   (objeto para link estático)
 *
 * Uso:
 *   ./FunctionChecker graph.json [--path dir1:dir2:...]
 *
 * Salida JSON:
 *   {
 *     "status": "ok" | "error",
 *     "checked": N,
 *     "found": N,
 *     "missing": N,
 *     "functions": [
 *       { "id": 0, "name": "...", "object": "nombre.o|.so",
 *         "full_path": "/ruta/..." | null, "found": true|false }
 *     ]
 *   }
 *
 * Exit code: 0 si todos encontrados, 1 si alguno falta, 2 si error fatal.
 *
 * INTEGRACIÓN CON PIPELINE:
 * ──────────────────────────────────────────────────────────────────────────────
 * Ver pipeline.sh para invocación automática:
 *   SyntaxChecker → JsonToGraph → FunctionChecker → FwdConsistency → ...
 *)

uses
  MiniSys, MiniJSON;

const
  DEFAULT_PATH = '.:./lib:./obj:/usr/local/lib/csp';
  MAX_DIRS     = 64;
  MAX_FUNCS    = 256;

type
  TFuncResult = record
    Id       : Integer;
    Name     : string;
    ObjFile  : string;   { nombre buscado, p.ej. "mifunc.so" o "mifunc.o" }
    FullPath : string;   { ruta completa si found, '' si no }
    Found    : Boolean;
  end;

var
  GraphFile   : string;
  SearchPath  : string;
  Dirs        : array[0..MAX_DIRS-1] of string;
  DirCount    : Integer;
  Results     : array[0..MAX_FUNCS-1] of TFuncResult;
  FuncCount   : Integer;
  TotalFound  : Integer;
  TotalMiss   : Integer;

{ ── helpers ───────────────────────────────────────────────────────────────── }

procedure SplitPath(const S: string);
var
  i, Start: Integer;
  Part: string;
begin
  DirCount := 0;
  Start    := 1;
  for i := 1 to Length(S) do
  begin
    if S[i] = ':' then
    begin
      Part := Copy(S, Start, i - Start);
      if (Part <> '') and (DirCount < MAX_DIRS) then
      begin
        Dirs[DirCount] := Part;
        Inc(DirCount);
      end;
      Start := i + 1;
    end;
  end;
  Part := Copy(S, Start, Length(S) - Start + 1);
  if (Part <> '') and (DirCount < MAX_DIRS) then
  begin
    Dirs[DirCount] := Part;
    Inc(DirCount);
  end;
end;

{ Busca primero .so, luego .o en todos los directorios del path.
  Devuelve ruta completa si encontrado, '' si no. }
function FindObject(const FuncName: string; out ObjFile: string): string;
var
  d, ext: Integer;
  Exts: array[0..1] of string;
  Candidate: string;
begin
  Exts[0] := '.so';
  Exts[1] := '.o';
  Result  := '';
  ObjFile := '';
  for ext := 0 to 1 do
  begin
    ObjFile := LowerCase(FuncName) + Exts[ext];
    for d := 0 to DirCount - 1 do
    begin
      Candidate := Dirs[d] + '/' + ObjFile;
      if FileExists(Candidate) then
      begin
        Result := Candidate;
        Exit;
      end;
    end;
  end;
  { no encontrado: reportamos el .o como objeto esperado }
  ObjFile := LowerCase(FuncName) + '.o';
end;

{ ── lector de JSON ────────────────────────────────────────────────────────── }

procedure LoadGraph(const FileName: string);
var
  Raw: string;
  Root, FuncArr, FuncObj: TJSONValue;
  i: Integer;
  FName: string;
  FullP, ObjF: string;
begin
  Raw  := ReadFileToStr(FileName);
  Root := ParseJSON(Raw);
  if Root = nil then
  begin
    WriteLn(StdErr, 'Error: no se pudo parsear "', FileName, '"');
    Halt(2);
  end;

  if not (Root is TJSONObject) then
  begin
    WriteLn(StdErr, 'Error: JSON raíz debe ser un objeto');
    Halt(2);
  end;

  FuncArr   := TJSONObject(Root).Find('functions');
  FuncCount := 0;

  if (FuncArr = nil) or not (FuncArr is TJSONArray) then
    Exit;   { sin funciones declaradas — ok }

  for i := 0 to TJSONArray(FuncArr).Count - 1 do
  begin
    if FuncCount >= MAX_FUNCS then Break;

    FuncObj := TJSONArray(FuncArr).Items[i];
    if not (FuncObj is TJSONObject) then Continue;

    FName := TJSONObject(FuncObj).GetStr('name', '');
    if FName = '' then Continue;

    Results[FuncCount].Id   := i;
    Results[FuncCount].Name := FName;

    FullP := FindObject(FName, ObjF);
    Results[FuncCount].ObjFile  := ObjF;
    Results[FuncCount].FullPath := FullP;
    Results[FuncCount].Found    := FullP <> '';

    if FullP <> '' then
      Inc(TotalFound)
    else
      Inc(TotalMiss);

    Inc(FuncCount);
  end;

  Root.Free;
end;

{ ── salida JSON ───────────────────────────────────────────────────────────── }

procedure PrintResult;
var
  i: Integer;
  Sep: string;
begin
  WriteLn('{');
  if TotalMiss = 0 then
    WriteLn('  "status": "ok",')
  else
    WriteLn('  "status": "error",');
  WriteLn('  "checked": ', FuncCount, ',');
  WriteLn('  "found": ',   TotalFound, ',');
  WriteLn('  "missing": ', TotalMiss, ',');
  WriteLn('  "functions": [');
  for i := 0 to FuncCount - 1 do
  begin
    if i < FuncCount - 1 then Sep := ',' else Sep := '';
    WriteLn('    {');
    WriteLn('      "id": ',     Results[i].Id,              ',');
    WriteLn('      "name": "',  Results[i].Name,            '",');
    WriteLn('      "object": "', Results[i].ObjFile,        '",');
    if Results[i].Found then
      WriteLn('      "full_path": "', Results[i].FullPath,  '",')
    else
      WriteLn('      "full_path": null,');
    if Results[i].Found then
      WriteLn('      "found": true')
    else
      WriteLn('      "found": false');
    WriteLn('    }', Sep);
  end;
  WriteLn('  ]');
  WriteLn('}');
end;

{ ── main ──────────────────────────────────────────────────────────────────── }

var
  a: Integer;
  Arg: string;

begin
  GraphFile  := '';
  SearchPath := DEFAULT_PATH;
  TotalFound := 0;
  TotalMiss  := 0;
  FuncCount  := 0;

  { parsear args }
  a := 1;
  while a <= ParamCount do
  begin
    Arg := ParamStr(a);
    if (Arg = '--path') and (a < ParamCount) then
    begin
      Inc(a);
      SearchPath := ParamStr(a);
    end
    else if GraphFile = '' then
      GraphFile := Arg;
    Inc(a);
  end;

  if GraphFile = '' then
  begin
    WriteLn(StdErr, 'Uso: FunctionChecker graph.json [--path dir1:dir2:...]');
    Halt(2);
  end;

  if not FileExists(GraphFile) then
  begin
    WriteLn(StdErr, 'Error: archivo no encontrado "', GraphFile, '"');
    Halt(2);
  end;

  SplitPath(SearchPath);
  LoadGraph(GraphFile);
  PrintResult;

  if TotalMiss > 0 then
    Halt(1)
  else
    Halt(0);
end.
