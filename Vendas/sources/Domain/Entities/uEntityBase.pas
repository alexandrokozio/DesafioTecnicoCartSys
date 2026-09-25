unit uEntityBase;

interface

type
  TEntityBase = class
  private
    FId: Integer;
    FDataCadastro: TDateTime;
    FAtivo: Boolean;
  public
    property Id: Integer read FId write FId;
    property DataCadastro: TDateTime read FDataCadastro write FDataCadastro;
    property Ativo: Boolean read FAtivo write FAtivo;
  end;

implementation

end.
