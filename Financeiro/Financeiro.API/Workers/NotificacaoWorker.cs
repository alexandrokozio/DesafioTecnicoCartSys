using System.ComponentModel.DataAnnotations;
using Financeiro.Application.Integracao;
using Microsoft.Extensions.Options;

namespace Financeiro.API.Workers;

public sealed class OutboxOptions
{
    public const string Secao = "Outbox";

    public bool Habilitado { get; set; } = true;

    [Range(1, 3600)]
    public int IntervaloSegundos { get; set; } = 15;

    [Range(1, 500)]
    public int LoteMaximo { get; set; } = 20;
}

internal sealed class NotificacaoWorker(
    IServiceScopeFactory escopos,
    IOptionsMonitor<OutboxOptions> opcoes,
    ILogger<NotificacaoWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!opcoes.CurrentValue.Habilitado)
        {
            logger.LogInformation("Envio de notificações ao ERP Vendas desabilitado (Outbox:Habilitado = false).");
            return;
        }

        logger.LogInformation("Worker de notificações iniciado (intervalo de {Intervalo} s).", opcoes.CurrentValue.IntervaloSegundos);

        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(opcoes.CurrentValue.IntervaloSegundos));
        do
        {
            await ProcessarCicloAsync(stoppingToken);
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task ProcessarCicloAsync(CancellationToken stoppingToken)
    {
        try
        {
            await using var escopo = escopos.CreateAsyncScope();
            var processador = escopo.ServiceProvider.GetRequiredService<NotificacaoProcessor>();
            var resultado = await processador.ProcessarPendentesAsync(opcoes.CurrentValue.LoteMaximo, stoppingToken);

            if (resultado.Enviadas > 0 || resultado.Falhas > 0)
                logger.LogInformation("Ciclo de notificações: {Enviadas} enviada(s), {Falhas} falha(s).",
                    resultado.Enviadas, resultado.Falhas);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Encerramento do serviço.
        }
        catch (Exception ex)
        {
            // Ex.: banco indisponível. O worker não pode parar: tenta no próximo ciclo.
            logger.LogError(ex, "Falha no ciclo de envio de notificações ao ERP Vendas.");
        }
    }
}
