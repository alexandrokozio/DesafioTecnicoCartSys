unit uProduto;

interface

uses
  uEntityBase;

type
  TProduto = class(TEntityBase)
  private
    FDescricao: string;
    FSku: string;
    FPreco: Currency;
    FEstoqueAtual: Integer;
  public
    constructor Create;
    procedure Validar;

    property Descricao: string read FDescricao write FDescricao;
    property Sku: string read FSku write FSku;
    property Preco: Currency read FPreco write FPreco;
    property EstoqueAtual: Integer read FEstoqueAtual write FEstoqueAtual;
  end;

implementation

uses
  System.SysUtils,
  uDomainExceptions;

constructor TProduto.Create;
begin
  inherited Create;
  Ativo := True;
end;

procedure TProduto.Validar;
begin
  if FDescricao.Trim.IsEmpty then
    raise EProdutoInvalido.Create('A descrição do produto é obrigatória.');

  if FPreco <= 0 then
    raise EProdutoInvalido.Create('O preço do produto deve ser maior que zero.');

  if FEstoqueAtual < 0 then
    raise EProdutoInvalido.Create('O estoque atual do produto não pode ser negativo.');
end;

end.
