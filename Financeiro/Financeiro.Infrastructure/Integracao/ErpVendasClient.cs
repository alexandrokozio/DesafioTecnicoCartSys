using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Net.Http.Json;
using Financeiro.Application.Integracao;

namespace Financeiro.Infrastructure.Integracao;

// Configuração da API REST do ERP Vendas (Delphi
public sealed class ErpVendasOptions
{
    public const string Secao = "ErpVendas";

    [Required, Url]
    public string BaseUrl { get; set; } = "http://localhost:9000/api/v1/";

    public string ApiKey { get; set; } = string.Empty;

    [Range(1, 300)]
    public int TimeoutSegundos { get; set; } = 10;
}

// Webhooks para o ERP Vendas (Delphi):
internal sealed class ErpVendasClient(HttpClient http) : IErpVendasClient
{
    public Task NotificarQuitacaoAsync(int vendaId, NotificacaoQuitacao notificacao, CancellationToken cancellationToken) =>
        EnviarAsync($"vendas/{vendaId}/quitacao",
            new { dataQuitacao = ComFuso(notificacao.DataQuitacao), notificacao.FormaPagamento },
            cancellationToken);

    public Task NotificarCancelamentoAsync(int vendaId, NotificacaoCancelamento notificacao, CancellationToken cancellationToken) =>
        EnviarAsync($"vendas/{vendaId}/cancelamento",
            new { notificacao.Motivo, dataCancelamento = ComFuso(notificacao.DataCancelamento) },
            cancellationToken);

    private static DateTimeOffset ComFuso(DateTime data) =>
        new(DateTime.SpecifyKind(data, DateTimeKind.Local));

    private async Task EnviarAsync(string recurso, object corpo, CancellationToken cancellationToken)
    {
        HttpResponseMessage resposta;
        try
        {
            resposta = await http.PostAsJsonAsync(recurso, corpo, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            throw new IntegracaoException($"Falha de comunicação com o ERP Vendas (POST {recurso}): {ex.Message}", definitiva: false, ex);
        }
        catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            throw new IntegracaoException($"Tempo esgotado aguardando o ERP Vendas (POST {recurso}).", definitiva: false, ex);
        }

        using (resposta)
        {
            if (resposta.IsSuccessStatusCode)
                return;

            var status = (int)resposta.StatusCode;
            var detalhe = await resposta.Content.ReadAsStringAsync(cancellationToken);
            if (detalhe.Length > 500)
                detalhe = detalhe[..500];
           
            var definitiva = status is >= 400 and < 500
                && resposta.StatusCode is not (HttpStatusCode.RequestTimeout or HttpStatusCode.Conflict or HttpStatusCode.TooManyRequests);

            throw new IntegracaoException($"ERP Vendas respondeu HTTP {status} em POST {recurso}: {detalhe}", definitiva);
        }
    }
}
