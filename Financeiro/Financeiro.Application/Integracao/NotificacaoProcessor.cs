using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace Financeiro.Application.Integracao;

public sealed record PoliticaRetentativa(int MaxTentativas, TimeSpan IntervaloBase, TimeSpan IntervaloMaximo)
{
    public static PoliticaRetentativa Padrao { get; } = new(10, TimeSpan.FromSeconds(30), TimeSpan.FromHours(1));

    public bool Esgotou(int tentativasRealizadas) => tentativasRealizadas >= MaxTentativas;

    public DateTime ProximaTentativa(int tentativasRealizadas, DateTime agora)
    {
        var expoente = Math.Clamp(tentativasRealizadas - 1, 0, 20);
        var espera = TimeSpan.FromTicks(Math.Min(IntervaloBase.Ticks << expoente, IntervaloMaximo.Ticks));
        return agora + espera;
    }
}

public sealed record ResultadoProcessamento(int Enviadas, int Falhas);


public sealed class NotificacaoProcessor(
    INotificacaoOutbox outbox,
    IErpVendasClient erpVendas,
    PoliticaRetentativa politica,
    TimeProvider relogio,
    ILogger<NotificacaoProcessor> logger)
{
    public const int TamanhoMaximoErro = 1000;

    internal static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private DateTime Agora => relogio.GetLocalNow().DateTime;

    public async Task<ResultadoProcessamento> ProcessarPendentesAsync(int limite, CancellationToken cancellationToken)
    {
        var enviadas = 0;
        var falhas = 0;

        foreach (var notificacao in await outbox.ListarPendentesAsync(limite, Agora, cancellationToken))
        {
            cancellationToken.ThrowIfCancellationRequested();

            var resultado = await EntregarAsync(notificacao, cancellationToken);
            if (resultado == ResultadoEntrega.Entregue)
            {
                enviadas++;
                continue;
            }

            falhas++;

            if (resultado == ResultadoEntrega.FalhaDeComunicacao)
                break;
        }

        return new ResultadoProcessamento(enviadas, falhas);
    }

    private enum ResultadoEntrega
    {
        Entregue,
        Falha,
        FalhaDeComunicacao
    }

    private async Task<ResultadoEntrega> EntregarAsync(NotificacaoPendente notificacao, CancellationToken cancellationToken)
    {
        try
        {
            switch (notificacao.Tipo)
            {
                case TipoNotificacao.Quitacao:
                    await erpVendas.NotificarQuitacaoAsync(notificacao.VendaId,
                        Desserializar<NotificacaoQuitacao>(notificacao), cancellationToken);
                    break;

                case TipoNotificacao.Cancelamento:
                    await erpVendas.NotificarCancelamentoAsync(notificacao.VendaId,
                        Desserializar<NotificacaoCancelamento>(notificacao), cancellationToken);
                    break;

                default:
                    throw new IntegracaoException($"Tipo de notificação desconhecido: {notificacao.Tipo}.", definitiva: true);
            }

            await outbox.MarcarEnviadaAsync(notificacao.Id, Agora, cancellationToken);
            logger.LogInformation("Notificação {Id} ({Tipo}) da venda {VendaId} entregue ao ERP Vendas.",
                notificacao.Id, notificacao.Tipo, notificacao.VendaId);
            return ResultadoEntrega.Entregue;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            await RegistrarFalhaAsync(notificacao, ex, cancellationToken);

            return ex is IntegracaoException { Definitiva: false, InnerException: HttpRequestException or TaskCanceledException }
                ? ResultadoEntrega.FalhaDeComunicacao
                : ResultadoEntrega.Falha;
        }
    }

    private async Task RegistrarFalhaAsync(NotificacaoPendente notificacao, Exception erro, CancellationToken cancellationToken)
    {
        var tentativas = notificacao.Tentativas + 1;
        var definitiva = politica.Esgotou(tentativas) || erro is IntegracaoException { Definitiva: true };
        var mensagem = $"{erro.GetType().Name}: {erro.Message}";
        if (mensagem.Length > TamanhoMaximoErro)
            mensagem = mensagem[..TamanhoMaximoErro];

        logger.LogWarning(erro, "Falha ao notificar o ERP Vendas: notificação {Id} ({Tipo}), venda {VendaId}, tentativa {Tentativa}{Definitiva}.",
            notificacao.Id, notificacao.Tipo, notificacao.VendaId, tentativas, definitiva ? " (definitiva)" : string.Empty);

        try
        {
            await outbox.RegistrarFalhaAsync(notificacao.Id, mensagem,
                politica.ProximaTentativa(tentativas, Agora), definitiva, cancellationToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogError(ex, "Não foi possível registrar a falha da notificação {Id}.", notificacao.Id);
        }
    }

    private static T Desserializar<T>(NotificacaoPendente notificacao) =>
        JsonSerializer.Deserialize<T>(notificacao.Conteudo, Json)
        ?? throw new IntegracaoException($"Conteúdo inválido na notificação {notificacao.Id}.", definitiva: true);
}
