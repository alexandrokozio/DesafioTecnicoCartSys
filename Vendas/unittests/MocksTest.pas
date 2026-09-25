unit MocksTest;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  connection.interfaces,
  repository.interfaces,
  uCliente,
  uProduto,
  uVenda,
  uItemVenda,
  uVendaResumo,
  uEventoIntegracao,
  uIntegracaoPortas;

type
  /// <summary>Executa a operação sem banco, registrando commits e rollbacks.</summary>
  TFakeUnitOfWork = class(TInterfacedObject, IUnitOfWork)
  private
    FCommits: Integer;
    FRollbacks: Integer;
  public
    procedure Executar(const AOperacao: TProc);

    property Commits: Integer read FCommits;
    property Rollbacks: Integer read FRollbacks;
  end;

  TFakeProdutoRepository = class(TInterfacedObject, IProdutoRepository)
  public
    function Inserir(AProduto: TProduto): Integer;
    procedure Atualizar(AProduto: TProduto);
    procedure Excluir(AId: Integer);
    function BuscarPorId(AId: Integer): TProduto;
    function Listar: TObjectList<TProduto>;
  end;

  TFakeClienteRepository = class(TInterfacedObject, IClienteRepository)
  public
    CpfJaExisteRetorno: Boolean;
    /// <summary>E-mail do cliente devolvido por BuscarPorId.</summary>
    EmailCliente: string;

    constructor Create;

    function Inserir(ACliente: TCliente): Integer;
    procedure Atualizar(ACliente: TCliente);
    procedure Excluir(AId: Integer);
    function BuscarPorId(AId: Integer): TCliente;
    function Listar: TObjectList<TCliente>;
    function CpfCnpjJaExiste(const ACpfCnpj: string; AIdIgnorado: Integer): Boolean;
  end;

  /// <summary>Repositório em memória: guarda apenas a situação de cada venda
  /// e reconstrói uma TVenda nova a cada BuscarPorId, como faria o banco.</summary>
  TFakeVendaRepository = class(TInterfacedObject, IVendaRepository)
  private type
    TSituacao = record
      ClienteId: Integer;
      Status: TStatusVenda;
      DataQuitacao: TDateTime;
      DataCancelamento: TDateTime;
      Motivo: string;
      RelatorioEnviado: Boolean;
    end;
  private
    FVendas: TDictionary<Integer, TSituacao>;
    FProximoId: Integer;
    FAtualizacoesSituacao: Integer;

    procedure Gravar(AVenda: TVenda);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Semeia uma venda persistida com o status informado.</summary>
    function Semear(AStatus: TStatusVenda; ARelatorioEnviado: Boolean = False): Integer;
    function StatusDe(AVendaId: Integer): TStatusVenda;
    function RelatorioEnviadoDe(AVendaId: Integer): Boolean;

    function Inserir(AVenda: TVenda): Integer;
    procedure Atualizar(AVenda: TVenda);
    procedure AtualizarSituacao(AVenda: TVenda);
    function BuscarPorId(AId: Integer): TVenda;
    function Listar: TObjectList<TVendaResumo>;

    property AtualizacoesSituacao: Integer read FAtualizacoesSituacao;
  end;

  TFalhaOutbox = record
    EventoId: Integer;
    Definitiva: Boolean;
    ProximaTentativa: TDateTime;
    Erro: string;
  end;

  TFakeOutboxRepository = class(TInterfacedObject, IOutboxRepository)
  private
    FEventos: TList<TTipoEventoIntegracao>;
    FPendentes: TList<TEventoOutbox>;
    FProcessados: TList<Integer>;
    FFalhas: TList<TFalhaOutbox>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AdicionarPendente(AEventoId: Integer; ATipo: TTipoEventoIntegracao;
      AVendaId: Integer; ATentativas: Integer = 0);

    procedure Enfileirar(ATipo: TTipoEventoIntegracao; AVendaId: Integer);
    function ListarPendentes(ALimite: Integer; AAgora: TDateTime): TArray<TEventoOutbox>;
    procedure MarcarProcessado(AEventoId: Integer);
    procedure RegistrarFalha(AEventoId: Integer; const AErro: string;
      AProximaTentativa: TDateTime; ADefinitiva: Boolean);

    /// <summary>Eventos enfileirados pelos serviços.</summary>
    property Eventos: TList<TTipoEventoIntegracao> read FEventos;
    property Processados: TList<Integer> read FProcessados;
    property Falhas: TList<TFalhaOutbox> read FFalhas;
  end;

  TFakeFinanceiroGateway = class(TInterfacedObject, IFinanceiroGateway)
  public
    VendasEnviadas: Integer;
    Cancelamentos: Integer;
    Falhar: Boolean;
    FalhaDefinitiva: Boolean;

    procedure EnviarVenda(AVenda: TVenda; ACliente: TCliente);
    procedure CancelarVenda(AVendaId: Integer; const AMotivo: string; ADataCancelamento: TDateTime);
  end;

  TFakeEmailSender = class(TInterfacedObject, IEmailSender)
  private
    FEnviados: TList<TEmailMensagem>;
  public
    Falhar: Boolean;

    constructor Create;
    destructor Destroy; override;

    procedure Enviar(const AMensagem: TEmailMensagem);

    property Enviados: TList<TEmailMensagem> read FEnviados;
  end;

implementation

{ TFakeUnitOfWork }

procedure TFakeUnitOfWork.Executar(const AOperacao: TProc);
begin
  try
    AOperacao();
    Inc(FCommits);
  except
    Inc(FRollbacks);
    raise;
  end;
end;

{ TFakeProdutoRepository }

function TFakeProdutoRepository.Inserir(AProduto: TProduto): Integer;
begin
  Result := 1;
end;

procedure TFakeProdutoRepository.Atualizar(AProduto: TProduto);
begin
end;

procedure TFakeProdutoRepository.Excluir(AId: Integer);
begin
end;

function TFakeProdutoRepository.BuscarPorId(AId: Integer): TProduto;
begin
  Result := nil;
end;

function TFakeProdutoRepository.Listar: TObjectList<TProduto>;
begin
  Result := TObjectList<TProduto>.Create(True);
end;

{ TFakeClienteRepository }

constructor TFakeClienteRepository.Create;
begin
  inherited Create;
  EmailCliente := 'cliente@teste.com.br';
end;

function TFakeClienteRepository.Inserir(ACliente: TCliente): Integer;
begin
  Result := 1;
end;

procedure TFakeClienteRepository.Atualizar(ACliente: TCliente);
begin
end;

procedure TFakeClienteRepository.Excluir(AId: Integer);
begin
end;

function TFakeClienteRepository.BuscarPorId(AId: Integer): TCliente;
begin
  Result := TCliente.Create;
  Result.Id := AId;
  Result.Nome := 'Cliente Teste';
  Result.CpfCnpj := '12345678901';
  Result.Email := EmailCliente;
end;

function TFakeClienteRepository.Listar: TObjectList<TCliente>;
begin
  Result := TObjectList<TCliente>.Create(True);
end;

function TFakeClienteRepository.CpfCnpjJaExiste(const ACpfCnpj: string; AIdIgnorado: Integer): Boolean;
begin
  Result := CpfJaExisteRetorno;
end;

{ TFakeVendaRepository }

constructor TFakeVendaRepository.Create;
begin
  inherited Create;
  FVendas := TDictionary<Integer, TSituacao>.Create;
end;

destructor TFakeVendaRepository.Destroy;
begin
  FVendas.Free;
  inherited;
end;

procedure TFakeVendaRepository.Gravar(AVenda: TVenda);
var
  LSituacao: TSituacao;
begin
  LSituacao.ClienteId := AVenda.ClienteId;
  LSituacao.Status := AVenda.Status;
  LSituacao.DataQuitacao := AVenda.DataQuitacao;
  LSituacao.DataCancelamento := AVenda.DataCancelamento;
  LSituacao.Motivo := AVenda.MotivoCancelamento;
  LSituacao.RelatorioEnviado := AVenda.RelatorioEnviado;
  FVendas.AddOrSetValue(AVenda.Id, LSituacao);
end;

function TFakeVendaRepository.Semear(AStatus: TStatusVenda; ARelatorioEnviado: Boolean): Integer;
var
  LSituacao: TSituacao;
begin
  Inc(FProximoId);
  LSituacao := Default(TSituacao);
  LSituacao.ClienteId := 1;
  LSituacao.Status := AStatus;
  LSituacao.RelatorioEnviado := ARelatorioEnviado;
  if AStatus = svQuitada then
    LSituacao.DataQuitacao := Now;
  FVendas.Add(FProximoId, LSituacao);
  Result := FProximoId;
end;

function TFakeVendaRepository.StatusDe(AVendaId: Integer): TStatusVenda;
begin
  Result := FVendas[AVendaId].Status;
end;

function TFakeVendaRepository.RelatorioEnviadoDe(AVendaId: Integer): Boolean;
begin
  Result := FVendas[AVendaId].RelatorioEnviado;
end;

function TFakeVendaRepository.Inserir(AVenda: TVenda): Integer;
begin
  Inc(FProximoId);
  AVenda.Id := FProximoId;
  Gravar(AVenda);
  Result := AVenda.Id;
end;

procedure TFakeVendaRepository.Atualizar(AVenda: TVenda);
begin
  Gravar(AVenda);
end;

procedure TFakeVendaRepository.AtualizarSituacao(AVenda: TVenda);
begin
  Inc(FAtualizacoesSituacao);
  Gravar(AVenda);
end;

function TFakeVendaRepository.BuscarPorId(AId: Integer): TVenda;
var
  LSituacao: TSituacao;
begin
  if not FVendas.TryGetValue(AId, LSituacao) then
    Exit(nil);

  Result := TVenda.Create;
  Result.Id := AId;
  Result.ClienteId := LSituacao.ClienteId;
  Result.AdicionarItem(1, 'Produto', 1, 10);
  Result.RestaurarSituacao(LSituacao.Status, LSituacao.DataQuitacao,
    LSituacao.DataCancelamento, LSituacao.Motivo, LSituacao.RelatorioEnviado);
end;

function TFakeVendaRepository.Listar: TObjectList<TVendaResumo>;
begin
  Result := TObjectList<TVendaResumo>.Create(True);
end;

{ TFakeOutboxRepository }

constructor TFakeOutboxRepository.Create;
begin
  inherited Create;
  FEventos := TList<TTipoEventoIntegracao>.Create;
  FPendentes := TList<TEventoOutbox>.Create;
  FProcessados := TList<Integer>.Create;
  FFalhas := TList<TFalhaOutbox>.Create;
end;

destructor TFakeOutboxRepository.Destroy;
begin
  FFalhas.Free;
  FProcessados.Free;
  FPendentes.Free;
  FEventos.Free;
  inherited;
end;

procedure TFakeOutboxRepository.AdicionarPendente(AEventoId: Integer; ATipo: TTipoEventoIntegracao;
  AVendaId: Integer; ATentativas: Integer);
var
  LEvento: TEventoOutbox;
begin
  LEvento.Id := AEventoId;
  LEvento.Tipo := ATipo;
  LEvento.VendaId := AVendaId;
  LEvento.Tentativas := ATentativas;
  FPendentes.Add(LEvento);
end;

procedure TFakeOutboxRepository.Enfileirar(ATipo: TTipoEventoIntegracao; AVendaId: Integer);
begin
  FEventos.Add(ATipo);
end;

function TFakeOutboxRepository.ListarPendentes(ALimite: Integer; AAgora: TDateTime): TArray<TEventoOutbox>;
begin
  Result := FPendentes.ToArray;
end;

procedure TFakeOutboxRepository.MarcarProcessado(AEventoId: Integer);
begin
  FProcessados.Add(AEventoId);
end;

procedure TFakeOutboxRepository.RegistrarFalha(AEventoId: Integer; const AErro: string;
  AProximaTentativa: TDateTime; ADefinitiva: Boolean);
var
  LFalha: TFalhaOutbox;
begin
  LFalha.EventoId := AEventoId;
  LFalha.Definitiva := ADefinitiva;
  LFalha.ProximaTentativa := AProximaTentativa;
  LFalha.Erro := AErro;
  FFalhas.Add(LFalha);
end;

{ TFakeFinanceiroGateway }

procedure TFakeFinanceiroGateway.EnviarVenda(AVenda: TVenda; ACliente: TCliente);
begin
  if Falhar then
    raise EIntegracaoException.Create('Falha simulada no Financeiro', FalhaDefinitiva);
  Inc(VendasEnviadas);
end;

procedure TFakeFinanceiroGateway.CancelarVenda(AVendaId: Integer; const AMotivo: string;
  ADataCancelamento: TDateTime);
begin
  if Falhar then
    raise EIntegracaoException.Create('Falha simulada no Financeiro', FalhaDefinitiva);
  Inc(Cancelamentos);
end;

{ TFakeEmailSender }

constructor TFakeEmailSender.Create;
begin
  inherited Create;
  FEnviados := TList<TEmailMensagem>.Create;
end;

destructor TFakeEmailSender.Destroy;
begin
  FEnviados.Free;
  inherited;
end;

procedure TFakeEmailSender.Enviar(const AMensagem: TEmailMensagem);
begin
  if Falhar then
    raise EIntegracaoException.Create('Falha simulada no SMTP', False);
  FEnviados.Add(AMensagem);
end;

end.
