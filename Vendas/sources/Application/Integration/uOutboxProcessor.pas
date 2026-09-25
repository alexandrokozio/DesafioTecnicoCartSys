unit uOutboxProcessor;

interface

uses
  System.SysUtils,
  connection.interfaces,
  repository.interfaces,
  uEventoIntegracao,
  uIntegracaoPortas;

type
  /// <summary>Backoff exponencial: Base * 2^(tentativa-1), limitado ao máximo.</summary>
  TPoliticaRetentativa = record
    MaxTentativas: Integer;
    IntervaloBaseSegundos: Integer;
    IntervaloMaximoSegundos: Integer;

    class function Padrao(AMaxTentativas: Integer): TPoliticaRetentativa; static;
    function ProximaTentativa(ATentativasRealizadas: Integer; AAgora: TDateTime): TDateTime;
    function Esgotou(ATentativasRealizadas: Integer): Boolean;
  end;

  TResultadoProcessamento = record
    Processados: Integer;
    Falhas: Integer;
  end;

  TOutboxProcessor = class
  private
    FUnitOfWork: IUnitOfWork;
    FOutbox: IOutboxRepository;
    FVendas: IVendaRepository;
    FClientes: IClienteRepository;
    FFinanceiro: IFinanceiroGateway;
    FEmail: IEmailSender;
    FPolitica: TPoliticaRetentativa;
    FLoteMaximo: Integer;

    function ProcessarEvento(const AEvento: TEventoOutbox): Boolean;
    procedure Processar(const AEvento: TEventoOutbox);
    procedure EnviarVenda(AVendaId: Integer);
    procedure CancelarVenda(AVendaId: Integer);
    procedure EnviarEmailConfirmacao(AVendaId: Integer);
    procedure RegistrarFalha(const AEvento: TEventoOutbox; AErro: Exception);
  public
    constructor Create(AUnitOfWork: IUnitOfWork; AOutbox: IOutboxRepository;
      AVendas: IVendaRepository; AClientes: IClienteRepository;
      AFinanceiro: IFinanceiroGateway; AEmail: IEmailSender;
      const APolitica: TPoliticaRetentativa; ALoteMaximo: Integer);

    function ProcessarPendentes: TResultadoProcessamento;
  end;

implementation

uses
  System.Math,
  System.StrUtils,
  System.DateUtils,
  uCliente,
  uVenda,
  uDomainExceptions,
  uConfirmacaoPedidoEmail,
  uLogger;

const
  TAMANHO_MAXIMO_ERRO = 1000;

{ TPoliticaRetentativa }

class function TPoliticaRetentativa.Padrao(AMaxTentativas: Integer): TPoliticaRetentativa;
begin
  Result.MaxTentativas := AMaxTentativas;
  Result.IntervaloBaseSegundos := 30;
  Result.IntervaloMaximoSegundos := 3600;
end;

function TPoliticaRetentativa.Esgotou(ATentativasRealizadas: Integer): Boolean;
begin
  Result := ATentativasRealizadas >= MaxTentativas;
end;

function TPoliticaRetentativa.ProximaTentativa(ATentativasRealizadas: Integer; AAgora: TDateTime): TDateTime;
var
  LSegundos: Int64;
begin
  // Limitei o expoente para não estourar Int64 em cenários de muitas tentativas.
  LSegundos := Int64(IntervaloBaseSegundos) shl Min(Max(ATentativasRealizadas - 1, 0), 20);
  LSegundos := Min(LSegundos, Int64(IntervaloMaximoSegundos));
  Result := IncSecond(AAgora, LSegundos);
end;

{ TOutboxProcessor }

constructor TOutboxProcessor.Create(AUnitOfWork: IUnitOfWork; AOutbox: IOutboxRepository;
  AVendas: IVendaRepository; AClientes: IClienteRepository;
  AFinanceiro: IFinanceiroGateway; AEmail: IEmailSender;
  const APolitica: TPoliticaRetentativa; ALoteMaximo: Integer);
begin
  inherited Create;

  FUnitOfWork := AUnitOfWork;
  FOutbox := AOutbox;
  FVendas := AVendas;
  FClientes := AClientes;
  FFinanceiro := AFinanceiro;
  FEmail := AEmail;
  FPolitica := APolitica;
  FLoteMaximo := ALoteMaximo;
end;

function TOutboxProcessor.ProcessarPendentes: TResultadoProcessamento;
var
  LEvento: TEventoOutbox;
begin
  Result := Default(TResultadoProcessamento);

  for LEvento in FOutbox.ListarPendentes(FLoteMaximo, Now) do
  begin
    if ProcessarEvento(LEvento) then
      Inc(Result.Processados)
    else
      Inc(Result.Falhas);
  end;
end;

function TOutboxProcessor.ProcessarEvento(const AEvento: TEventoOutbox): Boolean;
var
  LEventoId: Integer;
begin
  // Cópia local: métodos anônimos não podem capturar variáveis de controle
  // de laço, e capturar um local simples deixa explícito o que é usado.
  LEventoId := AEvento.Id;
  try
    Processar(AEvento);
    FUnitOfWork.Executar(
      procedure
      begin
        FOutbox.MarcarProcessado(LEventoId);
      end);

    TLogger.Info('Outbox: evento %d (%s, venda %d) processado.',
      [AEvento.Id, TipoEventoToStr(AEvento.Tipo), AEvento.VendaId]);

    Result := True;
  except
    on E: Exception do
    begin
      RegistrarFalha(AEvento, E);
      Result := False;
    end;
  end;
end;

procedure TOutboxProcessor.Processar(const AEvento: TEventoOutbox);
begin
  case AEvento.Tipo of
    teEnviarVenda: EnviarVenda(AEvento.VendaId);
    teCancelarVenda: CancelarVenda(AEvento.VendaId);
    teEnviarEmailConfirmacao: EnviarEmailConfirmacao(AEvento.VendaId);
  end;
end;

procedure TOutboxProcessor.EnviarVenda(AVendaId: Integer);
var
  LVenda: TVenda;
  LCliente: TCliente;
begin
  LVenda := FVendas.BuscarPorId(AVendaId);
  try
    if not Assigned(LVenda) then
      raise EIntegracaoException.Create(Format('Venda %d não encontrada.', [AVendaId]), True);

    LCliente := FClientes.BuscarPorId(LVenda.ClienteId);
    try
      if not Assigned(LCliente) then
        raise EIntegracaoException.Create(
          Format('Cliente %d da venda %d não encontrado.', [LVenda.ClienteId, AVendaId]), True);

      // O estado enviado é o atual da venda (não o do momento do evento):
      // o Financeiro sempre recebe a versão mais recente.
      FFinanceiro.EnviarVenda(LVenda, LCliente);
    finally
      LCliente.Free;
    end;
  finally
    LVenda.Free;
  end;
end;

procedure TOutboxProcessor.CancelarVenda(AVendaId: Integer);
var
  LVenda: TVenda;
begin
  LVenda := FVendas.BuscarPorId(AVendaId);
  try
    if not Assigned(LVenda) then
      raise EIntegracaoException.Create(Format('Venda %d não encontrada.', [AVendaId]), True);

    FFinanceiro.CancelarVenda(LVenda.Id, LVenda.MotivoCancelamento, LVenda.DataCancelamento);
  finally
    LVenda.Free;
  end;
end;

procedure TOutboxProcessor.EnviarEmailConfirmacao(AVendaId: Integer);
var
  LVenda: TVenda;
  LCliente: TCliente;
begin
  LVenda := FVendas.BuscarPorId(AVendaId);
  try
    if not Assigned(LVenda) then
      raise EIntegracaoException.Create(Format('Venda %d não encontrada.', [AVendaId]), True);

    if LVenda.RelatorioEnviado then
      Exit;

    LCliente := FClientes.BuscarPorId(LVenda.ClienteId);
    try
      if not Assigned(LCliente) then
        raise EIntegracaoException.Create(
          Format('Cliente %d da venda %d não encontrado.', [LVenda.ClienteId, AVendaId]), True);

      if LCliente.Email.Trim.IsEmpty then
        raise EIntegracaoException.Create(
          Format('Cliente "%s" não possui e-mail cadastrado.', [LCliente.Nome]), True);

      FEmail.Enviar(TConfirmacaoPedidoEmail.Montar(LVenda, LCliente));
    finally
      LCliente.Free;
    end;

    LVenda.MarcarRelatorioEnviado;
    FUnitOfWork.Executar(
      procedure
      begin
        FVendas.AtualizarSituacao(LVenda);
      end);
  finally
    LVenda.Free;
  end;
end;

procedure TOutboxProcessor.RegistrarFalha(const AEvento: TEventoOutbox; AErro: Exception);
var
  LEventoId, LTentativas: Integer;
  LDefinitiva: Boolean;
  LMensagem: string;
  LProxima: TDateTime;
begin
  LEventoId := AEvento.Id;
  LTentativas := AEvento.Tentativas + 1;

  // Regra de negócio violada (ex.: estado inválido) também não se resolve sozinha com o tempo.
  LDefinitiva := FPolitica.Esgotou(LTentativas) or
                 (AErro is EDomainException) or
                 ((AErro is EIntegracaoException) and EIntegracaoException(AErro).Definitiva);

  LMensagem := Copy(Format('%s: %s', [AErro.ClassName, AErro.Message]), 1, TAMANHO_MAXIMO_ERRO);
  LProxima := FPolitica.ProximaTentativa(LTentativas, Now);

  TLogger.Erro(Format('Outbox: falha no evento %d (%s, venda %d), tentativa %d%s',
    [AEvento.Id, TipoEventoToStr(AEvento.Tipo), AEvento.VendaId, LTentativas,
     IfThen(LDefinitiva, ' - DEFINITIVA', '')]), AErro);

  try
    FUnitOfWork.Executar(
      procedure
      begin
        FOutbox.RegistrarFalha(LEventoId, LMensagem, LProxima, LDefinitiva);
      end);
  except
    on E: Exception do
      // Sem conseguir registrar a falha, o evento continua PENDENTE e será retentado no próximo ciclo.
      TLogger.Erro(Format('Outbox: não foi possível registrar a falha do evento %d', [AEvento.Id]), E);
  end;
end;

end.
