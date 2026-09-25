unit uApiRouter;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections;

type
  EApiErro = class(Exception)
  private
    FStatusCode: Integer;
    FCodigo: string;
  public
    constructor Create(AStatusCode: Integer; const ACodigo, AMensagem: string);
    property StatusCode: Integer read FStatusCode;
    property Codigo: string read FCodigo;
  end;

  TApiRequisicao = class
  private
    FMetodo: string;
    FCaminho: string;
    FBody: string;
    FParametros: TDictionary<string, string>;
    FBodyJson: TJSONObject;
  public
    constructor Create(const AMetodo, ACaminho, ABody: string);
    destructor Destroy; override;

    function Parametro(const ANome: string): string;
    function ParametroInteiro(const ANome: string): Integer;
    function BodyJson: TJSONObject;

    property Metodo: string read FMetodo;
    property Caminho: string read FCaminho;
    property Body: string read FBody;
  end;

  TApiResposta = record
    StatusCode: Integer;
    Body: string;
  end;

  TApiHandler = reference to function(ARequisicao: TApiRequisicao): TApiResposta;

  TApiRouter = class
  private type
    TRota = class
      Metodo: string;
      Segmentos: TArray<string>;
      Handler: TApiHandler;
      RequerAutenticacao: Boolean;
    end;
  private
    FRotas: TObjectList<TRota>;
    FApiKey: string;

    class function Segmentar(const ACaminho: string): TArray<string>; static;
    class function Casar(ARota: TRota; const ASegmentos: TArray<string>;
      AParametros: TDictionary<string, string>): Boolean; static;
    class function ChavesIguais(const A, B: string): Boolean; static;
    procedure Autenticar(const AApiKeyRecebida: string);
  public
    constructor Create(const AApiKey: string);
    destructor Destroy; override;

    procedure Registrar(const AMetodo, APadrao: string; const AHandler: TApiHandler;
      ARequerAutenticacao: Boolean = True);

    function Despachar(const AMetodo, ACaminho, ABody, AApiKeyRecebida: string): TApiResposta;

    class function Json(AStatusCode: Integer; AValor: TJSONValue): TApiResposta; static;
    class function Erro(AStatusCode: Integer; const ACodigo, AMensagem: string): TApiResposta; static;
  end;

implementation

uses
  uDomainExceptions,
  uLogger;

{ EApiErro }

constructor EApiErro.Create(AStatusCode: Integer; const ACodigo, AMensagem: string);
begin
  inherited Create(AMensagem);
  FStatusCode := AStatusCode;
  FCodigo := ACodigo;
end;

{ TApiRequisicao }

constructor TApiRequisicao.Create(const AMetodo, ACaminho, ABody: string);
begin
  inherited Create;
  FMetodo := AMetodo.ToUpper;
  FCaminho := ACaminho;
  FBody := ABody;
  FParametros := TDictionary<string, string>.Create;
end;

destructor TApiRequisicao.Destroy;
begin
  FBodyJson.Free;
  FParametros.Free;
  inherited;
end;

function TApiRequisicao.Parametro(const ANome: string): string;
begin
  if not FParametros.TryGetValue(ANome, Result) then
    Result := EmptyStr;
end;

function TApiRequisicao.ParametroInteiro(const ANome: string): Integer;
begin
  if not TryStrToInt(Parametro(ANome), Result) or (Result <= 0) then
  begin
    raise EApiErro.Create(400, 'PARAMETRO_INVALIDO',
      Format('O parâmetro "%s" deve ser um número inteiro positivo.', [ANome]));
  end;
end;

function TApiRequisicao.BodyJson: TJSONObject;
var
  LValor: TJSONValue;
begin
  if not Assigned(FBodyJson) then
  begin
    if FBody.Trim.IsEmpty then
      FBodyJson := TJSONObject.Create
    else
    begin
      LValor := TJSONObject.ParseJSONValue(FBody);
      if not (LValor is TJSONObject) then
      begin
        LValor.Free;
        raise EApiErro.Create(400, 'JSON_INVALIDO', 'O Body da requisição deve ser um objeto JSON válido.');
      end;
      FBodyJson := TJSONObject(LValor);
    end;
  end;

  Result := FBodyJson;
end;

{ TApiRouter }

constructor TApiRouter.Create(const AApiKey: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FRotas := TObjectList<TRota>.Create(True);
end;

destructor TApiRouter.Destroy;
begin
  FRotas.Free;
  inherited;
end;

procedure TApiRouter.Registrar(const AMetodo, APadrao: string; const AHandler: TApiHandler;
  ARequerAutenticacao: Boolean);
var
  LRota: TRota;
begin
  LRota := TRota.Create;
  FRotas.Add(LRota);
  LRota.Metodo := AMetodo.ToUpper;
  LRota.Segmentos := Segmentar(APadrao);
  LRota.Handler := AHandler;
  LRota.RequerAutenticacao := ARequerAutenticacao;
end;

class function TApiRouter.Segmentar(const ACaminho: string): TArray<string>;
begin
  Result := ACaminho.Split(['/'], TStringSplitOptions.ExcludeEmpty);
end;

class function TApiRouter.Casar(ARota: TRota; const ASegmentos: TArray<string>;
  AParametros: TDictionary<string, string>): Boolean;
var
  I: Integer;
  LPadrao: string;
begin
  AParametros.Clear;

  if Length(ARota.Segmentos) <> Length(ASegmentos) then
    Exit(False);

  for I := 0 to High(ASegmentos) do
  begin
    LPadrao := ARota.Segmentos[I];
    if LPadrao.StartsWith('{') and LPadrao.EndsWith('}') then
      AParametros.AddOrSetValue(LPadrao.Substring(1, LPadrao.Length - 2), ASegmentos[I])
    else
    if not SameText(LPadrao, ASegmentos[I]) then
      Exit(False);
  end;

  Result := True;
end;

class function TApiRouter.ChavesIguais(const A, B: string): Boolean;
var
  I, LDiferenca: Integer;
begin
  LDiferenca := Length(A) xor Length(B);
  for I := 1 to Length(A) do
  begin
    if I <= Length(B) then
      LDiferenca := LDiferenca or (Ord(A[I]) xor Ord(B[I]))
    else
      LDiferenca := LDiferenca or Ord(A[I]);
  end;

  Result := LDiferenca = 0;
end;

procedure TApiRouter.Autenticar(const AApiKeyRecebida: string);
begin
  if FApiKey.IsEmpty then
    raise EApiErro.Create(401, 'NAO_AUTORIZADO', 'API key não configurada no servidor ([Api] ApiKey).');

  if not ChavesIguais(FApiKey, AApiKeyRecebida) then
    raise EApiErro.Create(401, 'NAO_AUTORIZADO', 'API key ausente ou inválida (header X-Api-Key).');
end;

function TApiRouter.Despachar(const AMetodo, ACaminho, ABody, AApiKeyRecebida: string): TApiResposta;
var
  LRequisicao: TApiRequisicao;
  LSegmentos: TArray<string>;
  LRota, LEncontrada: TRota;
  LCaminhoExiste: Boolean;
begin
  LRequisicao := TApiRequisicao.Create(AMetodo, ACaminho, ABody);
  try
    try
      LSegmentos := Segmentar(ACaminho);
      LEncontrada := nil;
      LCaminhoExiste := False;

      for LRota in FRotas do
        if Casar(LRota, LSegmentos, LRequisicao.FParametros) then
        begin
          LCaminhoExiste := True;
          if LRota.Metodo = LRequisicao.Metodo then
          begin
            LEncontrada := LRota;
            Break;
          end;
        end;

      if not Assigned(LEncontrada) then
      begin
        if LCaminhoExiste then
          raise EApiErro.Create(405, 'METODO_NAO_PERMITIDO',
            Format('Método %s não permitido para %s.', [LRequisicao.Metodo, ACaminho]));

        raise EApiErro.Create(404, 'ROTA_NAO_ENCONTRADA', Format('Rota %s não encontrada.', [ACaminho]));
      end;

      Casar(LEncontrada, LSegmentos, LRequisicao.FParametros);

      if LEncontrada.RequerAutenticacao then
        Autenticar(AApiKeyRecebida);

      Result := LEncontrada.Handler(LRequisicao);
    except
      on E: EApiErro do
        Result := Erro(E.StatusCode, E.Codigo, E.Message);

      on E: ERegistroNaoEncontrado do
        Result := Erro(404, 'NAO_ENCONTRADO', E.Message);

      on E: EDomainException do
        Result := Erro(422, 'REGRA_DE_NEGOCIO', E.Message);

      on E: Exception do
      begin
        TLogger.Erro(Format('API: erro não tratado em %s %s', [AMetodo, ACaminho]), E);
        Result := Erro(500, 'ERRO_INTERNO', 'Erro interno ao processar a requisição.');
      end;
    end;
  finally
    LRequisicao.Free;
  end;
end;

class function TApiRouter.Json(AStatusCode: Integer; AValor: TJSONValue): TApiResposta;
begin
  try
    Result.StatusCode := AStatusCode;
    Result.Body := AValor.ToJSON;
  finally
    AValor.Free;
  end;
end;

class function TApiRouter.Erro(AStatusCode: Integer; const ACodigo, AMensagem: string): TApiResposta;
begin
  Result := Json(AStatusCode,
    TJSONObject.Create
      .AddPair('codigo', ACodigo)
      .AddPair('mensagem', AMensagem));
end;

end.
