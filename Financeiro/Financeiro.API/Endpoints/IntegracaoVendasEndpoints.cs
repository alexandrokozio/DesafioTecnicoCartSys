using Financeiro.API.Erros;
using Financeiro.API.Seguranca;
using Financeiro.Application.Abstractions;
using Financeiro.Application.Common;
using Financeiro.Application.Vendas;

namespace Financeiro.API.Endpoints;

/*
 Endpoints consumidos pelo ERP Vendas (Delphi) via outbox:
   PUT  /api/v1/vendas/{vendaId}               
   POST /api/v1/vendas/{vendaId}/cancelamento
   GET  /api/v1/vendas/{vendaId}
*/
public static class IntegracaoVendasEndpoints
{
    public static IEndpointRouteBuilder MapIntegracaoVendasEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1/vendas")
            .WithTags("Integração ERP Vendas")
            .AddEndpointFilter<ApiKeyFilter>();

        grupo.MapPut("/{vendaId:int}", SincronizarAsync)
            .WithName("SincronizarVenda")
            .WithSummary("Cria ou atualiza a venda no Financeiro (idempotente).")
            .Produces<SincronizacaoVendaResultado>(StatusCodes.Status200OK)
            .Produces<SincronizacaoVendaResultado>(StatusCodes.Status201Created)
            .Produces<ErroApi>(StatusCodes.Status400BadRequest)
            .Produces<ErroApi>(StatusCodes.Status409Conflict)
            .Produces<ErroApi>(StatusCodes.Status422UnprocessableEntity);

        grupo.MapPost("/{vendaId:int}/cancelamento", CancelarAsync)
            .WithName("CancelarVendaPeloErpVendas")
            .WithSummary("Registra o cancelamento feito no ERP Vendas (idempotente).")
            .Produces<VendaFinanceiraDto>(StatusCodes.Status200OK)
            .Produces<ErroApi>(StatusCodes.Status404NotFound);

        grupo.MapGet("/{vendaId:int}", ObterAsync)
            .WithName("ObterVendaIntegracao")
            .WithSummary("Consulta a situação financeira da venda.")
            .Produces<VendaFinanceiraDto>(StatusCodes.Status200OK)
            .Produces<ErroApi>(StatusCodes.Status404NotFound);

        return app;
    }

    private static async Task<IResult> SincronizarAsync(
        int vendaId, VendaRecebidaDto venda, VendaFinanceiraService servico, CancellationToken cancellationToken)
    {
        var resultado = await servico.SincronizarVendaAsync(vendaId, venda, cancellationToken);

        return resultado.Criada
            ? Results.Created($"/api/v1/financeiro/vendas/{vendaId}", resultado)
            : Results.Ok(resultado);
    }

    private static async Task<IResult> CancelarAsync(
        int vendaId, CancelamentoRequest request, VendaFinanceiraService servico, CancellationToken cancellationToken) =>
        Results.Ok(await servico.RegistrarCancelamentoDoErpVendasAsync(
            vendaId, request.Motivo, request.DataCancelamento, cancellationToken));

    private static async Task<IResult> ObterAsync(
        int vendaId, IConsultaVendasFinanceiras consultas, CancellationToken cancellationToken) =>
        Results.Ok(await consultas.ObterAsync(vendaId, cancellationToken)
                   ?? throw RegistroNaoEncontradoException.Venda(vendaId));
}
