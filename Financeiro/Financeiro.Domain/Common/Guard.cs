namespace Financeiro.Domain.Common;

internal static class Guard
{
    public static void Contra(bool condicao, string mensagem)
    {
        if (condicao)
            throw new DomainException(mensagem);
    }

    public static void Positivo(int valor, string campo) =>
        Contra(valor <= 0, $"O campo '{campo}' deve ser maior que zero.");

    public static void Positivo(decimal valor, string campo) =>
        Contra(valor <= 0, $"O campo '{campo}' deve ser maior que zero.");

    public static string Obrigatorio(string? valor, string campo, int tamanhoMaximo)
    {
        Contra(string.IsNullOrWhiteSpace(valor), $"O campo '{campo}' é obrigatório.");

        var normalizado = valor!.Trim();
        Contra(normalizado.Length > tamanhoMaximo,
            $"O campo '{campo}' deve ter no máximo {tamanhoMaximo} caracteres.");

        return normalizado;
    }

    public static string? Opcional(string? valor, string campo, int tamanhoMaximo)
    {
        if (string.IsNullOrWhiteSpace(valor))
            return null;

        var normalizado = valor.Trim();
        Contra(normalizado.Length > tamanhoMaximo,
            $"O campo '{campo}' deve ter no máximo {tamanhoMaximo} caracteres.");

        return normalizado;
    }
}
