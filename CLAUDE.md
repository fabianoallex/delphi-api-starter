# delphi-api-starter — Guia para Agentes de IA

Template de projeto para APIs REST em Delphi com Horse e [delphi-api-infra-faa](https://github.com/fabianoallex/delphi-api-infra-faa).
Consulte também o `CLAUDE.md` da infra (em `infra/CLAUDE.md`) para padrões detalhados de DTOs, Repository, Service e Controller.

---

## Estrutura essencial

```
Api.Starter.dpr       — programa principal; registra factories, migrations, middlewares e rotas
.env                  — configuração de ambiente (KEY=VALUE, não versionado)
.env.example          — template de configuração (versionado, sem segredos)
sql/
  queries.rc          — registra os arquivos SQL como resources (prefixo SQL_QUERIES_)
  queries.bat         — compila queries.rc → queries.res
  MIG.0001.sql        — primeira migration (deve criar SCHEMA_MIGRATIONS)
  EXEMPLO.*.sql       — queries do domínio Exemplo
src/Domain/Exemplo/   — domínio de referência: DTOs, Repository, Service, Controller
infra/                — submodule delphi-api-infra-faa
modules/horse/        — submodule Horse
```

---

## Como os SQLs são carregados

Os arquivos `.sql` são compilados em recursos binários (`queries.res`) e embutidos no executável.
O nome do resource segue o padrão:

```
SQL_<SQLDirectory>_<NomeDoArquivo_pontos_viram_underscores>
```

Exemplo: `SQLDirectory = 'QUERIES'` + chave `'EXEMPLO.FIND'` → resource `SQL_QUERIES_EXEMPLO_FIND`.

O `SQLDirectory` é configurado em `TFDConfig.SQLDirectory` no DPR. Cada factory tem o seu próprio loader e portanto o seu próprio namespace.

---

## Adicionando um domínio

1. Criar `src/Domain/<Nome>/` com os 4 arquivos Pascal (DTOs, Repository, Service, Controller)
2. Criar os arquivos SQL em `sql/` (FIND, FIND_COUNT, FIND_BY_ID, INSERT, UPDATE, DELETE)
3. Registrar cada SQL em `sql/queries.rc` seguindo o padrão `SQL_QUERIES_<NOME>`
4. Recompilar: `cd sql && queries.bat`
5. Adicionar as 4 units ao `uses` do DPR e chamar `RegisterRoutes` no `begin`
6. Criar `sql/MIG.000X.sql` e adicionar à constante `MIGRATIONS` no DPR

---

## Migrations

- O script `MIG.0001` **deve** criar a tabela `SCHEMA_MIGRATIONS` — o engine não a cria automaticamente
- Use `^` como terminador de nível superior em scripts Firebird (evita cortar `BEGIN...END` no `;` interno); declare `Terminator: '^'` no DPR
- Use `';'` para PostgreSQL (DDL é transacional; não precisa de terminador alternativo)
- Todos os scripts de migration devem ter `IsDDL: True` para DDL

---

## .env

Formato plano `KEY=VALUE`, uma chave por linha. Linhas em branco e comentários com `#` são ignorados. Valores podem ser opcionalmente delimitados por aspas simples ou duplas.

```env
DB_PATH=C:\delphi-api\bd.fdb
DB_USER=SYSDBA
DB_PASSWORD=masterkey
FB_CLIENT_DIR=C:\Program Files\Firebird\Firebird_2_5\WOW64
SERVER_PORT=9000
BASE_URL=http://localhost:9000
```

- O arquivo `.env` **não deve ser versionado** — está no `.gitignore`
- Use `.env.example` como template (versionado, sem valores reais)
- Variáveis de ambiente do sistema têm precedência sobre o arquivo

---

## Suporte a múltiplos bancos por configuração

O mesmo executável pode ser implantado com Firebird ou PostgreSQL — o banco ativo é determinado pela chave `DB_DIALECT` no `.env`. Nenhum código de domínio muda; apenas o DPR lê o dialeto e monta a factory correta.

### Estrutura de arquivos SQL

```
sql/
  fb/
    fb.rc        — SQL_FB_MIG_0001, SQL_FB_EXEMPLO_FIND ...
    fb.bat
    MIG.0001.sql — DDL Firebird (terminador ^)
    EXEMPLO.FIND.sql
    ...
  pg/
    pg.rc        — SQL_PG_MIG_0001, SQL_PG_EXEMPLO_FIND ...
    pg.bat
    MIG.0001.sql — DDL PostgreSQL (terminador ;)
    EXEMPLO.FIND.sql
    ...
```

Ambos os `.res` são embutidos no executável via `{$R}`; em runtime, apenas os resources do dialeto configurado são acessados.

### DPR — factory única, seleção em runtime

```pascal
{$R 'sql\fb\fb.res'}
{$R 'sql\pg\pg.res'}

// Inclua os dois drivers para que o FireDAC os registre
uses FireDAC.Phys.FB, FireDAC.Phys.PG, ...

LDialect := TAppConfig.Get('DB_DIALECT', 'Firebird');

if SameText(LDialect, 'PostgreSQL') then
begin
  LConfig.ConnectionParams.Add('DriverID=PG');
  ...
  LConfig.SQLDialect   := 'PostgreSQL';
  LConfig.SQLDirectory := 'PG';   // → resources SQL_PG_*
end
else
begin
  LConfig.ConnectionParams.Add('DriverID=FB');
  ...
  LConfig.SQLDialect   := 'Firebird';
  LConfig.SQLDirectory := 'FB';   // → resources SQL_FB_*
end;

LFactory := TFDFactory.Create(LConfig, nil);

// Migration do dialeto ativo
LEngine := TDBMigrationEngine.Create(LFactory);
if SameText(LDialect, 'PostgreSQL') then
  LEngine.Execute(MIGRATIONS_PG)   // Terminator ';'
else
  LEngine.Execute(MIGRATIONS_FB);  // Terminator '^'
LEngine.Free;

// Domínio — nenhuma alteração
LService := TExemploService.Create(TExemploRepository.Create(LFactory));
```

---

## Diferenças SQL por banco

| Recurso | Firebird | PostgreSQL |
|---|---|---|
| Paginação | `SELECT FIRST ${LIMIT} SKIP ${OFFSET} ...` | `SELECT ... LIMIT ${LIMIT} OFFSET ${OFFSET}` |
| Auto-incremento | `CREATE GENERATOR` + trigger | `GENERATED BY DEFAULT AS IDENTITY` |
| Terminador migration | `^` | `;` |
| Driver FireDAC | `FireDAC.Phys.FB` | `FireDAC.Phys.PG` |
| `INSERT RETURNING` | suportado | suportado |

---

## Anti-padrões a evitar

- Versionar o `.env` — ele contém segredos; use `.env.example` como template
- Usar `';'` como terminador de migration Firebird com triggers — corta o `BEGIN...END` no `;` interno
- Omitir `SCHEMA_MIGRATIONS` no `MIG.0001` — o engine não a cria; `InsertVersionRecord` falha
- Registrar `{$R}` de apenas um banco ao usar múltiplos — o outro não terá resources
- Usar um único namespace de SQL (`QUERIES`) para dois bancos — resources de mesmo nome colidem
