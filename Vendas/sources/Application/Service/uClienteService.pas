unit uClienteService;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  connection.interfaces,
  repository.interfaces,
  uCliente;

type
  TClienteService = class
  private
    FUnitOfWork: IUnitOfWork;
    FClienteRepository: IClienteRepository;

    procedure Validar(ACliente: TCliente);
  public
    constructor Create(AUnitOfWork: IUnitOfWork; AClienteRepository: IClienteRepository);

    function Salvar(ACliente: TCliente): Integer;
    procedure Excluir(AId: Integer);
    function BuscarPorId(AId: Integer): TCliente;
    function Listar: TObjectList<TCliente>;
  end;

implementation

uses
  uDomainExceptions;

{ TClienteService }

constructor TClienteService.Create(AUnitOfWork: IUnitOfWork; AClienteRepository: IClienteRepository);
begin
  inherited Create;

  if not Assigned(AUnitOfWork) then
    raise EArgumentNilException.Create('AUnitOfWork');
  if not Assigned(AClienteRepository) then
    raise EArgumentNilException.Create('AClienteRepository');

  FUnitOfWork := AUnitOfWork;
  FClienteRepository := AClienteRepository;
end;

procedure TClienteService.Validar(ACliente: TCliente);
begin
  if not Assigned(ACliente) then
    raise EArgumentNilException.Create('ACliente');

  ACliente.Validar;

  if FClienteRepository.CpfCnpjJaExiste(ACliente.CpfCnpj, ACliente.Id) then
    raise EClienteInvalido.CreateFmt('Já existe outro cliente cadastrado com o CPF/CNPJ %s.',
      [ACliente.CpfCnpj]);
end;

function TClienteService.Salvar(ACliente: TCliente): Integer;
begin
  Validar(ACliente);

  FUnitOfWork.Executar(
    procedure
    begin
      if ACliente.Id <= 0 then
        ACliente.Id := FClienteRepository.Inserir(ACliente)
      else
        FClienteRepository.Atualizar(ACliente);
    end);

  Result := ACliente.Id;
end;

procedure TClienteService.Excluir(AId: Integer);
begin
  if AId <= 0 then
    raise EClienteInvalido.Create('ID de cliente inválido para exclusão.');

  FUnitOfWork.Executar(
    procedure
    begin
      FClienteRepository.Excluir(AId);
    end);
end;

function TClienteService.BuscarPorId(AId: Integer): TCliente;
begin
  if AId <= 0 then
    Exit(nil);

  Result := FClienteRepository.BuscarPorId(AId);
end;

function TClienteService.Listar: TObjectList<TCliente>;
begin
  Result := FClienteRepository.Listar;
end;

end.
