unit uOutboxDAO;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  connection.interfaces,
  repository.interfaces,
  uEventoIntegracao;

type
  TOutboxDAO = class(TInterfacedObject, IOutboxRepository)
  private
    FFactory: IDBConnectionFactory;
  public
    constructor Create(AFactory: IDBConnectionFactory);
    class function New(AFactory: IDBConnectionFactory): IOutboxRepository;

    procedure Enfileirar(ATipo: TTipoEventoIntegracao; AVendaId: Integer);
    function ListarPendentes(ALimite: Integer; AAgora: TDateTime): TArray<TEventoOutbox>;
    procedure MarcarProcessado(AEventoId: Integer);
    procedure RegistrarFalha(AEventoId: Integer; const AErro: string;
      AProximaTentativa: TDateTime; ADefinitiva: Boolean);
  end;

implementation

constructor TOutboxDAO.Create(AFactory: IDBConnectionFactory);
begin
  inherited Create;

  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('AFactory');

  FFactory := AFactory;
end;

class function TOutboxDAO.New(AFactory: IDBConnectionFactory): IOutboxRepository;
begin
  Result := Self.Create(AFactory);
end;

procedure TOutboxDAO.Enfileirar(ATipo: TTipoEventoIntegracao; AVendaId: Integer);
begin
  FFactory.Query
    .SQL('INSERT INTO INTEGRACAO_OUTBOX (TIPO, VENDA_ID) VALUES (:TIPO, :VENDA_ID)')
    .AddParam('TIPO', TipoEventoToStr(ATipo))
    .AddParam('VENDA_ID', AVendaId)
    .ExecSQL;
end;

function TOutboxDAO.ListarPendentes(ALimite: Integer; AAgora: TDateTime): TArray<TEventoOutbox>;
var
  LQuery: IQuery;
  LEventos: TList<TEventoOutbox>;
  LEvento: TEventoOutbox;
begin
  if ALimite <= 0 then
    raise EArgumentOutOfRangeException.Create('ALimite');

  LQuery := FFactory.Query;
  LQuery
    .SQL(Format(
         'SELECT FIRST %d O.ID, O.TIPO, O.VENDA_ID, O.TENTATIVAS ' +
         '  FROM INTEGRACAO_OUTBOX O ' +
         ' WHERE O.STATUS = ''PENDENTE'' ' +
         '   AND O.PROXIMA_TENTATIVA <= :AGORA ' +
         '   AND NOT EXISTS (SELECT 1 FROM INTEGRACAO_OUTBOX A ' +
         '                    WHERE A.VENDA_ID = O.VENDA_ID ' +
         '                      AND A.ID < O.ID ' +
         '                      AND A.STATUS = ''PENDENTE'') ' +
         ' ORDER BY O.ID', [ALimite]))
    .AddParam('AGORA', AAgora)
    .Open;

  LEventos := TList<TEventoOutbox>.Create;
  try
    while not LQuery.Query.Eof do
    begin
      LEvento.Id := LQuery.Query.FieldByName('ID').AsInteger;
      LEvento.Tipo := StrToTipoEvento(LQuery.Query.FieldByName('TIPO').AsString);
      LEvento.VendaId := LQuery.Query.FieldByName('VENDA_ID').AsInteger;
      LEvento.Tentativas := LQuery.Query.FieldByName('TENTATIVAS').AsInteger;
      LEventos.Add(LEvento);

      LQuery.Query.Next;
    end;

    Result := LEventos.ToArray;
  finally
    LEventos.Free;
  end;
end;

procedure TOutboxDAO.MarcarProcessado(AEventoId: Integer);
begin
  FFactory.Query
    .SQL('UPDATE INTEGRACAO_OUTBOX ' +
         '   SET STATUS = ''PROCESSADO'', DATA_PROCESSAMENTO = CURRENT_TIMESTAMP, ULTIMO_ERRO = NULL ' +
         ' WHERE ID = :ID')
    .AddParam('ID', AEventoId)
    .ExecSQL;
end;

procedure TOutboxDAO.RegistrarFalha(AEventoId: Integer; const AErro: string;
  AProximaTentativa: TDateTime; ADefinitiva: Boolean);
const
  STATUS_EVENTO: array[Boolean] of string = ('PENDENTE', 'FALHA');
begin
  FFactory.Query
    .SQL('UPDATE INTEGRACAO_OUTBOX ' +
         '   SET TENTATIVAS = TENTATIVAS + 1, STATUS = :STATUS, ' +
         '       PROXIMA_TENTATIVA = :PROXIMA_TENTATIVA, ULTIMO_ERRO = :ULTIMO_ERRO ' +
         ' WHERE ID = :ID')
    .AddParam('STATUS', STATUS_EVENTO[ADefinitiva])
    .AddParam('PROXIMA_TENTATIVA', AProximaTentativa)
    .AddParam('ULTIMO_ERRO', Copy(AErro, 1, 1000))
    .AddParam('ID', AEventoId)
    .ExecSQL;
end;

end.
