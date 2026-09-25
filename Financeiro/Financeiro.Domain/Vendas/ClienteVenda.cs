using System.Text.RegularExpressions;
using Financeiro.Domain.Common;

namespace Financeiro.Domain.Vendas;


public sealed partial record ClienteVenda
{
    public const int TamanhoNome = 150;
    public const int TamanhoDocumento = 18;
    public const int TamanhoEmail = 150;

    public int ClienteId { get; private init; }
    public string Nome { get; private init; } = string.Empty;
    public string Documento { get; private init; } = string.Empty;
    public string? Email { get; private init; }

    private ClienteVenda()
    {
    }

    public static ClienteVenda Criar(int clienteId, string? nome, string? documento, string? email)
    {
        Guard.Positivo(clienteId, "cliente.id");

        var emailNormalizado = Guard.Opcional(email, "cliente.email", TamanhoEmail);
        Guard.Contra(emailNormalizado is not null && !EmailValido().IsMatch(emailNormalizado),
            $"O e-mail do cliente '{emailNormalizado}' é inválido.");

        return new ClienteVenda
        {
            ClienteId = clienteId,
            Nome = Guard.Obrigatorio(nome, "cliente.nome", TamanhoNome),
            Documento = Guard.Obrigatorio(documento, "cliente.documento", TamanhoDocumento),
            Email = emailNormalizado
        };
    }

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex EmailValido();
}
