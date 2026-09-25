unit uVendaController;

interface

uses
  uApiRouter;

type
  /// <summary>
  /// Endpoints de venda consumidos pelo ERP Financeiro:
  ///   GET  /api/v1/vendas/{id}               consulta (reconciliação)
  ///   POST /api/v1/vendas/{id}/quitacao      webhook de quitação
  ///   POST /api/v1/vendas/{id}/cancelamento  webhook de cancelamento
  /// Cada requisição monta seus serviços sobre uma conexão própria do pool
  /// (as requisições rodam em threads do Indy).
  /// </summary>
  TVendaController = class
  private
    class function Obter(ARequisicao: TApiRequisicao): TApiResposta; static;
    class function Quitar(ARequisicao: TApiRequisicao): TApiResposta; static;
    class function Cancelar(ARequisicao: TApiRequisicao): TApiResposta; static;
    class function DataOpcional(ARequisicao: TApiRequisicao; const ACampo: string): TDateTime; static;
    class function RespostaSituacao(AVendaId: Integer): TApiResposta; static;
  public
    class procedure Registrar(ARouter: TApiRouter);
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON,
  connection.interfaces,
  uCliente,
  uVenda,
  uClienteService,
  uVendaService,
  uDomainExceptions,
  uVendaJsonMapper,
  uServiceFactory;

class procedure TVendaController.Registrar(ARouter: TApiRouter);
begin
  ARouter.Registrar('GET', '/api/v1/vendas/{id}', Obter);
  ARouter.Registrar('POST', '/api/v1/vendas/{id}/quitacao', Quitar);
  ARouter.Registrar('POST', '/api/v1/vendas/{id}/cancelamento', Cancelar);
end;

class function TVendaController.DataOpcional(ARequisicao: TApiRequisicao; const ACampo: string): TDateTime;
var
  LTexto: string;
begin
  if not ARequisicao.BodyJson.TryGetValue<string>(ACampo, LTexto) or LTexto.Trim.IsEmpty then
    Exit(Now);

  if not TryISO8601ToDate(LTexto, Result, False) then
    raise EApiErro.Create(400, 'DATA_INVALIDA',
      Format('O campo "%s" deve estar no formato ISO 8601 (ex.: 2026-09-25T14:30:00).', [ACampo]));
end;

class function TVendaController.RespostaSituacao(AVendaId: Integer): TApiResposta;
var
  LConexao: IDBConnectionFactory;
  LService: TVendaService;
  LVenda: TVenda;
begin
  LConexao := TServiceFactory.New;
  LService := TServiceFactory.VendaService(LConexao);
  try
    LVenda := LService.BuscarPorId(AVendaId);
    if not Assigned(LVenda) then
      raise ERegistroNaoEncontrado.CreateFmt('Venda %d não encontrada.', [AVendaId]);

    try
      Result := TApiRouter.Json(200,
        TJSONObject.Create
          .AddPair('vendaId', TJSONNumber.Create(LVenda.Id))
          .AddPair('status', StatusVendaToStr(LVenda.Status))
          .AddPair('dataQuitacao', TVendaJsonMapper.DataOuNulo(LVenda.DataQuitacao))
          .AddPair('dataCancelamento', TVendaJsonMapper.DataOuNulo(LVenda.DataCancelamento)));
    finally
      LVenda.Free;
    end;
  finally
    LService.Free;
  end;
end;

class function TVendaController.Obter(ARequisicao: TApiRequisicao): TApiResposta;
var
  LConexao: IDBConnectionFactory;
  LVendaService: TVendaService;
  LClienteService: TClienteService;
  LVenda: TVenda;
  LCliente: TCliente;
begin
  LConexao := TServiceFactory.New;
  LVendaService := TServiceFactory.VendaService(LConexao);
  LClienteService := TServiceFactory.ClienteService(LConexao);
  try
    LVenda := LVendaService.BuscarPorId(ARequisicao.ParametroInteiro('id'));
    if not Assigned(LVenda) then
      raise ERegistroNaoEncontrado.CreateFmt('Venda %s não encontrada.', [ARequisicao.Parametro('id')]);

    try
      LCliente := LClienteService.BuscarPorId(LVenda.ClienteId);
      try
        Result := TApiRouter.Json(200, TVendaJsonMapper.ToJson(LVenda, LCliente));
      finally
        LCliente.Free;
      end;
    finally
      LVenda.Free;
    end;
  finally
    LClienteService.Free;
    LVendaService.Free;
  end;
end;

class function TVendaController.Quitar(ARequisicao: TApiRequisicao): TApiResposta;
var
  LVendaId: Integer;
  LDataQuitacao: TDateTime;
  LService: TVendaService;
begin
  LVendaId := ARequisicao.ParametroInteiro('id');
  LDataQuitacao := DataOpcional(ARequisicao, 'dataQuitacao');

  LService := TServiceFactory.VendaService(TServiceFactory.New);
  try
    // Idempotente: reenvio do webhook devolve 200 com o estado atual.
    LService.RegistrarQuitacao(LVendaId, LDataQuitacao);
  finally
    LService.Free;
  end;

  Result := RespostaSituacao(LVendaId);
end;

class function TVendaController.Cancelar(ARequisicao: TApiRequisicao): TApiResposta;
var
  LVendaId: Integer;
  LMotivo: string;
  LDataCancelamento: TDateTime;
  LService: TVendaService;
begin
  LVendaId := ARequisicao.ParametroInteiro('id');

  if not ARequisicao.BodyJson.TryGetValue<string>('motivo', LMotivo) or LMotivo.Trim.IsEmpty then
    raise EApiErro.Create(400, 'CAMPO_OBRIGATORIO', 'O campo "motivo" é obrigatório.');

  LDataCancelamento := DataOpcional(ARequisicao, 'dataCancelamento');

  LService := TServiceFactory.VendaService(TServiceFactory.New);
  try
    LService.RegistrarCancelamento(LVendaId, LMotivo, LDataCancelamento);
  finally
    LService.Free;
  end;

  Result := RespostaSituacao(LVendaId);
end;

end.
