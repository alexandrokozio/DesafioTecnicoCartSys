unit uVendaResumo;

interface

uses
  uVenda;

type
  /// <summary>Modelo de leitura para listagens de vendas. Evita carregar o
  /// agregado completo (itens) e acoplar dados do cliente à entidade TVenda.</summary>
  TVendaResumo = class
  private
    FId: Integer;
    FClienteId: Integer;
    FClienteNome: string;
    FDataVenda: TDateTime;
    FStatus: TStatusVenda;
    FValorTotal: Currency;
    FMotivoCancelamento: string;
  public
    property Id: Integer read FId write FId;
    property ClienteId: Integer read FClienteId write FClienteId;
    property ClienteNome: string read FClienteNome write FClienteNome;
    property DataVenda: TDateTime read FDataVenda write FDataVenda;
    property Status: TStatusVenda read FStatus write FStatus;
    property ValorTotal: Currency read FValorTotal write FValorTotal;
    property MotivoCancelamento: string read FMotivoCancelamento write FMotivoCancelamento;
  end;

implementation

end.
