unit uClienteDAO;

interface

uses
  System.Generics.Collections,
  Data.DB,
  System.SysUtils,
  connection.interfaces,
  repository.interfaces,
  uCliente;

type
  TClienteDAO = class(TInterfacedObject, IClienteRepository)
  private
    FFactory: IDBConnectionFactory;

    function MapearCliente(ADataSet: TDataSet): TCliente;
  public
    constructor Create(AFactory: IDBConnectionFactory);
    class function New(AFactory: IDBConnectionFactory): IClienteRepository;

    function Inserir(ACliente: TCliente): Integer;
    procedure Atualizar(ACliente: TCliente);
    procedure Excluir(AId: Integer);

    function BuscarPorId(AId: Integer): TCliente;
    function Listar: TObjectList<TCliente>;
    function CpfCnpjJaExiste(const ACpfCnpj: string; AIdIgnorado: Integer): Boolean;
  end;

implementation

uses
  Common.Utils;

const
  SQL_SELECT =
    'SELECT ID, NOME, CPF_CNPJ, EMAIL, TELEFONE, ENDERECO, DATA_CADASTRO, ATIVO ' +
    '  FROM CLIENTE ';

constructor TClienteDAO.Create(AFactory: IDBConnectionFactory);
begin
  inherited Create;

  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('AFactory');

  FFactory := AFactory;
end;

class function TClienteDAO.New(AFactory: IDBConnectionFactory): IClienteRepository;
begin
  Result := Self.Create(AFactory);
end;

function TClienteDAO.MapearCliente(ADataSet: TDataSet): TCliente;
begin
  Result := TCliente.Create;
  Result.Id := ADataSet.FieldByName('ID').AsInteger;
  Result.Nome := ADataSet.FieldByName('NOME').AsString;
  Result.CpfCnpj := ADataSet.FieldByName('CPF_CNPJ').AsString;
  Result.Email := ADataSet.FieldByName('EMAIL').AsString;
  Result.Telefone := ADataSet.FieldByName('TELEFONE').AsString;
  Result.Endereco := ADataSet.FieldByName('ENDERECO').AsString;
  Result.DataCadastro := ADataSet.FieldByName('DATA_CADASTRO').AsDateTime;
  Result.Ativo := ADataSet.FieldByName('ATIVO').AsBoolean;
end;

function TClienteDAO.Inserir(ACliente: TCliente): Integer;
var
  LQuery: IQuery;
begin
  LQuery := FFactory.Query;

  LQuery
    .SQL('INSERT INTO CLIENTE (NOME, CPF_CNPJ, EMAIL, TELEFONE, ENDERECO, ATIVO) ' +
         'VALUES (:NOME, :CPF_CNPJ, :EMAIL, :TELEFONE, :ENDERECO, :ATIVO) ' +
         'RETURNING ID')
    .AddParam('NOME', ACliente.Nome.Trim)
    .AddParam('CPF_CNPJ', ACliente.CpfCnpj.Trim)
    .AddParam('EMAIL', TUtils.TextoOuNulo(ACliente.Email))
    .AddParam('TELEFONE', TUtils.TextoOuNulo(ACliente.Telefone))
    .AddParam('ENDERECO', TUtils.TextoOuNulo(ACliente.Endereco))
    .AddParam('ATIVO', ACliente.Ativo)
    .Open;

  Result := LQuery.Query.FieldByName('ID').AsInteger;
end;

procedure TClienteDAO.Atualizar(ACliente: TCliente);
begin
  FFactory.Query
    .SQL('UPDATE CLIENTE SET NOME = :NOME, CPF_CNPJ = :CPF_CNPJ, EMAIL = :EMAIL, ' +
         '       TELEFONE = :TELEFONE, ENDERECO = :ENDERECO, ATIVO = :ATIVO ' +
         ' WHERE ID = :ID')
    .AddParam('NOME', ACliente.Nome.Trim)
    .AddParam('CPF_CNPJ', ACliente.CpfCnpj.Trim)
    .AddParam('EMAIL', TUtils.TextoOuNulo(ACliente.Email))
    .AddParam('TELEFONE', TUtils.TextoOuNulo(ACliente.Telefone))
    .AddParam('ENDERECO', TUtils.TextoOuNulo(ACliente.Endereco))
    .AddParam('ATIVO', ACliente.Ativo)
    .AddParam('ID', ACliente.Id)
    .ExecSQL;
end;

procedure TClienteDAO.Excluir(AId: Integer);
begin
  // Apenas exclusão lógica
  FFactory.Query
    .SQL('UPDATE CLIENTE SET ATIVO = FALSE WHERE ID = :ID')
    .AddParam('ID', AId)
    .ExecSQL;
end;

function TClienteDAO.BuscarPorId(AId: Integer): TCliente;
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
    Result := MapearCliente(LQuery.Query);
end;

function TClienteDAO.Listar: TObjectList<TCliente>;
var
  LQuery: IQuery;
begin
  Result := TObjectList<TCliente>.Create(True);
  try
    LQuery := FFactory.Query;
    LQuery
      .SQL(SQL_SELECT + 'WHERE ATIVO = TRUE ORDER BY NOME')
      .Open;

    while not LQuery.Query.Eof do
    begin
      Result.Add(MapearCliente(LQuery.Query));
      LQuery.Query.Next;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TClienteDAO.CpfCnpjJaExiste(const ACpfCnpj: string; AIdIgnorado: Integer): Boolean;
var
  LQuery: IQuery;
begin
  LQuery := FFactory.Query;
  LQuery
    .SQL('SELECT COUNT(*) AS TOTAL ' +
         '  FROM CLIENTE ' +
         ' WHERE CPF_CNPJ = :CPF_CNPJ ' +
         '   AND ID <> :ID_IGNORADO')
    .AddParam('CPF_CNPJ', ACpfCnpj.Trim)
    .AddParam('ID_IGNORADO', AIdIgnorado)
    .Open;

  Result := LQuery.Query.FieldByName('TOTAL').AsInteger > 0;
end;

end.
