unit connection.firedac;

interface

uses
  Data.DB,
  System.Classes,
  System.SysUtils,
  System.Variants,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Stan.Param,
  FireDAC.UI.Intf, FireDAC.VCLUI.Wait,
  FireDAC.Phys.Intf, FireDAC.Phys, FireDAC.Phys.IBBase, FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  connection.interfaces;

type
  TFDAConnection = class(TInterfacedObject, IDBConnection)
  private
    FConnection: TFDConnection;
    FNivelTransacao: Integer;

    procedure LoadConfiguration;
  public
    constructor Create;
    destructor Destroy; override;

    class function New: IDBConnection;
    function Connection: TCustomConnection;

    procedure Connect;
    function InTransaction: Boolean;
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;
  end;

  TFDAQuery = class(TInterfacedObject, IQuery)
  private
    FQuery: TFDQuery;
    FConnection: IDBConnection;
  public
    constructor Create(AConnection: IDBConnection);
    destructor Destroy; override;

    class function New(AConnection: IDBConnection): IQuery;

    function Query: TDataSet;

    function SQL(const AValue: string): IQuery;
    function AddParam(const AName: string; AValue: Variant): IQuery;

    function Open: IQuery; overload;
    function ExecSQL: IQuery; overload;

    function Open(const ASql: string): IQuery; overload;
    function ExecSQL(const ASql: string): IQuery; overload;
  end;

implementation

uses
  uAppConfig;

const
  CONNECTION_DEF_NAME = 'CARTSYS_ERP_VENDAS';

var
  GLockDefinicao: TObject;
  GDefinicaoRegistrada: Boolean = False;

{ TFDAConnection }

constructor TFDAConnection.Create;
begin
  inherited Create;
  FConnection := TFDConnection.Create(nil);
  LoadConfiguration;
end;

destructor TFDAConnection.Destroy;
begin
  FreeAndNil(FConnection);
  inherited;
end;

procedure RegistrarDefinicaoConexao;
var
  LConfig: TDatabaseConfig;
  LParams: TStringList;
begin
  TMonitor.Enter(GLockDefinicao);
  try
    if GDefinicaoRegistrada then
      Exit;

    LConfig := TAppConfig.Database;

    LParams := TStringList.Create;
    try
      LParams.Values['Protocol'] := 'TCPIP';
      LParams.Values['Server'] := LConfig.Server;
      LParams.Values['Port'] := LConfig.Port.ToString;
      LParams.Values['Database'] := LConfig.Database;
      LParams.Values['User_Name'] := LConfig.UserName;
      LParams.Values['Password'] := LConfig.Password;
      LParams.Values['CharacterSet'] := LConfig.CharacterSet;
      LParams.Values['LockTimeout'] := '15';
      LParams.Values['WaitOnLocks'] := 'True';
      LParams.Values['Pooled'] := 'True';
      LParams.Values['POOL_MaximumItems'] := '50';

      FDManager.AddConnectionDef(CONNECTION_DEF_NAME, 'FB', LParams);
    finally
      LParams.Free;
    end;

    GDefinicaoRegistrada := True;
  finally
    TMonitor.Exit(GLockDefinicao);
  end;
end;

procedure TFDAConnection.LoadConfiguration;
begin
  RegistrarDefinicaoConexao;

  FConnection.ConnectionDefName := CONNECTION_DEF_NAME;
  FConnection.LoginPrompt := False;
  FConnection.ResourceOptions.SilentMode := True;

  // Leituras fora de uma transação explícita usam a transação implícita do
  // FireDAC, que precisa ser encerrada ao fim do comando (AutoStop = True).
  // Com AutoStop = False ela ficava aberta após o primeiro SELECT e as
  // gravações posteriores "entravam" nela sem nunca receber commit.
  FConnection.TxOptions.AutoStart := True;
  FConnection.TxOptions.AutoStop := True;
end;

procedure TFDAConnection.Connect;
begin
  if FConnection.Connected then
    Exit;

  try
    FConnection.Connected := True;
  except
    on E: EFDDBEngineException do
      raise Exception.CreateFmt(
        'Falha ao conectar ao banco de dados Firebird.' + sLineBreak +
        'Arquivo: %s' + sLineBreak +
        'Erro: %s (Código: %d)',
        [TAppConfig.Database.Database, E.Message, E.ErrorCode]);
  end;
end;

function TFDAConnection.Connection: TCustomConnection;
begin
  Connect;
  Result := FConnection;
end;

class function TFDAConnection.New: IDBConnection;
begin
  Result := Self.Create;
end;

function TFDAConnection.InTransaction: Boolean;
begin
  // Somente transações explícitas (abertas pelo Unit of Work) contam; a
  // transação implícita de leitura do FireDAC não é uma transação de negócio.
  Result := FNivelTransacao > 0;
end;

procedure TFDAConnection.StartTransaction;
begin
  Connect;

  if FNivelTransacao = 0 then
  begin
    // Encerra uma eventual transação implícita de leitura ainda ativa (ex.:
    // cursor aberto) antes de iniciar a transação explícita.
    if FConnection.InTransaction then
      FConnection.Commit;
    FConnection.StartTransaction;
  end;

  Inc(FNivelTransacao);
end;

procedure TFDAConnection.Commit;
begin
  if FNivelTransacao = 0 then
    Exit;

  Dec(FNivelTransacao);

  // Chamadas aninhadas só confirmam quando o nível mais externo termina.
  if FNivelTransacao = 0 then
    FConnection.Commit;
end;

procedure TFDAConnection.Rollback;
begin
  if FNivelTransacao = 0 then
    Exit;

  // Rollback em qualquer nível desfaz a transação inteira.
  FNivelTransacao := 0;
  if FConnection.InTransaction then
    FConnection.Rollback;
end;

{ TFDAQuery }

constructor TFDAQuery.Create(AConnection: IDBConnection);
begin
  inherited Create;

  FConnection := AConnection;
  FQuery := TFDQuery.Create(nil);
  FQuery.Connection := FConnection.Connection as TFDConnection;
end;

destructor TFDAQuery.Destroy;
begin
  FreeAndNil(FQuery);

  inherited;
end;

class function TFDAQuery.New(AConnection: IDBConnection): IQuery;
begin
  Result := Self.Create(AConnection);
end;

function TFDAQuery.Query: TDataSet;
begin
  Result := FQuery;
end;

function TFDAQuery.SQL(const AValue: string): IQuery;
begin
  Result := Self;
  FQuery.SQL.Text := AValue;
end;

function TFDAQuery.AddParam(const AName: string; AValue: Variant): IQuery;
var
  LParam: TFDParam;
begin
  Result := Self;
  LParam := FQuery.ParamByName(AName);

  if VarIsNull(AValue) and (LParam.DataType = ftUnknown) then
    LParam.DataType := ftString;

  LParam.Value := AValue;
end;

function TFDAQuery.ExecSQL: IQuery;
begin
  Result := Self;
  FQuery.ExecSQL;
end;

function TFDAQuery.Open: IQuery;
begin
  Result := Self;
  FQuery.Open;
end;

function TFDAQuery.ExecSQL(const ASql: string): IQuery;
begin
  Result := Self.SQL(ASql).ExecSQL;
end;

function TFDAQuery.Open(const ASql: string): IQuery;
begin
  Result := Self.SQL(ASql).Open;
end;

initialization
  GLockDefinicao := TObject.Create;

finalization
  GLockDefinicao.Free;

end.
