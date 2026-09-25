unit fMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, fBaseMain, Vcl.Menus, System.Actions,
  Vcl.ActnList, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Imaging.pngimage;

type
  TfrmMain = class(TfrmBaseMain)
    actSair: TAction;
    actCadClientes: TAction;
    actCadProdutos: TAction;
    actCadVendas: TAction;
    pnlWorkArea: TPanel;
    pnlBotoes: TPanel;
    btnCadProdutos: TButton;
    btnCadClientes: TButton;
    btnSair: TButton;
    btnCadVendas: TButton;
    procedure actSairExecute(Sender: TObject);
    procedure actCadClientesExecute(Sender: TObject);
    procedure actCadProdutosExecute(Sender: TObject);
    procedure actCadVendasExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FFormActive: TForm;
    FPainelApi: TStatusPanel;
    FPainelIntegracao: TStatusPanel;

    procedure LoadForm(AClass: TFormClass);
    procedure AtualizarStatusIntegracao(Sender: TObject);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  uDtmMain, fCadCliente, fCadProduto, fCadVenda;

{$R *.dfm}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  inherited;

  FPainelApi := stbMain.Panels.Add;
  FPainelApi.Width := 320;
  FPainelIntegracao := stbMain.Panels.Add;
  FPainelIntegracao.Width := 420;

  dtmMain.OnStatusAlterado := AtualizarStatusIntegracao;
  AtualizarStatusIntegracao(nil);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Assigned(dtmMain) then
    dtmMain.OnStatusAlterado := nil;

  inherited;
end;

procedure TfrmMain.AtualizarStatusIntegracao(Sender: TObject);
begin
  FPainelApi.Text := dtmMain.StatusApi;
  FPainelIntegracao.Text := dtmMain.StatusIntegracao;
end;

procedure TfrmMain.LoadForm(AClass: TFormClass);
begin
  if Assigned(Self.FFormActive) then
  begin
    Self.FFormActive.Close;
    Self.FFormActive.Free;
    Self.FFormActive := nil;
  end;

  Self.FFormActive := AClass.Create(nil);
  Self.FFormActive.Parent := Self.pnlWorkArea;
  Self.FFormActive.BorderStyle := TFormBorderStyle.bsNone;
  Self.FFormActive.Top := 0;
  Self.FFormActive.Left := 0;
  Self.FFormActive.Align := TAlign.alClient;
  Self.FFormActive.Show;

  Self.Caption := Format('%s - [%s]', [Application.Title, Self.FFormActive.Caption]);
end;

procedure TfrmMain.actCadClientesExecute(Sender: TObject);
begin
  inherited;
  Self.LoadForm(TfrmCadCliente);
end;

procedure TfrmMain.actCadProdutosExecute(Sender: TObject);
begin
  inherited;
  Self.LoadForm(TfrmCadProduto);
end;

procedure TfrmMain.actCadVendasExecute(Sender: TObject);
begin
  inherited;
  Self.LoadForm(TfrmCadVenda);
end;

procedure TfrmMain.actSairExecute(Sender: TObject);
begin
  inherited;
  Close;
end;

end.
