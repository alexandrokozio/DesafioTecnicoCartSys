using System.Text.Json;
using Financeiro.Application.Integracao;
using Microsoft.Extensions.Logging.Abstractions;

namespace Financeiro.Application.Tests;

public class NotificacaoProcessorTests
{
    private static readonly DateTime Agora = new(2026, 9, 25, 14, 0, 0, DateTimeKind.Local);
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly FakeOutbox _outbox = new();
    private readonly FakeErpVendas _erpVendas = new();
    private readonly NotificacaoProcessor _processador;

    public NotificacaoProcessorTests()
    {
        _processador = new NotificacaoProcessor(_outbox, _erpVendas, new PoliticaRetentativa(5, TimeSpan.FromSeconds(30), TimeSpan.FromHours(1)),
            new RelogioFixo(Agora), NullLogger<NotificacaoProcessor>.Instance);
    }

    [Fact]
    public async Task Quitacao_EntregueComSucesso_MarcaComoEnviada()
    {
        _outbox.AdicionarQuitacao(id: 10, vendaId: 1);

        var resultado = await _processador.ProcessarPendentesAsync(20, CancellationToken.None);

        resultado.Should().Be(new ResultadoProcessamento(1, 0));
        _erpVendas.Quitacoes.Should().ContainSingle().Which.VendaId.Should().Be(1);
        _outbox.Enviadas.Should().Equal(10);
    }

    [Fact]
    public async Task Cancelamento_EntregueComSucesso_EnviaMotivo()
    {
        _outbox.AdicionarCancelamento(id: 11, vendaId: 3, motivo: "Estorno solicitado pela serventia");

        await _processador.ProcessarPendentesAsync(20, CancellationToken.None);

        _erpVendas.Cancelamentos.Should().ContainSingle()
            .Which.Notificacao.Motivo.Should().Be("Estorno solicitado pela serventia");
    }

    [Fact]
    public async Task FalhaDeComunicacao_ReagendaComBackoffEInterrompeOLote()
    {
        _erpVendas.Falha = new IntegracaoException("sem conexão", definitiva: false, new HttpRequestException("recusada"));
        _outbox.AdicionarQuitacao(id: 1, vendaId: 1);
        _outbox.AdicionarQuitacao(id: 2, vendaId: 2);

        var resultado = await _processador.ProcessarPendentesAsync(20, CancellationToken.None);

        resultado.Should().Be(new ResultadoProcessamento(0, 1), "o ERP Vendas está fora: não adianta tentar as demais agora");
        _outbox.Falhas.Should().ContainSingle();
        _outbox.Falhas[0].Definitiva.Should().BeFalse();
        _outbox.Falhas[0].ProximaTentativa.Should().Be(Agora.AddSeconds(30));
    }

    [Fact]
    public async Task FalhaDefinitiva_NaoReagendaENaoInterrompeOLote()
    {
        _erpVendas.Falha = new IntegracaoException("HTTP 422", definitiva: true);
        _outbox.AdicionarQuitacao(id: 1, vendaId: 1);
        _outbox.AdicionarQuitacao(id: 2, vendaId: 2);

        var resultado = await _processador.ProcessarPendentesAsync(20, CancellationToken.None);

        resultado.Falhas.Should().Be(2);
        _outbox.Falhas.Should().OnlyContain(f => f.Definitiva);
    }

    [Fact]
    public async Task UltimaTentativa_FalhaTornaSeDefinitiva()
    {
        _erpVendas.Falha = new IntegracaoException("HTTP 503", definitiva: false);
        _outbox.AdicionarQuitacao(id: 1, vendaId: 1, tentativas: 4);

        await _processador.ProcessarPendentesAsync(20, CancellationToken.None);

        _outbox.Falhas.Should().ContainSingle().Which.Definitiva.Should().BeTrue();
    }

    [Fact]
    public async Task ConteudoInvalido_FalhaDefinitiva()
    {
        _outbox.Pendentes.Add(new NotificacaoPendente(1, TipoNotificacao.Quitacao, 1, "null", 0));

        await _processador.ProcessarPendentesAsync(20, CancellationToken.None);

        _outbox.Falhas.Should().ContainSingle().Which.Definitiva.Should().BeTrue();
    }

    [Theory]
    [InlineData(1, 30)]
    [InlineData(2, 60)]
    [InlineData(3, 120)]
    [InlineData(50, 3600)]
    public void Politica_BackoffExponencialLimitado(int tentativas, int segundosEsperados)
    {
        PoliticaRetentativa.Padrao.ProximaTentativa(tentativas, Agora)
            .Should().Be(Agora.AddSeconds(segundosEsperados));
    }


    // fakes

    private sealed record FalhaRegistrada(long Id, string Erro, DateTime ProximaTentativa, bool Definitiva);

    private sealed class FakeOutbox : INotificacaoOutbox
    {
        public List<NotificacaoPendente> Pendentes { get; } = [];
        public List<long> Enviadas { get; } = [];
        public List<FalhaRegistrada> Falhas { get; } = [];

        public void AdicionarQuitacao(long id, int vendaId, int tentativas = 0) =>
            Pendentes.Add(new NotificacaoPendente(id, TipoNotificacao.Quitacao, vendaId,
                JsonSerializer.Serialize(new NotificacaoQuitacao(Agora, "PIX"), Json), tentativas));

        public void AdicionarCancelamento(long id, int vendaId, string motivo) =>
            Pendentes.Add(new NotificacaoPendente(id, TipoNotificacao.Cancelamento, vendaId,
                JsonSerializer.Serialize(new NotificacaoCancelamento(motivo, Agora), Json), 0));

        public Task<IReadOnlyList<NotificacaoPendente>> ListarPendentesAsync(int limite, DateTime agora, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<NotificacaoPendente>>(Pendentes.Take(limite).ToList());

        public Task MarcarEnviadaAsync(long id, DateTime agora, CancellationToken cancellationToken)
        {
            Enviadas.Add(id);
            return Task.CompletedTask;
        }

        public Task RegistrarFalhaAsync(long id, string erro, DateTime proximaTentativa, bool definitiva, CancellationToken cancellationToken)
        {
            Falhas.Add(new FalhaRegistrada(id, erro, proximaTentativa, definitiva));
            return Task.CompletedTask;
        }
    }

    private sealed class FakeErpVendas : IErpVendasClient
    {
        public Exception? Falha { get; set; }
        public List<(int VendaId, NotificacaoQuitacao Notificacao)> Quitacoes { get; } = [];
        public List<(int VendaId, NotificacaoCancelamento Notificacao)> Cancelamentos { get; } = [];

        public Task NotificarQuitacaoAsync(int vendaId, NotificacaoQuitacao notificacao, CancellationToken cancellationToken)
        {
            if (Falha is not null)
                throw Falha;
            Quitacoes.Add((vendaId, notificacao));
            return Task.CompletedTask;
        }

        public Task NotificarCancelamentoAsync(int vendaId, NotificacaoCancelamento notificacao, CancellationToken cancellationToken)
        {
            if (Falha is not null)
                throw Falha;
            Cancelamentos.Add((vendaId, notificacao));
            return Task.CompletedTask;
        }
    }

    private sealed class RelogioFixo(DateTime agora) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new DateTimeOffset(agora).ToUniversalTime();
    }
}
