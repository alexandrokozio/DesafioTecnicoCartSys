unit uServiceFactory;

interface

uses
  connection.interfaces,
  uClienteService,
  uProdutoService,
  uVendaService,
  uOutboxProcessor;

type
  TServiceFactory = class
  public
    class function New: IDBConnectionFactory;

    class function ClienteService(AConexao: IDBConnectionFactory): TClienteService;
    class function ProdutoService(AConexao: IDBConnectionFactory): TProdutoService;
    class function VendaService(AConexao: IDBConnectionFactory): TVendaService;
    class function OutboxProcessor(AConexao: IDBConnectionFactory): TOutboxProcessor;
  end;

implementation

uses
  connection.factory,
  connection.unitofwork,
  uAppConfig,
  uClienteDAO,
  uProdutoDAO,
  uVendaDAO,
  uOutboxDAO,
  uFinanceiroHttpGateway,
  uIndySmtpEmailSender;

class function TServiceFactory.New: IDBConnectionFactory;
begin
  Result := TDBConnectionFactory.New;
end;

class function TServiceFactory.ClienteService(AConexao: IDBConnectionFactory): TClienteService;
begin
  Result := TClienteService.Create(TUnitOfWork.New(AConexao), TClienteDAO.New(AConexao));
end;

class function TServiceFactory.ProdutoService(AConexao: IDBConnectionFactory): TProdutoService;
begin
  Result := TProdutoService.Create(TUnitOfWork.New(AConexao), TProdutoDAO.New(AConexao));
end;

class function TServiceFactory.VendaService(AConexao: IDBConnectionFactory): TVendaService;
begin
  Result := TVendaService.Create(TUnitOfWork.New(AConexao), TVendaDAO.New(AConexao),
    TOutboxDAO.New(AConexao));
end;

class function TServiceFactory.OutboxProcessor(AConexao: IDBConnectionFactory): TOutboxProcessor;
var
  LConfig: TOutboxConfig;
begin
  LConfig := TAppConfig.Outbox;

  Result := TOutboxProcessor.Create(
    TUnitOfWork.New(AConexao),
    TOutboxDAO.New(AConexao),
    TVendaDAO.New(AConexao),
    TClienteDAO.New(AConexao),
    TFinanceiroHttpGateway.Create(TAppConfig.Financeiro),
    TIndySmtpEmailSender.Create(TAppConfig.Smtp),
    TPoliticaRetentativa.Padrao(LConfig.MaxTentativas),
    LConfig.LoteMaximo);
end;

end.
