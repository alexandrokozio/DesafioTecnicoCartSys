using Financeiro.API.Erros;
using Financeiro.API.Seguranca;
using Financeiro.Application.Abstractions;
using Financeiro.Application.Common;
using Financeiro.Application.Vendas;

namespace Financeiro.API.Endpoints;

/* 
    GET  /api/v1/financeiro/vendas                         consulta com filtros
    GET  /api/v1/financeiro/vendas/{vendaId}               detalhe
    POST /api/v1/financeiro/vendas/{vendaId}/quitacao      quitação (notifica o ERP Vendas)
    POST /api/v1/financeiro/vendas/{vendaId}/cancelamento  cancelamento/estorno (notifica o ERP Vendas)
    GET  /api/v1/financeiro/resumo                         indicadores do período
*/
public static class FinanceiroEndpoints
{
    public static IEndpointRouteBuilder MapFinanceiroEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1/financeiro")
            .WithTags("Operação financeira")
            .AddEndpointFilter<ApiKeyFilter>();

        grupo.MapGet("/vendas", ListarAsync)
            .WithName("ListarVendas")
            .WithSummary("Consulta vendas por status, período (data da venda) e cliente (nome ou documento).")
            .Produces<IReadOnlyList<VendaFinanceiraResumoDto>>(StatusCodes.Status200OK)
            .Produces<ErroApi>(StatusCodes.Status400BadRequest);

        grupo.MapGet("/vendas/{vendaId:int}", ObterAsync)
            .WithName("ObterVenda")
            .WithSummary("Detalhe financeiro da venda, com itens.")
            .Produces<VendaFinanceiraDto>(StatusCodes.Status200OK)
            .Produces<ErroApi>(StatusCodes.Status404NotFound);

        grupo.MapPost("/vendas/{vendaId:int}/quitacao", QuitarAsync)
            .WithName("QuitarVenda")
            .WithSummary("Quita a venda e agenda a notificação ao ERP Vendas.")
            .Produces<VendaFinanceiraDto>(StatusCodes.Status200OK)
            .Produces<ErroApi>(StatusCodes.Status404NotFound)
            .Produces<ErroApi>(StatusCodes.Status409Conflict)
            .Produces<ErroApi>(StatusCodes.Status422UnprocessableEntity);

        grupo.MapPost("/vendas/{vendaId:int}/cancelamento", CancelarAsync)
            .WithName("CancelarVenda")
            .WithSummary("Cancela (ou estorna, se quitada) a venda e agenda a notificação ao ERP Vendas.")
            .Produces<VendaFinanceiraDto>(StatusCodes.Status200OK)
            .Produces<ErroApi>(StatusCodes.Status404NotFound)
            .Produces<ErroApi>(StatusCodes.Status409Conflict)
            .Produces<ErroApi>(StatusCodes.Status422UnprocessableEntity);

        grupo.MapGet("/resumo", ResumirAsync)
            .WithName("ResumoFinanceiro")
            .WithSummary("Totais por status e ticket médio no período (padrão: mês corrente).")
            .Produces<ResumoFinanceiroDto>(StatusCodes.Status200OK)
            .Produces<ErroApi>(StatusCodes.Status400BadRequest);

        return app;
    }

    private static async Task<IResult> ListarAsync(
        string? status, DateTime? dataInicial, DateTime? dataFinal, string? cliente, int? limite,
        IConsultaVendasFinanceiras consultas, CancellationToken cancellationToken) =>
        Results.Ok(await consultas.ListarAsync(
            new FiltroVendas(status, dataInicial, dataFinal, cliente, limite ?? 500), cancellationToken));

    private static async Task<IResult> ObterAsync(
        int vendaId, IConsultaVendasFinanceiras consultas, CancellationToken cancellationToken) =>
        Results.Ok(await consultas.ObterAsync(vendaId, cancellationToken)
                   ?? throw RegistroNaoEncontradoException.Venda(vendaId));

    private static async Task<IResult> QuitarAsync(
        int vendaId, QuitacaoRequest? request, VendaFinanceiraService servico, CancellationToken cancellationToken) =>
        Results.Ok(await servico.QuitarAsync(vendaId, request?.DataQuitacao, request?.FormaPagamento, cancellationToken));

    private static async Task<IResult> CancelarAsync(
        int vendaId, CancelamentoRequest request, VendaFinanceiraService servico, CancellationToken cancellationToken) =>
        Results.Ok(await servico.CancelarAsync(vendaId, request.Motivo, cancellationToken));

    private static async Task<IResult> ResumirAsync(
        DateTime? dataInicial, DateTime? dataFinal, IConsultaVendasFinanceiras consultas,
        TimeProvider relogio, CancellationToken cancellationToken)
    {
        var hoje = relogio.GetLocalNow().Date;
        var inicio = dataInicial ?? new DateTime(hoje.Year, hoje.Month, 1, 0, 0, 0, DateTimeKind.Unspecified);
        var fim = dataFinal ?? hoje;

        return Results.Ok(await consultas.ResumirAsync(inicio, fim, cancellationToken));
    }
}
