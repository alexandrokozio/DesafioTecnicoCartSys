unit uEventoIntegracao;

interface

type
  /// <summary>Eventos registrados no outbox (tabela INTEGRACAO_OUTBOX) e
  /// processados de forma assíncrona após o commit da transação de negócio.</summary>
  TTipoEventoIntegracao = (
    teEnviarVenda,             // cria/atualiza a venda no ERP Financeiro
    teCancelarVenda,           // cancelamento originado no ERP Vendas
    teEnviarEmailConfirmacao   // quitação recebida do Financeiro -> e-mail ao cliente
  );

  /// <summary>Evento pendente lido do outbox para processamento.</summary>
  TEventoOutbox = record
    Id: Integer;
    Tipo: TTipoEventoIntegracao;
    VendaId: Integer;
    Tentativas: Integer;
  end;

function TipoEventoToStr(ATipo: TTipoEventoIntegracao): string;
function StrToTipoEvento(const AValue: string): TTipoEventoIntegracao;

implementation

uses
  System.SysUtils;

const
  NOMES_EVENTO: array[TTipoEventoIntegracao] of string = (
    'ENVIAR_VENDA',
    'CANCELAR_VENDA',
    'ENVIAR_EMAIL_CONFIRMACAO'
  );

function TipoEventoToStr(ATipo: TTipoEventoIntegracao): string;
begin
  Result := NOMES_EVENTO[ATipo];
end;

function StrToTipoEvento(const AValue: string): TTipoEventoIntegracao;
var
  LTipo: TTipoEventoIntegracao;
begin
  for LTipo := Low(TTipoEventoIntegracao) to High(TTipoEventoIntegracao) do
    if SameText(NOMES_EVENTO[LTipo], AValue) then
      Exit(LTipo);

  raise EArgumentException.CreateFmt('Tipo de evento de integração desconhecido: "%s".', [AValue]);
end;

end.
