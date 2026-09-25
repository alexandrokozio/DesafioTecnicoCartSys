using Financeiro.API.Endpoints;
using Financeiro.API.Erros;
using Financeiro.API.Seguranca;
using Financeiro.API.Workers;
using Financeiro.Application;
using Financeiro.Infrastructure;
using Financeiro.Infrastructure.Persistence;
using Microsoft.AspNetCore.Http.Json;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Executa como console (dotnet run / Financeiro.Api.exe) ou como serviço do Windows (sc create ...).
builder.Host.UseWindowsService(options => options.ServiceName = "CartSys ERP Financeiro API");

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddOptions<SegurancaOptions>().Bind(builder.Configuration.GetSection(SegurancaOptions.Secao));
builder.Services.AddOptions<OutboxOptions>()
    .Bind(builder.Configuration.GetSection(OutboxOptions.Secao))
    .ValidateDataAnnotations()
    .ValidateOnStart();
builder.Services.AddHostedService<NotificacaoWorker>();

builder.Services.AddExceptionHandler<ApiExceptionHandler>();
builder.Services.AddProblemDetails();
// Erros de binding (JSON inválido, tipo errado) também passam pelo ApiExceptionHandler.
builder.Services.Configure<RouteHandlerOptions>(options => options.ThrowOnBadRequest = true);
builder.Services.Configure<JsonOptions>(options => options.SerializerOptions.AllowTrailingCommas = true);

builder.Services.AddOpenApi(options => options.AddDocumentTransformer((documento, _, _) =>
{
    documento.Info.Title = "CartSys - ERP Financeiro API";
    documento.Info.Version = "v1";
    documento.Info.Description = "Integração com o ERP Vendas e operação financeira (quitação, cancelamento, consultas). " +
                                 "Autenticação: header X-Api-Key.";
    return Task.CompletedTask;
}));

var app = builder.Build();

app.UseExceptionHandler();

app.MapOpenApi();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/openapi/v1.json", "ERP Financeiro API v1");
    options.RoutePrefix = "swagger";
});
app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();

app.MapGet("/api/v1/health", async (FinanceiroDbContext db, CancellationToken cancellationToken) =>
    {
        var bancoOk = await db.Database.CanConnectAsync(cancellationToken);
        return Results.Json(new { servico = "erp-financeiro", status = bancoOk ? "ok" : "degradado", banco = bancoOk ? "ok" : "indisponivel" },
            statusCode: bancoOk ? StatusCodes.Status200OK : StatusCodes.Status503ServiceUnavailable);
    })
    .WithTags("Monitoramento")
    .WithSummary("Disponibilidade da API e do banco (sem autenticação).");

app.MapIntegracaoVendasEndpoints();
app.MapFinanceiroEndpoints();

// Cria/atualiza o banco na inicialização (desligado nos testes de integração).
if (app.Configuration.GetValue("Database:AplicarMigracoesAoIniciar", defaultValue: true))
    await app.Services.AplicarMigracoesAsync();

await app.RunAsync();

/// <summary>Exposto para os testes de integração (WebApplicationFactory).</summary>
public partial class Program;
