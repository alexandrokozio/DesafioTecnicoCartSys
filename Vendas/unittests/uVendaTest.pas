unit uVendaTest;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  uVenda,
  uDomainExceptions;

type
  [TestFixture]
  TVendaTest = class
  private
    FVenda: TVenda;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_NovaVenda_DeveIniciarPendente;
    [Test]
    procedure Test_ValorTotal_DeveSomarItens;
    [Test]
    procedure Test_Validar_ItemComPrecoZero_DeveLancarExcecao;

    [Test]
    procedure Test_Quitar_VendaPendente_DeveQuitar;
    [Test]
    procedure Test_Quitar_VendaJaQuitada_DeveLancarExcecao;
    [Test]
    procedure Test_Quitar_VendaCancelada_DeveLancarExcecao;

    [Test]
    procedure Test_Cancelar_SemMotivo_DeveLancarExcecao;
    [Test]
    procedure Test_Cancelar_VendaQuitada_DevePermitirEstorno;
    [Test]
    procedure Test_Cancelar_VendaCancelada_DeveLancarExcecao;

    [Test]
    procedure Test_MarcarRelatorioEnviado_VendaPendente_DeveLancarExcecao;
  end;

implementation

procedure TVendaTest.Setup;
begin
  FVenda := TVenda.Create;
  FVenda.ClienteId := 1;
  FVenda.AdicionarItem(1, 'Produto A', 2, 150.00);
  FVenda.AdicionarItem(2, 'Produto B', 1, 89.90);
end;

procedure TVendaTest.TearDown;
begin
  FVenda.Free;
end;

procedure TVendaTest.Test_NovaVenda_DeveIniciarPendente;
begin
  Assert.IsTrue(FVenda.Status = svPendente);
  Assert.IsTrue(FVenda.PodeSerAlterada);
end;

procedure TVendaTest.Test_ValorTotal_DeveSomarItens;
begin
  Assert.AreEqual<Currency>(389.90, FVenda.ValorTotal);
end;

procedure TVendaTest.Test_Validar_ItemComPrecoZero_DeveLancarExcecao;
begin
  FVenda.AdicionarItem(3, 'Brinde', 1, 0);

  Assert.WillRaise(
    procedure
    begin
      FVenda.Validar;
    end,
    EVendaInvalida);
end;

procedure TVendaTest.Test_Quitar_VendaPendente_DeveQuitar;
var
  LData: TDateTime;
begin
  LData := EncodeDate(2026, 9, 25);

  FVenda.Quitar(LData);

  Assert.IsTrue(FVenda.Status = svQuitada);
  Assert.AreEqual<TDateTime>(LData, FVenda.DataQuitacao);
  Assert.IsFalse(FVenda.PodeSerAlterada);
end;

procedure TVendaTest.Test_Quitar_VendaJaQuitada_DeveLancarExcecao;
begin
  FVenda.Quitar(Now);

  Assert.WillRaise(
    procedure
    begin
      FVenda.Quitar(Now);
    end,
    EVendaInvalida);
end;

procedure TVendaTest.Test_Quitar_VendaCancelada_DeveLancarExcecao;
begin
  FVenda.Cancelar('Desistência', Now);

  Assert.WillRaise(
    procedure
    begin
      FVenda.Quitar(Now);
    end,
    EVendaInvalida);
end;

procedure TVendaTest.Test_Cancelar_SemMotivo_DeveLancarExcecao;
begin
  Assert.WillRaise(
    procedure
    begin
      FVenda.Cancelar('   ', Now);
    end,
    EVendaInvalida);
  Assert.IsTrue(FVenda.Status = svPendente);
end;

procedure TVendaTest.Test_Cancelar_VendaQuitada_DevePermitirEstorno;
begin
  FVenda.Quitar(Now);
  FVenda.Cancelar('Estorno', Now);

  Assert.IsTrue(FVenda.Status = svCancelada);
  Assert.AreEqual('Estorno', FVenda.MotivoCancelamento);
end;

procedure TVendaTest.Test_Cancelar_VendaCancelada_DeveLancarExcecao;
begin
  FVenda.Cancelar('Desistência', Now);

  Assert.WillRaise(
    procedure
    begin
      FVenda.Cancelar('Outra vez', Now);
    end,
    EVendaInvalida);
end;

procedure TVendaTest.Test_MarcarRelatorioEnviado_VendaPendente_DeveLancarExcecao;
begin
  Assert.WillRaise(
    procedure
    begin
      FVenda.MarcarRelatorioEnviado;
    end,
    EVendaInvalida);
end;

initialization
  TDUnitX.RegisterTestFixture(TVendaTest);

end.
