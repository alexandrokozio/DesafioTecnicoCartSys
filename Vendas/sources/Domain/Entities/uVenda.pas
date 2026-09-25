unit uVenda;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  uEntityBase,
  uItemVenda;

type
  TStatusVenda = (svPendente, svQuitada, svCancelada);

  TVenda = class(TEntityBase)
  private
    FClienteId: Integer;
    FDataVenda: TDateTime;
    FStatus: TStatusVenda;
    FDataQuitacao: TDateTime;
    FDataCancelamento: TDateTime;
    FMotivoCancelamento: string;
    FRelatorioEnviado: Boolean;
    FItens: TObjectList<TVendaItem>;
  public
    constructor Create;
    destructor Destroy; override;

    function AdicionarItem(AProdutoId: Integer; const AProdutoDescricao: string;
      AQuantidade: Integer; APrecoUnitario: Currency): TVendaItem;
    procedure Validar;
    function PodeSerAlterada: Boolean;
    function ValorTotal: Currency;

    procedure Quitar(ADataQuitacao: TDateTime);
    procedure Cancelar(const AMotivo: string; ADataCancelamento: TDateTime);
    procedure MarcarRelatorioEnviado;

    procedure RestaurarSituacao(AStatus: TStatusVenda; ADataQuitacao, ADataCancelamento: TDateTime;
      const AMotivoCancelamento: string; ARelatorioEnviado: Boolean);

    property ClienteId: Integer read FClienteId write FClienteId;
    property DataVenda: TDateTime read FDataVenda write FDataVenda;
    property Status: TStatusVenda read FStatus;
    property DataQuitacao: TDateTime read FDataQuitacao;
    property DataCancelamento: TDateTime read FDataCancelamento;
    property MotivoCancelamento: string read FMotivoCancelamento;
    property RelatorioEnviado: Boolean read FRelatorioEnviado;
    property Itens: TObjectList<TVendaItem> read FItens;
  end;

function StatusVendaToStr(AStatus: TStatusVenda): string;
function StrToStatusVenda(const AValue: string): TStatusVenda;

implementation

uses
  uDomainExceptions;

constructor TVenda.Create;
begin
  inherited Create;
  FItens := TObjectList<TVendaItem>.Create(True);
  FStatus := svPendente;
  FDataVenda := Now;
end;

destructor TVenda.Destroy;
begin
  FItens.Free;
  inherited Destroy;
end;

function TVenda.AdicionarItem(AProdutoId: Integer; const AProdutoDescricao: string;
  AQuantidade: Integer; APrecoUnitario: Currency): TVendaItem;
begin
  Result := TVendaItem.Create;
  Result.ProdutoId := AProdutoId;
  Result.ProdutoDescricao := AProdutoDescricao;
  Result.Quantidade := AQuantidade;
  Result.PrecoUnitario := APrecoUnitario;
  FItens.Add(Result);
end;

procedure TVenda.Validar;
var
  LItem: TVendaItem;
begin
  if FClienteId <= 0 then
    raise EVendaInvalida.Create('Cliente é obrigatório.');

  if FItens.Count = 0 then
    raise EVendaInvalida.Create('A venda deve conter pelo menos um item.');

  for LItem in FItens do
    LItem.Validar;

  if ValorTotal <= 0 then
    raise EVendaInvalida.Create('O valor total da venda deve ser maior que zero.');
end;

function TVenda.PodeSerAlterada: Boolean;
begin
  Result := FStatus = svPendente;
end;

function TVenda.ValorTotal: Currency;
var
  LItem: TVendaItem;
begin
  Result := 0;
  for LItem in FItens do
    Result := Result + LItem.ValorTotal;
end;

procedure TVenda.Quitar(ADataQuitacao: TDateTime);
begin
  case FStatus of
    svQuitada:
      raise EVendaInvalida.Create('Esta venda já se encontra quitada.');
    svCancelada:
      raise EVendaInvalida.Create('Não é possível quitar uma venda cancelada.');
  end;

  FStatus := svQuitada;
  FDataQuitacao := ADataQuitacao;
end;

procedure TVenda.Cancelar(const AMotivo: string; ADataCancelamento: TDateTime);
begin
  if FStatus = svCancelada then
    raise EVendaInvalida.Create('Esta venda já está cancelada.');

  if AMotivo.Trim.IsEmpty then
    raise EVendaInvalida.Create('O motivo do cancelamento é obrigatório.');

  FStatus := svCancelada;
  FDataCancelamento := ADataCancelamento;
  FMotivoCancelamento := AMotivo.Trim;
end;

procedure TVenda.MarcarRelatorioEnviado;
begin
  if FStatus <> svQuitada then
    raise EVendaInvalida.Create('O relatório de confirmação só pode ser enviado para vendas quitadas.');

  FRelatorioEnviado := True;
end;

procedure TVenda.RestaurarSituacao(AStatus: TStatusVenda; ADataQuitacao, ADataCancelamento: TDateTime;
  const AMotivoCancelamento: string; ARelatorioEnviado: Boolean);
begin
  FStatus := AStatus;
  FDataQuitacao := ADataQuitacao;
  FDataCancelamento := ADataCancelamento;
  FMotivoCancelamento := AMotivoCancelamento;
  FRelatorioEnviado := ARelatorioEnviado;
end;

function StatusVendaToStr(AStatus: TStatusVenda): string;
begin
  case AStatus of
    svQuitada:   Result := 'QUITADA';
    svCancelada: Result := 'CANCELADA';
  else
    Result := 'PENDENTE';
  end;
end;

function StrToStatusVenda(const AValue: string): TStatusVenda;
begin
  if SameText(AValue, 'QUITADA') then
    Result := svQuitada
  else
  if SameText(AValue, 'CANCELADA') then
    Result := svCancelada
  else
  if SameText(AValue, 'PENDENTE') then
    Result := svPendente
  else
    raise EArgumentException.CreateFmt('Status de venda desconhecido: "%s".', [AValue]);
end;

end.
