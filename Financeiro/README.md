# CartSys — ERP Financeiro (API REST)

API REST do módulo financeiro: recebe as vendas do **ERP Vendas** (Delphi), registra
**quitações** e **cancelamentos/estornos**, oferece **consultas financeiras** e
**notifica o ERP Vendas** (webhooks) — que então envia o e-mail de confirmação ao cliente.

## Tecnologias

| Item | Escolha |
|---|---|
| Plataforma | .NET 10 (C# 14), ASP.NET Core Minimal APIs |
| Persistência | Entity Framework Core 10 + SQL Server (LocalDB por padrão), migrations |
| Hospedagem | Console **ou** Serviço do Windows (`UseWindowsService`) |
| Documentação | OpenAPI + Swagger UI (`/swagger`) |
| Testes | xUnit, FluentAssertions 7 (Apache 2.0) |

> **Nota sobre o edital:** o requisito mínimo cita .NET Framework 4.8. Optou-se por
> .NET 10 (LTS atual) por decisão de projeto: suporte de longo prazo, hospedagem
> como serviço, EF Core com migrations e desempenho superior. O Entity Framework
> (requisito) é atendido pelo EF Core. DevExpress e o relatório financeiro ficam para a
> etapa do front-end do Financeiro.

## Arquitetura

```
Financeiro.Domain          Agregado VendaFinanceira (regras de quitação/cancelamento), eventos de domínio
Financeiro.Application     Casos de uso, DTOs, portas (repositório, UoW, outbox, cliente do ERP Vendas),
                           processador de notificações com retentativa (backoff exponencial)
Financeiro.Infrastructure  EF Core (DbContext, mapeamentos, migrations, repositórios, consultas),
                           outbox transacional, cliente HTTP do ERP Vendas
Financeiro.API             Endpoints, autenticação por API key, tratamento de erros, worker de webhooks
```

Decisões principais:

- **Transactional Outbox:** quitar/cancelar gera um evento de domínio que o `DbContext`
  converte em linha de `OUTBOX_NOTIFICACAO` **no mesmo `SaveChanges`**. O worker entrega
  ao ERP Vendas com retentativa (30 s, 60 s, 120 s… até 1 h; máx. 10 tentativas) e, se o
  ERP Vendas estiver fora do ar, interrompe o lote no primeiro erro de comunicação.
  Notificações de uma mesma venda são entregues em ordem.
- **Idempotência:** o `PUT` de venda é um upsert — reenvios com os mesmos dados não
  alteram nada; o cancelamento vindo do ERP Vendas também é idempotente.
- **Autoridade da quitação:** somente o Financeiro quita. Uma venda quitada/cancelada
  aqui não é alterada por reenvios do ERP Vendas (HTTP 422).
- **Concorrência otimista:** token `VERSAO` na venda → HTTP 409 (o ERP Vendas retenta).

## Contrato REST (`/api/v1`, autenticação `X-Api-Key`)

Integração com o ERP Vendas:

| Método | Rota | Descrição |
|---|---|---|
| `PUT` | `/vendas/{vendaId}` | Cria/atualiza a venda (201 criada, 200 atualizada/sem alteração) |
| `POST` | `/vendas/{vendaId}/cancelamento` | `{ motivo, dataCancelamento? }` cancelamento feito no ERP Vendas |
| `GET` | `/vendas/{vendaId}` | Situação financeira da venda |

Operação financeira:

| Método | Rota | Descrição |
|---|---|---|
| `GET` | `/financeiro/vendas?status=&dataInicial=&dataFinal=&cliente=&limite=` | Consulta |
| `GET` | `/financeiro/vendas/{vendaId}` | Detalhe com itens |
| `POST` | `/financeiro/vendas/{vendaId}/quitacao` | `{ dataQuitacao?, formaPagamento? }` — notifica o ERP Vendas |
| `POST` | `/financeiro/vendas/{vendaId}/cancelamento` | `{ motivo }` cancela/estorna — notifica o ERP Vendas |
| `GET` | `/financeiro/resumo?dataInicial=&dataFinal=` | Totais por status e ticket médio |
| `GET` | `/health` | Disponibilidade (sem autenticação) |

Erros seguem o mesmo formato do ERP Vendas: `{ "codigo": "REGRA_DE_NEGOCIO", "mensagem": "..." }`
(400 requisição inválida, 401, 404, 409 conflito, 422 regra de negócio, 500).

Webhooks enviados ao ERP Vendas (`ErpVendas:BaseUrl`):
`POST vendas/{id}/quitacao { dataQuitacao, formaPagamento }` e
`POST vendas/{id}/cancelamento { motivo, dataCancelamento }`.

## Como executar

Pré-requisitos: SDK .NET 10 e SQL Server LocalDB (instalado com o Visual Studio).

```powershell
cd Financeiro
dotnet run --project Financeiro.API
# API:      http://localhost:5001
# Swagger:  http://localhost:5001/swagger
```

O banco `CartsysFinanceiro` é criado/atualizado automaticamente na inicialização
(`Database:AplicarMigracoesAoIniciar`). Alternativa manual: `Database/schema_financeiro_sqlserver.sql`
(script idempotente gerado das migrations).

### Configuração (`Financeiro.API/appsettings.json`)

| Chave | Descrição |
|---|---|
| `ConnectionStrings:Financeiro` | SQL Server (padrão: LocalDB) |
| `Seguranca:ApiKeys:*` | Chaves aceitas no `X-Api-Key`. `ErpVendas` deve ser igual a `[Financeiro] ApiKey` do `ERP.Vendas.ini` |
| `ErpVendas:BaseUrl` / `ApiKey` | API do ERP Vendas; `ApiKey` deve ser igual a `[Api] ApiKey` do `ERP.Vendas.ini` |
| `Outbox:*` | Intervalo e lote do worker de notificações |

### Como serviço do Windows

```powershell
dotnet publish Financeiro.API -c Release -o C:\CartSys\Financeiro
sc.exe create CartSysFinanceiro binPath= "C:\CartSys\Financeiro\Financeiro.Api.exe" start= auto
sc.exe start CartSysFinanceiro
```

> A interface do operador financeiro (desktop, relatório financeiro) ainda não foi
> implementada; as operações financeiras são feitas pela API (Swagger ou chamadas HTTP
> com a chave `Seguranca:ApiKeys:Operador`).

## Teste integrado com o ERP Vendas

1. Firebird com o banco do ERP Vendas; `ERP.Vendas.ini` ao lado do `ERP.Vendas.exe` com as chaves
   coerentes (`[Financeiro] ApiKey` = `Seguranca:ApiKeys:ErpVendas`; `[Api] ApiKey` = `ErpVendas:ApiKey`).
   Detalhes em [`../Vendas/README.md`](../Vendas/README.md).
2. Servidor SMTP de teste em `[Smtp] Host/Porta` (ex.: smtp4dev ou Papercut).
3. Subir a API (`dotnet run --project Financeiro.API`) e abrir o `ERP.Vendas.exe`.
4. O outbox do ERP Vendas envia as vendas ao Financeiro (verificável em `GET /financeiro/vendas`).
5. Quitar uma venda (`POST /financeiro/vendas/{vendaId}/quitacao`) → o Financeiro notifica o
   ERP Vendas → a venda fica QUITADA lá e o e-mail de confirmação é enviado ao cliente.
6. Estornar uma venda quitada (`POST /financeiro/vendas/{vendaId}/cancelamento`) → a venda fica
   CANCELADA no ERP Vendas.

## Testes

```powershell
dotnet test
```

- `Financeiro.Domain.Tests` — regras do agregado (quitação, estorno, sincronização idempotente).
- `Financeiro.Application.Tests` — processador de notificações (retentativa, falhas definitivas, backoff).
