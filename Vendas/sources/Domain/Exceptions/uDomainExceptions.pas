unit uDomainExceptions;

interface

uses
  System.SysUtils;

type
  EDomainException = class(Exception);

  EClienteInvalido = class(EDomainException);
  EProdutoInvalido = class(EDomainException);
  EVendaInvalida = class(EDomainException);

  ERegistroNaoEncontrado = class(EDomainException);

implementation

end.
