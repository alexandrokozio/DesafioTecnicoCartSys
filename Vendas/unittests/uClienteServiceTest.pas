unit uClienteServiceTest;

interface

uses
  DUnitX.TestFramework,
  connection.interfaces,
  repository.interfaces,
  uCliente,
  uClienteService,
  uDomainExceptions,
  MocksTest;

type
  [TestFixture]
  TClienteServiceTest = class
  private
    FFakeRepo: TFakeClienteRepository;
    FRepo: IClienteRepository;
    FService: TClienteService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Salvar_ClienteValido_DeveSalvarComSucesso;

    [Test]
    procedure Test_Salvar_ClienteSemNome_DeveLancarExcecao;

    [Test]
    [TestCase('Email Invalido Sem At', 'usuario.dominio.com')]
    [TestCase('Email Invalido Sem Dominio', 'usuario@')]
    procedure Test_Salvar_EmailComFormatoInvalido_DeveLancarExcecao(const AEmail: string);

    [Test]
    procedure Test_Salvar_CpfDuplicado_DeveLancarExcecao;

    [Test]
    procedure Test_Excluir_IdInvalido_DeveLancarExcecao;
  end;

implementation

procedure TClienteServiceTest.Setup;
begin
  FFakeRepo := TFakeClienteRepository.Create;
  FRepo := FFakeRepo;
  FService := TClienteService.Create(TFakeUnitOfWork.Create, FRepo);
end;

procedure TClienteServiceTest.TearDown;
begin
  FService.Free;
  FRepo := nil;
  FFakeRepo := nil;
end;

procedure TClienteServiceTest.Test_Salvar_ClienteValido_DeveSalvarComSucesso;
var
  LCliente: TCliente;
begin
  FFakeRepo.CpfJaExisteRetorno := False;

  LCliente := TCliente.Create;
  try
    LCliente.Nome := 'Carlos Silva';
    LCliente.CpfCnpj := '12345678901';
    LCliente.Email := 'carlos@empresa.com.br';

    Assert.AreEqual(1, FService.Salvar(LCliente));
    Assert.AreEqual(1, LCliente.Id);
  finally
    LCliente.Free;
  end;
end;

procedure TClienteServiceTest.Test_Salvar_ClienteSemNome_DeveLancarExcecao;
var
  LCliente: TCliente;
begin
  LCliente := TCliente.Create;
  try
    LCliente.Nome := '';
    LCliente.CpfCnpj := '12345678901';

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LCliente);
      end,
      EClienteInvalido);
  finally
    LCliente.Free;
  end;
end;

procedure TClienteServiceTest.Test_Salvar_EmailComFormatoInvalido_DeveLancarExcecao(const AEmail: string);
var
  LCliente: TCliente;
begin
  LCliente := TCliente.Create;
  try
    LCliente.Nome := 'Ana Maria';
    LCliente.CpfCnpj := '98765432100';
    LCliente.Email := AEmail;

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LCliente);
      end,
      EClienteInvalido);
  finally
    LCliente.Free;
  end;
end;

procedure TClienteServiceTest.Test_Salvar_CpfDuplicado_DeveLancarExcecao;
var
  LCliente: TCliente;
begin
  FFakeRepo.CpfJaExisteRetorno := True;

  LCliente := TCliente.Create;
  try
    LCliente.Nome := 'João Pedro';
    LCliente.CpfCnpj := '11122233344';

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LCliente);
      end,
      EClienteInvalido);
  finally
    LCliente.Free;
  end;
end;

procedure TClienteServiceTest.Test_Excluir_IdInvalido_DeveLancarExcecao;
begin
  Assert.WillRaise(
    procedure
    begin
      FService.Excluir(0);
    end,
    EClienteInvalido);
end;

initialization
  TDUnitX.RegisterTestFixture(TClienteServiceTest);

end.
