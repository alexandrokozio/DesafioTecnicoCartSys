unit uAppConfig;

interface

type
  TDatabaseConfig = record
    Server: string;
    Port: Integer;
    Database: string;
    UserName: string;
    Password: string;
    CharacterSet: string;
  end;

  // API REST exposta pelo ERP Vendas (recebe webhooks do Financeiro).
  TApiConfig = record
    Habilitada: Boolean;
    Porta: Integer;
    Bind: string;
    ApiKey: string;
  end;

  // Cliente da API REST do ERP Financeiro.
  TFinanceiroConfig = record
    BaseUrl: string;
    ApiKey: string;
    TimeoutMs: Integer;
  end;

  TSmtpConfig = record
    Host: string;
    Porta: Integer;
    Usuario: string;
    Senha: string;
    UsarTLS: Boolean;
    Remetente: string;
    NomeRemetente: string;
  end;

  TOutboxConfig = record
    Habilitado: Boolean;
    IntervaloSegundos: Integer;
    LoteMaximo: Integer;
    MaxTentativas: Integer;
  end;

  TAppConfig = class
  public
    class function ArquivoConfiguracao: string;
    class function Database: TDatabaseConfig;
    class function Api: TApiConfig;
    class function Financeiro: TFinanceiroConfig;
    class function Smtp: TSmtpConfig;
    class function Outbox: TOutboxConfig;
  end;

implementation

uses
  System.SysUtils,
  System.IniFiles;

const
  BANCO_PADRAO = 'CARTSYS_ERP_VENDAS.FDB';
  URL_API_FINANCEIRO_PADRAO = 'http://localhost:5001/api/v1';

function AbrirIni: TMemIniFile;
begin
  Result := TMemIniFile.Create(TAppConfig.ArquivoConfiguracao, TEncoding.UTF8);
end;

class function TAppConfig.ArquivoConfiguracao: string;
begin
  Result := ChangeFileExt(ParamStr(0), '.ini');
end;

class function TAppConfig.Database: TDatabaseConfig;
var
  LIni: TMemIniFile;
begin
  LIni := AbrirIni;
  try
    Result.Server := LIni.ReadString('Database', 'Server', 'localhost');
    Result.Port := LIni.ReadInteger('Database', 'Port', 3050);
    Result.Database := LIni.ReadString('Database', 'Database',
      IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + BANCO_PADRAO);
    Result.UserName := LIni.ReadString('Database', 'UserName', 'SYSDBA');
    Result.Password := LIni.ReadString('Database', 'Password', 'masterkey');
    Result.CharacterSet := LIni.ReadString('Database', 'CharacterSet', 'UTF8');
  finally
    LIni.Free;
  end;
end;

class function TAppConfig.Api: TApiConfig;
var
  LIni: TMemIniFile;
begin
  LIni := AbrirIni;
  try
    Result.Habilitada := LIni.ReadBool('Api', 'Habilitada', True);
    Result.Porta := LIni.ReadInteger('Api', 'Porta', 9000);
    Result.Bind := LIni.ReadString('Api', 'Bind', '0.0.0.0');
    Result.ApiKey := LIni.ReadString('Api', 'ApiKey', EmptyStr);
  finally
    LIni.Free;
  end;
end;

class function TAppConfig.Financeiro: TFinanceiroConfig;
var
  LIni: TMemIniFile;
begin
  LIni := AbrirIni;
  try
    Result.BaseUrl := LIni.ReadString('Financeiro', 'BaseUrl', URL_API_FINANCEIRO_PADRAO);
    Result.ApiKey := LIni.ReadString('Financeiro', 'ApiKey', EmptyStr);
    Result.TimeoutMs := LIni.ReadInteger('Financeiro', 'TimeoutMs', 10000);
  finally
    LIni.Free;
  end;
end;

class function TAppConfig.Smtp: TSmtpConfig;
var
  LIni: TMemIniFile;
begin
  LIni := AbrirIni;
  try
    Result.Host := LIni.ReadString('Smtp', 'Host', 'localhost');
    Result.Porta := LIni.ReadInteger('Smtp', 'Porta', 25);
    Result.Usuario := LIni.ReadString('Smtp', 'Usuario', EmptyStr);
    Result.Senha := LIni.ReadString('Smtp', 'Senha', EmptyStr);
    Result.UsarTLS := LIni.ReadBool('Smtp', 'UsarTLS', False);
    Result.Remetente := LIni.ReadString('Smtp', 'Remetente', 'vendas@cartsys.local');
    Result.NomeRemetente := LIni.ReadString('Smtp', 'NomeRemetente', 'CartSys ERP Vendas');
  finally
    LIni.Free;
  end;
end;

class function TAppConfig.Outbox: TOutboxConfig;
var
  LIni: TMemIniFile;
begin
  LIni := AbrirIni;
  try
    Result.Habilitado := LIni.ReadBool('Outbox', 'Habilitado', True);
    Result.IntervaloSegundos := LIni.ReadInteger('Outbox', 'IntervaloSegundos', 15);
    Result.LoteMaximo := LIni.ReadInteger('Outbox', 'LoteMaximo', 20);
    Result.MaxTentativas := LIni.ReadInteger('Outbox', 'MaxTentativas', 10);
  finally
    LIni.Free;
  end;
end;

end.
