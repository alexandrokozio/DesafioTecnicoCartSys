unit uVendaJsonMapper;

interface

uses
  System.JSON,
  uCliente,
  uVenda;

type
  // Contrato JSON da venda para o payload enviado ao Financeiro e na resposta de GET /api/v1/vendas/{id}
  TVendaJsonMapper = class
  public
    class function ToJson(AVenda: TVenda; ACliente: TCliente): TJSONObject;
    class function Moeda(AValor: Currency): TJSONNumber;
    class function DataOuNulo(AData: TDateTime): TJSONValue;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  uItemVenda;

class function TVendaJsonMapper.Moeda(AValor: Currency): TJSONNumber;
begin
  Result := TJSONNumber.Create(CurrToStrF(AValor, ffFixed, 2, TFormatSettings.Invariant));
end;

class function TVendaJsonMapper.DataOuNulo(AData: TDateTime): TJSONValue;
begin
  if AData <= 0 then
    Result := TJSONNull.Create
  else
    Result := TJSONString.Create(DateToISO8601(AData, False));
end;

class function TVendaJsonMapper.ToJson(AVenda: TVenda; ACliente: TCliente): TJSONObject;
var
  LCliente: TJSONObject;
  LItens: TJSONArray;
  LItem: TVendaItem;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('vendaId', TJSONNumber.Create(AVenda.Id));
    Result.AddPair('dataVenda', DataOuNulo(AVenda.DataVenda));
    Result.AddPair('status', StatusVendaToStr(AVenda.Status));
    Result.AddPair('valorTotal', Moeda(AVenda.ValorTotal));
    Result.AddPair('dataQuitacao', DataOuNulo(AVenda.DataQuitacao));
    Result.AddPair('dataCancelamento', DataOuNulo(AVenda.DataCancelamento));
    Result.AddPair('motivoCancelamento', AVenda.MotivoCancelamento);
    Result.AddPair('relatorioEnviado', TJSONBool.Create(AVenda.RelatorioEnviado));

    if Assigned(ACliente) then
    begin
      LCliente := TJSONObject.Create;
      Result.AddPair('cliente', LCliente);
      LCliente.AddPair('id', TJSONNumber.Create(ACliente.Id));
      LCliente.AddPair('nome', ACliente.Nome);
      LCliente.AddPair('documento', ACliente.CpfCnpj);
      LCliente.AddPair('email', ACliente.Email);
    end;

    LItens := TJSONArray.Create;
    Result.AddPair('itens', LItens);
    for LItem in AVenda.Itens do
      LItens.AddElement(
        TJSONObject.Create
          .AddPair('produtoId', TJSONNumber.Create(LItem.ProdutoId))
          .AddPair('descricao', LItem.ProdutoDescricao)
          .AddPair('quantidade', TJSONNumber.Create(LItem.Quantidade))
          .AddPair('precoUnitario', Moeda(LItem.PrecoUnitario))
          .AddPair('valorTotal', Moeda(LItem.ValorTotal)));
  except
    Result.Free;
    raise;
  end;
end;

end.
