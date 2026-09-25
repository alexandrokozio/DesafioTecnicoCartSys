using System.Text.Json;
using Financeiro.Application.Integracao;
using Financeiro.Domain.Common;
using Financeiro.Domain.Vendas;
using Financeiro.Infrastructure.Persistence.Outbox;
using Microsoft.EntityFrameworkCore;

namespace Financeiro.Infrastructure.Persistence;

public sealed class FinanceiroDbContext(DbContextOptions<FinanceiroDbContext> options, TimeProvider relogio)
    : DbContext(options)
{
    internal const string PropriedadeVersao = "Versao";

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public DbSet<VendaFinanceira> Vendas => Set<VendaFinanceira>();

    public DbSet<OutboxNotificacao> Notificacoes => Set<OutboxNotificacao>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(FinanceiroDbContext).Assembly);
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        AtualizarVersoes();
        ConverterEventosEmNotificacoes();
        return await base.SaveChangesAsync(cancellationToken);
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        AtualizarVersoes();
        ConverterEventosEmNotificacoes();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    private void AtualizarVersoes()
    {
        foreach (var entrada in ChangeTracker.Entries<VendaFinanceira>())
        {
            if (entrada.State is EntityState.Added or EntityState.Modified)
                entrada.Property(PropriedadeVersao).CurrentValue = Guid.NewGuid();
        }
    }

    private void ConverterEventosEmNotificacoes()
    {
        var agora = relogio.GetLocalNow().DateTime;
        var entidades = ChangeTracker.Entries<Entity>()
            .Select(e => e.Entity)
            .Where(e => e.EventosDeDominio.Count > 0)
            .ToList();

        foreach (var entidade in entidades)
        {
            foreach (var evento in entidade.EventosDeDominio)
            {
                var notificacao = evento switch
                {
                    VendaQuitadaEvent e => OutboxNotificacao.Criar(TipoNotificacao.Quitacao, e.VendaId,
                        JsonSerializer.Serialize(new NotificacaoQuitacao(e.DataQuitacao, e.FormaPagamento), Json), agora),
                    VendaCanceladaNoFinanceiroEvent e => OutboxNotificacao.Criar(TipoNotificacao.Cancelamento, e.VendaId,
                        JsonSerializer.Serialize(new NotificacaoCancelamento(e.Motivo, e.DataCancelamento), Json), agora),
                    _ => null
                };

                if (notificacao is not null)
                    Notificacoes.Add(notificacao);
            }

            entidade.LimparEventos();
        }
    }
}
