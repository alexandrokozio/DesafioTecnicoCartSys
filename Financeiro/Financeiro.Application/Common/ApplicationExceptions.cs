namespace Financeiro.Application.Common;

public class ValidacaoException : Exception
{
    public ValidacaoException()
    {
    }

    public ValidacaoException(string message) : base(message)
    {
    }

    public ValidacaoException(string message, Exception innerException) : base(message, innerException)
    {
    }
}

public class RegistroNaoEncontradoException : Exception
{
    public RegistroNaoEncontradoException()
    {
    }

    public RegistroNaoEncontradoException(string message) : base(message)
    {
    }

    public RegistroNaoEncontradoException(string message, Exception innerException) : base(message, innerException)
    {
    }

    public static RegistroNaoEncontradoException Venda(int vendaId) =>
        new($"Venda {vendaId} não encontrada no Financeiro.");
}

public class ConflitoConcorrenciaException : Exception
{
    public ConflitoConcorrenciaException()
    {
    }

    public ConflitoConcorrenciaException(string message) : base(message)
    {
    }

    public ConflitoConcorrenciaException(string message, Exception innerException) : base(message, innerException)
    {
    }
}
