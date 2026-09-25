unit uVendaServiceTest;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  repository.interfaces,
  uVenda,
  uVendaService,
  uDomainExceptions,
  uEventoIntegracao,
  MocksTest;

type
  [TestFixture]
  TVendaServiceTest = class
  private
    FVendaRepo: TFakeVendaRepository;
    FOutbox: TFakeOutboxRepository;
    FVendaRepoRef: IVendaRepository;
    FOutboxRef: IOutboxRepository;
    FService: TVendaService;

    function NovaVendaValida: TVenda;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Salvar_VendaSemCliente_DeveLancarExcecao;
    [Test]
    procedure Test_Salvar_VendaSemItens_DeveLancarExcecao;
    [Test]
    procedure Test_Salvar_VendaValida_DeveEnfileirarEnvioAoFinanceiro;
    [Test]
    procedure Test_Salvar_VendaQuitada_NaoPodeSerAlterada;

    [Test]
    procedure Test_CancelarVenda_DeveCancelarEEnfileirarNotificacao;
    [Test]
    procedure Test_CancelarVenda_Inexistente_DeveLancarNaoEncontrado;

    [Test]
    procedure Test_RegistrarQuitacao_DeveQuitarEEnfileirarEmail;
    [Test]
    procedure Test_RegistrarQuitacao_Repetida_DeveSerIdempotente;
    [Test]
    procedure Test_RegistrarQuitacao_VendaCancelada_DeveLancarExcecao;

    [Test]
    procedure Test_RegistrarCancelamento_NaoDeveNotificarFinanceiro;
  end;

implementation

procedure TVendaServiceTest.Setup;
begin
  FVendaRepo := TFakeVendaRepository.Create;
  FOutbox := TFakeOutboxRepository.Create;
  FVendaRepoRef := FVendaRepo;
  FOutboxRef := FOutbox;
  FService := TVendaService.Create(TFakeUnitOfWork.Create, FVendaRepoRef, FOutboxRef);
end;

procedure TVendaServiceTest.TearDown;
begin
  FService.Free;
  FVendaRepoRef := nil;
  FOutboxRef := nil;
end;

function TVendaServiceTest.NovaVendaValida: TVenda;
begin
  Result := TVenda.Create;
  Result.ClienteId := 1;
  Result.AdicionarItem(1, 'Produto A', 2, 150.00);
end;

procedure TVendaServiceTest.Test_Salvar_VendaSemCliente_DeveLancarExcecao;
var
  LVenda: TVenda;
begin
  LVenda := NovaVendaValida;
  try
    LVenda.ClienteId := 0;

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LVenda);
      end,
      EVendaInvalida);
  finally
    LVenda.Free;
  end;
end;

procedure TVendaServiceTest.Test_Salvar_VendaSemItens_DeveLancarExcecao;
var
  LVenda: TVenda;
begin
  LVenda := NovaVendaValida;
  try
    LVenda.Itens.Clear;

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LVenda);
      end,
      EVendaInvalida);
  finally
    LVenda.Free;
  end;
end;

procedure TVendaServiceTest.Test_Salvar_VendaValida_DeveEnfileirarEnvioAoFinanceiro;
var
  LVenda: TVenda;
begin
  LVenda := NovaVendaValida;
  try
    Assert.IsTrue(FService.Salvar(LVenda) > 0);
    Assert.AreEqual(1, FOutbox.Eventos.Count);
    Assert.IsTrue(FOutbox.Eventos[0] = teEnviarVenda);
  finally
    LVenda.Free;
  end;
end;

procedure TVendaServiceTest.Test_Salvar_VendaQuitada_NaoPodeSerAlterada;
var
  LVenda: TVenda;
begin
  LVenda := NovaVendaValida;
  try
    LVenda.Id := FVendaRepo.Semear(svQuitada);

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LVenda);
      end,
      EVendaInvalida);
    Assert.AreEqual(0, FOutbox.Eventos.Count);
  finally
    LVenda.Free;
  end;
end;

procedure TVendaServiceTest.Test_CancelarVenda_DeveCancelarEEnfileirarNotificacao;
var
  LId: Integer;
begin
  LId := FVendaRepo.Semear(svPendente);

  FService.CancelarVenda(LId, 'Cliente desistiu');

  Assert.IsTrue(FVendaRepo.StatusDe(LId) = svCancelada);
  Assert.AreEqual(1, FOutbox.Eventos.Count);
  Assert.IsTrue(FOutbox.Eventos[0] = teCancelarVenda);
end;

procedure TVendaServiceTest.Test_CancelarVenda_Inexistente_DeveLancarNaoEncontrado;
begin
  Assert.WillRaise(
    procedure
    begin
      FService.CancelarVenda(999, 'Motivo');
    end,
    ERegistroNaoEncontrado);
end;

procedure TVendaServiceTest.Test_RegistrarQuitacao_DeveQuitarEEnfileirarEmail;
var
  LId: Integer;
begin
  LId := FVendaRepo.Semear(svPendente);

  FService.RegistrarQuitacao(LId, Now);

  Assert.IsTrue(FVendaRepo.StatusDe(LId) = svQuitada);
  Assert.AreEqual(1, FOutbox.Eventos.Count);
  Assert.IsTrue(FOutbox.Eventos[0] = teEnviarEmailConfirmacao);
end;

procedure TVendaServiceTest.Test_RegistrarQuitacao_Repetida_DeveSerIdempotente;
var
  LId: Integer;
begin
  LId := FVendaRepo.Semear(svPendente);

  FService.RegistrarQuitacao(LId, Now);
  FService.RegistrarQuitacao(LId, Now);

  Assert.AreEqual(1, FVendaRepo.AtualizacoesSituacao);
  Assert.AreEqual(1, FOutbox.Eventos.Count, 'O e-mail não pode ser enfileirado duas vezes');
end;

procedure TVendaServiceTest.Test_RegistrarQuitacao_VendaCancelada_DeveLancarExcecao;
var
  LId: Integer;
begin
  LId := FVendaRepo.Semear(svCancelada);

  Assert.WillRaise(
    procedure
    begin
      FService.RegistrarQuitacao(LId, Now);
    end,
    EVendaInvalida);
end;

procedure TVendaServiceTest.Test_RegistrarCancelamento_NaoDeveNotificarFinanceiro;
var
  LId: Integer;
begin
  LId := FVendaRepo.Semear(svPendente);

  FService.RegistrarCancelamento(LId, 'Estorno', Now);

  Assert.IsTrue(FVendaRepo.StatusDe(LId) = svCancelada);
  Assert.AreEqual(0, FOutbox.Eventos.Count);
end;

initialization
  TDUnitX.RegisterTestFixture(TVendaServiceTest);

end.
