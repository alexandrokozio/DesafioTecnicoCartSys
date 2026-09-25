unit uVendaDAO;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  connection.interfaces,
  repository.interfaces,
  uVenda,
  uVendaResumo;

type
  TVendaDAO = class(TInterfacedObject, IVendaRepository)
  private
    FFactory: IDBConnectionFactory;
    FItemRepository: IItemVendaRepository;
  public
    constructor Create(AFactory: IDBConnectionFactory; AItemRepository: IItemVendaRepository = nil);
    class function New(AFactory: IDBConnectionFactory; AItemRepository: IItemVendaRepository = nil): IVendaRepository;

    function Inserir(AVenda: TVenda): Integer;
    procedure Atualizar(AVenda: TVenda);
    procedure AtualizarSituacao(AVenda: TVenda);

    function BuscarPorId(AId: Integer): TVenda;
    function Listar: TObjectList<TVendaResumo>;
  end;

implementation

uses
  Common.Utils,
  uItemVendaDAO;

constructor TVendaDAO.Create(AFactory: IDBConnectionFactory; AItemRepository: IItemVendaRepository);
begin
  inherited Create;

  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('AFactory');

  FFactory := AFactory;

  if Assigned(AItemRepository) then
    FItemRepository := AItemRepository
  else
    FItemRepository := TItemVendaDAO.New(FFactory);
end;

class function TVendaDAO.New(AFactory: IDBConnectionFactory; AItemRepository: IItemVendaRepository): IVendaRepository;
begin
  Result := Self.Create(AFactory, AItemRepository);
end;

function TVendaDAO.Inserir(AVenda: TVenda): Integer;
var
  LQuery: IQuery;
begin
  LQuery := FFactory.Query;

  LQuery
    .SQL('INSERT INTO VENDA (CLIENTE_ID, DATA_VENDA, VALOR_TOTAL, STATUS) ' +
         'VALUES (:CLIENTE_ID, :DATA_VENDA, :VALOR_TOTAL, :STATUS) ' +
         'RETURNING ID')
    .AddParam('CLIENTE_ID', AVenda.ClienteId)
    .AddParam('DATA_VENDA', AVenda.DataVenda)
    .AddParam('VALOR_TOTAL', AVenda.ValorTotal)
    .AddParam('STATUS', StatusVendaToStr(AVenda.Status))
    .Open;

  Result := LQuery.Query.FieldByName('ID').AsInteger;
  AVenda.Id := Result;

  FItemRepository.InserirLista(Result, AVenda.Itens);
end;

procedure TVendaDAO.Atualizar(AVenda: TVenda);
begin
  FFactory.Query
    .SQL('UPDATE VENDA SET CLIENTE_ID = :CLIENTE_ID, VALOR_TOTAL = :VALOR_TOTAL ' +
         ' WHERE ID = :ID')
    .AddParam('CLIENTE_ID', AVenda.ClienteId)
    .AddParam('VALOR_TOTAL', AVenda.ValorTotal)
    .AddParam('ID', AVenda.Id)
    .ExecSQL;

  FItemRepository.DeletarPorVendaId(AVenda.Id);
  FItemRepository.InserirLista(AVenda.Id, AVenda.Itens);
end;

procedure TVendaDAO.AtualizarSituacao(AVenda: TVenda);
begin
  FFactory.Query
    .SQL('UPDATE VENDA SET STATUS = :STATUS, DATA_QUITACAO = :DATA_QUITACAO, ' +
         '       DATA_CANCELAMENTO = :DATA_CANCELAMENTO, ' +
         '       MOTIVO_CANCELAMENTO = :MOTIVO_CANCELAMENTO, ' +
         '       RELATORIO_ENVIADO = :RELATORIO_ENVIADO ' +
         ' WHERE ID = :ID')
    .AddParam('STATUS', StatusVendaToStr(AVenda.Status))
    .AddParam('DATA_QUITACAO', TUtils.DataOuNulo(AVenda.DataQuitacao))
    .AddParam('DATA_CANCELAMENTO', TUtils.DataOuNulo(AVenda.DataCancelamento))
    .AddParam('MOTIVO_CANCELAMENTO', TUtils.TextoOuNulo(AVenda.MotivoCancelamento))
    .AddParam('RELATORIO_ENVIADO', AVenda.RelatorioEnviado)
    .AddParam('ID', AVenda.Id)
    .ExecSQL;
end;

function TVendaDAO.BuscarPorId(AId: Integer): TVenda;
var
  LQuery: IQuery;
begin
  Result := nil;
  if AId <= 0 then
    Exit;

  LQuery := FFactory.Query;
  LQuery
    .SQL('SELECT ID, CLIENTE_ID, DATA_VENDA, STATUS, DATA_QUITACAO, DATA_CANCELAMENTO, ' +
         '       MOTIVO_CANCELAMENTO, RELATORIO_ENVIADO ' +
         '  FROM VENDA ' +
         ' WHERE ID = :ID')
    .AddParam('ID', AId)
    .Open;

  if LQuery.Query.IsEmpty then
    Exit;

  Result := TVenda.Create;
  try
    Result.Id := LQuery.Query.FieldByName('ID').AsInteger;
    Result.ClienteId := LQuery.Query.FieldByName('CLIENTE_ID').AsInteger;
    Result.DataVenda := LQuery.Query.FieldByName('DATA_VENDA').AsDateTime;
    Result.RestaurarSituacao(
      StrToStatusVenda(LQuery.Query.FieldByName('STATUS').AsString),
      TUtils.DataOuZero(LQuery.Query.FieldByName('DATA_QUITACAO')),
      TUtils.DataOuZero(LQuery.Query.FieldByName('DATA_CANCELAMENTO')),
      LQuery.Query.FieldByName('MOTIVO_CANCELAMENTO').AsString,
      LQuery.Query.FieldByName('RELATORIO_ENVIADO').AsBoolean);

    FItemRepository.CarregarPorVendaId(Result.Id, Result.Itens);
  except
    Result.Free;
    raise;
  end;
end;

function TVendaDAO.Listar: TObjectList<TVendaResumo>;
var
  LQuery: IQuery;
  LResumo: TVendaResumo;
begin
  Result := TObjectList<TVendaResumo>.Create(True);
  try
    LQuery := FFactory.Query;
    LQuery
      .SQL('SELECT V.ID, V.CLIENTE_ID, C.NOME AS CLIENTE_NOME, V.DATA_VENDA, ' +
           '       V.STATUS, V.VALOR_TOTAL, V.MOTIVO_CANCELAMENTO ' +
           '  FROM VENDA V ' +
           ' INNER JOIN CLIENTE C ON C.ID = V.CLIENTE_ID ' +
           ' ORDER BY V.DATA_VENDA DESC')
      .Open;

    while not LQuery.Query.Eof do
    begin
      LResumo := TVendaResumo.Create;
      Result.Add(LResumo);

      LResumo.Id := LQuery.Query.FieldByName('ID').AsInteger;
      LResumo.ClienteId := LQuery.Query.FieldByName('CLIENTE_ID').AsInteger;
      LResumo.ClienteNome := LQuery.Query.FieldByName('CLIENTE_NOME').AsString;
      LResumo.DataVenda := LQuery.Query.FieldByName('DATA_VENDA').AsDateTime;
      LResumo.Status := StrToStatusVenda(LQuery.Query.FieldByName('STATUS').AsString);
      LResumo.ValorTotal := LQuery.Query.FieldByName('VALOR_TOTAL').AsCurrency;
      LResumo.MotivoCancelamento := LQuery.Query.FieldByName('MOTIVO_CANCELAMENTO').AsString;

      LQuery.Query.Next;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
