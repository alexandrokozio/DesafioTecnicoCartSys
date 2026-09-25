unit uFormHelper;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.DBGrids;

type
  /// <summary>
  /// Criação e posicionamento de controles em tempo de execução, cientes de DPI.
  ///
  /// Todas as medidas recebidas são "de projeto" (96 DPI, escala 100%) e são
  /// convertidas pela escala atual do form (TControl.ScaleValue). Controles
  /// criados em código não passam pelo escalonamento automático do DFM: sem
  /// essa conversão, a fonte cresce com a escala do Windows mas as posições
  /// não, e rótulos acabam sobrepostos aos campos.
  ///
  /// O campo de edição é posicionado a partir da altura REAL do rótulo, nunca
  /// por uma coordenada fixa.
  /// </summary>
  TFormHelper = class
  private const
    ESPACO_ROTULO_CAMPO = 3;
    MARGEM_PAINEL = 8;
  public
    /// <summary>Converte uma medida de projeto (96 DPI) para a escala do form.</summary>
    class function Escalar(AReferencia: TControl; AValor: Integer): Integer;

    /// <summary>Painel alinhado ao topo que agrupa os campos do formulário.
    /// A altura final é definida por AjustarAltura após criar os controles.</summary>
    class function CriarPainelCampos(AParent: TWinControl): TPanel;
    class procedure AjustarAltura(APainel: TPanel);

    class function CriarLabel(AParent: TWinControl; const ACaption: string;
      ALeft, ATop: Integer): TLabel;

    /// <summary>Cria o rótulo em (ALeft, ATop) e o campo imediatamente abaixo dele.</summary>
    class function CriarEdit(AParent: TWinControl; const ARotulo: string;
      ALeft, ATop, AWidth: Integer; out ALabel: TLabel): TEdit;

    class function CriarBotao(AParent: TWinControl; const ACaption: string;
      ALeft, ATop, AWidth: Integer; AOnClick: TNotifyEvent): TButton;

    class function CriarCheckBox(AParent: TWinControl; const ACaption: string;
      ALeft, AWidth: Integer; AAlinharCom: TControl): TCheckBox;

    /// <summary>Centraliza AControl verticalmente em relação a AReferencia
    /// (ex.: botão na mesma linha de um campo de edição).</summary>
    class procedure AlinharVerticalmente(AControl, AReferencia: TControl);

    /// <summary>
    /// Define explicitamente uma coluna do grid (título e largura de projeto).
    /// Sem colunas explícitas o TDBGrid dimensiona pelo tamanho declarado do
    /// campo (ex.: VARCHAR(150)), empurrando as demais colunas para fora da tela.
    /// Campos sem coluna definida não são exibidos.
    /// </summary>
    class function AdicionarColuna(AGrid: TDBGrid; const ACampo, ATitulo: string;
      ALargura: Integer; AAlinhamento: TAlignment = taLeftJustify): TColumn;

    /// <summary>Grid que ocupa todo o espaço restante do form (Align = alClient).</summary>
    class function CriarGridPrincipal(AParent: TWinControl): TDBGrid;

    /// <summary>Grid de altura fixa que ocupa a largura do parent (margens
    /// iguais à esquerda e à direita) e a acompanha ao redimensionar.</summary>
    class function CriarGrid(AParent: TWinControl; ALeft, ATop, AHeight: Integer): TDBGrid;
  end;

implementation

uses
  System.Math,
  Vcl.Forms;

const
  BOTAO_ALTURA = 30;

class function TFormHelper.Escalar(AReferencia: TControl; AValor: Integer): Integer;
var
  LForm: TCustomForm;
begin
  if AReferencia is TCustomForm then
    LForm := TCustomForm(AReferencia)
  else
    LForm := GetParentForm(AReferencia, False);

  if Assigned(LForm) then
    Result := LForm.ScaleValue(AValor)
  else
    Result := AValor;
end;

class function TFormHelper.CriarPainelCampos(AParent: TWinControl): TPanel;
begin
  Result := TPanel.Create(AParent);
  Result.Parent := AParent;
  Result.Align := alTop;
  Result.BevelOuter := bvNone;
  Result.ShowCaption := False;
  Result.ParentBackground := True;
end;

class procedure TFormHelper.AjustarAltura(APainel: TPanel);
var
  I, LFundo: Integer;
begin
  LFundo := 0;
  for I := 0 to APainel.ControlCount - 1 do
    LFundo := Max(LFundo, APainel.Controls[I].Top + APainel.Controls[I].Height);

  APainel.Height := LFundo + Escalar(APainel, MARGEM_PAINEL);
end;

class function TFormHelper.CriarLabel(AParent: TWinControl; const ACaption: string;
  ALeft, ATop: Integer): TLabel;
begin
  Result := TLabel.Create(AParent);
  Result.Parent := AParent;
  Result.AutoSize := True;
  Result.Caption := ACaption;
  Result.Left := Escalar(AParent, ALeft);
  Result.Top := Escalar(AParent, ATop);
end;

class function TFormHelper.CriarEdit(AParent: TWinControl; const ARotulo: string;
  ALeft, ATop, AWidth: Integer; out ALabel: TLabel): TEdit;
begin
  ALabel := CriarLabel(AParent, ARotulo, ALeft, ATop);

  Result := TEdit.Create(AParent);
  Result.Parent := AParent;
  Result.Left := ALabel.Left;
  // Abaixo da altura efetiva do rótulo (já com a fonte na escala atual).
  Result.Top := ALabel.Top + ALabel.Height + Escalar(AParent, ESPACO_ROTULO_CAMPO);
  Result.Width := Escalar(AParent, AWidth);

  ALabel.FocusControl := Result;
end;

class function TFormHelper.CriarBotao(AParent: TWinControl; const ACaption: string;
  ALeft, ATop, AWidth: Integer; AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(AParent);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.SetBounds(Escalar(AParent, ALeft), Escalar(AParent, ATop),
    Escalar(AParent, AWidth), Escalar(AParent, BOTAO_ALTURA));
  Result.OnClick := AOnClick;
end;

class function TFormHelper.CriarCheckBox(AParent: TWinControl; const ACaption: string;
  ALeft, AWidth: Integer; AAlinharCom: TControl): TCheckBox;
begin
  Result := TCheckBox.Create(AParent);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.Left := Escalar(AParent, ALeft);
  Result.Width := Escalar(AParent, AWidth);
  AlinharVerticalmente(Result, AAlinharCom);
end;

class procedure TFormHelper.AlinharVerticalmente(AControl, AReferencia: TControl);
begin
  AControl.Top := AReferencia.Top + (AReferencia.Height - AControl.Height) div 2;
end;

class function TFormHelper.AdicionarColuna(AGrid: TDBGrid; const ACampo, ATitulo: string;
  ALargura: Integer; AAlinhamento: TAlignment): TColumn;
begin
  Result := AGrid.Columns.Add;
  Result.FieldName := ACampo;
  Result.Title.Caption := ATitulo;
  Result.Title.Alignment := AAlinhamento;
  Result.Alignment := AAlinhamento;
  Result.Width := Escalar(AGrid, ALargura);
end;

class function TFormHelper.CriarGridPrincipal(AParent: TWinControl): TDBGrid;
var
  LMargem: Integer;
begin
  LMargem := Escalar(AParent, 12);

  Result := TDBGrid.Create(AParent);
  Result.Parent := AParent;
  Result.Align := alClient;
  Result.AlignWithMargins := True;
  Result.Margins.SetBounds(LMargem, 0, LMargem, LMargem);
end;

class function TFormHelper.CriarGrid(AParent: TWinControl; ALeft, ATop, AHeight: Integer): TDBGrid;
var
  LLeft: Integer;
begin
  LLeft := Escalar(AParent, ALeft);

  Result := TDBGrid.Create(AParent);
  Result.Parent := AParent;
  Result.SetBounds(LLeft, Escalar(AParent, ATop),
    Max(AParent.ClientWidth - 2 * LLeft, Escalar(AParent, 200)), Escalar(AParent, AHeight));
  Result.Anchors := [akLeft, akTop, akRight];
end;

end.
