unit uApiRouterTest;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.JSON,
  uApiRouter;

type
  [TestFixture]
  TApiRouterTest = class
  private
    FRouter: TApiRouter;
    FUltimoId: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_RotaComParametro_DeveExtrairValor;
    [Test]
    procedure Test_RotaInexistente_DeveRetornar404;
    [Test]
    procedure Test_MetodoErrado_DeveRetornar405;
    [Test]
    procedure Test_SemApiKey_DeveRetornar401;
    [Test]
    procedure Test_RotaPublica_NaoExigeApiKey;
    [Test]
    procedure Test_JsonInvalido_DeveRetornar400;
    [Test]
    procedure Test_ExcecaoDeDominio_DeveRetornar422;
    [Test]
    procedure Test_ExcecaoInesperada_DeveRetornar500SemDetalhes;
  end;

implementation

uses
  uDomainExceptions;

const
  CHAVE = 'chave-de-teste';

procedure TApiRouterTest.Setup;
begin
  FRouter := TApiRouter.Create(CHAVE);

  FRouter.Registrar('POST', '/api/v1/vendas/{id}/quitacao',
    function(ARequisicao: TApiRequisicao): TApiResposta
    begin
      FUltimoId := ARequisicao.Parametro('id');
      ARequisicao.BodyJson; // força a validação do JSON
      Result := TApiRouter.Json(200, TJSONObject.Create);
    end);

  FRouter.Registrar('GET', '/api/v1/health',
    function(ARequisicao: TApiRequisicao): TApiResposta
    begin
      Result := TApiRouter.Json(200, TJSONObject.Create);
    end, False);

  FRouter.Registrar('GET', '/api/v1/dominio',
    function(ARequisicao: TApiRequisicao): TApiResposta
    begin
      raise EVendaInvalida.Create('Regra violada');
    end);

  FRouter.Registrar('GET', '/api/v1/bug',
    function(ARequisicao: TApiRequisicao): TApiResposta
    begin
      raise EAccessViolation.Create('detalhe interno');
    end);
end;

procedure TApiRouterTest.TearDown;
begin
  FRouter.Free;
end;

procedure TApiRouterTest.Test_RotaComParametro_DeveExtrairValor;
var
  LResposta: TApiResposta;
begin
  LResposta := FRouter.Despachar('POST', '/api/v1/vendas/42/quitacao', '{}', CHAVE);

  Assert.AreEqual(200, LResposta.StatusCode);
  Assert.AreEqual('42', FUltimoId);
end;

procedure TApiRouterTest.Test_RotaInexistente_DeveRetornar404;
begin
  Assert.AreEqual(404, FRouter.Despachar('GET', '/api/v1/nada', '', CHAVE).StatusCode);
end;

procedure TApiRouterTest.Test_MetodoErrado_DeveRetornar405;
begin
  Assert.AreEqual(405, FRouter.Despachar('DELETE', '/api/v1/vendas/1/quitacao', '', CHAVE).StatusCode);
end;

procedure TApiRouterTest.Test_SemApiKey_DeveRetornar401;
begin
  Assert.AreEqual(401, FRouter.Despachar('POST', '/api/v1/vendas/1/quitacao', '{}', '').StatusCode);
  Assert.AreEqual(401, FRouter.Despachar('POST', '/api/v1/vendas/1/quitacao', '{}', 'errada').StatusCode);
end;

procedure TApiRouterTest.Test_RotaPublica_NaoExigeApiKey;
begin
  Assert.AreEqual(200, FRouter.Despachar('GET', '/api/v1/health', '', '').StatusCode);
end;

procedure TApiRouterTest.Test_JsonInvalido_DeveRetornar400;
begin
  Assert.AreEqual(400, FRouter.Despachar('POST', '/api/v1/vendas/1/quitacao', '{invalido', CHAVE).StatusCode);
end;

procedure TApiRouterTest.Test_ExcecaoDeDominio_DeveRetornar422;
var
  LResposta: TApiResposta;
begin
  LResposta := FRouter.Despachar('GET', '/api/v1/dominio', '', CHAVE);

  Assert.AreEqual(422, LResposta.StatusCode);
  Assert.Contains(LResposta.Body, 'Regra violada');
end;

procedure TApiRouterTest.Test_ExcecaoInesperada_DeveRetornar500SemDetalhes;
var
  LResposta: TApiResposta;
begin
  LResposta := FRouter.Despachar('GET', '/api/v1/bug', '', CHAVE);

  Assert.AreEqual(500, LResposta.StatusCode);
  Assert.DoesNotContain(LResposta.Body, 'detalhe interno');
end;

initialization
  TDUnitX.RegisterTestFixture(TApiRouterTest);

end.
