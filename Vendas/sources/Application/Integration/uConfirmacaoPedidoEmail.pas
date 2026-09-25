unit uConfirmacaoPedidoEmail;

interface

uses
  uCliente,
  uVenda,
  uIntegracaoPortas;

type
  /// <summary>
  /// Monta o e-mail de confirmação do pedido enviado após a quitação.
  /// Layout livre em HTML; o PDF do ReportBuilder será anexado quando o
  /// módulo de relatórios for implementado.
  /// </summary>
  TConfirmacaoPedidoEmail = class
  public
    class function Montar(AVenda: TVenda; ACliente: TCliente): TEmailMensagem;
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  uItemVenda;

function Html(const ATexto: string): string;
begin
  Result := TNetEncoding.HTML.Encode(ATexto);
end;

function Moeda(AValor: Currency): string;
begin
  Result := FormatCurr('"R$ "#,##0.00', AValor);
end;

class function TConfirmacaoPedidoEmail.Montar(AVenda: TVenda; ACliente: TCliente): TEmailMensagem;
var
  LBody: TStringBuilder;
  LItem: TVendaItem;
begin
  Result.Para := ACliente.Email.Trim;
  Result.NomeDestinatario := ACliente.Nome;
  Result.Assunto := Format('Confirmação do pedido nº %d', [AVenda.Id]);

  LBody := TStringBuilder.Create;
  try
    LBody
      .Append('<html><body style="font-family:Segoe UI,Arial,sans-serif;color:#222">')
      .Append('<h2>Confirmação do pedido nº ').Append(AVenda.Id).Append('</h2>')
      .Append('<p>Olá, ').Append(Html(ACliente.Nome)).Append('.</p>')
      .Append('<p>Confirmamos o recebimento do pagamento do seu pedido.</p>')
      .Append('<table cellpadding="6" cellspacing="0" border="1" style="border-collapse:collapse">')
      .Append('<tr style="background:#eee"><th>Pedido</th><th>Data</th><th>Quitação</th></tr>')
      .Append('<tr><td>').Append(AVenda.Id).Append('</td>')
      .Append('<td>').Append(FormatDateTime('dd/mm/yyyy hh:nn', AVenda.DataVenda)).Append('</td>')
      .Append('<td>').Append(FormatDateTime('dd/mm/yyyy hh:nn', AVenda.DataQuitacao)).Append('</td></tr>')
      .Append('</table><br>')
      .Append('<table cellpadding="6" cellspacing="0" border="1" style="border-collapse:collapse">')
      .Append('<tr style="background:#eee"><th>Produto</th><th>Qtd</th><th>Preço unit.</th><th>Total</th></tr>');

    for LItem in AVenda.Itens do
      LBody
        .Append('<tr><td>').Append(Html(LItem.ProdutoDescricao)).Append('</td>')
        .Append('<td align="right">').Append(LItem.Quantidade).Append('</td>')
        .Append('<td align="right">').Append(Moeda(LItem.PrecoUnitario)).Append('</td>')
        .Append('<td align="right">').Append(Moeda(LItem.ValorTotal)).Append('</td></tr>');

    LBody
      .Append('<tr><td colspan="3" align="right"><b>Total do pedido</b></td>')
      .Append('<td align="right"><b>').Append(Moeda(AVenda.ValorTotal)).Append('</b></td></tr>')
      .Append('</table>')
      .Append('<p style="color:#777;font-size:12px">E-mail automático enviado pelo ERP Vendas CartSys.</p>')
      .Append('</body></html>');

    Result.CorpoHtml := LBody.ToString;
  finally
    LBody.Free;
  end;
end;

end.
