unit uProdutoService;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  connection.interfaces,
  repository.interfaces,
  uProduto;

type
  TProdutoService = class
  private
    FUnitOfWork: IUnitOfWork;
    FProdutoRepository: IProdutoRepository;
  public
    constructor Create(AUnitOfWork: IUnitOfWork; AProdutoRepository: IProdutoRepository);

    function Salvar(AProduto: TProduto): Integer;
    procedure Excluir(AId: Integer);
    function BuscarPorId(AId: Integer): TProduto;
    function Listar: TObjectList<TProduto>;
  end;

implementation

uses
  uDomainExceptions;

{ TProdutoService }

constructor TProdutoService.Create(AUnitOfWork: IUnitOfWork; AProdutoRepository: IProdutoRepository);
begin
  inherited Create;

  if not Assigned(AUnitOfWork) then
    raise EArgumentNilException.Create('AUnitOfWork');
  if not Assigned(AProdutoRepository) then
    raise EArgumentNilException.Create('AProdutoRepository');

  FUnitOfWork := AUnitOfWork;
  FProdutoRepository := AProdutoRepository;
end;

function TProdutoService.Salvar(AProduto: TProduto): Integer;
begin
  if not Assigned(AProduto) then
    raise EArgumentNilException.Create('AProduto');

  AProduto.Validar;

  FUnitOfWork.Executar(
    procedure
    begin
      if AProduto.Id <= 0 then
        AProduto.Id := FProdutoRepository.Inserir(AProduto)
      else
        FProdutoRepository.Atualizar(AProduto);
    end);

  Result := AProduto.Id;
end;

procedure TProdutoService.Excluir(AId: Integer);
begin
  if AId <= 0 then
    raise EProdutoInvalido.Create('ID de produto inválido para exclusão.');

  FUnitOfWork.Executar(
    procedure
    begin
      FProdutoRepository.Excluir(AId);
    end);
end;

function TProdutoService.BuscarPorId(AId: Integer): TProduto;
begin
  if AId <= 0 then
    Exit(nil);

  Result := FProdutoRepository.BuscarPorId(AId);
end;

function TProdutoService.Listar: TObjectList<TProduto>;
begin
  Result := FProdutoRepository.Listar;
end;

end.
