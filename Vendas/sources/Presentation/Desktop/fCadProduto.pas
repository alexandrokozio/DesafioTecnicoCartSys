unit fCadProduto;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, Vcl.DBGrids, System.UITypes,
  Data.DB, FireDAC.Comp.Client, System.Generics.Collections,
  uDtmMain,
  fBaseCadastro,
  uProdutoService,
  uProduto;

type
  TfrmCadProduto = class(TfrmBaseCadastro)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FService: TProdutoService;
    FId: Integer;
    PnlCampos: TPanel;
    LblCodigo, LblDescricao, LblPreco, LblEstoque: TLabel;
    EdtCodigo, EdtDescricao, EdtPreco, EdtEstoque: TEdit;
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
  frmCadProduto: TfrmCadProduto;

implementation

uses
  uDomainExceptions,
  uFormHelper;

{$R *.dfm}

procedure TfrmCadProduto.FormCreate(Sender: TObject);
begin
  inherited;
  Caption := 'Cadastro de Produtos';

  // Medidas de projeto (96 DPI); TFormHelper converte para a escala atual.
  PnlCampos := TFormHelper.CriarPainelCampos(Self);

  EdtCodigo := TFormHelper.CriarEdit(PnlCampos, 'SKU:', 12, 8, 120, LblCodigo);
  EdtDescricao := TFormHelper.CriarEdit(PnlCampos, 'Descrição:', 142, 8, 350, LblDescricao);

  EdtPreco := TFormHelper.CriarEdit(PnlCampos, 'Preço (R$):', 12, 58, 120, LblPreco);
  EdtEstoque := TFormHelper.CriarEdit(PnlCampos, 'Estoque Atual:', 142, 58, 120, LblEstoque);
  ChbAtivo := TFormHelper.CriarCheckBox(PnlCampos, 'Ativo', 272, 100, EdtEstoque);
  ChbAtivo.Checked := True;

  BtnNovo := TFormHelper.CriarBotao(PnlCampos, 'Novo', 12, 112, 80, NovoClick);
  BtnSalvar := TFormHelper.CriarBotao(PnlCampos, 'Salvar', 97, 112, 80, SalvarClick);
  BtnExcluir := TFormHelper.CriarBotao(PnlCampos, 'Excluir', 182, 112, 80, ExcluirClick);

  TFormHelper.AjustarAltura(PnlCampos);

  Grd := TFormHelper.CriarGridPrincipal(Self);
  Grd.OnCellClick := GridCellClick;

  FMemTable := TFDMemTable.Create(Self);
  FMemTable.FieldDefs.Add('ID', ftInteger);
  FMemTable.FieldDefs.Add('SKU', ftString, 30);
  FMemTable.FieldDefs.Add('DESCRICAO', ftString, 150);
  FMemTable.FieldDefs.Add('PRECO', ftCurrency);
  FMemTable.FieldDefs.Add('ESTOQUE_ATUAL', ftInteger);
  FMemTable.FieldDefs.Add('ATIVO', ftBoolean);
  FMemTable.CreateDataSet;

  Dts := TDataSource.Create(Self);
  Dts.DataSet := FMemTable;
  Grd.DataSource := Dts;

  (FMemTable.FieldByName('ATIVO') as TBooleanField).DisplayValues := 'Sim;Não';
  TFormHelper.AdicionarColuna(Grd, 'ID', 'Código', 60, taRightJustify);
  TFormHelper.AdicionarColuna(Grd, 'SKU', 'SKU', 170);
  TFormHelper.AdicionarColuna(Grd, 'DESCRICAO', 'Descrição', 520);
  TFormHelper.AdicionarColuna(Grd, 'PRECO', 'Preço', 110, taRightJustify);
  TFormHelper.AdicionarColuna(Grd, 'ESTOQUE_ATUAL', 'Estoque', 80, taRightJustify);
  TFormHelper.AdicionarColuna(Grd, 'ATIVO', 'Ativo', 60, taCenter);

  FService := DtmMain.CriarProdutoService;

  CarregarDados;
end;

procedure TfrmCadProduto.FormDestroy(Sender: TObject);
begin
  if Assigned(FService) then
    FService.Free;

  inherited;
end;

procedure TfrmCadProduto.GridCellClick(Column: TColumn);
begin
  if FMemTable.IsEmpty then
    Exit;

  FId := FMemTable.FieldByName('ID').AsInteger;
  EdtCodigo.Text := FMemTable.FieldByName('SKU').AsString;
  EdtDescricao.Text := FMemTable.FieldByName('DESCRICAO').AsString;
  EdtPreco.Text := CurrToStr(FMemTable.FieldByName('PRECO').AsCurrency);
  EdtEstoque.Text := FMemTable.FieldByName('ESTOQUE_ATUAL').AsString;
  ChbAtivo.Checked := FMemTable.FieldByName('ATIVO').AsBoolean;
end;

procedure TfrmCadProduto.NovoClick(Sender: TObject);
begin
  FId := 0;
  EdtCodigo.Clear;
  EdtDescricao.Clear;
  EdtPreco.Clear;
  EdtEstoque.Clear;
  ChbAtivo.Checked := True;
  EdtCodigo.SetFocus;
end;

procedure TfrmCadProduto.SalvarClick(Sender: TObject);
var
  LProduto: TProduto;
begin
  LProduto := TProduto.Create;
  try
    try
      LProduto.Id := FId;
      LProduto.Sku := EdtCodigo.Text;
      LProduto.Descricao := EdtDescricao.Text;
      LProduto.Preco := StrToCurrDef(EdtPreco.Text, 0);
      LProduto.EstoqueAtual := StrToIntDef(EdtEstoque.Text, 0);
      LProduto.Ativo := ChbAtivo.Checked;

      FService.Salvar(LProduto);

      CarregarDados;
      ShowMessage('Produto salvo com sucesso.');
      NovoClick(nil);
    except
      on E: EDomainException do
        ShowMessage(E.Message);

      on E: Exception do
        ShowMessage('Erro inesperado: ' + E.Message);
    end;
  finally
    LProduto.Free;
  end;
end;

procedure TfrmCadProduto.CarregarDados;
var
  LListaProdutos: TObjectList<TProduto>;
  LProduto: TProduto;
begin
  LListaProdutos := FService.Listar;
  try
    FMemTable.DisableControls;
    FMemTable.EmptyDataSet;

    for LProduto in LListaProdutos do
    begin
      FMemTable.Append;
      FMemTable.FieldByName('ID').AsInteger := LProduto.Id;
      FMemTable.FieldByName('SKU').AsString := LProduto.Sku;
      FMemTable.FieldByName('DESCRICAO').AsString := LProduto.Descricao;
      FMemTable.FieldByName('PRECO').AsCurrency := LProduto.Preco;
      FMemTable.FieldByName('ESTOQUE_ATUAL').AsInteger := LProduto.EstoqueAtual;
      FMemTable.FieldByName('ATIVO').AsBoolean := LProduto.Ativo;
      FMemTable.Post;
    end;
  finally
    LListaProdutos.Free;
    FMemTable.EnableControls;
  end;
end;

procedure TfrmCadProduto.ExcluirClick(Sender: TObject);
begin
  if FId = 0 then
    Exit;

  if MessageDlg('Tem certeza que deseja excluir o produto selecionado?',
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

end.
