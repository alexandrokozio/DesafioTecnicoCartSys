using Financeiro.Domain.Common;

namespace Financeiro.Domain.Vendas;


public sealed record VendaQuitadaEvent(
    int VendaId,
    DateTime DataQuitacao,
    string? FormaPagamento,
    DateTime OcorridoEm) : IDomainEvent;

public sealed record VendaCanceladaNoFinanceiroEvent(
    int VendaId,
    string Motivo,
    DateTime DataCancelamento,
    DateTime OcorridoEm) : IDomainEvent;
