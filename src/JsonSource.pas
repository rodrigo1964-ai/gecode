program JsonSource;

{$mode objfpc}{$H+}

(*
 * JsonSource.pas
 *
 * Fuente de pipeline: lee JSON almacenado en SQLite y lo emite por stdout.
 * Complemento de JsonSink — juntos convierten SQLite en memoria persistente
 * del pipeline.
 *
 * Uso:
 *   JsonSource runs.db [tag] [id]
 *
 *   Sin argumentos extras : último registro insertado
 *   Con tag               : último registro con ese tag
 *   Con tag e id          : registro específico por id
 *
 * Ejemplos de pipeline:
 *   # Guardar grafo
 *   ./JsonToGraph sistema.json | ./JsonSink pipeline.db graph
 *
 *   # Leer grafo y procesar
 *   ./JsonSource pipeline.db graph | ./FwdConsistency | ./JsonSink pipeline.db fwd
 *   ./JsonSource pipeline.db graph | ./BwdConsistency | ./JsonSink pipeline.db bwd
 *
 *   # Continuar cadena
 *   ./JsonSource pipeline.db fwd | ./siguiente_etapa
 *
 * Salida stdout:
 *   El payload JSON original (para seguir encadenando)
 *
 * Salida en error (stderr):
 *   Mensaje si no hay resultados o error de DB
 *)

uses
  MiniSys;

// ── Binding mínimo de SQLite3 ─────────────────────────────────────────────────

const
  SQLITE_OK   = 0;
  SQLITE_ROW  = 100;
  SQLITE_DONE = 101;

function sqlite3_open(filename: PAnsiChar; out db: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_close(db: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_prepare_v2(db: Pointer; sql: PAnsiChar; nByte: LongInt;
                            out stmt: Pointer;
                            out tail: PAnsiChar): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_bind_text(stmt: Pointer; idx: LongInt;
                           text: PAnsiChar; nByte: LongInt;
                           destructor_: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_bind_int64(stmt: Pointer; idx: LongInt;
                            value: Int64): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_step(stmt: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_finalize(stmt: Pointer): LongInt;
  cdecl; external 'sqlite3';

function sqlite3_column_text(stmt: Pointer; col: LongInt): PAnsiChar;
  cdecl; external 'sqlite3';

function sqlite3_column_int64(stmt: Pointer; col: LongInt): Int64;
  cdecl; external 'sqlite3';

function sqlite3_errmsg(db: Pointer): PAnsiChar;
  cdecl; external 'sqlite3';

// ── Helpers ───────────────────────────────────────────────────────────────────

const SQLITE_TRANSIENT: Pointer = Pointer(-1);

procedure Fail(const Msg: string);
begin
  WriteLn(StdErr, 'JsonSource error: ', Msg);
  Halt(1);
end;

procedure DBCheck(rc: LongInt; db: Pointer; const Context: string);
begin
  if rc <> SQLITE_OK then
    Fail(Context + ': ' + string(sqlite3_errmsg(db)));
end;

// ── Main ─────────────────────────────────────────────────────────────────────

var
  DBPath:  string;
  Tag:     string;
  SpecId:  Int64;
  HasTag:  Boolean;
  HasId:   Boolean;
  ValCode: Integer;

  DB:      Pointer;
  Stmt:    Pointer;
  Tail:    PAnsiChar;
  rc:      LongInt;

  SQL:     string;
  Payload: string;

begin
  if ParamCount < 1 then
  begin
    WriteLn('Uso: JsonSource runs.db [tag] [id]');
    WriteLn('     Emite el payload JSON a stdout para continuar el pipeline.');
    Halt(0);
  end;

  DBPath := ParamStr(1);
  Tag    := '';
  SpecId := 0;
  HasTag := False;
  HasId  := False;

  if ParamCount >= 2 then begin Tag := ParamStr(2); HasTag := True; end;
  if ParamCount >= 3 then
  begin
    Val(ParamStr(3), SpecId, ValCode);
    if ValCode <> 0 then Fail('id inválido: ' + ParamStr(3));
    HasId := True;
  end;

  if not FileExists(DBPath) then
    Fail('base de datos no encontrada: ' + DBPath);

  rc := sqlite3_open(PAnsiChar(AnsiString(DBPath)), DB);
  if rc <> SQLITE_OK then Fail('no se pudo abrir: ' + DBPath);

  { Construir consulta según los argumentos }
  if HasId then
    SQL := 'SELECT id, payload FROM runs WHERE id = ? LIMIT 1;'
  else if HasTag then
    SQL := 'SELECT id, payload FROM runs WHERE tag = ? ORDER BY id DESC LIMIT 1;'
  else
    SQL := 'SELECT id, payload FROM runs ORDER BY id DESC LIMIT 1;';

  rc := sqlite3_prepare_v2(DB, PAnsiChar(AnsiString(SQL)), -1, Stmt, Tail);
  DBCheck(rc, DB, 'prepare');

  { Bind parámetro }
  if HasId then
  begin
    rc := sqlite3_bind_int64(Stmt, 1, SpecId);
    DBCheck(rc, DB, 'bind id');
  end
  else if HasTag then
  begin
    rc := sqlite3_bind_text(Stmt, 1, PAnsiChar(AnsiString(Tag)), -1, SQLITE_TRANSIENT);
    DBCheck(rc, DB, 'bind tag');
  end;

  { Ejecutar y leer resultado }
  rc := sqlite3_step(Stmt);

  if rc = SQLITE_ROW then
  begin
    sqlite3_column_int64(Stmt, 0);   { id — no usado, columna requerida para el índice }
    Payload := string(sqlite3_column_text(Stmt, 1));
  end
  else if rc = SQLITE_DONE then
  begin
    sqlite3_finalize(Stmt);
    sqlite3_close(DB);
    if HasTag then
      Fail('no hay registros con tag="' + Tag + '" en ' + DBPath)
    else
      Fail('no hay registros en ' + DBPath);
  end
  else
    Fail('step: ' + string(sqlite3_errmsg(DB)));

  sqlite3_finalize(Stmt);
  sqlite3_close(DB);

  { Emitir payload a stdout — el pipeline continúa }
  Write(Payload);
end.
