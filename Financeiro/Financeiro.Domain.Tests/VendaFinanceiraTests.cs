using Financeiro.Domain.Common;
using Financeiro.Domain.Vendas;
using static Financeiro.Domain.Tests.VendaFinanceiraBuilder;

namespace Financeiro.Domain.Tests;

public class VendaFinanceiraTests
{
    // ------------------------------------------------------------------ Registrar

    [Fact]
    public void Registrar_VendaPendente_CalculaTotalPelosItensSemGerarNotificacao()
    {
        var venda = Pendente();

        venda.Status.Should().Be(StatusVenda.Pendente);
        venda.ValorTotal.Should().Be(TotalItens);
        venda.Itens.Should().HaveCount(3);
        venda.Itens.Sum(i => i.ValorTotal).Should().Be(TotalItens);
        venda.DataRecebimento.Should().Be(Agora);
        venda.EventosDeDominio.Should().BeEmpty();
    }

    [Fact]
    public void Registrar_TotalInformadoDivergenteDosItens_LancaDomainException()
    {
        var acao = () => VendaFinanceira.Registrar(Dados(total: 100m), SituacaoOrigem.Pendente, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*difere da soma dos itens*");
    }

    [Fact]
    public void Registrar_SemItens_LancaDomainException()
    {
        var acao = () => VendaFinanceira.Registrar(Dados(itens: []), SituacaoOrigem.Pendente, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*pelo menos um item*");
    }

    [Theory]
    [InlineData(0, 1250.00)]
    [InlineData(1, 0)]
    [InlineData(1, -10)]
    public void Registrar_ItemComQuantidadeOuPrecoInvalido_LancaDomainException(int quantidade, double preco)
    {
        List<DadosItemVenda> itens = [new(1, "Licença CartSys Notas", quantidade, (decimal)preco)];

        var acao = () => VendaFinanceira.Registrar(Dados(itens), SituacaoOrigem.Pendente, Agora);

        acao.Should().Throw<DomainException>();
    }

    [Fact]
    public void Registrar_VendaJaQuitadaNaOrigem_ImportaComoQuitadaSemNotificar()
    {
        var quitadaEm = new DateTime(2026, 9, 19, 9, 0, 0, DateTimeKind.Local);

        var venda = VendaFinanceira.Registrar(Dados(),
            new SituacaoOrigem(StatusVenda.Quitada, quitadaEm, null, null), Agora);

        venda.Status.Should().Be(StatusVenda.Quitada);
        venda.DataQuitacao.Should().Be(quitadaEm);
        venda.EventosDeDominio.Should().BeEmpty("carga histórica não deve notificar o ERP Vendas");
    }

    [Fact]
    public void Registrar_VendaJaCanceladaNaOrigem_ImportaComoCanceladaPeloErpVendas()
    {
        var venda = VendaFinanceira.Registrar(Dados(),
            new SituacaoOrigem(StatusVenda.Cancelada, Agora, Agora, "Serventia optou por terceirizar a digitalização"), Agora);

        venda.Status.Should().Be(StatusVenda.Cancelada);
        venda.OrigemCancelamento.Should().Be(OrigemCancelamento.ErpVendas);
        venda.MotivoCancelamento.Should().Be("Serventia optou por terceirizar a digitalização");
        venda.EventosDeDominio.Should().BeEmpty();
    }

    // ------------------------------------------------------------------ Quitar

    [Fact]
    public void Quitar_VendaPendente_QuitaERegistraEventoParaNotificarErpVendas()
    {
        var venda = Pendente();

        venda.Quitar(Agora, " PIX ", Agora);

        venda.Status.Should().Be(StatusVenda.Quitada);
        venda.DataQuitacao.Should().Be(Agora);
        venda.FormaPagamento.Should().Be("PIX");
        venda.EventosDeDominio.Should().ContainSingle()
            .Which.Should().BeEquivalentTo(new VendaQuitadaEvent(1, Agora, "PIX", Agora));
    }

    [Fact]
    public void Quitar_VendaJaQuitada_LancaDomainException()
    {
        var venda = Quitada();

        var acao = () => venda.Quitar(Agora, null, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*já está quitada*");
    }

    [Fact]
    public void Quitar_VendaCancelada_LancaDomainException()
    {
        var venda = Pendente();
        venda.Cancelar("Desistência", Agora, OrigemCancelamento.Financeiro, Agora);

        var acao = () => venda.Quitar(Agora, null, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*cancelada*");
    }

    [Fact]
    public void Quitar_ComDataAnteriorAVenda_LancaDomainException()
    {
        var venda = Pendente();

        var acao = () => venda.Quitar(DataVenda.AddDays(-1), null, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*anterior à data da venda*");
    }

    [Fact]
    public void Quitar_ComDataFutura_LancaDomainException()
    {
        var venda = Pendente();

        var acao = () => venda.Quitar(Agora.AddDays(1), null, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*futuro*");
    }

    [Fact]
    public void Quitar_ComFormaPagamentoInvalida_NaoAlteraOEstado()
    {
        var venda = Pendente();

        var acao = () => venda.Quitar(Agora, new string('X', VendaFinanceira.TamanhoFormaPagamento + 1), Agora);

        acao.Should().Throw<DomainException>();
        venda.Status.Should().Be(StatusVenda.Pendente);
        venda.DataQuitacao.Should().BeNull();
        venda.EventosDeDominio.Should().BeEmpty();
    }

    // ------------------------------------------------------------------ Cancelar

    [Fact]
    public void Cancelar_PeloFinanceiro_RegistraEventoParaNotificarErpVendas()
    {
        var venda = Pendente();

        venda.Cancelar("Cliente desistiu", Agora, OrigemCancelamento.Financeiro, Agora);

        venda.Status.Should().Be(StatusVenda.Cancelada);
        venda.EventosDeDominio.Should().ContainSingle().Which.Should().BeOfType<VendaCanceladaNoFinanceiroEvent>();
    }

    [Fact]
    public void Cancelar_VendaQuitada_CaracterizaEstorno()
    {
        var venda = Quitada();

        venda.Cancelar("Estorno solicitado pela serventia", Agora, OrigemCancelamento.Financeiro, Agora);

        venda.Status.Should().Be(StatusVenda.Cancelada);
        venda.DataQuitacao.Should().NotBeNull("o histórico da quitação é preservado no estorno");
    }

    [Fact]
    public void Cancelar_PeloErpVendas_NaoGeraNotificacaoDeVolta()
    {
        var venda = Pendente();

        venda.Cancelar("Cancelada no ERP Vendas", Agora, OrigemCancelamento.ErpVendas, Agora);

        venda.EventosDeDominio.Should().BeEmpty();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Cancelar_SemMotivo_LancaDomainException(string? motivo)
    {
        var venda = Pendente();

        var acao = () => venda.Cancelar(motivo, Agora, OrigemCancelamento.Financeiro, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*motivo*");
        venda.Status.Should().Be(StatusVenda.Pendente);
    }

    [Fact]
    public void Cancelar_VendaJaCancelada_LancaDomainException()
    {
        var venda = Pendente();
        venda.Cancelar("Desistência", Agora, OrigemCancelamento.Financeiro, Agora);

        var acao = () => venda.Cancelar("Outra vez", Agora, OrigemCancelamento.Financeiro, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*já está cancelada*");
    }

    // ------------------------------------------------------------------ Sincronizar (PUT do ERP Vendas)

    [Fact]
    public void Sincronizar_MesmosDados_EhIdempotente()
    {
        var venda = Pendente();

        var resultado = venda.Sincronizar(Dados(), SituacaoOrigem.Pendente, Agora.AddHours(1));

        resultado.Should().Be(ResultadoSincronizacao.SemAlteracao);
        venda.DataAtualizacao.Should().Be(Agora);
    }

    [Fact]
    public void Sincronizar_VendaPendenteAlteradaNoErpVendas_AtualizaItensETotal()
    {
        var venda = Pendente();
        List<DadosItemVenda> novosItens = [new(1, "Licença CartSys Notas - Tabelionato de Notas (por estação)", 5, 1250.00m)];

        var resultado = venda.Sincronizar(Dados(novosItens), SituacaoOrigem.Pendente, Agora.AddHours(1));

        resultado.Should().Be(ResultadoSincronizacao.DadosAtualizados);
        venda.Itens.Should().ContainSingle().Which.Quantidade.Should().Be(5);
        venda.ValorTotal.Should().Be(6250.00m);
        venda.DataAtualizacao.Should().Be(Agora.AddHours(1));
    }

    [Fact]
    public void Sincronizar_VendaQuitadaNoFinanceiroComDadosDiferentes_LancaDomainException()
    {
        var venda = Quitada();
        List<DadosItemVenda> novosItens = [new(1, "Licença CartSys Notas", 1, 1250.00m)];

        var acao = () => venda.Sincronizar(Dados(novosItens), SituacaoOrigem.Pendente, Agora);

        acao.Should().Throw<DomainException>().WithMessage("*QUITADA no Financeiro*");
    }

    [Fact]
    public void Sincronizar_VendaQuitadaNoFinanceiroComMesmosDados_EhIdempotente()
    {
        var venda = Quitada();

        venda.Sincronizar(Dados(), SituacaoOrigem.Pendente, Agora)
            .Should().Be(ResultadoSincronizacao.SemAlteracao);
    }

    [Fact]
    public void Sincronizar_StatusCanceladoNaOrigem_CancelaSemNotificarDeVolta()
    {
        var venda = Pendente();

        var resultado = venda.Sincronizar(Dados(),
            new SituacaoOrigem(StatusVenda.Cancelada, null, Agora, "Cliente desistiu"), Agora);

        resultado.Should().Be(ResultadoSincronizacao.Cancelada);
        venda.OrigemCancelamento.Should().Be(OrigemCancelamento.ErpVendas);
        venda.EventosDeDominio.Should().BeEmpty();
    }

    [Fact]
    public void Sincronizar_OrigemInformaQuitacaoDeVendaPendente_LancaDomainException()
    {
        var venda = Pendente();

        var acao = () => venda.Sincronizar(Dados(), new SituacaoOrigem(StatusVenda.Quitada, Agora, null, null), Agora);

        acao.Should().Throw<DomainException>().WithMessage("*exclusivamente pelo Financeiro*");
    }
}
