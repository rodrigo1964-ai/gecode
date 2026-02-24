program JsonSink;

{$mode objfpc}{$H+}

(*
 * JsonSink.pas
 *
 * Sumidero de JSON para pipeline Unix.
 * Lee JSON de stdin, lo persiste en SQLite y confirma por stdout.
 *
 * Uso:
 *   FwdConsistency graph.json | JsonSink runs.db [tag]
 *   BwdConsistency graph.json | JsonSink runs.db [tag]
 *   cat resultado.json        | JsonSink runs.db bwd
 *
 * Argumentos:
 *   runs.db   ruta a la base de datos (se crea si no existe)
 *   tag       etiqueta opcional (fwd, bwd, csp, …)   default=""
 *
 * Esquema:
 *   CREATE TABLE runs (
 *     id      INTEGER PRIMARY KEY AUTOINCREMENT,
 *     ts      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%f','now')),
 *     tag     TEXT NOT NULL DEFAULT '',
 *     status  TEXT NOT NULL DEFAULT '',
 *     payload TEXT NOT NULL
 *   );
 *
 * Salida stdout (encadenable):
 *   { "ok": true,  "id": 42, "tag": "fwd", "status": "arc_consistent" }
 *   { "ok": false, "error": "mensaje" }
 *)

uses
  MiniSys, MiniJSON;

// ── Binding mínimo de SQLite3 ─────────────────────────────────────────────────

const
  SQLITE_OK   = 0;
  SQLITE_DONE = 101;
  SQLITE_TRANSIENT: Pointer = Pointer(-1);  { SQLite copia el string }

function sqlite3_open(filename: PAnsiChar; out db: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_close(db: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_exec(db: Pointer; sql: PAnsiChar;
                      callback, arg: Pointer;
                      out errmsg: PAnsiChar): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_prepare_v2(db: Pointer; sql: PAnsiChar; nByte: LongInt;
                            out stmt: Pointer;
                            out tail: PAnsiChar): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_bind_text(stmt: Pointer; idx: LongInt;
                           text: PAnsiChar; nByte: LongInt;
                           destructor_: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_step(stmt: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_finalize(stmt: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_last_insert_rowid(db: Pointer): Int64;
  cdecl; external 'sqlite3';

function sqlite3_errmsg(db: Pointer): PAnsiChar;
  cdecl; external 'sqlite3';

function sqlite3_free(p: Pointer): LongInt;
  cdecl; external 'sqlite3';

// ── Helpers ───────────────────────────────────────────────────────────────────

procedure Die(const Msg: string);
var Out: TJSONObject;
begin
  Out := TJSONObject.Create;
  Out.AddBool('ok', False);
  Out.AddStr('error', Msg);
  WriteLn(Out.ToJSON(0));
  Out.Free;
  Halt(1);
end;

procedure DBCheck(rc: LongInt; db: Pointer; const Context: string);
begin
  if rc <> SQLITE_OK then
    Die(Context + ': ' + string(sqlite3_errmsg(db)));
end;

// ── Lectura de stdin ──────────────────────────────────────────────────────────

function ReadStdin: string;
var Line, Acc: string;
begin
  Acc := '';
  while not EOF(Input) do
  begin
    ReadLn(Line);
    if Acc <> '' then Acc := Acc + #10;
    Acc := Acc + Line;
  end;
  Result := Acc;
end;

// ── Extrae campo string del JSON raíz ─────────────────────────────────────────

function ExtractStr(const JSON, Key: string): string;
var JData: TJSONValue; JObj: TJSONObject;
begin
  Result := '';
  JData := ParseJSON(JSON);
  if JData = nil then Exit;
  try
    if JData is TJSONObject then
    begin
      JObj := TJSONObject(JData);
      Result := JObj.GetStr(Key, '');
    end;
  finally
    JData.Free;
  end;
end;

// ── JSON de confirmación ─────────────────────────────────────────────────────

function OkJSON(Id: Int64; const Tag, Status: string): string;
var Out: TJSONObject;
begin
  Out := TJSONObject.Create;
  Out.AddBool('ok',     True);
  Out.AddNum( 'id',     Id);
  Out.AddStr( 'tag',    Tag);
  Out.AddStr( 'status', Status);
  Result := Out.ToJSON(0);
  Out.Free;
end;

// ── Main ─────────────────────────────────────────────────────────────────────

const DDL =
  'CREATE TABLE IF NOT EXISTS runs (' +
  '  id      INTEGER PRIMARY KEY AUTOINCREMENT,' +
  '  ts      TEXT NOT NULL DEFAULT (strftime(''%Y-%m-%dT%H:%M:%f'',''now'')),' +
  '  tag     TEXT NOT NULL DEFAULT '''',' +
  '  status  TEXT NOT NULL DEFAULT '''',' +
  '  payload TEXT NOT NULL' +
  ');';

const INS =
  'INSERT INTO runs (tag, status, payload) VALUES (?, ?, ?);';

var
  DBPath, Tag, Payload, Status: string;
  DB:    Pointer;
  Stmt:  Pointer;
  Tail:  PAnsiChar;
  ErrMsg: PAnsiChar;
  InsId:  Int64;
  rc:     LongInt;

begin
  if ParamCount < 1 then
  begin
    WriteLn('Uso: JsonSink runs.db [tag]');
    WriteLn('     Lee JSON de stdin, persiste en SQLite, confirma a stdout.');
    Halt(0);
  end;

  DBPath := ParamStr(1);
  Tag    := '';
  if ParamCount >= 2 then Tag := ParamStr(2);

  { Leer payload del pipeline }
  Payload := ReadStdin;
  if Payload = '' then Die('stdin vacío');

  { Extraer status del JSON para indexarlo }
  Status := ExtractStr(Payload, 'status');

  { Abrir / crear base de datos }
  rc := sqlite3_open(PAnsiChar(AnsiString(DBPath)), DB);
  if rc <> SQLITE_OK then Die('No se pudo abrir: ' + DBPath);

  { Crear tabla si no existe }
  ErrMsg := nil;
  rc := sqlite3_exec(DB, PAnsiChar(AnsiString(DDL)), nil, nil, ErrMsg);
  if rc <> SQLITE_OK then
  begin
    Die('DDL: ' + string(ErrMsg));
    sqlite3_free(ErrMsg);
  end;

  { Preparar INSERT }
  rc := sqlite3_prepare_v2(DB, PAnsiChar(AnsiString(INS)), -1, Stmt, Tail);
  DBCheck(rc, DB, 'prepare');

  { Bind parámetros }
  rc := sqlite3_bind_text(Stmt, 1, PAnsiChar(AnsiString(Tag)),     -1, SQLITE_TRANSIENT);
  DBCheck(rc, DB, 'bind tag');
  rc := sqlite3_bind_text(Stmt, 2, PAnsiChar(AnsiString(Status)),  -1, SQLITE_TRANSIENT);
  DBCheck(rc, DB, 'bind status');
  rc := sqlite3_bind_text(Stmt, 3, PAnsiChar(AnsiString(Payload)), -1, SQLITE_TRANSIENT);
  DBCheck(rc, DB, 'bind payload');

  { Ejecutar }
  rc := sqlite3_step(Stmt);
  if rc <> SQLITE_DONE then
    Die('step: ' + string(sqlite3_errmsg(DB)));

  InsId := sqlite3_last_insert_rowid(DB);

  sqlite3_finalize(Stmt);
  sqlite3_close(DB);

  { Confirmar por stdout — encadenable }
  WriteLn(OkJSON(InsId, Tag, Status));
end.
