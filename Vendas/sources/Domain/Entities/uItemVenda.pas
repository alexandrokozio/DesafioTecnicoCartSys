unit uItemVenda;

interface

uses
  uEntityBase;

type
  TVendaItem = class(TEntityBase)
  private
    FProdutoId: Integer;
    FProdutoDescricao: string;
    FQuantidade: Integer;
    FPrecoUnitario: Currency;
  public
    procedure Validar;
    function ValorTotal: Currency;

    property ProdutoId: Integer read FProdutoId write FProdutoId;
    property ProdutoDescricao: string read FProdutoDescricao write FProdutoDescricao;
    property Quantidade: Integer read FQuantidade write FQuantidade;
    property PrecoUnitario: Currency read FPrecoUnitario write FPrecoUnitario;
  end;

implementation

uses
  uDomainExceptions;

procedure TVendaItem.Validar;
begin
  if FProdutoId <= 0 then
    raise EVendaInvalida.Create('Item de venda contém produto inválido.');

  if FQuantidade <= 0 then
    raise EVendaInvalida.CreateFmt('A quantidade do produto %s deve ser maior que zero.', [FProdutoDescricao]);

  if FPrecoUnitario <= 0 then
    raise EVendaInvalida.CreateFmt('O preço unitário do produto %s deve ser maior que zero.', [FProdutoDescricao]);
end;

function TVendaItem.ValorTotal: Currency;
begin
  Result := FPrecoUnitario * FQuantidade;
end;

end.
