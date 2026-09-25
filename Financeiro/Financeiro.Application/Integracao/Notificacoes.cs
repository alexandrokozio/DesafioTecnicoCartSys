namespace Financeiro.Application.Integracao;


public enum TipoNotificacao
{
    Quitacao = 1,
    Cancelamento = 2
}

public sealed record NotificacaoQuitacao(DateTime DataQuitacao, string? FormaPagamento);

public sealed record NotificacaoCancelamento(string Motivo, DateTime DataCancelamento);

public sealed record NotificacaoPendente(long Id, TipoNotificacao Tipo, int VendaId, string Conteudo, int Tentativas);

public interface INotificacaoOutbox
{
    Task<IReadOnlyList<NotificacaoPendente>> ListarPendentesAsync(int limite, DateTime agora, CancellationToken cancellationToken);

    Task MarcarEnviadaAsync(long id, DateTime agora, CancellationToken cancellationToken);

    Task RegistrarFalhaAsync(long id, string erro, DateTime proximaTentativa, bool definitiva, CancellationToken cancellationToken);
}

public interface IErpVendasClient
{
    Task NotificarQuitacaoAsync(int vendaId, NotificacaoQuitacao notificacao, CancellationToken cancellationToken);

    Task NotificarCancelamentoAsync(int vendaId, NotificacaoCancelamento notificacao, CancellationToken cancellationToken);
}

public class IntegracaoException : Exception
{
    public IntegracaoException()
    {
    }

    public IntegracaoException(string message) : base(message)
    {
    }

    public IntegracaoException(string message, Exception innerException) : base(message, innerException)
    {
    }

    public IntegracaoException(string message, bool definitiva, Exception? innerException = null)
        : base(message, innerException)
    {
        Definitiva = definitiva;
    }

    public bool Definitiva { get; }
}
