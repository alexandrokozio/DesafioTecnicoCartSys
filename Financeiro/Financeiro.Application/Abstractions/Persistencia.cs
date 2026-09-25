using Financeiro.Application.Vendas;
using Financeiro.Domain.Vendas;

namespace Financeiro.Application.Abstractions;


public interface IVendaFinanceiraRepository
{
    Task<VendaFinanceira?> ObterPorVendaIdAsync(int vendaId, CancellationToken cancellationToken);

    void Adicionar(VendaFinanceira venda);
}

public interface IUnitOfWork
{
    Task SalvarAsync(CancellationToken cancellationToken);
}

public interface IConsultaVendasFinanceiras
{
    Task<VendaFinanceiraDto?> ObterAsync(int vendaId, CancellationToken cancellationToken);

    Task<IReadOnlyList<VendaFinanceiraResumoDto>> ListarAsync(FiltroVendas filtro, CancellationToken cancellationToken);

    Task<ResumoFinanceiroDto> ResumirAsync(DateTime dataInicial, DateTime dataFinal, CancellationToken cancellationToken);
}
