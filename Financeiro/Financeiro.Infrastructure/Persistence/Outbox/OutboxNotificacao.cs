using Financeiro.Application.Integracao;

namespace Financeiro.Infrastructure.Persistence.Outbox;

public enum StatusNotificacao
{
    Pendente = 1,
    Enviada = 2,
    Falha = 3
}

public sealed class OutboxNotificacao
{
    public long Id { get; private set; }
    public TipoNotificacao Tipo { get; private set; }
    public int VendaId { get; private set; }
    public string Conteudo { get; private set; } = string.Empty;

    public StatusNotificacao Status { get; private set; }
    public int Tentativas { get; private set; }
    public DateTime ProximaTentativa { get; private set; }
    public string? UltimoErro { get; private set; }
    public DateTime DataCriacao { get; private set; }
    public DateTime? DataEnvio { get; private set; }

    private OutboxNotificacao()
    {
    }

    public static OutboxNotificacao Criar(TipoNotificacao tipo, int vendaId, string conteudo, DateTime agora) => new()
    {
        Tipo = tipo,
        VendaId = vendaId,
        Conteudo = conteudo,
        Status = StatusNotificacao.Pendente,
        ProximaTentativa = agora,
        DataCriacao = agora
    };
}
