# delphi-api-starter

Template de projeto Delphi para APIs REST com [Horse](https://github.com/HashLoad/horse) e [delphi-api-infra-faa](https://github.com/fabianoallex/delphi-api-infra-faa).

Inclui um domínio `Exemplo` funcional (CRUD completo com paginação, busca, ordenação e MCP) que serve como ponto de partida para qualquer novo domínio.

---

## Pré-requisitos

- RAD Studio / Delphi 11 Alexandria ou superior
- Firebird 2.5+ (driver `fbclient.dll` 32-bit no PATH ou configurado via `FB_CLIENT_DIR`)
- Git com suporte a submodules

---

## Criando um novo projeto

### Via GitHub (recomendado)

1. Clique em **"Use this template"** → **"Create a new repository"**
2. Dê um nome ao seu repositório e confirme
3. Clone com submodules:

```bash
git clone --recurse-submodules https://github.com/seu-usuario/meu-projeto
cd meu-projeto
```

### Clone direto

```bash
git clone --recurse-submodules https://github.com/fabianoallex/delphi-api-starter meu-projeto
cd meu-projeto
```

---

## Configuração

### 1. Criar o banco de dados Firebird

O arquivo `.fdb` precisa existir antes de rodar o projeto pela primeira vez. Crie-o com o `isql` (ferramenta incluída na instalação do Firebird):

```bash
"C:\Program Files\Firebird\Firebird_2_5\isql.exe" -user SYSDBA -password masterkey
```

Dentro do prompt `isql`, execute:

```sql
CREATE DATABASE 'C:\delphi-api\bd.fdb'
  USER 'SYSDBA' PASSWORD 'masterkey'
  DEFAULT CHARACTER SET UTF8;
EXIT;
```

> O diretório `C:\delphi-api\` precisa existir antes. Crie-o manualmente se necessário.

### 2. Configurar o app.ini

Edite o `app.ini` na raiz do projeto com o caminho do banco recém-criado:

```ini
[database]
DB_PATH=C:\delphi-api\bd.fdb
DB_USER=SYSDBA
DB_PASSWORD=masterkey
FB_CLIENT_DIR=C:\Program Files\Firebird\Firebird_2_5\WOW64

[server]
SERVER_PORT=9000
BASE_URL=http://localhost:9000
```

> `FB_CLIENT_DIR` aponta para a pasta que contém a `fbclient.dll` 32-bit. Em instalações 64-bit do Windows, ela fica em `WOW64\` fora do PATH — por isso o caminho explícito é necessário.

Todas as chaves do `app.ini` também podem ser fornecidas como variáveis de ambiente, que têm precedência sobre o arquivo.

---

## Compilando e executando

### Primeira compilação

Na primeira vez, é necessário compilar o arquivo de recursos SQL manualmente antes de abrir o projeto no Delphi:

```bash
cd sql
queries.bat
```

Isso gera `sql\queries.res`, que o projeto referencia via `{$R 'sql\queries.res'}`. Nas compilações seguintes, o Delphi IDE atualiza o `.res` automaticamente via o target `BeforeBuild` do `.dproj`.

### Build e execução

1. Abra `Api.Starter.dproj` no Delphi IDE
2. Compile (`Ctrl+F9`)
3. Execute — o servidor aplica as migrations automaticamente e sobe na porta configurada

Endpoints disponíveis após subir:

| URL | Descrição |
|---|---|
| `GET /health` | Health check do banco |
| `GET /swagger` | Swagger UI |
| `GET /mcp` | Todas as tools MCP |
| `GET /mcp/exemplos` | Tools MCP do domínio Exemplo |
| `GET /exemplos` | Listar (paginado, com busca e ordenação) |
| `GET /exemplos/:id` | Buscar por ID |
| `POST /exemplos` | Criar |
| `PATCH /exemplos/:id` | Atualizar (parcial) |
| `DELETE /exemplos/:id` | Excluir |

---

## Adicionando seu próprio domínio

Renomeie ou copie o domínio `Exemplo` seguindo estes passos:

### 1. Criar os arquivos Pascal

```
src/Domain/Pedido/
  Pedido.DTOs.pas
  Pedido.Repository.pas
  Pedido.Service.pas
  Pedido.Controller.pas
```

Use `src/Domain/Exemplo/` como referência — estrutura idêntica.

### 2. Criar os arquivos SQL

```
sql/
  PEDIDO.FIND.sql
  PEDIDO.FIND_COUNT.sql
  PEDIDO.FIND_BY_ID.sql
  PEDIDO.INSERT.sql
  PEDIDO.UPDATE.sql
  PEDIDO.DELETE.sql
```

### 3. Registrar os SQLs em `sql/queries.rc`

```
PEDIDO.FIND       RCDATA "PEDIDO.FIND.sql"
PEDIDO.FIND_COUNT RCDATA "PEDIDO.FIND_COUNT.sql"
...
```

Recompile o resource (ou deixe o build automático fazer isso):

```bash
cd sql
queries.bat
```

### 4. Registrar no `Api.Starter.dpr`

Adicione as 4 units do domínio ao `uses` e chame `TPedidoController.RegisterRoutes` no `begin`.

### 5. Adicionar a migration

Crie `sql/MIG.000X.sql` com o DDL da tabela e adicione à constante `MIGRATIONS` no DPR.

---

## Estrutura do projeto

```
.
├── Api.Starter.dpr          — programa principal
├── Api.Starter.dproj        — configuração do projeto Delphi
├── app.ini                  — configurações de ambiente
├── infra/                   — submodule delphi-api-infra-faa
├── modules/
│   └── horse/               — submodule Horse (framework HTTP)
├── sql/
│   ├── queries.rc           — registro dos arquivos SQL como resources
│   ├── queries.bat          — compila queries.rc → queries.res
│   ├── MIG.0001.sql         — migration: cria tabela EXEMPLO
│   ├── EXEMPLO.FIND.sql
│   ├── EXEMPLO.FIND_COUNT.sql
│   ├── EXEMPLO.FIND_BY_ID.sql
│   ├── EXEMPLO.INSERT.sql
│   ├── EXEMPLO.UPDATE.sql
│   └── EXEMPLO.DELETE.sql
└── src/
    └── Domain/
        └── Exemplo/
            ├── Exemplo.DTOs.pas
            ├── Exemplo.Repository.pas
            ├── Exemplo.Service.pas
            └── Exemplo.Controller.pas
```

---

## Middlewares disponíveis

O DPR já tem todos os middlewares da infra configurados. Logger e ErrorHandler estão ativos por padrão; os demais estão comentados para habilitar conforme necessário:

```pascal
// Logger — PRIMEIRO (captura status correto de erros)
THorse.Use(TLoggerMiddleware.New);

// ErrorHandler — converte exceções em respostas JSON padronizadas
THorse.Use(TErrorHandlerMiddleware.New);

// Rate limiting — descomente para habilitar (60 req/min por IP)
// THorse.Use(TRateLimitMiddleware.New(60, 60));

// CORS — descomente para habilitar
// THorse.Use(TCorsMiddleware.New);                            // dev: libera *
// THorse.Use(TCorsMiddleware.New('https://app.example.com')); // produção

// Autenticação Bearer — descomente e configure API_KEY no app.ini
// THorse.Use(TAuthMiddleware.Bearer(
//   function(const AToken: string): Boolean
//   begin
//     Result := AToken = TAppConfig.Get('API_KEY', '');
//   end,
//   ['/health', '/swagger']));
```

---

## Referência

- [delphi-api-infra-faa](https://github.com/fabianoallex/delphi-api-infra-faa) — biblioteca de infraestrutura (padrões, convenções e CLAUDE.md)
- [Horse](https://github.com/HashLoad/horse) — framework HTTP para Delphi
