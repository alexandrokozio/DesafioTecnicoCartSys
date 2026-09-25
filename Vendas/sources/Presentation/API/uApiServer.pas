unit uApiServer;

interface

uses
  System.SysUtils,
  IdHTTPWebBrokerBridge,
  uAppConfig;

type
  TApiServer = class
  private
    FConfig: TApiConfig;
    FServidor: TIdHTTPWebBrokerBridge;
  public
    constructor Create(const AConfig: TApiConfig);
    destructor Destroy; override;

    procedure Iniciar;
    procedure Parar;
    function Ativo: Boolean;
    function Endereco: string;
  end;

implementation

uses
  IdSocketHandle,
  uWebModuleMain,
  uLogger;

constructor TApiServer.Create(const AConfig: TApiConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FServidor := TIdHTTPWebBrokerBridge.Create(nil);
  FServidor.RegisterWebModuleClass(TwmApi);
end;

destructor TApiServer.Destroy;
begin
  Parar;
  FServidor.Free;
  inherited;
end;

procedure TApiServer.Iniciar;
var
  LBinding: TIdSocketHandle;
begin
  if FServidor.Active then
    Exit;

  FServidor.Bindings.Clear;
  LBinding := FServidor.Bindings.Add;
  LBinding.IP := FConfig.Bind;
  LBinding.Port := FConfig.Porta;
  FServidor.DefaultPort := FConfig.Porta;
  FServidor.Active := True;

  if FConfig.ApiKey.IsEmpty then
    TLogger.Aviso('API: [Api] ApiKey não configurada; rotas protegidas responderão 401.');

  TLogger.Info('API: servidor iniciado em %s.', [Endereco]);
end;

procedure TApiServer.Parar;
begin
  if not FServidor.Active then
    Exit;

  FServidor.Active := False;
  FServidor.Bindings.Clear;
  TLogger.Info('API: servidor parado.');
end;

function TApiServer.Ativo: Boolean;
begin
  Result := FServidor.Active;
end;

function TApiServer.Endereco: string;
begin
  Result := Format('http://%s:%d/api/v1', [FConfig.Bind, FConfig.Porta]);
end;

end.
