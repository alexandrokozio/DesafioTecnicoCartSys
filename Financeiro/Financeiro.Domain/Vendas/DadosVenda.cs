namespace Financeiro.Domain.Vendas;


public sealed record DadosVenda(
    int VendaId,
    DateTime DataVenda,
    ClienteVenda Cliente,
    IReadOnlyList<DadosItemVenda> Itens,
    decimal ValorTotalInformado);

public sealed record DadosItemVenda(
    int ProdutoId,
    string Descricao,
    int Quantidade,
    decimal PrecoUnitario);

public sealed record SituacaoOrigem(
    StatusVenda Status,
    DateTime? DataQuitacao,
    DateTime? DataCancelamento,
    string? MotivoCancelamento)
{
    public static SituacaoOrigem Pendente { get; } = new(StatusVenda.Pendente, null, null, null);
}
