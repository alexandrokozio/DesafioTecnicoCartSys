using Financeiro.Application.Abstractions;
using Financeiro.Application.Integracao;
using Financeiro.Infrastructure.Integracao;
using Financeiro.Infrastructure.Persistence;
using Financeiro.Infrastructure.Persistence.Outbox;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Financeiro.Infrastructure;

public static class DependencyInjection
{
    public const string ConnectionStringName = "Financeiro";

    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString(ConnectionStringName)
            ?? throw new InvalidOperationException($"ConnectionStrings:{ConnectionStringName} não configurada.");

        services.AddDbContext<FinanceiroDbContext>(options =>
            options.UseSqlServer(connectionString, sql => sql.EnableRetryOnFailure(3)));

        services.AddScoped<IVendaFinanceiraRepository, VendaFinanceiraRepository>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<IConsultaVendasFinanceiras, ConsultaVendasFinanceiras>();
        services.AddScoped<INotificacaoOutbox, NotificacaoOutbox>();

        services.AddOptions<ErpVendasOptions>()
            .Bind(configuration.GetSection(ErpVendasOptions.Secao))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddHttpClient<IErpVendasClient, ErpVendasClient>((provider, http) =>
        {
            var options = provider.GetRequiredService<IOptions<ErpVendasOptions>>().Value;
            // BaseAddress precisa terminar com "/" para os caminhos relativos.
            http.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
            http.Timeout = TimeSpan.FromSeconds(options.TimeoutSegundos);
            http.DefaultRequestHeaders.Add("X-Api-Key", options.ApiKey);
        });

        return services;
    }

    /// <summary>Aplica as migrations pendentes (usado na inicialização da API).</summary>
    public static async Task AplicarMigracoesAsync(this IServiceProvider services, CancellationToken cancellationToken = default)
    {
        await using var escopo = services.CreateAsyncScope();
        var db = escopo.ServiceProvider.GetRequiredService<FinanceiroDbContext>();
        await db.Database.MigrateAsync(cancellationToken);
    }
}
