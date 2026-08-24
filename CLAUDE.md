# delphi-api-starter — Guia para Agentes de IA

Template de projeto para APIs REST em Delphi com Horse e [delphi-api-infra-faa](https://github.com/fabianoallex/delphi-api-infra-faa).

@infra/CLAUDE.md

O import acima traz os padrões detalhados de DTOs, Optionals, JsonMapper, Repository, Service e
Controller definidos na infra — carregado automaticamente em toda sessão, independente da
subpasta em que o trabalho estiver acontecendo. As seções abaixo cobrem apenas o que é específico
deste projeto (estrutura de pastas, migrations, `.env`, mensageria).

---

## Estrutura essencial

```
Api.Starter.dpr       — binário CONSOLE (dev/testes); casca fina, só chama TApp
Api.Starter.Svc.dpr   — binário SERVIÇO Windows (produção); casca fina, só sobe o TService
src/
  Api.Starter.App.pas     — TApp.Bootstrap/StartHttp/Shutdown: TODO o código de inicialização
  Api.Starter.SvcMain.pas — TService (+ .dfm); só o projeto do serviço o compila
.env                  — configuração de ambiente (KEY=VALUE, não versionado)
.env.example          — template de configuração (versionado, sem segredos)
tools/
  build_sql_res.bat   — recompila todo .rc sob sql/ (ver "Como os SQLs são carregados" abaixo)
sql/
  queries.rc          — registra os arquivos SQL como resources (prefixo SQL_QUERIES_)
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

O `SQLDirectory` é configurado em `TFDConfig.SQLDirectory` em `Api.Starter.App.pas`. Cada factory tem o seu próprio loader e portanto o seu próprio namespace.

O `.res` **nunca é editado/recompilado manualmente** — `Api.Starter.dproj` **e**
`Api.Starter.Svc.dproj` já vêm com um `Target Name="BeforeBuild"` que chama
`tools\build_sql_res.bat` antes de cada compilação. O script varre
toda a `sql/` e recompila qualquer `.rc` que encontrar (funciona também se o projeto adotar o
padrão multi-banco descrito mais abaixo, com um `.rc` por dialeto). Detalhes e o porquê dessa
automação em `infra/CLAUDE.md`, seção "Build automático dos `.res`".

---

## Adicionando um domínio

1. Criar `src/Domain/<Nome>/` com os 4 arquivos Pascal (DTOs, Repository, Service, Controller)
2. Criar os arquivos SQL em `sql/` (FIND, FIND_COUNT, FIND_BY_ID, INSERT, UPDATE, DELETE)
3. Registrar cada SQL em `sql/queries.rc` seguindo o padrão `SQL_QUERIES_<NOME>` — recompilação do
   `.res` é automática (pre-build event), não rode `brcc32` manualmente
4. Adicionar as 4 units ao `uses` dos **dois** `.dpr` (`Api.Starter.dpr` e `Api.Starter.Svc.dpr`)
   — o `uses` do DPR é a lista de arquivos do projeto; esquecer o do serviço faz o domínio
   simplesmente não entrar naquele binário, sem erro de compilação
5. Montar as dependências (Repository → Service) e chamar `RegisterRoutes` em
   `src/Api.Starter.App.pas` — **nunca no `begin` do DPR**, que é só uma casca
6. Criar `sql/MIG.000X.sql` e adicionar à constante `MIGRATIONS` em `Api.Starter.App.pas`

---

## Migrations

- O script `MIG.0001` **deve** criar a tabela `SCHEMA_MIGRATIONS` — o engine não a cria automaticamente
- Use `^` como terminador de nível superior em scripts Firebird (evita cortar `BEGIN...END` no `;` interno); declare `Terminator: '^'` na constante `MIGRATIONS` de `Api.Starter.App.pas`
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

O mesmo executável pode ser implantado com Firebird ou PostgreSQL — o banco ativo é determinado pela chave `DB_DIALECT` no `.env`. Nenhum código de domínio muda; apenas `Api.Starter.App.pas` lê o dialeto e monta a factory correta.

### Estrutura de arquivos SQL

```
sql/
  fb/
    fb.rc        — SQL_FB_MIG_0001, SQL_FB_EXEMPLO_FIND ...
    MIG.0001.sql — DDL Firebird (terminador ^)
    EXEMPLO.FIND.sql
    ...
  pg/
    pg.rc        — SQL_PG_MIG_0001, SQL_PG_EXEMPLO_FIND ...
    MIG.0001.sql — DDL PostgreSQL (terminador ;)
    EXEMPLO.FIND.sql
    ...
```

Ambos os `.res` são embutidos no executável via `{$R}`; em runtime, apenas os resources do dialeto configurado são acessados. `tools\build_sql_res.bat` já cobre esse layout sem nenhum ajuste — ele varre `sql/` inteira e recompila todo `.rc` que encontrar, um por dialeto ou não.

### `Api.Starter.App.pas` — factory única, seleção em runtime

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

## Mensageria (RabbitMQ)

Se o projeto precisar consumir ou publicar mensagens, adicione as chaves ao `.env` e monte o consumer em `TApp.Bootstrap` (`Api.Starter.App.pas`) após os middlewares, e registre o `Stop`/`Free` dele em `TApp.Shutdown`:

Adapter concreto disponível: `delphi-amqp-faa` (https://github.com/fabianoallex/delphi-amqp-faa, MIT) - `Messaging.Adapters.DelphiAmqpFaa.pas` registra-se como `'rabbitmq'`. Adicione também a pasta `src` desse repo ao search path do projeto.

```pascal
uses
  Messaging.Interfaces          in 'infra\src\Messaging\Messaging.Interfaces.pas',
  Messaging.Adapters.Registry   in 'infra\src\Messaging\Messaging.Adapters.Registry.pas',
  Messaging.Adapters.DelphiAmqpFaa; // basta estar no uses para se registrar

// Montar config
LMessagingConfig          := TMessagingConfig.Create;
LMessagingConfig.Host     := TAppConfig.Get('RABBITMQ_HOST', 'localhost');
LMessagingConfig.Port     := TAppConfig.GetInt('RABBITMQ_PORT', 5672);
LMessagingConfig.User     := TAppConfig.Get('RABBITMQ_USER', 'guest');
LMessagingConfig.Password := TAppConfig.Get('RABBITMQ_PASSWORD', 'guest');
LMessagingConfig.VHost    := TAppConfig.Get('RABBITMQ_VHOST', '/');

// Iniciar consumer em background - 'rabbitmq' e o nome que o adapter concreto
// usa para se registrar no TMessagingRegistry
LFactory  := TMessagingRegistry.GetFactory(TAppConfig.Get('MESSAGING_ADAPTER', 'rabbitmq'));
LConsumer := LFactory.CreateConsumer(LMessagingConfig);
LConsumer.Subscribe(TAppConfig.Get('RABBITMQ_QUEUE', ''), TMinhaHandler.Create(LService));
LConsumer.Start;

THorse.Listen(TAppConfig.GetInt('SERVER_PORT', 9000));

LConsumer.Stop;
```

O `IMessageHandler` é implementado no projeto — ver padrão completo em `infra/CLAUDE.md`.

> Nenhum adapter concreto está disponível ainda. A seção acima documenta o padrão para quando o adapter for adicionado à infra.

---

## Console + serviço Windows (mesmo código, dois binários)

**O template já vem separado — não há nada a fazer para ganhar isso.** Um projeto que vai para
produção como serviço Windows normalmente quer manter também a versão console, para
desenvolvimento e testes; a estrutura é **um par de `.dpr`/`.dproj` sobre uma unit de aplicação
compartilhada** — nunca `{$IFDEF}` espalhado pelo DPR, nunca dois repositórios.

| Binário | `{$APPTYPE CONSOLE}` | Uso |
|---|---|---|
| `Api.Starter.exe` | sim | desenvolvimento/testes |
| `Api.Starter.Svc.exe` | **não** | produção, serviço Windows |

Ao renomear o projeto, renomeie os dois `.dpr`/`.dproj` e as duas units juntos, e ajuste
`Name`/`DisplayName` em `src/Api.Starter.SvcMain.dfm` (é o `Name` que vira o nome no SCM).
Se o projeto nunca for virar serviço, dá para apagar `Api.Starter.Svc.*` e
`src/Api.Starter.SvcMain.*` — mas **mantenha `Api.Starter.App.pas`**: é lá que o código de
inicialização deve morar de qualquer forma, e é o que permite acrescentar o serviço depois sem
refatorar nada.

### Por que não precisa de define nenhum do Horse

Em `modules/horse/src/Horse.Provider.Console.pas` o loop de espera é:

```pascal
if IsConsole then
  while FRunning do
    GetDefaultEvent.WaitFor();
```

`IsConsole` (RTL) é `True` só quando o binário foi compilado com `{$APPTYPE CONSOLE}`. Logo o
**mesmo provider padrão serve os dois**: no console `THorse.Listen` bloqueia (comportamento de
sempre), no serviço ele **retorna já ouvindo** — que é exatamente o que `TService.OnStart`
precisa. Não use `HORSE_VCL`/`HORSE_APPTYPE_VCL` nem suba o Horse numa thread só para isso.

### Estrutura

```
Api.Starter.dpr / .dproj         — console;  {$APPTYPE CONSOLE};  DCC_ConsoleTarget = true
Api.Starter.Svc.dpr / .dproj     — serviço;  sem APPTYPE;         DCC_ConsoleTarget = false
src/
  Api.Starter.App.pas            — TODO o corpo do DPR vive aqui
  Api.Starter.SvcMain.pas+.dfm   — TService; só o projeto do serviço referencia
```

Os dois `.dproj` são idênticos exceto por: `ProjectGuid`, `MainSource`, `ProjectName`,
`SanitizedProjectName`, `FrameworkType` (None/VCL), `AppType` (Console/Application),
`DCC_ConsoleTarget` (true/false), `DCC_DcuOutput` (o do serviço acrescenta `\Svc`) e as duas
`DCCReference` a mais. O `Target Name="BeforeBuild"` que chama `tools\build_sql_res.bat` está
**nos dois** — nunca remova de um só.

A unit de aplicação expõe três pontos de entrada, porque o ciclo de vida do serviço é
`start → (roda) → stop`, enquanto o do console é `start → (bloqueia) → stop`:

```pascal
type
  TApp = class
  public
    class procedure Bootstrap;   // bancos, migrations, mensageria, middlewares, Swagger/MCP
    class procedure StartHttp;   // THorse.Listen(porta) — bloqueia se IsConsole, senão retorna
    class procedure Shutdown;    // para HTTP, consumidores e threads; libera factories. Idempotente
  end;
```

```pascal
// DPR console
ReportMemoryLeaksOnShutdown := True;
TApp.Bootstrap;
TApp.StartHttp;   // bloqueia aqui
TApp.Shutdown;

// TService.OnStart — bootstrap em thread, ver "timeout do SCM" abaixo
FBootstrap := TThread.CreateAnonymousThread(
  procedure
  begin
    TApp.Bootstrap;
    TApp.StartHttp;   // retorna já ouvindo
  end);
FBootstrap.FreeOnTerminate := False;
FBootstrap.Start;
Started := True;

// TService.OnStop
FBootstrap.WaitFor;
TApp.Shutdown;
Stopped := True;
```

### As seis armadilhas do binário sem console

Todas são silenciosas: compilam, e só aparecem com o serviço instalado.

| Problema | Correção |
|---|---|
| `SafeWriteln` levantava `EInOutError` (105) — sem console não há `Output` | já resolvido na infra (guard `IsConsole`); **atualize o submodule** |
| cwd de um serviço é `C:\Windows\System32` — `LOG_DIR` relativo cria `System32\logs`, e LocalSystem *tem* permissão de escrever lá (falha silenciosa) | `SetCurrentDir(ExtractFilePath(ParamStr(0)))` como 1ª linha do `OnStart` + `LOG_DIR` absoluto no `.env` |
| `ReportMemoryLeaksOnShutdown := True` abre diálogo modal na sessão 0 (invisível) e trava o stop | deixar só no `.dpr` do console |
| Startup longo (bancos + migrations + fila) estoura o timeout do SCM (~30s) e o serviço é marcado como falho | `Bootstrap` numa thread; `Started := True` imediato |
| Threads `while True` sem `Terminate` (ex.: loggers de snapshot do pool) impedem o processo de sair; `net stop` dá timeout | `TEvent` de parada + `WaitFor` no `Shutdown` — mesmo padrão de `StartIdleSweep`/`StopIdleSweep` em `Db.Connection.Pool.pas` |
| Falha de bootstrap fica invisível — sem console e possivelmente sem `LOG_DIR` válido | `FileLog(['exception', ...])` **+** `TService.LogMessage` (Event Viewer) + `Controller(SERVICE_CONTROL_STOP)` |

Ordem obrigatória no `Shutdown`: **HTTP → consumidores → threads que usam a factory → factories**.
As threads de snapshot chamam `AFactory.GetPool` a cada ciclo; soltar as factories antes de pará-las
é *use-after-free*.

### Detalhes de compilação

- `SERVICE_CONTROL_STOP` vem de `Winapi.WinSvc` (`Vcl.SvcMgr` não repassa). `EVENTLOG_ERROR_TYPE`
  vem de `Winapi.Windows`.
- Mantenha `FireDAC.ConsoleUI.Wait` nos **dois** projetos — é o wait handler sem UI. Trocar por
  `FireDAC.VCLUI.Wait` tentaria abrir UI na sessão 0.
- `<DCC_DcuOutput>` **separado por projeto** — senão os dois compartilham DCUs compilados com
  `APPTYPE` diferente.
- Pre-build event (`call tools\build_sql_res.bat`) e os `{$R 'sql\...\*.res'}` precisam estar
  **nos dois** `.dpr`/`.dproj`.
- Instalação: `MinhaApiSvc.exe /install` / `/uninstall` (prompt como Administrador). Depois:
  `sc.exe config <nome> start= auto` e `sc.exe failure <nome> reset= 86400 actions= restart/60000/restart/60000/restart/60000`.
- Os dois binários **não convivem na mesma pasta**: mesmo `.env` ⇒ mesma `SERVER_PORT` e mesmos
  arquivos de log, com dois processos brigando pela porta e pela rotação.
- LocalSystem não enxerga drive mapeado — `DB_PATH` em `Z:\...` ou UNC quebra no serviço.

---

## Anti-padrões a evitar

- Remover ou pular o `Target Name="BeforeBuild"` do `.dproj` — é ele que chama `tools\build_sql_res.bat` e garante que o `.res` nunca fica desatualizado em relação ao `.sql`
- Versionar o `.env` — ele contém segredos; use `.env.example` como template
- Usar `';'` como terminador de migration Firebird com triggers — corta o `BEGIN...END` no `;` interno
- Omitir `SCHEMA_MIGRATIONS` no `MIG.0001` — o engine não a cria; `InsertVersionRecord` falha
- Registrar `{$R}` de apenas um banco ao usar múltiplos — o outro não terá resources
- Usar um único namespace de SQL (`QUERIES`) para dois bancos — resources de mesmo nome colidem
- Escrever código de inicialização no `begin` do `.dpr` — os dois `.dpr` são cascas finas; tudo
  vive em `Api.Starter.App.pas` (`Bootstrap`/`StartHttp`/`Shutdown`). Duplicar esse corpo, ou
  espalhar `{$IFDEF}` para diferenciar console de serviço, desfaz exatamente o que o template
  já resolve (ver "Console + serviço Windows")
- Definir `HORSE_VCL`/`HORSE_APPTYPE_VCL` para "fazer o `Listen` não bloquear" num serviço — o
  provider padrão já resolve isso sozinho via `IsConsole`; basta o binário não ter `{$APPTYPE CONSOLE}`
- Deixar thread de background em `while True` sem sinal de parada — no console passa despercebido
  (o processo é morto de fora), num serviço o `net stop` dá timeout no SCM
