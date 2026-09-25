# CartSys — ERP Vendas (Delphi)

Módulo de vendas desktop: **cadastro de clientes, produtos e vendas**, integrado ao
**ERP Financeiro** (.NET) por **API REST** nos dois sentidos. Após a quitação no
Financeiro, envia automaticamente ao cliente o **e-mail de confirmação do pedido**.

## Tecnologias

| Item | Escolha |
|---|---|
| Linguagem / IDE | Delphi 12 Athens (Community Edition) |
| Interface | VCL |
| Acesso a dados | FireDAC (pool de conexões) |
| Banco de dados | Firebird 3.0+ (validado no Firebird 5.0) |
| API REST embutida | WebBroker hospedado no Indy (`TIdHTTPWebBrokerBridge`) |
| Cliente HTTP | `System.Net.HttpClient` (WinHTTP, sem DLLs externas) |
| E-mail | Indy SMTP (`TIdSMTP`) |
| Testes | DUnitX |

> DevExpress e ReportBuilder (requisitos do edital) estão planejados para a próxima
> etapa. O e-mail de confirmação é hoje um HTML gerado por `TConfirmacaoPedidoEmail`;
> o PDF do ReportBuilder será anexado a ele sem alterar o fluxo.

## Funcionalidades

- **Clientes e produtos:** CRUD com validação no domínio (CPF/CNPJ único, e-mail, preço,
  estoque) e exclusão lógica (registros referenciados por vendas não são apagados).
- **Vendas:** inclusão/alteração com itens (preço unitário gravado como *snapshot*),
  cancelamento com motivo. Venda quitada ou cancelada não pode ser alterada.
- **Quitação:** feita exclusivamente no ERP Financeiro, que a informa ao ERP Vendas via API.
- **Confirmação do pedido por e-mail:** enviada automaticamente após a quitação.
- **Integração resiliente:** nenhuma chamada externa acontece dentro da transação da tela;
  tudo passa pelo **outbox** com retentativa.

## Arquitetura

Camadas (pasta `sources/`), com dependências apontando para o domínio:

```
Domain            Entidades com regras (TVenda.Quitar/Cancelar/Validar, TCliente, TProduto),
                  exceções de domínio
Application       Serviços (casos de uso), DTOs de leitura, portas de integração
                  (IFinanceiroGateway, IEmailSender), processador do outbox
Infrastructure    FireDAC (conexão em pool, Unit of Work, DAOs), configuração (.ini), log,
                  gateway HTTP do Financeiro, SMTP, worker do outbox, mapeamento JSON
Presentation      Desktop VCL (forms) e API REST (roteador, controllers, WebModule, servidor)
CompositionRoot   TServiceFactory: único ponto que conhece as implementações concretas
SharedKernel      Utilitários sem dependência de VCL
```

Decisões principais:

- **Regras no domínio:** transições de status só por métodos de negócio
  (`PENDENTE → QUITADA`, `PENDENTE | QUITADA → CANCELADA`; cancelada é estado final).
  O status sempre vem do banco, nunca da tela.
- **Unit of Work com aninhamento:** os serviços não chamam `Commit/Rollback`; só o nível
  mais externo confirma e um rollback em qualquer nível desfaz tudo.
- **Transactional Outbox (`INTEGRACAO_OUTBOX`):** salvar/cancelar venda e receber quitação
  gravam o evento na mesma transação. Um worker (thread) entrega ao Financeiro ou envia o
  e-mail, com backoff exponencial (30 s, 60 s, 120 s… até 1 h; máx. 10 tentativas).
  Eventos de uma mesma venda são processados em ordem; falhas definitivas (HTTP 4xx,
  cliente sem e-mail) não são retentadas.
- **Idempotência:** reenvios de quitação/cancelamento pelo Financeiro não geram efeito duplicado
  nem e-mail repetido.
- **Thread safety:** cada contexto (tela, requisição HTTP, ciclo do worker) usa sua própria
  conexão, obtida do pool do FireDAC; o WebModule é criado por requisição.
- **Interface ciente de DPI:** controles criados em código têm medidas convertidas pela escala
  do Windows (`TFormHelper`), e os campos são posicionados pela altura real dos rótulos.

## Integração com o ERP Financeiro

### API exposta pelo ERP Vendas (`http://127.0.0.1:9000/api/v1`, header `X-Api-Key`)

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/vendas/{id}/quitacao` | `{ dataQuitacao?, formaPagamento? }` — registra a quitação e agenda o e-mail |
| `POST` | `/vendas/{id}/cancelamento` | `{ motivo, dataCancelamento? }` — cancelamento/estorno feito no Financeiro |
| `GET` | `/vendas/{id}` | Venda com cliente e itens |
| `GET` | `/health` | Disponibilidade da API e do banco (sem autenticação) |

Erros: `{ "codigo": "...", "mensagem": "..." }` — 400, 401, 404, 405, 422 (regra de negócio), 500.

### Chamadas feitas ao ERP Financeiro (pelo outbox)

| Evento | Chamada |
|---|---|
| Venda incluída/alterada | `PUT {Financeiro}/vendas/{id}` (upsert idempotente com o estado atual da venda) |
| Venda cancelada no ERP Vendas | `POST {Financeiro}/vendas/{id}/cancelamento` |

### Fluxo completo

```
Tela de vendas ──salva──► VENDA + INTEGRACAO_OUTBOX (1 transação)
                                   │ worker
                                   ▼
                         PUT Financeiro /vendas/{id}
Operador financeiro quita ──► Financeiro ──POST /vendas/{id}/quitacao──► ERP Vendas
                                   VENDA = QUITADA + evento ENVIAR_EMAIL_CONFIRMACAO
                                   │ worker
                                   ▼
                         E-mail de confirmação ao cliente (SMTP)
```

## Como executar

### 1. Banco de dados

1. Firebird 3.0 ou superior em execução (porta 3050).
2. Ajuste o caminho do `CREATE DATABASE`/`CONNECT` em
   `sources/Infrastructure/Database/schema_vendas_firebird.sql`.
3. Execute a partir da pasta `Vendas`:

   ```powershell
   isql -user SYSDBA -password masterkey -i sources\Infrastructure\Database\schema_vendas_firebird.sql
   ```

O script cria tabelas, índices e **dados de exemplo do segmento de cartórios**
(clientes, produtos/serviços CartSys e 5 vendas em todos os status), e agenda o envio
dessas vendas ao Financeiro. Os dados são fictícios.

### 2. Configuração

Copie `packages/d12/ERP.Vendas.ini.example` para a pasta do executável como
`ERP.Vendas.ini` e ajuste:

| Seção | Chave | Descrição |
|---|---|---|
| `[Database]` | `Database`, `Server`, `Port`, `UserName`, `Password` | Banco Firebird |
| `[Api]` | `Porta`, `Bind`, `ApiKey` | API embutida. `Bind=127.0.0.1` evita o aviso do Firewall quando o Financeiro roda na mesma máquina. `ApiKey` = `ErpVendas:ApiKey` do Financeiro |
| `[Financeiro]` | `BaseUrl`, `ApiKey`, `TimeoutMs` | API do Financeiro. `ApiKey` = `Seguranca:ApiKeys:ErpVendas` do Financeiro |
| `[Smtp]` | `Host`, `Porta`, `Usuario`, `Senha`, `UsarTLS`, `Remetente` | Servidor de e-mail. Para testes: smtp4dev ou Papercut |
| `[Outbox]` | `IntervaloSegundos`, `LoteMaximo`, `MaxTentativas` | Worker de integração |

Sem a chave `[Api] ApiKey` a API recusa todas as chamadas protegidas (401).

### 3. Compilação e execução

1. Abra `packages/d12/ERP.Vendas_group.groupproj` no Delphi 12.
2. **Build All** (a Community Edition não compila por linha de comando).
3. Execute `packages/d12/out/ERP.Vendas.exe`. As DLLs do cliente Firebird (`fbclient.dll` e
   dependências) devem estar na mesma pasta.

Ao abrir, o sistema inicia a API e o worker de integração em segundo plano; a barra de
status mostra o endereço da API e o resultado da última sincronização.

### Teste integrado com o Financeiro

Suba a API do Financeiro ([`../Financeiro/README.md`](../Financeiro/README.md)), abra o ERP Vendas e:

1. as vendas pendentes do outbox são enviadas ao Financeiro em até 15 s;
2. quite uma venda pela API do Financeiro (`POST /financeiro/vendas/{vendaId}/quitacao`,
   pelo Swagger) → a venda fica QUITADA no ERP Vendas
   e o e-mail de confirmação é enviado;
3. na tela de vendas, **Atualizar** mostra o novo status.

## Testes

Projeto `packages/d12/ERP.Vendas.Tests` (DUnitX; executa com a interface gráfica do DUnitX):

| Unit | Cobertura |
|---|---|
| `uVendaTest` | Regras da entidade venda (quitação, cancelamento, estorno, validação) |
| `uVendaServiceTest` | Casos de uso da venda, outbox, idempotência da quitação |
| `uClienteServiceTest` / `uProdutoServiceTest` | Validações de cadastro |
| `uOutboxProcessorTest` | Envio ao Financeiro e e-mail: sucesso, falha transitória/definitiva, backoff |
| `uApiRouterTest` | Rotas, autenticação, tradução de erros HTTP |

Os testes usam fakes em memória (`MocksTest.pas`) e não dependem de banco ou rede.

## Diagnóstico

- **Log:** `logs\ERP.Vendas-AAAA-MM-DD.log` ao lado do executável (API, worker, falhas de integração).
- **Fila de integração:** tabela `INTEGRACAO_OUTBOX` (`STATUS`, `TENTATIVAS`, `ULTIMO_ERRO`,
  `PROXIMA_TENTATIVA`).
- **Porta 9000 ocupada:** o sistema continua operando; a barra de status indica a falha da API.
- **SMTP com TLS** (`UsarTLS=1`): requer `libeay32.dll` e `ssleay32.dll` ao lado do executável.
