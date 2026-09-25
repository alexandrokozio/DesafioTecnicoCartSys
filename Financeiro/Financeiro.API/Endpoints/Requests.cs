namespace Financeiro.API.Endpoints;


public sealed record QuitacaoRequest(DateTime? DataQuitacao, string? FormaPagamento);

public sealed record CancelamentoRequest(string? Motivo, DateTime? DataCancelamento);
