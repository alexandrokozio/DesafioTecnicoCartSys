using System.Security.Cryptography;
using System.Text;
using Financeiro.API.Erros;
using Microsoft.Extensions.Options;

namespace Financeiro.API.Seguranca;


public sealed class SegurancaOptions
{
    public const string Secao = "Seguranca";

    public Dictionary<string, string> ApiKeys { get; init; } = [];
}

internal sealed class ApiKeyFilter(IOptionsMonitor<SegurancaOptions> opcoes, ILogger<ApiKeyFilter> logger) : IEndpointFilter
{
    public const string Header = "X-Api-Key";

    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var recebida = context.HttpContext.Request.Headers[Header].ToString();

        var cliente = opcoes.CurrentValue.ApiKeys
            .Where(par => !string.IsNullOrWhiteSpace(par.Value))
            .FirstOrDefault(par => ChavesIguais(par.Value, recebida)).Key;

        if (cliente is null)
        {
            logger.LogWarning("Requisição recusada (API key ausente ou inválida): {Metodo} {Caminho}.",
                context.HttpContext.Request.Method, context.HttpContext.Request.Path);

            return Results.Json(new ErroApi("NAO_AUTORIZADO", $"API key ausente ou inválida (header {Header})."),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        context.HttpContext.Items["ClienteApi"] = cliente;
        return await next(context);
    }

    private static bool ChavesIguais(string esperada, string recebida) =>
        CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(esperada), Encoding.UTF8.GetBytes(recebida));
}
