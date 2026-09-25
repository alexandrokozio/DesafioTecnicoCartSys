using Financeiro.Application.Integracao;
using Microsoft.EntityFrameworkCore;

namespace Financeiro.Infrastructure.Persistence.Outbox;

internal sealed class NotificacaoOutbox(FinanceiroDbContext db) : INotificacaoOutbox
{
    public async Task<IReadOnlyList<NotificacaoPendente>> ListarPendentesAsync(int limite, DateTime agora, CancellationToken cancellationToken)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(limite);

        return await db.Notificacoes.AsNoTracking()
            .Where(n => n.Status == StatusNotificacao.Pendente && n.ProximaTentativa <= agora)
            .Where(n => !db.Notificacoes.Any(anterior =>
                anterior.VendaId == n.VendaId
                && anterior.Id < n.Id
                && anterior.Status == StatusNotificacao.Pendente))
            .OrderBy(n => n.Id)
            .Take(limite)
            .Select(n => new NotificacaoPendente(n.Id, n.Tipo, n.VendaId, n.Conteudo, n.Tentativas))
            .ToListAsync(cancellationToken);
    }

    public Task MarcarEnviadaAsync(long id, DateTime agora, CancellationToken cancellationToken) =>
        db.Notificacoes
            .Where(n => n.Id == id)
            .ExecuteUpdateAsync(s => s
                .SetProperty(n => n.Status, StatusNotificacao.Enviada)
                .SetProperty(n => n.DataEnvio, agora)
                .SetProperty(n => n.UltimoErro, (string?)null), cancellationToken);

    public Task RegistrarFalhaAsync(long id, string erro, DateTime proximaTentativa, bool definitiva, CancellationToken cancellationToken)
    {
        var status = definitiva ? StatusNotificacao.Falha : StatusNotificacao.Pendente;

        return db.Notificacoes
            .Where(n => n.Id == id)
            .ExecuteUpdateAsync(s => s
                .SetProperty(n => n.Tentativas, n => n.Tentativas + 1)
                .SetProperty(n => n.Status, status)
                .SetProperty(n => n.ProximaTentativa, proximaTentativa)
                .SetProperty(n => n.UltimoErro, erro), cancellationToken);
    }
}
