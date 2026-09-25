using Financeiro.Domain.Common;
using Financeiro.Domain.Vendas;

namespace Financeiro.Domain.Tests;

public class ClienteVendaTests
{
    [Fact]
    public void Criar_ComDadosValidos_NormalizaEspacos()
    {
        var cliente = ClienteVenda.Criar(4, "  Ofício de Registro Civil de Serra Clara/GO ", "44.555.666/0001-14", " civil@serraclara.example ");

        cliente.Nome.Should().Be("Ofício de Registro Civil de Serra Clara/GO");
        cliente.Email.Should().Be("civil@serraclara.example");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("  ")]
    public void Criar_SemEmail_EhPermitido(string? email)
    {
        ClienteVenda.Criar(4, "Ofício de Serra Clara/GO", "44.555.666/0001-14", email)
            .Email.Should().BeNull();
    }

    [Fact]
    public void Criar_EmailInvalido_LancaDomainException()
    {
        var acao = () => ClienteVenda.Criar(1, "Cartório", "11.222.333/0001-81", "sem-arroba");

        acao.Should().Throw<DomainException>().WithMessage("*e-mail*inválido*");
    }

    [Fact]
    public void Criar_SemNome_LancaDomainException()
    {
        var acao = () => ClienteVenda.Criar(1, " ", "11.222.333/0001-81", null);

        acao.Should().Throw<DomainException>().WithMessage("*cliente.nome*");
    }

    [Fact]
    public void Igualdade_PorValor()
    {
        ClienteVenda.Criar(1, "Cartório", "11.222.333/0001-81", null)
            .Should().Be(ClienteVenda.Criar(1, "Cartório", "11.222.333/0001-81", null));
    }
}
