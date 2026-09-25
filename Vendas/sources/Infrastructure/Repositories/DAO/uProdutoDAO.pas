unit uProdutoDAO;

interface

uses
  System.Generics.Collections,
  Data.DB,
  System.SysUtils,
  connection.interfaces,
  repository.interfaces,
  uProduto;

type
  TProdutoDAO = class(TInterfacedObject, IProdutoRepository)
  private
    FFactory: IDBConnectionFactory;

    function MapearProduto(ADataSet: TDataSet): TProduto;
  public
    constructor Create(AFactory: IDBConnectionFactory);
    class function New(AFactory: IDBConnectionFactory): IProdutoRepository;

    function Inserir(AProduto: TProduto): Integer;
    procedure Atualizar(AProduto: TProduto);
    procedure Excluir(AId: Integer);

    function BuscarPorId(AId: Integer): TProduto;
    function Listar: TObjectList<TProduto>;
  end;

implementation

uses
  Common.Utils;

const
  SQL_SELECT =
    'SELECT ID, DESCRICAO, SKU, PRECO, ESTOQUE_ATUAL, DATA_CADASTRO, ATIVO ' +
    '  FROM PRODUTO ';

constructor TProdutoDAO.Create(AFactory: IDBConnectionFactory);
begin
  inherited Create;

  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('AFactory');

  FFactory := AFactory;
end;

class function TProdutoDAO.New(AFactory: IDBConnectionFactory): IProdutoRepository;
begin
  Result := Self.Create(AFactory);
end;

function TProdutoDAO.MapearProduto(ADataSet: TDataSet): TProduto;
begin
  Result := TProduto.Create;
  Result.Id := ADataSet.FieldByName('ID').AsInteger;
  Result.Descricao := ADataSet.FieldByName('DESCRICAO').AsString;
  Result.Sku := ADataSet.FieldByName('SKU').AsString;
  Result.Preco := ADataSet.FieldByName('PRECO').AsCurrency;
  Result.EstoqueAtual := ADataSet.FieldByName('ESTOQUE_ATUAL').AsInteger;
  Result.DataCadastro := ADataSet.FieldByName('DATA_CADASTRO').AsDateTime;
  Result.Ativo := ADataSet.FieldByName('ATIVO').AsBoolean;
end;

function TProdutoDAO.Inserir(AProduto: TProduto): Integer;
var
  LQuery: IQuery;
begin
  LQuery := FFactory.Query;

  LQuery
    .SQL('INSERT INTO PRODUTO (DESCRICAO, SKU, PRECO, ESTOQUE_ATUAL, ATIVO) ' +
         'VALUES (:DESCRICAO, :SKU, :PRECO, :ESTOQUE_ATUAL, :ATIVO) ' +
         'RETURNING ID')
    .AddParam('DESCRICAO', AProduto.Descricao.Trim)
    .AddParam('SKU', TUtils.TextoOuNulo(AProduto.Sku))
    .AddParam('PRECO', AProduto.Preco)
    .AddParam('ESTOQUE_ATUAL', AProduto.EstoqueAtual)
    .AddParam('ATIVO', AProduto.Ativo)
    .Open;

  Result := LQuery.Query.FieldByName('ID').AsInteger;
end;

procedure TProdutoDAO.Atualizar(AProduto: TProduto);
begin
  FFactory.Query
    .SQL('UPDATE PRODUTO SET DESCRICAO = :DESCRICAO, SKU = :SKU, PRECO = :PRECO, ' +
         '       ESTOQUE_ATUAL = :ESTOQUE_ATUAL, ATIVO = :ATIVO ' +
         ' WHERE ID = :ID')
    .AddParam('DESCRICAO', AProduto.Descricao.Trim)
    .AddParam('SKU', TUtils.TextoOuNulo(AProduto.Sku))
    .AddParam('PRECO', AProduto.Preco)
    .AddParam('ESTOQUE_ATUAL', AProduto.EstoqueAtual)
    .AddParam('ATIVO', AProduto.Ativo)
    .AddParam('ID', AProduto.Id)
    .ExecSQL;
end;

procedure TProdutoDAO.Excluir(AId: Integer);
begin
  // Apenas exclusão lógica
  FFactory.Query
    .SQL('UPDATE PRODUTO SET ATIVO = FALSE WHERE ID = :ID')
    .AddParam('ID', AId)
    .ExecSQL;
end;

function TProdutoDAO.BuscarPorId(AId: Integer): TProduto;
var
  LQuery: IQuery;
begin
  Result := nil;
  LQuery := FFactory.Query;

  LQuery
    .SQL(SQL_SELECT + 'WHERE ID = :ID')
    .AddParam('ID', AId)
    .Open;

  if not LQuery.Query.IsEmpty then
    Result := MapearProduto(LQuery.Query);
end;

function TProdutoDAO.Listar: TObjectList<TProduto>;
var
  LQuery: IQuery;
begin
  Result := TObjectList<TProduto>.Create(True);
  try
    LQuery := FFactory.Query;
    LQuery
      .SQL(SQL_SELECT + 'WHERE ATIVO = TRUE ORDER BY DESCRICAO')
      .Open;

    while not LQuery.Query.Eof do
    begin
      Result.Add(MapearProduto(LQuery.Query));
      LQuery.Query.Next;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
