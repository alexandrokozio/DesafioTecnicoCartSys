using Financeiro.Application.Abstractions;
using Financeiro.Application.Common;
using Financeiro.Domain.Vendas;
using Microsoft.Extensions.Logging;

namespace Financeiro.Application.Vendas;

public sealed class VendaFinanceiraService(
    IVendaFinanceiraRepository repositorio,
    IUnitOfWork unitOfWork,
    TimeProvider relogio,
    ILogger<VendaFinanceiraService> logger)
{
    private DateTime Agora => relogio.GetLocalNow().DateTime;

    public async Task<SincronizacaoVendaResultado> SincronizarVendaAsync(
        int vendaId, VendaRecebidaDto dto, CancellationToken cancellationToken)
    {
        var (dados, situacao) = VendaMapper.ParaDominio(vendaId, dto);

        var venda = await repositorio.ObterPorVendaIdAsync(vendaId, cancellationToken);
        var criada = venda is null;
        ResultadoSincronizacao efeito;

        if (venda is null)
        {
            venda = VendaFinanceira.Registrar(dados, situacao, Agora);
            repositorio.Adicionar(venda);
            efeito = ResultadoSincronizacao.DadosAtualizados;
        }
        else
        {
            efeito = venda.Sincronizar(dados, situacao, Agora);
        }

        if (criada || efeito != ResultadoSincronizacao.SemAlteracao)
            await unitOfWork.SalvarAsync(cancellationToken);

        logger.LogInformation("Venda {VendaId} sincronizada com o ERP Vendas: {Efeito} (nova: {Criada}).",
            vendaId, efeito, criada);

        return new SincronizacaoVendaResultado(criada, criada ? "Criada" : efeito.ToString(), VendaMapper.ParaDto(venda));
    }

    public async Task<VendaFinanceiraDto> RegistrarCancelamentoDoErpVendasAsync(
        int vendaId, string? motivo, DateTime? dataCancelamento, CancellationToken cancellationToken)
    {
        var venda = await ObterAsync(vendaId, cancellationToken);

        if (venda.Status != StatusVenda.Cancelada)
        {
            venda.Cancelar(motivo, dataCancelamento ?? Agora, OrigemCancelamento.ErpVendas, Agora);
            await unitOfWork.SalvarAsync(cancellationToken);
            logger.LogInformation("Venda {VendaId} cancelada por solicitação do ERP Vendas.", vendaId);
        }

        return VendaMapper.ParaDto(venda);
    }

    public async Task<VendaFinanceiraDto> QuitarAsync(
        int vendaId, DateTime? dataQuitacao, string? formaPagamento, CancellationToken cancellationToken)
    {
        var venda = await ObterAsync(vendaId, cancellationToken);

        venda.Quitar(dataQuitacao ?? Agora, formaPagamento, Agora);
        await unitOfWork.SalvarAsync(cancellationToken);

        logger.LogInformation("Venda {VendaId} quitada no Financeiro.", vendaId);
        return VendaMapper.ParaDto(venda);
    }

    public async Task<VendaFinanceiraDto> CancelarAsync(
        int vendaId, string? motivo, CancellationToken cancellationToken)
    {
        var venda = await ObterAsync(vendaId, cancellationToken);

        venda.Cancelar(motivo, Agora, OrigemCancelamento.Financeiro, Agora);
        await unitOfWork.SalvarAsync(cancellationToken);

        logger.LogInformation("Venda {VendaId} cancelada no Financeiro.", vendaId);
        return VendaMapper.ParaDto(venda);
    }

    private async Task<VendaFinanceira> ObterAsync(int vendaId, CancellationToken cancellationToken)
    {
        if (vendaId <= 0)
            throw new ValidacaoException("O identificador da venda deve ser maior que zero.");

        return await repositorio.ObterPorVendaIdAsync(vendaId, cancellationToken)
               ?? throw RegistroNaoEncontradoException.Venda(vendaId);
    }
}
