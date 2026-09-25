unit uProdutoServiceTest;

interface

uses
  DUnitX.TestFramework,
  connection.interfaces,
  repository.interfaces,
  uProduto,
  uProdutoService,
  uDomainExceptions,
  MocksTest;

type
  [TestFixture]
  TProdutoServiceTest = class
  private
    FRepo: IProdutoRepository;
    FService: TProdutoService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Salvar_ProdutoValido_DeveSalvarComSucesso;

    [Test]
    procedure Test_Salvar_ProdutoSemDescricao_DeveLancarExcecao;

    [Test]
    [TestCase('Preco Zero', '0')]
    [TestCase('Preco Negativo', '-10.5')]
    procedure Test_Salvar_ProdutoComPrecoInvalido_DeveLancarExcecao(const APreco: Double);

    [Test]
    procedure Test_Salvar_ProdutoComEstoqueNegativo_DeveLancarExcecao;

    [Test]
    procedure Test_Excluir_IdInvalido_DeveLancarExcecao;
  end;

implementation

procedure TProdutoServiceTest.Setup;
begin
  FRepo := TFakeProdutoRepository.Create;
  FService := TProdutoService.Create(TFakeUnitOfWork.Create, FRepo);
end;

procedure TProdutoServiceTest.TearDown;
begin
  FService.Free;
end;

procedure TProdutoServiceTest.Test_Salvar_ProdutoValido_DeveSalvarComSucesso;
var
  LProduto: TProduto;
  LIdGerado: Integer;
begin
  LProduto := TProduto.Create;
  try
    LProduto.Descricao := 'Teclado Mecânico RGB';
    LProduto.Preco := 250.00;
    LProduto.EstoqueAtual := 10;

    LIdGerado := FService.Salvar(LProduto);

    Assert.AreEqual(1, LIdGerado);
    Assert.AreEqual(1, LProduto.Id);
  finally
    LProduto.Free;
  end;
end;

procedure TProdutoServiceTest.Test_Salvar_ProdutoSemDescricao_DeveLancarExcecao;
var
  LProduto: TProduto;
begin
  LProduto := TProduto.Create;
  try
    LProduto.Descricao := '   ';
    LProduto.Preco := 100.00;

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LProduto);
      end,
      EProdutoInvalido
    );
  finally
    LProduto.Free;
  end;
end;

procedure TProdutoServiceTest.Test_Salvar_ProdutoComPrecoInvalido_DeveLancarExcecao(const APreco: Double);
var
  LProduto: TProduto;
begin
  LProduto := TProduto.Create;
  try
    LProduto.Descricao := 'Mouse Pad';
    LProduto.Preco := APreco;

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LProduto);
      end,
      EProdutoInvalido
    );
  finally
    LProduto.Free;
  end;
end;

procedure TProdutoServiceTest.Test_Salvar_ProdutoComEstoqueNegativo_DeveLancarExcecao;
var
  LProduto: TProduto;
begin
  LProduto := TProduto.Create;
  try
    LProduto.Descricao := 'Monitor 27"';
    LProduto.Preco := 1200.00;
    LProduto.EstoqueAtual := -1;

    Assert.WillRaise(
      procedure
      begin
        FService.Salvar(LProduto);
      end,
      EProdutoInvalido
    );
  finally
    LProduto.Free;
  end;
end;

procedure TProdutoServiceTest.Test_Excluir_IdInvalido_DeveLancarExcecao;
begin
  Assert.WillRaise(
    procedure
    begin
      FService.Excluir(0);
    end,
    EProdutoInvalido
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TProdutoServiceTest);

end.
