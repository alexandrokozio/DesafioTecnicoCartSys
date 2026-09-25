program ERP.Vendas.Tests;

{$IFDEF CONSOLE_TESTRUNNER}
  {$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  Vcl.Forms,
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  {$IFDEF CONSOLE_TESTRUNNER}
  DUnitX.Loggers.Console,
  {$ENDIF }
  {$ENDIF }
  DUnitX.Loggers.GUI.VCL,
  DUnitX.TestFramework,
  MocksTest in '..\..\unittests\MocksTest.pas',
  uVendaTest in '..\..\unittests\uVendaTest.pas',
  uClienteServiceTest in '..\..\unittests\uClienteServiceTest.pas',
  uProdutoServiceTest in '..\..\unittests\uProdutoServiceTest.pas',
  uVendaServiceTest in '..\..\unittests\uVendaServiceTest.pas',
  uOutboxProcessorTest in '..\..\unittests\uOutboxProcessorTest.pas',
  uApiRouterTest in '..\..\unittests\uApiRouterTest.pas',
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
  uLogger in '..\..\sources\Infrastructure\Logging\uLogger.pas',
  connection.interfaces in '..\..\sources\Infrastructure\Interfaces\connection.interfaces.pas',
  repository.interfaces in '..\..\sources\Infrastructure\Interfaces\repository.interfaces.pas',
  uApiRouter in '..\..\sources\Presentation\API\Router\uApiRouter.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFDEF CONSOLE_TESTRUNNER}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger: ITestLogger;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  {$IFDEF CONSOLE_TESTRUNNER}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    runner.FailsOnNoAsserts := False;

    //tell the runner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;
    //Generate an NUnit compatible XML File
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);

    //Run tests
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
  {$ELSE}
  // Execução Padrão: Interface Gráfica VCL
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  DUnitX.Loggers.GUI.VCL.Run;
  {$ENDIF}
{$ENDIF}
end.
