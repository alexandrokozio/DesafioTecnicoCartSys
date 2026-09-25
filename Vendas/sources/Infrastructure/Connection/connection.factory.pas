unit connection.factory;

interface

uses
  connection.interfaces;

type
  { Manter uma única conexão por instância da fábrica. Cada contexto de
    execução (thread da UI, thread do servidor HTTP, worker do outbox)
    deve possuir sua própria fábrica. }
  TDBConnectionFactory = class(TInterfacedObject, IDBConnectionFactory)
  private
    FConnInstance: IDBConnection;
  public
    class function New: IDBConnectionFactory;
    function Connection: IDBConnection;
    function Query: IQuery;
  end;

implementation

uses
  connection.firedac;

{ TDBConnectionFactory }

class function TDBConnectionFactory.New: IDBConnectionFactory;
begin
  Result := Self.Create;
end;

function TDBConnectionFactory.Connection: IDBConnection;
begin
  if not Assigned(FConnInstance) then
    FConnInstance := TFDAConnection.New;

  Result := FConnInstance;
end;

function TDBConnectionFactory.Query: IQuery;
begin
  Result := TFDAQuery.New(Self.Connection);
end;

end.
