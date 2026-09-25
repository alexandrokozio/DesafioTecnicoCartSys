unit fBaseMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, fBase, Vcl.Menus,
  uCommons, System.Actions, Vcl.ActnList, Vcl.ComCtrls;

type
  TfrmBaseMain = class(TfrmBase)
    mmuMain: TMainMenu;
    actlstMain: TActionList;
    stbMain: TStatusBar;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmBaseMain: TfrmBaseMain;

implementation

{$R *.dfm}

procedure TfrmBaseMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  inherited;

  if Application.MessageBox(TMessagesAppType.MSG_DESEJA_REALMENTE_SAIR_SISTEMA,
     TMessagesAppType.MSG_SAIR_SISTEMA,
     MB_YESNO+MB_ICONQUESTION+MB_DEFBUTTON2) = ID_NO then
    Action := caNone;
end;

procedure TfrmBaseMain.FormShow(Sender: TObject);
begin
  inherited;

  Self.Caption := Application.Title;
  Self.WindowState := wsMaximized;
end;

end.
