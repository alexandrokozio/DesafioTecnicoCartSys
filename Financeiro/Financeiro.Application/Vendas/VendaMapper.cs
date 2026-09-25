using Financeiro.Application.Common;
using Financeiro.Domain.Common;
using Financeiro.Domain.Vendas;

namespace Financeiro.Application.Vendas;


public static class VendaMapper
{
    public static string ParaTexto(StatusVenda status) => status.ToString().ToUpperInvariant();

    public static StatusVenda ParaStatus(string? status)
    {
        if (string.IsNullOrWhiteSpace(status))
            return StatusVenda.Pendente;

        return Enum.TryParse<StatusVenda>(status.Trim(), ignoreCase: true, out var resultado)
               && Enum.IsDefined(resultado)
            ? resultado
            : throw new ValidacaoException(
                $"Status '{status}' inválido. Valores aceitos: PENDENTE, QUITADA, CANCELADA.");
    }

    public static (DadosVenda Dados, SituacaoOrigem Situacao) ParaDominio(int vendaId, VendaRecebidaDto dto)
    {
        ArgumentNullException.ThrowIfNull(dto);

        if (dto.VendaId != 0 && dto.VendaId != vendaId)
            throw new ValidacaoException($"O vendaId do corpo ({dto.VendaId}) difere do informado na rota ({vendaId}).");

        if (dto.DataVenda is null)
            throw new ValidacaoException("O campo 'dataVenda' é obrigatório.");

        if (dto.Cliente is null)
            throw new ValidacaoException("O campo 'cliente' é obrigatório.");

        if (dto.Itens is null || dto.Itens.Count == 0)
            throw new ValidacaoException("A venda deve conter pelo menos um item.");

        var cliente = ClienteVenda.Criar(dto.Cliente.Id, dto.Cliente.Nome, dto.Cliente.Documento, dto.Cliente.Email);
        var itens = dto.Itens
            .Select(i => new DadosItemVenda(i.ProdutoId, i.Descricao ?? string.Empty, i.Quantidade, i.PrecoUnitario))
            .ToList();

        var dados = new DadosVenda(vendaId, dto.DataVenda.Value, cliente, itens, dto.ValorTotal);
        var situacao = new SituacaoOrigem(ParaStatus(dto.Status), dto.DataQuitacao, dto.DataCancelamento, dto.MotivoCancelamento);

        return (dados, situacao);
    }

    public static VendaFinanceiraDto ParaDto(VendaFinanceira venda)
    {
        ArgumentNullException.ThrowIfNull(venda);

        return new VendaFinanceiraDto(
            venda.VendaId,
            venda.DataVenda,
            ParaTexto(venda.Status),
            venda.ValorTotal,
            new ClienteDto(venda.Cliente.ClienteId, venda.Cliente.Nome, venda.Cliente.Documento, venda.Cliente.Email),
            venda.DataRecebimento,
            venda.DataAtualizacao,
            venda.DataQuitacao,
            venda.FormaPagamento,
            venda.DataCancelamento,
            venda.MotivoCancelamento,
            venda.OrigemCancelamento?.ToString(),
            venda.Itens
                .Select(i => new ItemDto(i.ProdutoId, i.Descricao, i.Quantidade, i.PrecoUnitario, i.ValorTotal))
                .ToList());
    }
}
