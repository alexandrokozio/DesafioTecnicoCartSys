using Financeiro.Application.Common;
using Financeiro.Domain.Common;
using Microsoft.AspNetCore.Diagnostics;

namespace Financeiro.API.Erros;


public sealed record ErroApi(string Codigo, string Mensagem);

internal sealed class ApiExceptionHandler(ILogger<ApiExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var (status, erro) = exception switch
        {
            BadHttpRequestException ex => (ex.StatusCode, new ErroApi("REQUISICAO_INVALIDA", MensagemRequisicaoInvalida(ex))),
            ValidacaoException ex => (StatusCodes.Status400BadRequest, new ErroApi("REQUISICAO_INVALIDA", ex.Message)),
            RegistroNaoEncontradoException ex => (StatusCodes.Status404NotFound, new ErroApi("NAO_ENCONTRADO", ex.Message)),
            ConflitoConcorrenciaException ex => (StatusCodes.Status409Conflict, new ErroApi("CONFLITO", ex.Message)),
            DomainException ex => (StatusCodes.Status422UnprocessableEntity, new ErroApi("REGRA_DE_NEGOCIO", ex.Message)),
            _ => (StatusCodes.Status500InternalServerError,
                new ErroApi("ERRO_INTERNO", "Erro interno ao processar a requisição."))
        };

        if (status >= StatusCodes.Status500InternalServerError)
            logger.LogError(exception, "Erro não tratado em {Metodo} {Caminho}.", httpContext.Request.Method, httpContext.Request.Path);
        else
            logger.LogInformation("{Metodo} {Caminho} -> {Status}: {Mensagem}",
                httpContext.Request.Method, httpContext.Request.Path, status, erro.Mensagem);

        httpContext.Response.StatusCode = status;
        await httpContext.Response.WriteAsJsonAsync(erro, cancellationToken);
        return true;
    }

    private static string MensagemRequisicaoInvalida(BadHttpRequestException ex) =>
        ex.InnerException is System.Text.Json.JsonException json
            ? $"JSON inválido: {json.Message}"
            : ex.Message;
}
