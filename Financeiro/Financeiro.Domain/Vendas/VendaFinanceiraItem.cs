using Financeiro.Domain.Common;

namespace Financeiro.Domain.Vendas;

public sealed class VendaFinanceiraItem : Entity
{
    public const int TamanhoDescricao = 150;
    public int ProdutoId { get; private set; }
    public string Descricao { get; private set; } = string.Empty;
    public int Quantidade { get; private set; }
    public decimal PrecoUnitario { get; private set; }
    public decimal ValorTotal { get; private set; }

    private VendaFinanceiraItem()
    {
    }

    internal static VendaFinanceiraItem Criar(DadosItemVenda dados)
    {
        Guard.Positivo(dados.ProdutoId, "itens.produtoId");
        Guard.Positivo(dados.Quantidade, "itens.quantidade");
        Guard.Positivo(dados.PrecoUnitario, "itens.precoUnitario");

        return new VendaFinanceiraItem
        {
            ProdutoId = dados.ProdutoId,
            Descricao = Guard.Obrigatorio(dados.Descricao, "itens.descricao", TamanhoDescricao),
            Quantidade = dados.Quantidade,
            PrecoUnitario = dados.PrecoUnitario,
            ValorTotal = dados.Quantidade * dados.PrecoUnitario
        };
    }

    internal bool Equivale(DadosItemVenda dados) =>
        ProdutoId == dados.ProdutoId
        && Quantidade == dados.Quantidade
        && PrecoUnitario == dados.PrecoUnitario
        && string.Equals(Descricao, dados.Descricao?.Trim(), StringComparison.Ordinal);
}
