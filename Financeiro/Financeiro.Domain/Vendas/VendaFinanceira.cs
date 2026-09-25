using Financeiro.Domain.Common;

namespace Financeiro.Domain.Vendas;

public sealed class VendaFinanceira : Entity
{
    public const int TamanhoMotivo = 250;
    public const int TamanhoFormaPagamento = 50;

    private const decimal ToleranciaTotal = 0.01m;

    private readonly List<VendaFinanceiraItem> _itens = [];

    public int VendaId { get; private set; }
    public DateTime DataVenda { get; private set; }
    public ClienteVenda Cliente { get; private set; } = null!;
    public StatusVenda Status { get; private set; }
    public decimal ValorTotal { get; private set; }

    public DateTime DataRecebimento { get; private set; }
    public DateTime DataAtualizacao { get; private set; }

    public DateTime? DataQuitacao { get; private set; }
    public string? FormaPagamento { get; private set; }

    public DateTime? DataCancelamento { get; private set; }
    public string? MotivoCancelamento { get; private set; }
    public OrigemCancelamento? OrigemCancelamento { get; private set; }

    public IReadOnlyCollection<VendaFinanceiraItem> Itens => _itens.AsReadOnly();

    private VendaFinanceira()
    {
    }

    public static VendaFinanceira Registrar(DadosVenda dados, SituacaoOrigem situacao, DateTime agora)
    {
        ArgumentNullException.ThrowIfNull(dados);
        ArgumentNullException.ThrowIfNull(situacao);
        Guard.Positivo(dados.VendaId, "vendaId");

        var venda = new VendaFinanceira
        {
            VendaId = dados.VendaId,
            Status = StatusVenda.Pendente,
            DataRecebimento = agora,
            DataAtualizacao = agora
        };

        venda.AplicarDados(dados);

        switch (situacao.Status)
        {
            case StatusVenda.Quitada:
                venda.Status = StatusVenda.Quitada;
                venda.DataQuitacao = situacao.DataQuitacao ?? agora;
                break;

            case StatusVenda.Cancelada:
                venda.Status = StatusVenda.Cancelada;
                venda.DataCancelamento = situacao.DataCancelamento ?? agora;
                venda.MotivoCancelamento = Guard.Opcional(situacao.MotivoCancelamento, "motivoCancelamento", TamanhoMotivo)
                    ?? "Cancelada no ERP Vendas";
                venda.OrigemCancelamento = Vendas.OrigemCancelamento.ErpVendas;
                break;
        }

        return venda;
    }

    public ResultadoSincronizacao Sincronizar(DadosVenda dados, SituacaoOrigem situacao, DateTime agora)
    {
        ArgumentNullException.ThrowIfNull(dados);
        ArgumentNullException.ThrowIfNull(situacao);
        Guard.Contra(dados.VendaId != VendaId, $"Os dados enviados são da venda {dados.VendaId}, não da venda {VendaId}.");

        if (situacao.Status == StatusVenda.Cancelada)
        {
            if (Status == StatusVenda.Cancelada)
                return ResultadoSincronizacao.SemAlteracao;

            Cancelar(situacao.MotivoCancelamento ?? "Cancelada no ERP Vendas",
                situacao.DataCancelamento ?? agora, Vendas.OrigemCancelamento.ErpVendas, agora);
            return ResultadoSincronizacao.Cancelada;
        }

        var dadosIguais = PossuiMesmosDados(dados);

        if (Status != StatusVenda.Pendente)
        {
            Guard.Contra(!dadosIguais,
                $"A venda {VendaId} está {Status.ToString().ToUpperInvariant()} no Financeiro e não pode ser alterada.");
            return ResultadoSincronizacao.SemAlteracao;
        }

        Guard.Contra(situacao.Status == StatusVenda.Quitada,
            $"A venda {VendaId} está pendente no Financeiro: a quitação é registrada exclusivamente pelo Financeiro.");

        if (dadosIguais)
            return ResultadoSincronizacao.SemAlteracao;

        AplicarDados(dados);
        DataAtualizacao = agora;
        return ResultadoSincronizacao.DadosAtualizados;
    }

    public void Quitar(DateTime dataQuitacao, string? formaPagamento, DateTime agora)
    {
        Guard.Contra(Status == StatusVenda.Quitada, $"A venda {VendaId} já está quitada.");
        Guard.Contra(Status == StatusVenda.Cancelada, $"A venda {VendaId} está cancelada e não pode ser quitada.");
        Guard.Contra(dataQuitacao.Date < DataVenda.Date,
            $"A data de quitação ({dataQuitacao:dd/MM/yyyy}) não pode ser anterior à data da venda ({DataVenda:dd/MM/yyyy}).");
        Guard.Contra(dataQuitacao > agora.AddMinutes(5), "A data de quitação não pode estar no futuro.");
        var formaPagamentoValidada = Guard.Opcional(formaPagamento, "formaPagamento", TamanhoFormaPagamento);

        Status = StatusVenda.Quitada;
        DataQuitacao = dataQuitacao;
        FormaPagamento = formaPagamentoValidada;
        DataAtualizacao = agora;

        RegistrarEvento(new VendaQuitadaEvent(VendaId, dataQuitacao, FormaPagamento, agora));
    }

    public void Cancelar(string? motivo, DateTime dataCancelamento, OrigemCancelamento origem, DateTime agora)
    {
        Guard.Contra(Status == StatusVenda.Cancelada, $"A venda {VendaId} já está cancelada.");

        var motivoValidado = Guard.Obrigatorio(motivo, "motivo", TamanhoMotivo);

        Status = StatusVenda.Cancelada;
        MotivoCancelamento = motivoValidado;
        DataCancelamento = dataCancelamento;
        OrigemCancelamento = origem;
        DataAtualizacao = agora;

        if (origem == Vendas.OrigemCancelamento.Financeiro)
            RegistrarEvento(new VendaCanceladaNoFinanceiroEvent(VendaId, MotivoCancelamento, dataCancelamento, agora));
    }

    private void AplicarDados(DadosVenda dados)
    {
        ArgumentNullException.ThrowIfNull(dados.Cliente);
        Guard.Contra(dados.Itens is null || dados.Itens.Count == 0, "A venda deve conter pelo menos um item.");

        var itens = dados.Itens!.Select(VendaFinanceiraItem.Criar).ToList();
        var total = itens.Sum(i => i.ValorTotal);

        Guard.Contra(Math.Abs(total - dados.ValorTotalInformado) > ToleranciaTotal,
            $"O valor total informado ({dados.ValorTotalInformado:N2}) difere da soma dos itens ({total:N2}).");

        DataVenda = dados.DataVenda;
        Cliente = dados.Cliente;
        ValorTotal = total;

        _itens.Clear();
        _itens.AddRange(itens);
    }

    private bool PossuiMesmosDados(DadosVenda dados) =>
        DataVenda == dados.DataVenda
        && Cliente == dados.Cliente
        && _itens.Count == dados.Itens.Count
        && _itens.Zip(dados.Itens).All(par => par.First.Equivale(par.Second));
}
