using Financeiro.Application.Integracao;
using Financeiro.Application.Vendas;
using Microsoft.Extensions.DependencyInjection;

namespace Financeiro.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton(PoliticaRetentativa.Padrao);
        services.AddScoped<VendaFinanceiraService>();
        services.AddScoped<NotificacaoProcessor>();
        return services;
    }
}
