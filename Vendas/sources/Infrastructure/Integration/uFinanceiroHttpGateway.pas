unit uFinanceiroHttpGateway;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  uAppConfig,
  uCliente,
  uVenda,
  uIntegracaoPortas;

type
  /// <summary>
  /// Cliente REST do ERP Financeiro (THTTPClient/WinHTTP: sem DLLs externas).
  /// Contrato:
  ///   PUT  {BaseUrl}/vendas/{vendaId}              upsert idempotente da venda
  ///   POST {BaseUrl}/vendas/{vendaId}/cancelamento cancelamento originado no Vendas
  /// Autenticação: header X-Api-Key.
  /// </summary>
  TFinanceiroHttpGateway = class(TInterfacedObject, IFinanceiroGateway)
  private
    FConfig: TFinanceiroConfig;

    function CriarCliente: THTTPClient;
    function Url(const ARecurso: string): string;
    procedure Enviar(const AMetodo, ARecurso: string; ACorpo: TJSONObject);
    procedure ValidarResposta(const AMetodo, ARecurso: string; AResposta: IHTTPResponse);
  public
    constructor Create(const AConfig: TFinanceiroConfig);

    procedure EnviarVenda(AVenda: TVenda; ACliente: TCliente);
    procedure CancelarVenda(AVendaId: Integer; const AMotivo: string; ADataCancelamento: TDateTime);
  end;

implementation

uses
  System.Net.URLClient,
  uVendaJsonMapper;

constructor TFinanceiroHttpGateway.Create(const AConfig: TFinanceiroConfig);
begin
  inherited Create;

  if AConfig.BaseUrl.Trim.IsEmpty then
    raise EArgumentException.Create('URL da API do Financeiro não configurada ([Financeiro] BaseUrl).');

  FConfig := AConfig;
end;

function TFinanceiroHttpGateway.CriarCliente: THTTPClient;
begin
  Result := THTTPClient.Create;
  Result.ConnectionTimeout := FConfig.TimeoutMs;
  Result.ResponseTimeout := FConfig.TimeoutMs;
  Result.ContentType := 'application/json; charset=utf-8';
  Result.Accept := 'application/json';
  Result.CustomHeaders['X-Api-Key'] := FConfig.ApiKey;
end;

function TFinanceiroHttpGateway.Url(const ARecurso: string): string;
begin
  Result := FConfig.BaseUrl.TrimRight(['/']) + ARecurso;
end;

procedure TFinanceiroHttpGateway.Enviar(const AMetodo, ARecurso: string; ACorpo: TJSONObject);
var
  LCliente: THTTPClient;
  LConteudo: TStringStream;
  LResposta: IHTTPResponse;
begin
  LCliente := CriarCliente;
  LConteudo := TStringStream.Create(ACorpo.ToJSON, TEncoding.UTF8);
  try
    try
      if AMetodo = 'PUT' then
        LResposta := LCliente.Put(Url(ARecurso), LConteudo)
      else
        LResposta := LCliente.Post(Url(ARecurso), LConteudo);
    except
      on E: ENetException do
        raise EIntegracaoException.Create(
          Format('Falha de comunicação com o Financeiro (%s %s): %s', [AMetodo, ARecurso, E.Message]), False);
    end;

    ValidarResposta(AMetodo, ARecurso, LResposta);
  finally
    LConteudo.Free;
    LCliente.Free;
  end;
end;

procedure TFinanceiroHttpGateway.ValidarResposta(const AMetodo, ARecurso: string; AResposta: IHTTPResponse);
var
  LStatus: Integer;
  LDefinitiva: Boolean;
begin
  LStatus := AResposta.StatusCode;
  if (LStatus >= 200) and (LStatus < 300) then
    Exit;

  LDefinitiva := (LStatus >= 400) and (LStatus < 500)
    and (LStatus <> 408) and (LStatus <> 409) and (LStatus <> 429);

  raise EIntegracaoException.Create(
    Format('Financeiro respondeu HTTP %d em %s %s: %s',
      [LStatus, AMetodo, ARecurso, Copy(AResposta.ContentAsString(TEncoding.UTF8), 1, 500)]),
    LDefinitiva);
end;

procedure TFinanceiroHttpGateway.EnviarVenda(AVenda: TVenda; ACliente: TCliente);
var
  LCorpo: TJSONObject;
begin
  LCorpo := TVendaJsonMapper.ToJson(AVenda, ACliente);
  try
    Enviar('PUT', Format('/vendas/%d', [AVenda.Id]), LCorpo);
  finally
    LCorpo.Free;
  end;
end;

procedure TFinanceiroHttpGateway.CancelarVenda(AVendaId: Integer; const AMotivo: string;
  ADataCancelamento: TDateTime);
var
  LCorpo: TJSONObject;
begin
  LCorpo := TJSONObject.Create;
  try
    LCorpo.AddPair('motivo', AMotivo);
    LCorpo.AddPair('dataCancelamento', TVendaJsonMapper.DataOuNulo(ADataCancelamento));
    Enviar('POST', Format('/vendas/%d/cancelamento', [AVendaId]), LCorpo);
  finally
    LCorpo.Free;
  end;
end;

end.
