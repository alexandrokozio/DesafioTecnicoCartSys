unit connection.unitofwork;

interface

uses
  System.SysUtils,
  connection.interfaces;

type
  TUnitOfWork = class(TInterfacedObject, IUnitOfWork)
  private
    FFactory: IDBConnectionFactory;
  public
    constructor Create(AFactory: IDBConnectionFactory);
    class function New(AFactory: IDBConnectionFactory): IUnitOfWork;

    procedure Executar(const AOperacao: TProc);
  end;

implementation

constructor TUnitOfWork.Create(AFactory: IDBConnectionFactory);
begin
  inherited Create;

  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('AFactory');

  FFactory := AFactory;
end;

class function TUnitOfWork.New(AFactory: IDBConnectionFactory): IUnitOfWork;
begin
  Result := Self.Create(AFactory);
end;

procedure TUnitOfWork.Executar(const AOperacao: TProc);
var
  LConnection: IDBConnection;
begin
  LConnection := FFactory.Connection;

  LConnection.StartTransaction;
  try
    AOperacao();
    LConnection.Commit;
  except
    LConnection.Rollback;
    raise;
  end;
end;

end.
