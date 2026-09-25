using Financeiro.Application.Abstractions;
using Financeiro.Application.Common;
using Financeiro.Application.Vendas;
using Financeiro.Domain.Vendas;
using Microsoft.EntityFrameworkCore;

namespace Financeiro.Infrastructure.Persistence;

internal sealed class VendaFinanceiraRepository(FinanceiroDbContext db) : IVendaFinanceiraRepository
{
    public Task<VendaFinanceira?> ObterPorVendaIdAsync(int vendaId, CancellationToken cancellationToken) =>
        db.Vendas.Include(v => v.Itens).SingleOrDefaultAsync(v => v.VendaId == vendaId, cancellationToken);

    public void Adicionar(VendaFinanceira venda) => db.Vendas.Add(venda);
}

internal sealed class UnitOfWork(FinanceiroDbContext db) : IUnitOfWork
{
    public async Task SalvarAsync(CancellationToken cancellationToken)
    {
        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException ex)
        {
            throw new ConflitoConcorrenciaException(
                "A venda foi alterada por outra operação. Recarregue os dados e tente novamente.", ex);
        }
        catch (DbUpdateException ex) when (ex.Entries.Any(e => e is { State: EntityState.Added, Entity: VendaFinanceira }))
        {
            throw new ConflitoConcorrenciaException("A venda já foi registrada por outra requisição simultânea.", ex);
        }
    }
}

internal sealed class ConsultaVendasFinanceiras(FinanceiroDbContext db) : IConsultaVendasFinanceiras
{
    private const int LimiteMaximo = 1000;

    public async Task<VendaFinanceiraDto?> ObterAsync(int vendaId, CancellationToken cancellationToken)
    {
        var venda = await db.Vendas.AsNoTracking()
            .Include(v => v.Itens)
            .SingleOrDefaultAsync(v => v.VendaId == vendaId, cancellationToken);

        return venda is null ? null : VendaMapper.ParaDto(venda);
    }

    public async Task<IReadOnlyList<VendaFinanceiraResumoDto>> ListarAsync(FiltroVendas filtro, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(filtro);

        var consulta = db.Vendas.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(filtro.Status))
        {
            var status = VendaMapper.ParaStatus(filtro.Status);
            consulta = consulta.Where(v => v.Status == status);
        }

        if (filtro.DataInicial is { } inicio)
            consulta = consulta.Where(v => v.DataVenda >= inicio.Date);

        if (filtro.DataFinal is { } fim)
            consulta = consulta.Where(v => v.DataVenda < fim.Date.AddDays(1));

        if (!string.IsNullOrWhiteSpace(filtro.Cliente))
        {
            var termo = filtro.Cliente.Trim();
            consulta = consulta.Where(v => v.Cliente.Nome.Contains(termo) || v.Cliente.Documento.Contains(termo));
        }

        var linhas = await consulta
            .OrderByDescending(v => v.DataVenda)
            .ThenByDescending(v => v.VendaId)
            .Take(Math.Clamp(filtro.Limite, 1, LimiteMaximo))
            .Select(v => new
            {
                v.VendaId, v.DataVenda, v.Cliente.Nome, v.Cliente.Documento,
                v.Status, v.ValorTotal, v.DataQuitacao, v.DataCancelamento
            })
            .ToListAsync(cancellationToken);

        return linhas
            .Select(l => new VendaFinanceiraResumoDto(l.VendaId, l.DataVenda, l.Nome, l.Documento,
                VendaMapper.ParaTexto(l.Status), l.ValorTotal, l.DataQuitacao, l.DataCancelamento))
            .ToList();
    }

    public async Task<ResumoFinanceiroDto> ResumirAsync(DateTime dataInicial, DateTime dataFinal, CancellationToken cancellationToken)
    {
        if (dataFinal < dataInicial)
            throw new ValidacaoException("A data final deve ser maior ou igual à data inicial.");

        var inicio = dataInicial.Date;
        var fimExclusivo = dataFinal.Date.AddDays(1);

        var valores = await db.Vendas.AsNoTracking()
            .Where(v => v.DataVenda >= inicio && v.DataVenda < fimExclusivo)
            .Select(v => new { v.Status, v.ValorTotal })
            .ToListAsync(cancellationToken);

        TotalPorStatusDto Total(StatusVenda status)
        {
            var doStatus = valores.Where(v => v.Status == status).ToList();
            return new TotalPorStatusDto(doStatus.Count, doStatus.Sum(v => v.ValorTotal));
        }

        var quitadas = Total(StatusVenda.Quitada);

        return new ResumoFinanceiroDto(
            inicio,
            dataFinal.Date,
            valores.Count,
            Total(StatusVenda.Pendente),
            quitadas,
            Total(StatusVenda.Cancelada),
            quitadas.Quantidade == 0 ? 0 : Math.Round(quitadas.Valor / quitadas.Quantidade, 2));
    }
}
