# CartSys — Desafio Técnico: ERP Vendas (Delphi) + ERP Financeiro (.NET)

![Delphi](https://img.shields.io/badge/Delphi-12.1%20Athens-EE1F35)
![.NET](https://img.shields.io/badge/.NET-10-512BD4)
![Firebird](https://img.shields.io/badge/Firebird-5.0-F40F02)
![SQL Server](https://img.shields.io/badge/SQL%20Server-LocalDB-CC2927)
![Testes](https://img.shields.io/badge/testes-94%20automatizados-2EA44F)

Dois sistemas independentes, cada um com seu banco de dados, integrados por **API REST
nos dois sentidos**:

- **ERP Vendas (Delphi / Firebird):** cadastro de clientes, produtos e vendas; envio
  automático da confirmação do pedido por e-mail após a quitação.
- **ERP Financeiro (.NET / SQL Server):** API REST para quitação e cancelamento/estorno
  de vendas, consulta de informações financeiras e resumo financeiro por período.

Os dados de exemplo são todos fictícios.

---

## Sumário

- [Arquitetura](#arquitetura)
- [Versões utilizadas](#versões-utilizadas)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Pré-requisitos](#pré-requisitos)
- [Configuração e execução](#configuração-e-execução)
- [Testes automatizados](#testes-automatizados)
- [Atendimento aos requisitos mínimos](#atendimento-aos-requisitos-minimos)
- [Documentação detalhada](#documentação-detalhada)

---

## Arquitetura

Princípios adotados nos dois sistemas:

| Princípio | Como foi aplicado |
|---|---|
| Camadas / DDD | Domain → Application → Infrastructure → Presentation; regras de negócio nas entidades |
| Práticas programação | POO, clean code, SOLID e design patterns |
| Transação Outbox | Toda integração é gravada na mesma transação da operação e entregue por um worker. Nenhuma chamada HTTP ocorre dentro da transação da tela. Eventos de venda são entregues na ordem que ocorreram |
| Autoridade | O ERP Vendas é dono do cadastro; o ERP Financeiro é dono da quitação |
| Segurança | Uso de KEY no Header nos dois sentidos |
| Erros padronizados | Em todas as APIs|

---

## Versões utilizadas

### Ambiente de desenvolvimento e validação

| Item | Versão |
|---|---|
| Sistema operacional | Windows 11  |
| Embarcadero Delphi | **12.1 Athens**, Community Edition  |
| Firebird (servidor e `fbclient.dll`) | **5.0** |
| .NET SDK | **10.0.401** (runtime .NET / ASP.NET Core 10.0.12) |
| SQL Server | **LocalDB 17.0** (compatível com SQL Server 2019/2022/2025) |
| Visual Studio | **2026 18.10**, Community |

### ERP Vendas (Delphi)

| Componente / framework | Versão | Uso |
|---|---|---|
| VCL | Delphi 12.1 | Interface desktop |
| FireDAC | Delphi 12.1 | Acesso ao Firebird, pool de conexões |
| Indy | 10.6.2 (Delphi 12.1) | Servidor HTTP (`TIdHTTPWebBrokerBridge`) e SMTP (`TIdSMTP`) |
| WebBroker | Delphi 12.1 | Roteamento da API embutida |
| System.Net.HttpClient | Delphi 12.1 | Cliente REST do Financeiro (WinHTTP) |
| System.JSON | Delphi 12.1 | Serialização do contrato REST |
| DUnitX | Delphi 12.1 | Testes unitários |
| Plataforma | Win32 | — |

### ERP Financeiro (.NET)

| Pacote / framework | Versão | Uso |
|---|---|---|
| .NET / ASP.NET Core | 10.0 | API REST (Minimal APIs) |
| Microsoft.EntityFrameworkCore.SqlServer | 10.0.12 | Persistência (Entity Framework) |
| Microsoft.EntityFrameworkCore.Design / dotnet-ef | 10.0.12 | Migrations |
| Microsoft.Extensions.Hosting.WindowsServices | 10.0.12 | Execução como serviço do Windows |
| Microsoft.Extensions.Http / Options.DataAnnotations | 10.0.12 | Cliente HTTP do ERP Vendas / validação de configuração |
| Microsoft.AspNetCore.OpenApi | 10.0.12 | Documento OpenAPI |
| Swashbuckle.AspNetCore.SwaggerUI | 10.2.3 | Swagger UI |
| xUnit / xunit.runner.visualstudio | 2.9.3 / 3.1.4 | Testes |
| FluentAssertions | 7.2.2 | Asserções |

As versões dos pacotes são centralizadas em `Financeiro/Directory.Packages.props`.

---

## Estrutura do repositório

```
DesafioTecnicoCartSys/
├── README.md                           este arquivo
├── docs/                               enunciado do desafio
├── Vendas/                             ERP Vendas (Delphi)
│   ├── sources/
│   │   ├── Domain/                    entidades e regras de negócio
│   │   ├── Application/               casos de uso, outbox, portas de integração
│   │   ├── Infrastructure/            FireDAC, DAOs, HTTP, SMTP, log, configuração
│   │   │   └── Database/schema_vendas_firebird.sql   criação do banco + dados de exemplo
│   │   ├── Presentation/              Desktop (VCL) e API (Indy/WebBroker)
│   │   └── CompositionRoot/           montagem das dependências
│   ├── unittests/                     testes DUnitX
│   ├── packages/d12/                  projetos Delphi 12 (.groupproj, .dproj) e ERP.Vendas.ini.example
└── Financeiro/                        ERP Financeiro (.NET)
    ├── Financeiro.slnx
    ├── Financeiro.Domain/             agregado VendaFinanceira
    ├── Financeiro.Application/        casos de uso, consultas, processador de notificações
    ├── Financeiro.Infrastructure/     EF Core, migrations, outbox, cliente do ERP Vendas
    ├── Financeiro.API/                API REST + worker de notificações
    ├── Financeiro.*.Tests/            testes (domínio, aplicação)
    ├── Database/schema_financeiro_sqlserver.sql   script gerado das migrations
```

---

## Pré-requisitos

| Para | Instalar |
|---|---|
| ERP Vendas | Delphi 12 (Community Edition ou superior) e Firebird 3.0+ (servidor) |
| ERP Financeiro | .NET SDK 10 e SQL Server (LocalDB, Express ou superior) |
| E-mail (opcional) | Servidor SMTP de teste |

---

## Configuração e execução

> Portas usadas: **9000** (API do ERP Vendas), **5001** (API do ERP Financeiro),
> **3050** (Firebird) e **25** (SMTP de teste, configurável).

### 1. Clonar o repositório

```powershell
git clone <url-do-repositorio> DesafioTecnicoCartSys
cd DesafioTecnicoCartSys
```

### 2. ERP Vendas: banco de dados (Firebird)

1. Confirme que o serviço do Firebird está em execução.
2. Edite o caminho do banco nas linhas `CREATE DATABASE` e `CONNECT` de
   `Vendas/sources/Infrastructure/Database/schema_vendas_firebird.sql`
   (ex.: `localhost:C:\CartSys\CARTSYS_ERP_VENDAS.FDB`).
3. Execute o script com o `isql` do Firebird:

   ```powershell
   & "C:\Program Files\Firebird\Firebird_5_0\isql.exe" -user SYSDBA -password masterkey `
     -i Vendas\sources\Infrastructure\Database\schema_vendas_firebird.sql
   ```

   O script cria tabelas, índices e **dados de exemplo** (6 clientes, 12 produtos/serviços,
   5 vendas em todos os status) e agenda o envio dessas vendas ao Financeiro.

### 3. ERP Vendas: compilação

1. Abra e Build All `Vendas/packages/d12/ERP.Vendas_group.groupproj` no Delphi 12.
2. O executável é gerado em `Vendas/packages/d12/out/ERP.Vendas.exe`.
3. Talvez seja necessário copiar para a mesma pasta a `fbclient.dll` de 32 bits do Firebird e as DLLs que a
   acompanham.

### 4. ERP Vendas: configuração

Copie `Vendas/packages/d12/ERP.Vendas.ini.example` para
`Vendas/packages/d12/out/ERP.Vendas.ini` e ajuste:

```ini
[Database]
Database=C:\CartSys\CARTSYS_ERP_VENDAS.FDB   ; mesmo caminho usado no script
UserName=SYSDBA
Password=masterkey

[Api]
Porta=9000
Bind=127.0.0.1                  ; somente local (evita o aviso do Firewall)
ApiKey=troque-esta-chave-vendas ; = ErpVendas:ApiKey do Financeiro

[Financeiro]
BaseUrl=http://localhost:5001/api/v1
ApiKey=troque-esta-chave-financeiro ; = Seguranca:ApiKeys:ErpVendas do Financeiro

[Smtp]
Host=localhost
Porta=25
```

> **As chaves precisam ser iguais nos dois sistemas** (tabela abaixo). Sem `[Api] ApiKey`,
> a API do ERP Vendas recusa as chamadas do Financeiro (HTTP 401).

| ERP Vendas (`ERP.Vendas.ini`) | ERP Financeiro (`Financeiro.API/appsettings.json`) |
|---|---|
| `[Api] ApiKey` | `ErpVendas:ApiKey` |
| `[Financeiro] ApiKey` | `Seguranca:ApiKeys:ErpVendas` |
| `[Api] Porta` | `ErpVendas:BaseUrl` |
| `[Financeiro] BaseUrl` | `Kestrel:Endpoints:Http:Url` |

### 5. ERP Financeiro: API

```powershell
cd Financeiro
dotnet run --project Financeiro.API
```

- API: <http://localhost:5001/api/v1>. Swagger: <http://localhost:5001/swagger>.
- O banco `CartsysFinanceiro` é **criado automaticamente** (migrations) na primeira execução.
  Alternativa manual: `Financeiro/Database/schema_financeiro_sqlserver.sql`.
- Para outro SQL Server, altere `ConnectionStrings:Financeiro` em
  `Financeiro/Financeiro.API/appsettings.json`.

### 6. ERP Vendas: execução

Execute `Vendas/packages/d12/out/ERP.Vendas.exe`. A API embutida e o worker de integração
iniciam em segundo plano; a barra de status mostra o endereço da API e a última sincronização.

---

## Testes automatizados

| Sistema | Como executar | Testes |
|---|---|---|
| ERP Financeiro | `cd Financeiro` → `dotnet test` | 44: domínio (34), aplicação (10) |
| ERP Vendas | Delphi: abrir `ERP.Vendas.Tests.dproj` → executar (DUnitX) | 50: entidade venda (10), serviço de vendas (10), clientes (6), produtos (6), outbox (10), roteador da API (8) |

Os testes dos dois sistemas usam *fakes* em memória e não dependem de banco ou rede.

---

## Atendimento aos requisitos mínimos

| Requisito do desafio | Situação |
|---|---|
| CRUD de clientes, produtos e vendas (Delphi) | ✅ |
| Delphi 12, FireDAC, Firebird | ✅ Delphi 12.1, FireDAC, Firebird 3.0+ (validado no 5.0) |
| Integração Vendas ↔ Financeiro via API REST | ✅ nos dois sentidos, com outbox e retentativa |
| Quitação e cancelamento de vendas (C#) | ✅ incluindo estorno de venda quitada |
| Consulta de informações financeiras (C#) | ✅ API: filtros, detalhe com itens, resumo por status no período |
| Relatório financeiro das vendas (C#) | ⏳ TO-DO |
| Entity Framework | ✅ Entity Framework Core 10 com migrations |
| Envio automático do relatório por e-mail após a quitação | ⏳ TO-DO, Criado e-mail de confirmação do pedido (HTML) para demonstração |
| Relatório de confirmação de pedido (Delphi, ReportBuilder) | ⏳ TO-DO |
| DevExpress (Delphi e C#) | ⏳ TO-DO |
| C# .NET Framework 4.8 | ⚠️ desenvolvido em NET 10 por decisão pessoal |

---

## Documentação detalhada API

- API do Financeiro: Swagger em <http://localhost:5001/swagger> (com a API em execução)
