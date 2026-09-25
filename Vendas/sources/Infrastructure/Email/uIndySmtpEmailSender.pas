unit uIndySmtpEmailSender;

interface

uses
  System.SysUtils,
  uAppConfig,
  uIntegracaoPortas;

type
  /// <summary>
  /// Envio SMTP com Indy. Uma conexão por mensagem: o componente é criado na
  /// thread que envia (worker do outbox), evitando compartilhar TIdSMTP.
  /// Com UsarTLS=True é necessário distribuir as DLLs do OpenSSL
  /// (libeay32.dll / ssleay32.dll) junto ao executável.
  /// </summary>
  TIndySmtpEmailSender = class(TInterfacedObject, IEmailSender)
  private
    FConfig: TSmtpConfig;
  public
    constructor Create(const AConfig: TSmtpConfig);
    procedure Enviar(const AMensagem: TEmailMensagem);
  end;

implementation

uses
  IdSMTP,
  IdReplySMTP,
  IdMessage,
  IdExplicitTLSClientServerBase,
  IdSSLOpenSSL,
  IdException;

constructor TIndySmtpEmailSender.Create(const AConfig: TSmtpConfig);
begin
  inherited Create;

  if AConfig.Host.Trim.IsEmpty then
    raise EArgumentException.Create('Servidor SMTP não configurado ([Smtp] Host).');

  FConfig := AConfig;
end;

procedure TIndySmtpEmailSender.Enviar(const AMensagem: TEmailMensagem);
var
  LSmtp: TIdSMTP;
  LMensagem: TIdMessage;
  LSsl: TIdSSLIOHandlerSocketOpenSSL;
begin
  if AMensagem.Para.Trim.IsEmpty then
    raise EIntegracaoException.Create('Destinatário do e-mail não informado.', True);

  LSmtp := TIdSMTP.Create(nil);
  LMensagem := TIdMessage.Create(nil);
  try
    LSmtp.Host := FConfig.Host;
    LSmtp.Port := FConfig.Porta;
    LSmtp.ConnectTimeout := 15000;
    LSmtp.ReadTimeout := 30000;

    if FConfig.Usuario.Trim.IsEmpty then
      LSmtp.AuthType := satNone
    else
    begin
      LSmtp.AuthType := satDefault;
      LSmtp.Username := FConfig.Usuario;
      LSmtp.Password := FConfig.Senha;
    end;

    if FConfig.UsarTLS then
    begin
      // Owner = LSmtp: liberado junto com o componente SMTP.
      LSsl := TIdSSLIOHandlerSocketOpenSSL.Create(LSmtp);
      LSsl.SSLOptions.Method := sslvTLSv1_2;
      LSsl.SSLOptions.SSLVersions := [sslvTLSv1_2];
      LSmtp.IOHandler := LSsl;
      LSmtp.UseTLS := utUseExplicitTLS;
    end;

    LMensagem.From.Address := FConfig.Remetente;
    LMensagem.From.Name := FConfig.NomeRemetente;
    LMensagem.Recipients.EMailAddresses := AMensagem.Para;
    LMensagem.Subject := AMensagem.Assunto;
    LMensagem.ContentType := 'text/html';
    LMensagem.CharSet := 'utf-8';
    LMensagem.ContentTransferEncoding := 'quoted-printable';
    LMensagem.Body.Text := AMensagem.CorpoHtml;

    try
      LSmtp.Connect;
      try
        LSmtp.Send(LMensagem);
      finally
        LSmtp.Disconnect;
      end;
    except
      on E: EIdSMTPReplyError do
        // 5xx do servidor = rejeição permanente (ex.: destinatário inexistente).
        raise EIntegracaoException.Create(
          Format('Servidor SMTP recusou o e-mail para %s: %s', [AMensagem.Para, E.Message]),
          (E.ErrorCode >= 500) and (E.ErrorCode < 600));
      on E: EIdException do
        raise EIntegracaoException.Create(
          Format('Falha de comunicação com o servidor SMTP %s:%d: %s',
            [FConfig.Host, FConfig.Porta, E.Message]), False);
    end;
  finally
    LMensagem.Free;
    LSmtp.Free;
  end;
end;

end.
