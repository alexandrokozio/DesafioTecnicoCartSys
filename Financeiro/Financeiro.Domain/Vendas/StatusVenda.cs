namespace Financeiro.Domain.Vendas;


public enum StatusVenda
{
    Pendente = 1,
    Quitada = 2,
    Cancelada = 3
}

public enum OrigemCancelamento
{
    ErpVendas = 1,
    Financeiro = 2
}

public enum ResultadoSincronizacao
{
    SemAlteracao = 0,
    DadosAtualizados = 1,
    Cancelada = 2
}
