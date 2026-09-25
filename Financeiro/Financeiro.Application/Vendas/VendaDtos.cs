namespace Financeiro.Application.Vendas;

// Response: Espelha o JSON gerado por TVendaJsonMapper (Delphi)
public sealed record VendaRecebidaDto(
    int VendaId,
    DateTime? DataVenda,
    string? Status,
    decimal ValorTotal,
    DateTime? DataQuitacao,
    DateTime? DataCancelamento,
    string? MotivoCancelamento,
    ClienteRecebidoDto? Cliente,
    IReadOnlyList<ItemRecebidoDto>? Itens);

public sealed record ClienteRecebidoDto(int Id, string? Nome, string? Documento, string? Email);

public sealed record ItemRecebidoDto(int ProdutoId, string? Descricao, int Quantidade, decimal PrecoUnitario);


public sealed record VendaFinanceiraDto(
    int VendaId,
    DateTime DataVenda,
    string Status,
    decimal ValorTotal,
    ClienteDto Cliente,
    DateTime DataRecebimento,
    DateTime DataAtualizacao,
    DateTime? DataQuitacao,
    string? FormaPagamento,
    DateTime? DataCancelamento,
    string? MotivoCancelamento,
    string? OrigemCancelamento,
    IReadOnlyList<ItemDto> Itens);

public sealed record ClienteDto(int Id, string Nome, string Documento, string? Email);

public sealed record ItemDto(int ProdutoId, string Descricao, int Quantidade, decimal PrecoUnitario, decimal ValorTotal);

public sealed record VendaFinanceiraResumoDto(
    int VendaId,
    DateTime DataVenda,
    string ClienteNome,
    string ClienteDocumento,
    string Status,
    decimal ValorTotal,
    DateTime? DataQuitacao,
    DateTime? DataCancelamento);

public sealed record FiltroVendas(
    string? Status = null,
    DateTime? DataInicial = null,
    DateTime? DataFinal = null,
    string? Cliente = null,
    int Limite = 500);

public sealed record ResumoFinanceiroDto(
    DateTime DataInicial,
    DateTime DataFinal,
    int QuantidadeVendas,
    TotalPorStatusDto Pendentes,
    TotalPorStatusDto Quitadas,
    TotalPorStatusDto Canceladas,
    decimal TicketMedioQuitadas);

public sealed record TotalPorStatusDto(int Quantidade, decimal Valor);

public sealed record SincronizacaoVendaResultado(bool Criada, string Efeito, VendaFinanceiraDto Venda);
