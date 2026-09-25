unit uOutboxWorker;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  uOutboxProcessor;

type
  TCicloOutboxEvent = procedure(const AResultado: TResultadoProcessamento) of object;

  /// <summary>
  /// Thread que processa o outbox periodicamente. Cada ciclo cria um
  /// processador novo (com conexão própria do pool) pela fábrica injetada,
  /// de modo que nenhum objeto de acesso a dados é compartilhado com a UI.
  /// </summary>
  TOutboxWorker = class(TThread)
  private
    FFabricaProcessador: TFunc<TOutboxProcessor>;
    FIntervaloMs: Cardinal;
    FSinal: TEvent;
    FOnCicloConcluido: TCicloOutboxEvent;

    procedure ExecutarCiclo;
  protected
    procedure Execute; override;
    procedure TerminatedSet; override;
  public
    constructor Create(const AFabricaProcessador: TFunc<TOutboxProcessor>; AIntervaloSegundos: Integer);
    destructor Destroy; override;

    /// <summary>Antecipa o próximo ciclo (ex.: logo após salvar uma venda).</summary>
    procedure Acordar;

    /// <summary>Disparado na thread principal (TThread.Queue) ao fim de cada
    /// ciclo que processou algum evento.</summary>
    property OnCicloConcluido: TCicloOutboxEvent read FOnCicloConcluido write FOnCicloConcluido;
  end;

implementation

uses
  uLogger;

constructor TOutboxWorker.Create(const AFabricaProcessador: TFunc<TOutboxProcessor>;
  AIntervaloSegundos: Integer);
begin
  if not Assigned(AFabricaProcessador) then
    raise EArgumentNilException.Create('AFabricaProcessador');

  FFabricaProcessador := AFabricaProcessador;
  FIntervaloMs := Cardinal(AIntervaloSegundos) * 1000;
  FSinal := TEvent.Create(nil, False, False, '');

  inherited Create(True);
  FreeOnTerminate := False;
  NameThreadForDebugging('OutboxWorker');
end;

destructor TOutboxWorker.Destroy;
begin
  inherited Destroy;
  FSinal.Free;
end;

procedure TOutboxWorker.Acordar;
begin
  FSinal.SetEvent;
end;

procedure TOutboxWorker.TerminatedSet;
begin
  inherited;
  // Interrompe a espera imediatamente ao encerrar a aplicação.
  FSinal.SetEvent;
end;

procedure TOutboxWorker.Execute;
begin
  TLogger.Info('Outbox: worker iniciado (intervalo de %d s).', [FIntervaloMs div 1000]);

  while not Terminated do
  begin
    ExecutarCiclo;

    if not Terminated then
      FSinal.WaitFor(FIntervaloMs);
  end;

  TLogger.Info('Outbox: worker finalizado.');
end;

procedure TOutboxWorker.ExecutarCiclo;
var
  LProcessador: TOutboxProcessor;
  LResultado: TResultadoProcessamento;
begin
  try
    LProcessador := FFabricaProcessador();
    try
      LResultado := LProcessador.ProcessarPendentes;
    finally
      LProcessador.Free;
    end;

    if Assigned(FOnCicloConcluido) and ((LResultado.Processados > 0) or (LResultado.Falhas > 0)) then
      // Queue(Self, ...): chamadas pendentes são descartadas se o worker for
      // destruído antes de a thread principal executá-las.
      TThread.Queue(Self,
        procedure
        begin
          if Assigned(FOnCicloConcluido) then
            FOnCicloConcluido(LResultado);
        end);
  except
    on E: Exception do
      TLogger.Erro('Outbox: falha no ciclo de processamento', E);
  end;
end;

end.
