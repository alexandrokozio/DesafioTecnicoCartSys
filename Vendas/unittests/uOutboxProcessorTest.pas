unit uOutboxProcessorTest;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.DateUtils,
  repository.interfaces,
  uVenda,
  uEventoIntegracao,
  uIntegracaoPortas,
  uOutboxProcessor,
  MocksTest;

type
  [TestFixture]
  TOutboxProcessorTest = class
  private
    FOutbox: TFakeOutboxRepository;
    FVendas: TFakeVendaRepository;
    FClientes: TFakeClienteRepository;
    FFinanceiro: TFakeFinanceiroGateway;
    FEmail: TFakeEmailSender;
    // Referências de interface: controlam o ciclo de vida dos fakes.
    FOutboxRef: IOutboxRepository;
    FVendasRef: IVendaRepository;
    FClientesRef: IClienteRepository;
    FFinanceiroRef: IFinanceiroGateway;
    FEmailRef: IEmailSender;
    FProcessador: TOutboxProcessor;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_EnviarVenda_Sucesso_DeveMarcarProcessado;
    [Test]
    procedure Test_EnviarVenda_FalhaTransitoria_DeveReagendar;
    [Test]
    procedure Test_EnviarVenda_FalhaDefinitiva_NaoDeveReagendar;
    [Test]
    procedure Test_EnviarVenda_UltimaTentativa_DeveSerDefinitiva;
    [Test]
    procedure Test_CancelarVenda_DeveNotificarFinanceiro;

    [Test]
    procedure Test_EmailConfirmacao_DeveEnviarEMarcarRelatorio;
    [Test]
    procedure Test_EmailConfirmacao_JaEnviado_NaoDeveReenviar;
    [Test]
    procedure Test_EmailConfirmacao_ClienteSemEmail_DeveFalharDefinitivo;

    [Test]
    procedure Test_FalhaEmUmEvento_NaoImpedeOsDemais;

    [Test]
    procedure Test_Politica_BackoffExponencialLimitado;
  end;

implementation

const
  MAX_TENTATIVAS = 5;

procedure TOutboxProcessorTest.Setup;
begin
  FOutbox := TFakeOutboxRepository.Create;
  FVendas := TFakeVendaRepository.Create;
  FClientes := TFakeClienteRepository.Create;
  FFinanceiro := TFakeFinanceiroGateway.Create;
  FEmail := TFakeEmailSender.Create;

  FOutboxRef := FOutbox;
  FVendasRef := FVendas;
  FClientesRef := FClientes;
  FFinanceiroRef := FFinanceiro;
  FEmailRef := FEmail;

  FProcessador := TOutboxProcessor.Create(TFakeUnitOfWork.Create, FOutboxRef, FVendasRef,
    FClientesRef, FFinanceiroRef, FEmailRef, TPoliticaRetentativa.Padrao(MAX_TENTATIVAS), 20);
end;

procedure TOutboxProcessorTest.TearDown;
begin
  FProcessador.Free;
  FOutboxRef := nil;
  FVendasRef := nil;
  FClientesRef := nil;
  FFinanceiroRef := nil;
  FEmailRef := nil;
end;

procedure TOutboxProcessorTest.Test_EnviarVenda_Sucesso_DeveMarcarProcessado;
var
  LResultado: TResultadoProcessamento;
begin
  FOutbox.AdicionarPendente(10, teEnviarVenda, FVendas.Semear(svPendente));

  LResultado := FProcessador.ProcessarPendentes;

  Assert.AreEqual(1, LResultado.Processados);
  Assert.AreEqual(1, FFinanceiro.VendasEnviadas);
  Assert.AreEqual(10, FOutbox.Processados[0]);
  Assert.AreEqual(0, FOutbox.Falhas.Count);
end;

procedure TOutboxProcessorTest.Test_EnviarVenda_FalhaTransitoria_DeveReagendar;
begin
  FFinanceiro.Falhar := True;
  FOutbox.AdicionarPendente(10, teEnviarVenda, FVendas.Semear(svPendente));

  FProcessador.ProcessarPendentes;

  Assert.AreEqual(0, FOutbox.Processados.Count);
  Assert.AreEqual(1, FOutbox.Falhas.Count);
  Assert.IsFalse(FOutbox.Falhas[0].Definitiva);
  Assert.IsTrue(FOutbox.Falhas[0].ProximaTentativa > Now);
end;

procedure TOutboxProcessorTest.Test_EnviarVenda_FalhaDefinitiva_NaoDeveReagendar;
begin
  FFinanceiro.Falhar := True;
  FFinanceiro.FalhaDefinitiva := True;
  FOutbox.AdicionarPendente(10, teEnviarVenda, FVendas.Semear(svPendente));

  FProcessador.ProcessarPendentes;

  Assert.IsTrue(FOutbox.Falhas[0].Definitiva);
end;

procedure TOutboxProcessorTest.Test_EnviarVenda_UltimaTentativa_DeveSerDefinitiva;
begin
  FFinanceiro.Falhar := True;
  FOutbox.AdicionarPendente(10, teEnviarVenda, FVendas.Semear(svPendente), MAX_TENTATIVAS - 1);

  FProcessador.ProcessarPendentes;

  Assert.IsTrue(FOutbox.Falhas[0].Definitiva, 'Esgotadas as tentativas, o evento deve ir para FALHA');
end;

procedure TOutboxProcessorTest.Test_CancelarVenda_DeveNotificarFinanceiro;
var
  LVendaId: Integer;
begin
  LVendaId := FVendas.Semear(svCancelada);
  FOutbox.AdicionarPendente(11, teCancelarVenda, LVendaId);

  FProcessador.ProcessarPendentes;

  Assert.AreEqual(1, FFinanceiro.Cancelamentos);
  Assert.AreEqual(11, FOutbox.Processados[0]);
end;

procedure TOutboxProcessorTest.Test_EmailConfirmacao_DeveEnviarEMarcarRelatorio;
var
  LVendaId: Integer;
begin
  LVendaId := FVendas.Semear(svQuitada);
  FOutbox.AdicionarPendente(12, teEnviarEmailConfirmacao, LVendaId);

  FProcessador.ProcessarPendentes;

  Assert.AreEqual(1, FEmail.Enviados.Count);
  Assert.AreEqual('cliente@teste.com.br', FEmail.Enviados[0].Para);
  Assert.Contains(FEmail.Enviados[0].CorpoHtml, 'Produto');
  Assert.IsTrue(FVendas.RelatorioEnviadoDe(LVendaId));
  Assert.AreEqual(12, FOutbox.Processados[0]);
end;

procedure TOutboxProcessorTest.Test_EmailConfirmacao_JaEnviado_NaoDeveReenviar;
begin
  FOutbox.AdicionarPendente(12, teEnviarEmailConfirmacao, FVendas.Semear(svQuitada, True));

  FProcessador.ProcessarPendentes;

  Assert.AreEqual(0, FEmail.Enviados.Count);
  Assert.AreEqual(12, FOutbox.Processados[0]);
end;

procedure TOutboxProcessorTest.Test_EmailConfirmacao_ClienteSemEmail_DeveFalharDefinitivo;
begin
  FClientes.EmailCliente := '';
  FOutbox.AdicionarPendente(12, teEnviarEmailConfirmacao, FVendas.Semear(svQuitada));

  FProcessador.ProcessarPendentes;

  Assert.AreEqual(0, FEmail.Enviados.Count);
  Assert.IsTrue(FOutbox.Falhas[0].Definitiva);
end;

procedure TOutboxProcessorTest.Test_FalhaEmUmEvento_NaoImpedeOsDemais;
var
  LResultado: TResultadoProcessamento;
begin
  FEmail.Falhar := True;
  FOutbox.AdicionarPendente(1, teEnviarEmailConfirmacao, FVendas.Semear(svQuitada));
  FOutbox.AdicionarPendente(2, teEnviarVenda, FVendas.Semear(svPendente));

  LResultado := FProcessador.ProcessarPendentes;

  Assert.AreEqual(1, LResultado.Falhas);
  Assert.AreEqual(1, LResultado.Processados);
  Assert.AreEqual(2, FOutbox.Processados[0]);
end;

procedure TOutboxProcessorTest.Test_Politica_BackoffExponencialLimitado;
var
  LPolitica: TPoliticaRetentativa;
  LAgora: TDateTime;
begin
  LPolitica := TPoliticaRetentativa.Padrao(10);
  LAgora := EncodeDateTime(2026, 9, 25, 12, 0, 0, 0);

  Assert.AreEqual<Int64>(30, SecondsBetween(LAgora, LPolitica.ProximaTentativa(1, LAgora)));
  Assert.AreEqual<Int64>(60, SecondsBetween(LAgora, LPolitica.ProximaTentativa(2, LAgora)));
  Assert.AreEqual<Int64>(120, SecondsBetween(LAgora, LPolitica.ProximaTentativa(3, LAgora)));
  Assert.AreEqual<Int64>(3600, SecondsBetween(LAgora, LPolitica.ProximaTentativa(50, LAgora)));
end;

initialization
  TDUnitX.RegisterTestFixture(TOutboxProcessorTest);

end.
