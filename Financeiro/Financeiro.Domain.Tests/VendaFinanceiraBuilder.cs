using Financeiro.Domain.Vendas;

namespace Financeiro.Domain.Tests;

internal static class VendaFinanceiraBuilder
{
    public static readonly DateTime DataVenda = new(2026, 9, 20, 10, 15, 0, DateTimeKind.Local);
    public static readonly DateTime Agora = new(2026, 9, 25, 14, 0, 0, DateTimeKind.Local);

    public static ClienteVenda Cliente(string? email = "atendimento@1notas-santaaurora.example") =>
        ClienteVenda.Criar(1, "1º Tabelionato de Notas e Protesto de Santa Aurora/MG", "11.222.333/0001-81", email);

    public static List<DadosItemVenda> Itens() =>
    [
        new(1, "Licença CartSys Notas - Tabelionato de Notas (por estação)", 3, 1250.00m),
        new(6, "Integração com Selo Digital do Tribunal de Justiça - ativação", 1, 650.00m),
        new(7, "Implantação e migração de acervo eletrônico (por módulo)", 1, 3500.00m)
    ];

    public const decimal TotalItens = 7900.00m;

    public static DadosVenda Dados(IReadOnlyList<DadosItemVenda>? itens = null, decimal? total = null, ClienteVenda? cliente = null)
    {
        var lista = itens ?? Itens();
        return new DadosVenda(1, DataVenda, cliente ?? Cliente(), lista,
            total ?? lista.Sum(i => i.Quantidade * i.PrecoUnitario));
    }

    public static VendaFinanceira Pendente() =>
        VendaFinanceira.Registrar(Dados(), SituacaoOrigem.Pendente, Agora);

    public static VendaFinanceira Quitada()
    {
        var venda = Pendente();
        venda.Quitar(Agora, "PIX", Agora);
        venda.LimparEventos();
        return venda;
    }
}
