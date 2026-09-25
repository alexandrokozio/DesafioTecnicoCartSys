unit uVendaService;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  connection.interfaces,
  repository.interfaces,
  uVenda,
  uVendaResumo;

type
  /// <summary>
  /// Casos de uso da venda. As regras de transição de status vivem na
  /// entidade TVenda; este serviço orquestra persistência, transação e o
  /// registro dos eventos de integração (outbox) na mesma transação.
  /// </summary>
  TVendaService = class
  private
    FUnitOfWork: IUnitOfWork;
    FVendaRepository: IVendaRepository;
    FOutboxRepository: IOutboxRepository;

    function ObterVenda(AVendaId: Integer): TVenda;
  public
    constructor Create(AUnitOfWork: IUnitOfWork; AVendaRepository: IVendaRepository;
      AOutboxRepository: IOutboxRepository);

    function BuscarPorId(AId: Integer): TVenda;
    function Listar: TObjectList<TVendaResumo>;

    /// <summary>Inclui ou altera uma venda pendente e agenda o envio ao Financeiro.</summary>
    function Salvar(AVenda: TVenda): Integer;

    /// <summary>Cancelamento solicitado no ERP Vendas; o Financeiro é notificado.</summary>
    procedure CancelarVenda(AVendaId: Integer; const AMotivo: string);

    /// <summary>Quitação informada pelo ERP Financeiro (webhook). Idempotente:
    /// reenvios de uma quitação já registrada são ignorados.</summary>
    procedure RegistrarQuitacao(AVendaId: Integer; ADataQuitacao: TDateTime);

    /// <summary>Cancelamento informado pelo ERP Financeiro (webhook). Idempotente.</summary>
    procedure RegistrarCancelamento(AVendaId: Integer; const AMotivo: string;
      ADataCancelamento: TDateTime);
  end;

implementation

uses
  uDomainExceptions,
  uEventoIntegracao;

{ TVendaService }

constructor TVendaService.Create(AUnitOfWork: IUnitOfWork; AVendaRepository: IVendaRepository;
  AOutboxRepository: IOutboxRepository);
begin
  inherited Create;

  if not Assigned(AUnitOfWork) then
    raise EArgumentNilException.Create('AUnitOfWork');
  if not Assigned(AVendaRepository) then
    raise EArgumentNilException.Create('AVendaRepository');
  if not Assigned(AOutboxRepository) then
    raise EArgumentNilException.Create('AOutboxRepository');

  FUnitOfWork := AUnitOfWork;
  FVendaRepository := AVendaRepository;
  FOutboxRepository := AOutboxRepository;
end;

function TVendaService.ObterVenda(AVendaId: Integer): TVenda;
begin
  if AVendaId <= 0 then
    raise EVendaInvalida.Create('ID de venda inválido.');

  Result := FVendaRepository.BuscarPorId(AVendaId);
  if not Assigned(Result) then
    raise ERegistroNaoEncontrado.CreateFmt('Venda %d não encontrada.', [AVendaId]);
end;

function TVendaService.BuscarPorId(AId: Integer): TVenda;
begin
  if AId <= 0 then
    Exit(nil);

  Result := FVendaRepository.BuscarPorId(AId);
end;

function TVendaService.Listar: TObjectList<TVendaResumo>;
begin
  Result := FVendaRepository.Listar;
end;

function TVendaService.Salvar(AVenda: TVenda): Integer;
var
  LPersistida: TVenda;
begin
  if not Assigned(AVenda) then
    raise EArgumentNilException.Create('AVenda');

  AVenda.Validar;

  // O status é sempre o do banco, nunca o recebido da tela.
  if AVenda.Id > 0 then
  begin
    LPersistida := ObterVenda(AVenda.Id);
    try
      if not LPersistida.PodeSerAlterada then
        raise EVendaInvalida.CreateFmt('A venda %d está %s e não pode ser alterada.',
          [AVenda.Id, StatusVendaToStr(LPersistida.Status)]);
    finally
      LPersistida.Free;
    end;
  end;

  FUnitOfWork.Executar(
    procedure
    begin
      if AVenda.Id <= 0 then
        FVendaRepository.Inserir(AVenda)
      else
        FVendaRepository.Atualizar(AVenda);

      FOutboxRepository.Enfileirar(teEnviarVenda, AVenda.Id);
    end);

  Result := AVenda.Id;
end;

procedure TVendaService.CancelarVenda(AVendaId: Integer; const AMotivo: string);
var
  LVenda: TVenda;
begin
  LVenda := ObterVenda(AVendaId);
  try
    LVenda.Cancelar(AMotivo, Now);

    FUnitOfWork.Executar(
      procedure
      begin
        FVendaRepository.AtualizarSituacao(LVenda);
        FOutboxRepository.Enfileirar(teCancelarVenda, LVenda.Id);
      end);
  finally
    LVenda.Free;
  end;
end;

procedure TVendaService.RegistrarQuitacao(AVendaId: Integer; ADataQuitacao: TDateTime);
var
  LVenda: TVenda;
begin
  LVenda := ObterVenda(AVendaId);
  try
    if LVenda.Status = svQuitada then
      Exit;

    LVenda.Quitar(ADataQuitacao);

    FUnitOfWork.Executar(
      procedure
      begin
        FVendaRepository.AtualizarSituacao(LVenda);
        FOutboxRepository.Enfileirar(teEnviarEmailConfirmacao, LVenda.Id);
      end);
  finally
    LVenda.Free;
  end;
end;

procedure TVendaService.RegistrarCancelamento(AVendaId: Integer; const AMotivo: string;
  ADataCancelamento: TDateTime);
var
  LVenda: TVenda;
begin
  LVenda := ObterVenda(AVendaId);
  try
    if LVenda.Status = svCancelada then
      Exit;

    LVenda.Cancelar(AMotivo, ADataCancelamento);

    // Origem é o Financeiro: não há evento de retorno a enfileirar.
    FUnitOfWork.Executar(
      procedure
      begin
        FVendaRepository.AtualizarSituacao(LVenda);
      end);
  finally
    LVenda.Free;
  end;
end;

end.
