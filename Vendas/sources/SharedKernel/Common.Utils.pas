unit Common.Utils;

interface

uses
  System.Variants,
  Data.DB;

type
  TUtils = class
  public
    class function DataOuNulo(AData: TDateTime): Variant;
    class function DataOuZero(AField: TField): TDateTime;
    class function TextoOuNulo(const ATexto: string): Variant;
  end;

implementation

uses
  System.SysUtils;

class function TUtils.DataOuNulo(AData: TDateTime): Variant;
begin
  if AData <= 0 then
    Result := Null
  else
    Result := AData;
end;

class function TUtils.DataOuZero(AField: TField): TDateTime;
begin
  if AField.IsNull then
    Result := 0
  else
    Result := AField.AsDateTime;
end;

class function TUtils.TextoOuNulo(const ATexto: string): Variant;
begin
  if ATexto.Trim.IsEmpty then
    Result := Null
  else
    Result := ATexto.Trim;
end;

end.
