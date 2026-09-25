unit uItemVendaDAO;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  connection.interfaces,
  repository.interfaces,
  uItemVenda;

type
  TItemVendaDAO = class(TInterfacedObject, IItemVendaRepository)
  private
    FFactory: IDBConnectionFactory;

    procedure Inserir(AVendaId: Integer; AItem: TVendaItem);
  public
    constructor Create(AFactory: IDBConnectionFactory);
    class function New(AFactory: IDBConnectionFactory): IItemVendaRepository;

    procedure InserirLista(AVendaId: Integer; AItens: TObjectList<TVendaItem>);
    procedure DeletarPorVendaId(AVendaId: Integer);
    procedure CarregarPorVendaId(AVendaId: Integer; AItens: TObjectList<TVendaItem>);
  end;

implementation

constructor TItemVendaDAO.Create(AFactory: IDBConnectionFactory);
begin
  inherited Create;

  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('AFactory');

  FFactory := AFactory;
end;

class function TItemVendaDAO.New(AFactory: IDBConnectionFactory): IItemVendaRepository;
begin
  Result := Self.Create(AFactory);
end;

procedure TItemVendaDAO.Inserir(AVendaId: Integer; AItem: TVendaItem);
var
  LQuery: IQuery;
begin
  LQuery := FFactory.Query;
  LQuery
    .SQL('INSERT INTO VENDA_ITEM (VENDA_ID, PRODUTO_ID, QUANTIDADE, PRECO_UNITARIO, VALOR_TOTAL) ' +
         'VALUES (:VENDA_ID, :PRODUTO_ID, :QUANTIDADE, :PRECO_UNITARIO, :VALOR_TOTAL) ' +
         'RETURNING ID')
    .AddParam('VENDA_ID', AVendaId)
    .AddParam('PRODUTO_ID', AItem.ProdutoId)
    .AddParam('QUANTIDADE', AItem.Quantidade)
    .AddParam('PRECO_UNITARIO', AItem.PrecoUnitario)
    .AddParam('VALOR_TOTAL', AItem.ValorTotal)
    .Open;

  AItem.Id := LQuery.Query.FieldByName('ID').AsInteger;
end;

procedure TItemVendaDAO.InserirLista(AVendaId: Integer; AItens: TObjectList<TVendaItem>);
var
  LItem: TVendaItem;
begin
  if not Assigned(AItens) then
    Exit;

  for LItem in AItens do
    Inserir(AVendaId, LItem);
end;

procedure TItemVendaDAO.DeletarPorVendaId(AVendaId: Integer);
begin
  FFactory.Query
    .SQL('DELETE FROM VENDA_ITEM WHERE VENDA_ID = :VENDA_ID')
    .AddParam('VENDA_ID', AVendaId)
    .ExecSQL;
end;

procedure TItemVendaDAO.CarregarPorVendaId(AVendaId: Integer; AItens: TObjectList<TVendaItem>);
var
  LQuery: IQuery;
  LItem: TVendaItem;
begin
  if not Assigned(AItens) then
    raise EArgumentNilException.Create('AItens');

  LQuery := FFactory.Query;
  LQuery
    .SQL('SELECT VI.ID, VI.PRODUTO_ID, VI.QUANTIDADE, VI.PRECO_UNITARIO, ' +
         '       P.DESCRICAO AS PRODUTO_DESCRICAO ' +
         '  FROM VENDA_ITEM VI ' +
         ' INNER JOIN PRODUTO P ON P.ID = VI.PRODUTO_ID ' +
         ' WHERE VI.VENDA_ID = :VENDA_ID ' +
         ' ORDER BY VI.ID')
    .AddParam('VENDA_ID', AVendaId)
    .Open;

  while not LQuery.Query.Eof do
  begin
    LItem := TVendaItem.Create;
    LItem.Id := LQuery.Query.FieldByName('ID').AsInteger;
    LItem.ProdutoId := LQuery.Query.FieldByName('PRODUTO_ID').AsInteger;
    LItem.ProdutoDescricao := LQuery.Query.FieldByName('PRODUTO_DESCRICAO').AsString;
    LItem.Quantidade := LQuery.Query.FieldByName('QUANTIDADE').AsInteger;
    LItem.PrecoUnitario := LQuery.Query.FieldByName('PRECO_UNITARIO').AsCurrency;
    AItens.Add(LItem);

    LQuery.Query.Next;
  end;
end;

end.
