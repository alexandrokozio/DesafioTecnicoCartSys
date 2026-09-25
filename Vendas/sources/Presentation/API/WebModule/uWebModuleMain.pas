unit uWebModuleMain;

interface

uses
  System.SysUtils,
  System.Classes,
  Web.HTTPApp,
  uApiRouter;

type
  TwmApi = class(TWebModule)
    procedure WebModuleCreate(Sender: TObject);
    procedure WebModuleDestroy(Sender: TObject);
    procedure DespacharAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  private
    FRouter: TApiRouter;
  end;

implementation

uses
  uAppConfig,
  uHealthController,
  uVendaController;

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

procedure TwmApi.WebModuleCreate(Sender: TObject);
begin
  FRouter := TApiRouter.Create(TAppConfig.Api.ApiKey);
  THealthController.Registrar(FRouter);
  TVendaController.Registrar(FRouter);
end;

procedure TwmApi.WebModuleDestroy(Sender: TObject);
begin
  FRouter.Free;
end;

procedure TwmApi.DespacharAction(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
var
  LCorpo: string;
  LResposta: TApiResposta;
begin
  LCorpo := TEncoding.UTF8.GetString(Request.RawContent);

  LResposta := FRouter.Despachar(
    Request.Method,
    Request.PathInfo,
    LCorpo,
    Request.GetFieldByName('X-Api-Key'));

  Response.StatusCode := LResposta.StatusCode;
  Response.ContentType := 'application/json; charset=utf-8';
  Response.ContentStream := TBytesStream.Create(TEncoding.UTF8.GetBytes(LResposta.Body));
  Handled := True;
end;

end.
