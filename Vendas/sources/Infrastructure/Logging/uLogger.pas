unit uLogger;

interface

uses
  System.SysUtils;

type
  TLogger = class
  private
    class var FLock: TObject;
    class procedure Escrever(const ANivel, AMensagem: string);
    class constructor Create;
    class destructor Destroy;
  public
    class procedure Info(const AMensagem: string); overload;
    class procedure Info(const AFormato: string; const AArgs: array of const); overload;
    class procedure Aviso(const AMensagem: string);
    class procedure Erro(const AMensagem: string; AErro: Exception = nil);
  end;

implementation

uses
  System.Classes,
  System.IOUtils;

class constructor TLogger.Create;
begin
  FLock := TObject.Create;
end;

class destructor TLogger.Destroy;
begin
  FLock.Free;
end;

class procedure TLogger.Escrever(const ANivel, AMensagem: string);
var
  LPasta, LLinha: string;
begin
  LLinha := Format('%s [%s] [T%d] %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), ANivel,
      TThread.CurrentThread.ThreadID, AMensagem]) + sLineBreak;

  TMonitor.Enter(FLock);
  try
    try
      LPasta := TPath.Combine(ExtractFilePath(ParamStr(0)), 'logs');
      ForceDirectories(LPasta);
      TFile.AppendAllText(
        TPath.Combine(LPasta, Format('%s-%s.log',
          [TPath.GetFileNameWithoutExtension(ParamStr(0)), FormatDateTime('yyyy-mm-dd', Date)])),
        LLinha, TEncoding.UTF8);
    except
      // O Log nunca deve interromper a operação.
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TLogger.Info(const AMensagem: string);
begin
  Escrever('INFO', AMensagem);
end;

class procedure TLogger.Info(const AFormato: string; const AArgs: array of const);
begin
  Escrever('INFO', Format(AFormato, AArgs));
end;

class procedure TLogger.Aviso(const AMensagem: string);
begin
  Escrever('AVISO', AMensagem);
end;

class procedure TLogger.Erro(const AMensagem: string; AErro: Exception);
begin
  if Assigned(AErro) then
    Escrever('ERRO', Format('%s | %s: %s', [AMensagem, AErro.ClassName, AErro.Message]))
  else
    Escrever('ERRO', AMensagem);
end;

end.
