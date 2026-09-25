program ERP.Vendas;

uses
  Vcl.Forms,
  uDomainExceptions in '..\..\sources\Domain\Exceptions\uDomainExceptions.pas',
  uEntityBase in '..\..\sources\Domain\Entities\uEntityBase.pas',
  uCliente in '..\..\sources\Domain\Entities\uCliente.pas',
  uProduto in '..\..\sources\Domain\Entities\uProduto.pas',
  uItemVenda in '..\..\sources\Domain\Entities\uItemVenda.pas',
  uVenda in '..\..\sources\Domain\Entities\uVenda.pas',
  uVendaResumo in '..\..\sources\Application\DTO\uVendaResumo.pas',
  uEventoIntegracao in '..\..\sources\Application\Integration\uEventoIntegracao.pas',
  uIntegracaoPortas in '..\..\sources\Application\Integration\uIntegracaoPortas.pas',
  uConfirmacaoPedidoEmail in '..\..\sources\Application\Integration\uConfirmacaoPedidoEmail.pas',
  uOutboxProcessor in '..\..\sources\Application\Integration\uOutboxProcessor.pas',
  uClienteService in '..\..\sources\Application\Service\uClienteService.pas',
  uProdutoService in '..\..\sources\Application\Service\uProdutoService.pas',
  uVendaService in '..\..\sources\Application\Service\uVendaService.pas',
  Common.Utils in '..\..\sources\SharedKernel\Common.Utils.pas',
  uAppConfig in '..\..\sources\Infrastructure\Config\uAppConfig.pas',
  uLogger in '..\..\sources\Infrastructure\Logging\uLogger.pas',
  connection.interfaces in '..\..\sources\Infrastructure\Interfaces\connection.interfaces.pas',
  repository.interfaces in '..\..\sources\Infrastructure\Interfaces\repository.interfaces.pas',
  connection.firedac in '..\..\sources\Infrastructure\Connection\connection.firedac.pas',
  connection.factory in '..\..\sources\Infrastructure\Connection\connection.factory.pas',
  connection.unitofwork in '..\..\sources\Infrastructure\Connection\connection.unitofwork.pas',
  uClienteDAO in '..\..\sources\Infrastructure\Repositories\DAO\uClienteDAO.pas',
  uProdutoDAO in '..\..\sources\Infrastructure\Repositories\DAO\uProdutoDAO.pas',
  uItemVendaDAO in '..\..\sources\Infrastructure\Repositories\DAO\uItemVendaDAO.pas',
  uVendaDAO in '..\..\sources\Infrastructure\Repositories\DAO\uVendaDAO.pas',
  uOutboxDAO in '..\..\sources\Infrastructure\Repositories\DAO\uOutboxDAO.pas',
  uVendaJsonMapper in '..\..\sources\Infrastructure\Mappers\uVendaJsonMapper.pas',
  uFinanceiroHttpGateway in '..\..\sources\Infrastructure\Integration\uFinanceiroHttpGateway.pas',
  uOutboxWorker in '..\..\sources\Infrastructure\Integration\uOutboxWorker.pas',
  uIndySmtpEmailSender in '..\..\sources\Infrastructure\Email\uIndySmtpEmailSender.pas',
  uServiceFactory in '..\..\sources\CompositionRoot\uServiceFactory.pas',
  uApiRouter in '..\..\sources\Presentation\API\Router\uApiRouter.pas',
  uHealthController in '..\..\sources\Presentation\API\Controllers\uHealthController.pas',
  uVendaController in '..\..\sources\Presentation\API\Controllers\uVendaController.pas',
  uWebModuleMain in '..\..\sources\Presentation\API\WebModule\uWebModuleMain.pas' {wmApi: TWebModule},
  uApiServer in '..\..\sources\Presentation\API\uApiServer.pas',
  uCommons in '..\..\sources\Presentation\Desktop\Commons\uCommons.pas',
  uFormHelper in '..\..\sources\Presentation\Desktop\Commons\uFormHelper.pas',
  fBase in '..\..\sources\Presentation\Desktop\Commons\fBase.pas' {frmBase},
  fBaseMain in '..\..\sources\Presentation\Desktop\Commons\fBaseMain.pas' {frmBaseMain},
  fBaseCadastro in '..\..\sources\Presentation\Desktop\Commons\fBaseCadastro.pas' {frmBaseCadastro},
  uDtmMain in '..\..\sources\Presentation\Desktop\uDtmMain.pas' {dtmMain: TDataModule},
  fMain in '..\..\sources\Presentation\Desktop\fMain.pas' {frmMain},
  fCadCliente in '..\..\sources\Presentation\Desktop\fCadCliente.pas' {frmCadCliente},
  fCadProduto in '..\..\sources\Presentation\Desktop\fCadProduto.pas' {frmCadProduto},
  fCadVenda in '..\..\sources\Presentation\Desktop\fCadVenda.pas' {frmCadVenda};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := TConstantsType.TITLE_APP;
  Application.CreateForm(TdtmMain, dtmMain);
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
