unit fCadVenda;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, Vcl.DBGrids,
  Data.DB, FireDAC.Comp.Client, System.Generics.Collections,
  uDtmMain,
  fBaseCadastro,
  uVendaService,
  uVenda,
  uItemVenda;

type
  TfrmCadVenda = class(TfrmBaseCadastro)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FService: TVendaService;
    FId: Integer;
    FCarregandoLista: Boolean;
    PnlCampos: TPanel;

    LblClienteId, LblClienteNome, LblStatus, LblMotivoCancelamento: TLabel;
    EdtClienteId, EdtClienteNome, EdtStatus, EdtMotivoCancelamento: TEdit;

    LblProdId, LblProdDesc, LblQtd, LblPreco: TLabel;
    EdtProdId, EdtProdDesc, EdtQtd, EdtPreco: TEdit;
    BtnAddItem, BtnRemItem: TButton;

    GrdItens: TDBGrid;
    DtsItens: TDataSource;
    FMemTableItens: TFDMemTable;

    LblTotalVenda: TLabel;
    EdtTotalVenda: TEdit;
    BtnNovo, BtnSalvar, BtnCancelar, BtnAtualizar: TButton;

    LblGridVendas: TLabel;
    Grd: TDBGrid;
    Dts: TDataSource;
    FMemTable: TFDMemTable;

    procedure CarregarDados(AVendaIdSelecionada: Integer = 0);
    procedure CarregarItens(AVenda: TVenda);
    procedure LimparCamposItem;
    procedure CalcularTotalVenda;
    procedure AtualizarEstadoBotoes;

    procedure AddItemClick(Sender: TObject);
    procedure RemItemClick(Sender: TObject);
    procedure NovoClick(Sender: TObject);
    procedure SalvarClick(Sender: TObject);
    procedure CancelarClick(Sender: TObject);
    procedure AtualizarClick(Sender: TObject);
    procedure GridCellClick(Column: TColumn);
    procedure VendaSelecionadaChange(Sender: TObject; Field: TField);
    procedure ExibirVendaSelecionada;
  public
    { Public declarations }
  end;

var
  frmCadVenda: TfrmCadVenda;

implementation

uses
  uDomainExceptions,
  uVendaResumo,
  uFormHelper;

{$R *.dfm}

{ TfrmCadVenda }

procedure TfrmCadVenda.FormCreate(Sender: TObject);
begin
  inherited;
  Caption := 'Gestão de Vendas';

  PnlCampos := TFormHelper.CriarPainelCampos(Self);

  // Cabeçalho da venda
  EdtClienteId := TFormHelper.CriarEdit(PnlCampos, 'Cód. Cliente:', 12, 8, 80, LblClienteId);
  EdtClienteNome := TFormHelper.CriarEdit(PnlCampos, 'Nome do Cliente:', 102, 8, 290, LblClienteNome);
  EdtClienteNome.ReadOnly := True;
  EdtStatus := TFormHelper.CriarEdit(PnlCampos, 'Status:', 402, 8, 100, LblStatus);
  EdtStatus.ReadOnly := True;
  EdtStatus.Text := StatusVendaToStr(svPendente);
  EdtMotivoCancelamento := TFormHelper.CriarEdit(PnlCampos, 'Motivo do Cancelamento:', 512, 8, 320,
    LblMotivoCancelamento);

  // Inclusão de itens
  EdtProdId := TFormHelper.CriarEdit(PnlCampos, 'Cód. Prod:', 12, 58, 70, LblProdId);
  EdtProdDesc := TFormHelper.CriarEdit(PnlCampos, 'Descrição do Produto:', 92, 58, 250, LblProdDesc);
  EdtQtd := TFormHelper.CriarEdit(PnlCampos, 'Qtd:', 352, 58, 60, LblQtd);
  EdtPreco := TFormHelper.CriarEdit(PnlCampos, 'Preço Un. (R$):', 422, 58, 90, LblPreco);

  BtnAddItem := TFormHelper.CriarBotao(PnlCampos, '+ Incluir Item', 522, 0, 150, AddItemClick);
  TFormHelper.AlinharVerticalmente(BtnAddItem, EdtPreco);
  BtnRemItem := TFormHelper.CriarBotao(PnlCampos, '- Excluir Item', 682, 0, 150, RemItemClick);
  TFormHelper.AlinharVerticalmente(BtnRemItem, EdtPreco);

  GrdItens := TFormHelper.CriarGrid(PnlCampos, 12, 112, 150);

  EdtTotalVenda := TFormHelper.CriarEdit(PnlCampos, 'Total Venda (R$):', 12, 272, 130, LblTotalVenda);
  EdtTotalVenda.ReadOnly := True;
  EdtTotalVenda.Text := FormatCurr('#,##0.00', 0);
  EdtTotalVenda.Font.Style := [fsBold];

  BtnNovo := TFormHelper.CriarBotao(PnlCampos, 'Novo', 512, 0, 100, NovoClick);
  TFormHelper.AlinharVerticalmente(BtnNovo, EdtTotalVenda);
  BtnSalvar := TFormHelper.CriarBotao(PnlCampos, 'Salvar', 617, 0, 100, SalvarClick);
  TFormHelper.AlinharVerticalmente(BtnSalvar, EdtTotalVenda);
  BtnCancelar := TFormHelper.CriarBotao(PnlCampos, 'Cancelar Venda', 722, 0, 110, CancelarClick);
  TFormHelper.AlinharVerticalmente(BtnCancelar, EdtTotalVenda);

  BtnAtualizar := TFormHelper.CriarBotao(PnlCampos, 'Atualizar', 12, 326, 100, AtualizarClick);
  LblGridVendas := TFormHelper.CriarLabel(PnlCampos, 'Vendas Cadastradas:', 122, 0);
  TFormHelper.AlinharVerticalmente(LblGridVendas, BtnAtualizar);

  TFormHelper.AjustarAltura(PnlCampos);

  Grd := TFormHelper.CriarGridPrincipal(Self);
  Grd.OnCellClick := GridCellClick;

  FMemTableItens := TFDMemTable.Create(Self);
  FMemTableItens.FieldDefs.Add('PRODUTO_ID', ftInteger);
  FMemTableItens.FieldDefs.Add('DESCRICAO', ftString, 150);
  FMemTableItens.FieldDefs.Add('QUANTIDADE', ftInteger);
  FMemTableItens.FieldDefs.Add('PRECO_UNITARIO', ftCurrency);
  FMemTableItens.FieldDefs.Add('VALOR_TOTAL', ftCurrency);
  FMemTableItens.CreateDataSet;

  DtsItens := TDataSource.Create(Self);
  DtsItens.DataSet := FMemTableItens;
  GrdItens.DataSource := DtsItens;

  TFormHelper.AdicionarColuna(GrdItens, 'PRODUTO_ID', 'Cód.', 60, taRightJustify);
  TFormHelper.AdicionarColuna(GrdItens, 'DESCRICAO', 'Produto', 460);
  TFormHelper.AdicionarColuna(GrdItens, 'QUANTIDADE', 'Qtd', 60, taRightJustify);
  TFormHelper.AdicionarColuna(GrdItens, 'PRECO_UNITARIO', 'Preço unit.', 110, taRightJustify);
  TFormHelper.AdicionarColuna(GrdItens, 'VALOR_TOTAL', 'Total', 110, taRightJustify);

  FMemTable := TFDMemTable.Create(Self);
  FMemTable.FieldDefs.Add('ID', ftInteger);
  FMemTable.FieldDefs.Add('CLIENTE_ID', ftInteger);
  FMemTable.FieldDefs.Add('CLIENTE_NOME', ftString, 150);
  FMemTable.FieldDefs.Add('DATA_VENDA', ftDateTime);
  FMemTable.FieldDefs.Add('STATUS', ftString, 20);
  FMemTable.FieldDefs.Add('VALOR_TOTAL', ftCurrency);
  FMemTable.FieldDefs.Add('MOTIVO_CANCELAMENTO', ftString, 250);
  FMemTable.CreateDataSet;

  Dts := TDataSource.Create(Self);
  Dts.DataSet := FMemTable;
  Dts.OnDataChange := VendaSelecionadaChange;
  Grd.DataSource := Dts;

  TFormHelper.AdicionarColuna(Grd, 'ID', 'Nº', 60, taRightJustify);
  TFormHelper.AdicionarColuna(Grd, 'CLIENTE_NOME', 'Cliente', 380);
  TFormHelper.AdicionarColuna(Grd, 'DATA_VENDA', 'Data', 130);
  TFormHelper.AdicionarColuna(Grd, 'STATUS', 'Status', 100);
  TFormHelper.AdicionarColuna(Grd, 'VALOR_TOTAL', 'Total', 110, taRightJustify);
  TFormHelper.AdicionarColuna(Grd, 'MOTIVO_CANCELAMENTO', 'Motivo do cancelamento', 320);

  FService := DtmMain.CriarVendaService;

  CarregarDados;
  AtualizarEstadoBotoes;
end;

procedure TfrmCadVenda.FormDestroy(Sender: TObject);
begin
  FService.Free;
  inherited;
end;

procedure TfrmCadVenda.CarregarDados(AVendaIdSelecionada: Integer);
var
  LListaVendas: TObjectList<TVendaResumo>;
  LVenda: TVendaResumo;
begin
  LListaVendas := FService.Listar;
  FCarregandoLista := True;
  try
    FMemTable.DisableControls;
    try
      FMemTable.EmptyDataSet;

      for LVenda in LListaVendas do
      begin
        FMemTable.Append;
        FMemTable.FieldByName('ID').AsInteger := LVenda.Id;
        FMemTable.FieldByName('CLIENTE_ID').AsInteger := LVenda.ClienteId;
        FMemTable.FieldByName('CLIENTE_NOME').AsString := LVenda.ClienteNome;
        FMemTable.FieldByName('DATA_VENDA').AsDateTime := LVenda.DataVenda;
        FMemTable.FieldByName('STATUS').AsString := StatusVendaToStr(LVenda.Status);
        FMemTable.FieldByName('VALOR_TOTAL').AsCurrency := LVenda.ValorTotal;
        FMemTable.FieldByName('MOTIVO_CANCELAMENTO').AsString := LVenda.MotivoCancelamento;
        FMemTable.Post;
      end;

      if (AVendaIdSelecionada <= 0) or not FMemTable.Locate('ID', AVendaIdSelecionada, []) then
        FMemTable.First;
    finally
      FMemTable.EnableControls;
    end;
  finally
    FCarregandoLista := False;
    LListaVendas.Free;
  end;

  ExibirVendaSelecionada;
end;

procedure TfrmCadVenda.CarregarItens(AVenda: TVenda);
var
  LItem: TVendaItem;
begin
  FMemTableItens.DisableControls;
  try
    FMemTableItens.EmptyDataSet;

    for LItem in AVenda.Itens do
    begin
      FMemTableItens.Append;
      FMemTableItens.FieldByName('PRODUTO_ID').AsInteger := LItem.ProdutoId;
      FMemTableItens.FieldByName('DESCRICAO').AsString := LItem.ProdutoDescricao;
      FMemTableItens.FieldByName('QUANTIDADE').AsInteger := LItem.Quantidade;
      FMemTableItens.FieldByName('PRECO_UNITARIO').AsCurrency := LItem.PrecoUnitario;
      FMemTableItens.FieldByName('VALOR_TOTAL').AsCurrency := LItem.ValorTotal;
      FMemTableItens.Post;
    end;
  finally
    FMemTableItens.EnableControls;
  end;

  CalcularTotalVenda;
end;

procedure TfrmCadVenda.LimparCamposItem;
begin
  EdtProdId.Clear;
  EdtProdDesc.Clear;
  EdtQtd.Clear;
  EdtPreco.Clear;
end;

procedure TfrmCadVenda.CalcularTotalVenda;
var
  LTotal: Currency;
begin
  LTotal := 0;
  FMemTableItens.DisableControls;
  try
    FMemTableItens.First;
    while not FMemTableItens.Eof do
    begin
      LTotal := LTotal + FMemTableItens.FieldByName('VALOR_TOTAL').AsCurrency;
      FMemTableItens.Next;
    end;
  finally
    FMemTableItens.EnableControls;
  end;

  EdtTotalVenda.Text := FormatCurr('#,##0.00', LTotal);
end;

procedure TfrmCadVenda.AtualizarEstadoBotoes;
var
  LPendente: Boolean;
begin
  LPendente := SameText(EdtStatus.Text, StatusVendaToStr(svPendente));

  BtnSalvar.Enabled := LPendente;
  BtnAddItem.Enabled := LPendente;
  BtnRemItem.Enabled := LPendente;
  BtnCancelar.Enabled := (FId > 0) and not SameText(EdtStatus.Text, StatusVendaToStr(svCancelada));
end;

procedure TfrmCadVenda.AddItemClick(Sender: TObject);
var
  LProdutoId, LQtd: Integer;
  LPreco: Currency;
begin
  LProdutoId := StrToIntDef(EdtProdId.Text, 0);
  LQtd := StrToIntDef(EdtQtd.Text, 0);
  LPreco := StrToCurrDef(EdtPreco.Text, 0);

  if LProdutoId <= 0 then
  begin
    ShowMessage('Informe um código de produto válido.');
    EdtProdId.SetFocus;
    Exit;
  end;

  if LQtd <= 0 then
  begin
    ShowMessage('A quantidade deve ser maior que zero.');
    EdtQtd.SetFocus;
    Exit;
  end;

  if LPreco <= 0 then
  begin
    ShowMessage('O preço unitário deve ser maior que zero.');
    EdtPreco.SetFocus;
    Exit;
  end;

  FMemTableItens.Append;
  FMemTableItens.FieldByName('PRODUTO_ID').AsInteger := LProdutoId;
  FMemTableItens.FieldByName('DESCRICAO').AsString := EdtProdDesc.Text;
  FMemTableItens.FieldByName('QUANTIDADE').AsInteger := LQtd;
  FMemTableItens.FieldByName('PRECO_UNITARIO').AsCurrency := LPreco;
  FMemTableItens.FieldByName('VALOR_TOTAL').AsCurrency := LQtd * LPreco;
  FMemTableItens.Post;

  CalcularTotalVenda;
  LimparCamposItem;
  EdtProdId.SetFocus;
end;

procedure TfrmCadVenda.RemItemClick(Sender: TObject);
begin
  if FMemTableItens.IsEmpty then
    Exit;

  FMemTableItens.Delete;
  CalcularTotalVenda;
end;

procedure TfrmCadVenda.NovoClick(Sender: TObject);
begin
  FId := 0;
  EdtClienteId.Clear;
  EdtClienteNome.Clear;
  EdtStatus.Text := StatusVendaToStr(svPendente);
  EdtMotivoCancelamento.Clear;

  FMemTableItens.EmptyDataSet;
  CalcularTotalVenda;
  LimparCamposItem;
  AtualizarEstadoBotoes;

  EdtClienteId.SetFocus;
end;

procedure TfrmCadVenda.SalvarClick(Sender: TObject);
var
  LVenda: TVenda;
begin
  LVenda := TVenda.Create;
  try
    try
      LVenda.Id := FId;
      LVenda.ClienteId := StrToIntDef(EdtClienteId.Text, 0);

      FMemTableItens.DisableControls;
      try
        FMemTableItens.First;
        while not FMemTableItens.Eof do
        begin
          LVenda.AdicionarItem(
            FMemTableItens.FieldByName('PRODUTO_ID').AsInteger,
            FMemTableItens.FieldByName('DESCRICAO').AsString,
            FMemTableItens.FieldByName('QUANTIDADE').AsInteger,
            FMemTableItens.FieldByName('PRECO_UNITARIO').AsCurrency);

          FMemTableItens.Next;
        end;
      finally
        FMemTableItens.EnableControls;
      end;

      CarregarDados(FService.Salvar(LVenda));
      DtmMain.SincronizarAgora;
      ShowMessage('Venda salva com sucesso.');
    except
      on E: EDomainException do
        ShowMessage(E.Message);

      on E: Exception do
        ShowMessage('Erro inesperado: ' + E.Message);
    end;
  finally
    LVenda.Free;
  end;
end;

procedure TfrmCadVenda.CancelarClick(Sender: TObject);
begin
  if FId = 0 then
  begin
    ShowMessage('Selecione uma venda para cancelar.');
    Exit;
  end;

  if Trim(EdtMotivoCancelamento.Text) = '' then
  begin
    ShowMessage('Informe o motivo do cancelamento.');
    EdtMotivoCancelamento.SetFocus;
    Exit;
  end;

  try
    FService.CancelarVenda(FId, EdtMotivoCancelamento.Text);
    DtmMain.SincronizarAgora;
    ShowMessage('Venda cancelada com sucesso.');
    CarregarDados(FId);
  except
    on E: EDomainException do
      ShowMessage(E.Message);

    on E: Exception do
      ShowMessage('Erro inesperado: ' + E.Message);
  end;
end;

procedure TfrmCadVenda.AtualizarClick(Sender: TObject);
begin
  CarregarDados(FId);
end;

procedure TfrmCadVenda.VendaSelecionadaChange(Sender: TObject; Field: TField);
begin
  if FCarregandoLista or Assigned(Field) then
    Exit;

  ExibirVendaSelecionada;
end;

procedure TfrmCadVenda.GridCellClick(Column: TColumn);
begin
  if (not FMemTable.IsEmpty) and (FMemTable.FieldByName('ID').AsInteger <> FId) then
    ExibirVendaSelecionada;
end;

procedure TfrmCadVenda.ExibirVendaSelecionada;
var
  LVenda: TVenda;
begin
  if FMemTable.IsEmpty then
    Exit;

  FId := FMemTable.FieldByName('ID').AsInteger;
  EdtClienteId.Text := FMemTable.FieldByName('CLIENTE_ID').AsString;
  EdtClienteNome.Text := FMemTable.FieldByName('CLIENTE_NOME').AsString;
  EdtStatus.Text := FMemTable.FieldByName('STATUS').AsString;
  EdtMotivoCancelamento.Text := FMemTable.FieldByName('MOTIVO_CANCELAMENTO').AsString;

  LVenda := FService.BuscarPorId(FId);
  try
    if Assigned(LVenda) then
      CarregarItens(LVenda);
  finally
    LVenda.Free;
  end;

  AtualizarEstadoBotoes;
end;

end.
