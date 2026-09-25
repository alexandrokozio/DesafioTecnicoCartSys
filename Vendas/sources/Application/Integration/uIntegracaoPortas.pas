unit uIntegracaoPortas;

interface

uses
  System.SysUtils,
  uCliente,
  uVenda;

type
  /// <summary>
  /// Falha de integração com sistema externo.
  /// Definitiva = repetir não resolve (ex.: HTTP 4xx, cliente sem e-mail);
  /// caso contrário é transitória (rede, timeout, HTTP 5xx) e será retentada.
  /// </summary>
  EIntegracaoException = class(Exception)
  private
    FDefinitiva: Boolean;
  public
    constructor Create(const AMensagem: string; ADefinitiva: Boolean);
    property Definitiva: Boolean read FDefinitiva;
  end;

  /// <summary>Porta de saída para o ERP Financeiro (API REST).</summary>
  IFinanceiroGateway = interface
    ['{5A1D9E30-8C4B-4F7A-9B21-3E6C0D7F2A14}']
    /// <summary>Cria ou atualiza (upsert idempotente) a venda no Financeiro.</summary>
    procedure EnviarVenda(AVenda: TVenda; ACliente: TCliente);
    procedure CancelarVenda(AVendaId: Integer; const AMotivo: string; ADataCancelamento: TDateTime);
  end;

  TEmailMensagem = record
    Para: string;
    NomeDestinatario: string;
    Assunto: string;
    CorpoHtml: string;
  end;

  /// <summary>Porta de saída para envio de e-mails.</summary>
  IEmailSender = interface
    ['{C3E7B8A2-1F64-4D0E-8A95-7B2F4C6D9E01}']
    procedure Enviar(const AMensagem: TEmailMensagem);
  end;

implementation

constructor EIntegracaoException.Create(const AMensagem: string; ADefinitiva: Boolean);
begin
  inherited Create(AMensagem);

  FDefinitiva := ADefinitiva;
end;

end.
