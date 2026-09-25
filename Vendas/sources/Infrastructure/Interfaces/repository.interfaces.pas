unit repository.interfaces;

interface

uses
  System.Generics.Collections,
  uCliente,
  uProduto,
  uVenda,
  uItemVenda,
  uVendaResumo,
  uEventoIntegracao;

type
  IClienteRepository = interface
    ['{9A0F3C1E-1B2A-4C3D-8E4F-1A2B3C4D5E01}']
    function Inserir(ACliente: TCliente): Integer;
    procedure Atualizar(ACliente: TCliente);
    procedure Excluir(AId: Integer);
    function BuscarPorId(AId: Integer): TCliente;
    function Listar: TObjectList<TCliente>;
    function CpfCnpjJaExiste(const ACpfCnpj: string; AIdIgnorado: Integer): Boolean;
  end;

  IProdutoRepository = interface
    ['{9A0F3C1E-1B2A-4C3D-8E4F-1A2B3C4D5E02}']
    function Inserir(AProduto: TProduto): Integer;
    procedure Atualizar(AProduto: TProduto);
    procedure Excluir(AId: Integer);

    function BuscarPorId(AId: Integer): TProduto;
    function Listar: TObjectList<TProduto>;
  end;

  IItemVendaRepository = interface
    ['{89EC89C1-A48A-413C-88B0-7DE3D81C015D}']
    procedure InserirLista(AVendaId: Integer; AItens: TObjectList<TVendaItem>);
    procedure DeletarPorVendaId(AVendaId: Integer);
    procedure CarregarPorVendaId(AVendaId: Integer; AItens: TObjectList<TVendaItem>);
  end;

  IVendaRepository = interface
    ['{9A0F3C1E-1B2A-4C3D-8E4F-1A2B3C4D5E03}']
    function Inserir(AVenda: TVenda): Integer;
    procedure Atualizar(AVenda: TVenda);
    procedure AtualizarSituacao(AVenda: TVenda);

    function BuscarPorId(AId: Integer): TVenda;
    function Listar: TObjectList<TVendaResumo>;
  end;

  IOutboxRepository = interface
    ['{2F4C8A1B-7E3D-4C59-A6B2-9D0E1F3A5C77}']
    procedure Enfileirar(ATipo: TTipoEventoIntegracao; AVendaId: Integer);

    /// <summary>Eventos pendentes cuja próxima tentativa já venceu, em ordem
    /// de criação. Um evento só é retornado se não houver evento anterior
    /// pendente da mesma venda (garante ordem por venda: ex. envio antes do
    /// cancelamento).</summary>
    function ListarPendentes(ALimite: Integer; AAgora: TDateTime): TArray<TEventoOutbox>;
    procedure MarcarProcessado(AEventoId: Integer);
    /// <param name="ADefinitiva">True = não haverá nova tentativa (STATUS = FALHA).</param>
    procedure RegistrarFalha(AEventoId: Integer; const AErro: string;
      AProximaTentativa: TDateTime; ADefinitiva: Boolean);
  end;

implementation

end.
