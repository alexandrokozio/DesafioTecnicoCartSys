unit uDtmMain;

interface

uses
  System.SysUtils,
  System.Classes,
  connection.interfaces,
  uClienteService,
  uProdutoService,
  uVendaService,
  uOutboxProcessor,
  uOutboxWorker,
  uApiServer;

type
  { Gerenciar o ciclo de vida da app desktop: conexão da thread principal,
    servidor da API REST e worker do outbox. A montagem dos serviços
    deleguei ao composition root (TServiceFactory). }
  TdtmMain = class(TDataModule)
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    FConexao: IDBConnectionFactory;
    FApiServer: TApiServer;
    FOutboxWorker: TOutboxWorker;
    FStatusApi: string;
    FStatusIntegracao: string;
    FOnStatusAlterado: TNotifyEvent;

    procedure IniciarApi;
    procedure IniciarOutbox;
    procedure CicloOutboxConcluido(const AResultado: TResultadoProcessamento);
    procedure NotificarStatus;
  public
    function CriarClienteService: TClienteService;
    function CriarProdutoService: TProdutoService;
    function CriarVendaService: TVendaService;

    // Antecipar a sincronização com o Financeiro (após salvar/cancelar).
    procedure SincronizarAgora;

    property StatusApi: string read FStatusApi;
    property StatusIntegracao: string read FStatusIntegracao;
    property OnStatusAlterado: TNotifyEvent read FOnStatusAlterado write FOnStatusAlterado;
  end;

var
  dtmMain: TdtmMain;

implementation

uses
  uAppConfig,
  uLogger,
  uServiceFactory;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure TdtmMain.DataModuleCreate(Sender: TObject);
begin
  FConexao := TServiceFactory.New;
  IniciarApi;
  IniciarOutbox;
end;

procedure TdtmMain.DataModuleDestroy(Sender: TObject);
begin
  FreeAndNil(FApiServer);
  FreeAndNil(FOutboxWorker);
  FConexao := nil;
end;

procedure TdtmMain.IniciarApi;
var
  LConfig: TApiConfig;
begin
  LConfig := TAppConfig.Api;
  if not LConfig.Habilitada then
  begin
    FStatusApi := 'API: desabilitada';
    Exit;
  end;

  FApiServer := TApiServer.Create(LConfig);
  try
    FApiServer.Iniciar;
    FStatusApi := 'API: ' + FApiServer.Endereco;
  except
    on E: Exception do
    begin
      // Deve permitir o app desktop continuar operando, em caso de erros na integração.
      TLogger.Erro('API: não foi possível iniciar o servidor', E);
      FStatusApi := 'API: falha ao iniciar (' + E.Message + ')';
    end;
  end;
end;

procedure TdtmMain.IniciarOutbox;
var
  LConfig: TOutboxConfig;
begin
  LConfig := TAppConfig.Outbox;
  if not LConfig.Habilitado then
  begin
    FStatusIntegracao := 'Integração: desabilitada';
    Exit;
  end;

  FOutboxWorker := TOutboxWorker.Create(
    function: TOutboxProcessor
    begin
      Result := TServiceFactory.OutboxProcessor(TServiceFactory.New);
    end,
    LConfig.IntervaloSegundos);
  FOutboxWorker.OnCicloConcluido := CicloOutboxConcluido;
  FOutboxWorker.Start;

  FStatusIntegracao := 'Integração: ativa';
end;

procedure TdtmMain.CicloOutboxConcluido(const AResultado: TResultadoProcessamento);
begin
  FStatusIntegracao := Format('Integração: %s - %d enviado(s), %d falha(s)',
    [FormatDateTime('hh:nn:ss', Now), AResultado.Processados, AResultado.Falhas]);
  NotificarStatus;
end;

procedure TdtmMain.NotificarStatus;
begin
  if Assigned(FOnStatusAlterado) then
    FOnStatusAlterado(Self);
end;

procedure TdtmMain.SincronizarAgora;
begin
  if Assigned(FOutboxWorker) then
    FOutboxWorker.Acordar;
end;

function TdtmMain.CriarClienteService: TClienteService;
begin
  Result := TServiceFactory.ClienteService(FConexao);
end;

function TdtmMain.CriarProdutoService: TProdutoService;
begin
  Result := TServiceFactory.ProdutoService(FConexao);
end;

function TdtmMain.CriarVendaService: TVendaService;
begin
  Result := TServiceFactory.VendaService(FConexao);
end;

end.
