unit uHealthController;

interface

uses
  uApiRouter;

type
  /// <summary>GET /api/v1/health: verificação de disponibilidade (sem
  /// autenticação). Confirma também o acesso ao banco de dados.</summary>
  THealthController = class
  private
    class function Health(ARequisicao: TApiRequisicao): TApiResposta; static;
  public
    class procedure Registrar(ARouter: TApiRouter);
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.DateUtils,
  System.JSON,
  uServiceFactory;

class procedure THealthController.Registrar(ARouter: TApiRouter);
begin
  ARouter.Registrar('GET', '/api/v1/health', Health, False);
end;

class function THealthController.Health(ARequisicao: TApiRequisicao): TApiResposta;
var
  LBanco: string;
  LStatus: Integer;
begin
  try
    TServiceFactory.New.Query.Open('SELECT 1 FROM RDB$DATABASE');
    LBanco := 'ok';
    LStatus := 200;
  except
    // Health check não propaga o erro: informa o estado degradado (503).
    LBanco := 'indisponivel';
    LStatus := 503;
  end;

  Result := TApiRouter.Json(LStatus,
    TJSONObject.Create
      .AddPair('servico', 'erp-vendas')
      .AddPair('status', IfThen(LStatus = 200, 'ok', 'degradado'))
      .AddPair('banco', LBanco)
      .AddPair('dataHora', DateToISO8601(Now, False)));
end;

end.
