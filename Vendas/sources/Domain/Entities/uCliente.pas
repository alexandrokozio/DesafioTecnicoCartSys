unit uCliente;

interface

uses
  uEntityBase;

type
  TCliente = class(TEntityBase)
  private
    FNome: string;
    FCpfCnpj: string;
    FEmail: string;
    FTelefone: string;
    FEndereco: string;
  public
    constructor Create;

    procedure Validar;

    property Nome: string read FNome write FNome;
    property CpfCnpj: string read FCpfCnpj write FCpfCnpj;
    property Email: string read FEmail write FEmail;
    property Telefone: string read FTelefone write FTelefone;
    property Endereco: string read FEndereco write FEndereco;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  uDomainExceptions;

const
  REGEX_EMAIL = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

constructor TCliente.Create;
begin
  inherited Create;
  Ativo := True;
end;

procedure TCliente.Validar;
begin
  if FNome.Trim.IsEmpty then
    raise EClienteInvalido.Create('O nome do cliente é obrigatório.');

  if FCpfCnpj.Trim.IsEmpty then
    raise EClienteInvalido.Create('O CPF/CNPJ do cliente é obrigatório.');

  if (not FEmail.Trim.IsEmpty) and (not TRegEx.IsMatch(FEmail.Trim, REGEX_EMAIL)) then
    raise EClienteInvalido.Create('O formato do e-mail informado é inválido.');
end;

end.
