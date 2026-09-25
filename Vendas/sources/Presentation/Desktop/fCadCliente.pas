unit fCadCliente;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, Vcl.DBGrids, System.UITypes,
  Data.DB, FireDAC.Comp.Client, System.Generics.Collections,
  uDtmMain,
  uClienteService,
  uCliente;

type
  TfrmCadCliente = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FService: TClienteService;
    FId: Integer;
    PnlCampos: TPanel;
    LblNome, LblCpfCnpj, LblEmail, LblTelefone: TLabel;
    EdtNome, EdtCpfCnpj, EdtEmail, EdtTelefone: TEdit;
    ChbAtivo: TCheckBox;
    BtnNovo, BtnSalvar, BtnExcluir: TButton;
    Grd: TDBGrid;
    Dts: TDataSource;
    FMemTable: TFDMemTable;

    procedure CarregarDados;
    procedure NovoClick(Sender: TObject);
    procedure SalvarClick(Sender: TObject);
    procedure ExcluirClick(Sender: TObject);
    procedure GridCellClick(Column: TColumn);
  public
    { Public declarations }
  end;

var
  frmCadCliente: TfrmCadCliente;

implementation

uses
  uDomainExceptions,
  uFormHelper;

{$R *.dfm}

{ TfrmCadCliente }

procedure TfrmCadCliente.FormCreate(Sender: TObject);
begin
  Caption := 'Cadastro de Clientes';

  // Medidas de projeto (96 DPI); TFormHelper converte para a escala atual.
  PnlCampos := TFormHelper.CriarPainelCampos(Self);

  EdtNome := TFormHelper.CriarEdit(PnlCampos, 'Nome:', 12, 8, 300, LblNome);
  EdtCpfCnpj := TFormHelper.CriarEdit(PnlCampos, 'CPF/CNPJ:', 322, 8, 180, LblCpfCnpj);
  EdtEmail := TFormHelper.CriarEdit(PnlCampos, 'E-mail:', 512, 8, 300, LblEmail);

  EdtTelefone := TFormHelper.CriarEdit(PnlCampos, 'Telefone:', 12, 58, 180, LblTelefone);
  ChbAtivo := TFormHelper.CriarCheckBox(PnlCampos, 'Ativo', 202, 100, EdtTelefone);
  ChbAtivo.Checked := True;

  BtnNovo := TFormHelper.CriarBotao(PnlCampos, 'Novo', 12, 112, 80, NovoClick);
  BtnSalvar := TFormHelper.CriarBotao(PnlCampos, 'Salvar', 97, 112, 80, SalvarClick);
  BtnExcluir := TFormHelper.CriarBotao(PnlCampos, 'Excluir', 182, 112, 80, ExcluirClick);

  TFormHelper.AjustarAltura(PnlCampos);

  Grd := TFormHelper.CriarGridPrincipal(Self);
  Grd.OnCellClick := GridCellClick;

  FMemTable := TFDMemTable.Create(Self);
  FMemTable.FieldDefs.Add('ID', ftInteger);
  FMemTable.FieldDefs.Add('NOME', ftString, 150);
  FMemTable.FieldDefs.Add('CPFCNPJ', ftString, 18);
  FMemTable.FieldDefs.Add('EMAIL', ftString, 150);
  FMemTable.FieldDefs.Add('TELEFONE', ftString, 20);
  FMemTable.FieldDefs.Add('ATIVO', ftBoolean);
  FMemTable.CreateDataSet;

  Dts := TDataSource.Create(Self);
  Dts.DataSet := FMemTable;
  Grd.DataSource := Dts;

  (FMemTable.FieldByName('ATIVO') as TBooleanField).DisplayValues := 'Sim;Não';
  TFormHelper.AdicionarColuna(Grd, 'ID', 'Código', 60, taRightJustify);
  TFormHelper.AdicionarColuna(Grd, 'NOME', 'Nome', 420);
  TFormHelper.AdicionarColuna(Grd, 'CPFCNPJ', 'CPF/CNPJ', 150);
  TFormHelper.AdicionarColuna(Grd, 'EMAIL', 'E-mail', 280);
  TFormHelper.AdicionarColuna(Grd, 'TELEFONE', 'Telefone', 130);
  TFormHelper.AdicionarColuna(Grd, 'ATIVO', 'Ativo', 60, taCenter);

  FService := DtmMain.CriarClienteService;

  CarregarDados;
end;

procedure TfrmCadCliente.FormDestroy(Sender: TObject);
begin
  if Assigned(FService) then
    FService.Free;
end;

procedure TfrmCadCliente.CarregarDados;
var
  LListaClientes: TObjectList<TCliente>;
  LCliente: TCliente;
begin
  LListaClientes := FService.Listar;
  try
    FMemTable.DisableControls;
    FMemTable.EmptyDataSet;

    for LCliente in LListaClientes do
    begin
      FMemTable.Append;
      FMemTable.FieldByName('ID').AsInteger := LCliente.Id;
      FMemTable.FieldByName('NOME').AsString := LCliente.Nome;
      FMemTable.FieldByName('CPFCNPJ').AsString := LCliente.CpfCnpj;
      FMemTable.FieldByName('EMAIL').AsString := LCliente.Email;
      FMemTable.FieldByName('TELEFONE').AsString := LCliente.Telefone;
      FMemTable.FieldByName('ATIVO').AsBoolean := LCliente.Ativo;
      FMemTable.Post;
    end;
  finally
    LListaClientes.Free;
    FMemTable.EnableControls;
  end;
end;

procedure TfrmCadCliente.ExcluirClick(Sender: TObject);
begin
  if FId = 0 then
    Exit;

  if MessageDlg('Tem certeza que deseja excluir o registro selecionado?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    try
      FService.Excluir(FId);
      NovoClick(nil);
      CarregarDados;
    except
      on E: Exception do
        ShowMessage(E.Message);
    end;
  end;
end;

procedure TfrmCadCliente.GridCellClick(Column: TColumn);
begin
  if FMemTable.IsEmpty then
    Exit;

  FId := FMemTable.FieldByName('ID').AsInteger;
  EdtNome.Text := FMemTable.FieldByName('NOME').AsString;
  EdtCpfCnpj.Text := FMemTable.FieldByName('CPFCNPJ').AsString;
  EdtEmail.Text := FMemTable.FieldByName('EMAIL').AsString;
  EdtTelefone.Text := FMemTable.FieldByName('TELEFONE').AsString;
  ChbAtivo.Checked := FMemTable.FieldByName('ATIVO').AsBoolean;
end;

procedure TfrmCadCliente.NovoClick(Sender: TObject);
begin
  FId := 0;
  EdtNome.Clear;
  EdtCpfCnpj.Clear;
  EdtEmail.Clear;
  EdtTelefone.Clear;
  ChbAtivo.Checked := True;
  EdtNome.SetFocus;
end;

procedure TfrmCadCliente.SalvarClick(Sender: TObject);
var
  LCliente: TCliente;
begin
  LCliente := TCliente.Create;
  try
    try
      LCliente.Id := FId;
      LCliente.Nome := EdtNome.Text;
      LCliente.CpfCnpj := EdtCpfCnpj.Text;
      LCliente.Email := EdtEmail.Text;
      LCliente.Telefone := EdtTelefone.Text;
      LCliente.Ativo := ChbAtivo.Checked;

      FService.Salvar(LCliente);

      CarregarDados;
      ShowMessage('Cliente salvo com sucesso.');
      NovoClick(nil);
    except
      on E: EDomainException do
        ShowMessage(E.Message);

      on E: Exception do
        ShowMessage('Erro inesperado: ' + E.Message);
    end;
  finally
    LCliente.Free;
  end;
end;

end.
