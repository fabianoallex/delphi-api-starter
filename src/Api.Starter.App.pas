unit Api.Starter.App;

{
  Corpo da aplicação, compartilhado pelos dois binários do template:

    Api.Starter.dpr       - console  ({$APPTYPE CONSOLE})  -> desenvolvimento/testes
    Api.Starter.Svc.dpr   - serviço Windows (sem APPTYPE)  -> produção

  Todo código de inicialização mora aqui, e nunca no .dpr. Os dois projetos
  chamam exatamente os mesmos três métodos; nenhum {$IFDEF} é necessário.
  Ver CLAUDE.md, seção "Console + serviço Windows (mesmo código, dois binários)".

  Ciclo de vida:

    Bootstrap   banco, migrations, dependências, middlewares, Swagger/MCP.
                NÃO sobe o HTTP.

    StartHttp   THorse.Listen(porta).
                ATENÇÃO: em Horse.Provider.Console.InternalListen o loop de espera é
                  if IsConsole then while FRunning do GetDefaultEvent.WaitFor();
                IsConsole (RTL) é True só quando o binário tem {$APPTYPE CONSOLE}. Logo:
                  - console -> StartHttp BLOQUEIA até o shutdown
                  - serviço -> StartHttp RETORNA já ouvindo (o que TService.OnStart precisa)
                É por isso que o mesmo provider padrão serve os dois binários, sem
                define HORSE_VCL e sem subir o Horse numa thread.

    Shutdown    para o HTTP e libera as dependências. Idempotente.

  Ao acrescentar recursos de background (consumidor de mensageria, threads de
  monitoramento, jobs), registre a parada de cada um em Shutdown, na ordem:
  HTTP -> consumidores -> threads que usam a factory -> factories.
}

interface

type
  TApp = class
  public
    class procedure Bootstrap;
    class procedure StartHttp;
    class procedure Shutdown;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Horse,
  Common.Config,
  Common.SafeLog,
  Common.HealthCheck,
  Db.Interfaces,
  Db.Adapters.Registry,
  Db.Adapters.FireDAC,
  Db.Migrations,
  Swagger.Server,
  MCP.Server,
  Horse.Middleware.Logger,
  Horse.Middleware.ErrorHandler,
  Horse.Middleware.Auth,
  Horse.Middleware.Jwt,
  Horse.Middleware.Cors,
  Horse.Middleware.RateLimit,
  Exemplo.Repository,
  Exemplo.Service,
  Exemplo.Controller;

const
  MIGRATIONS: array[0..0] of TMigrationItem = (
    (Version: 1; ScriptName: 'MIG.0001'; ParamReplaceProc: nil; Terminator: '^'; IsDDL: True)
  );

var
  GFactory:      IDBFactory;
  GService:      IExemploService;
  GShutdownDone: Boolean = False;

procedure ConfigurarBanco;
var
  LConfig: TFDConfig;
  LEngine: TDBMigrationEngine;
begin
  SetDllDirectory(PWideChar(TAppConfig.Get('FB_CLIENT_DIR',
    'C:\Program Files\Firebird\Firebird_2_5\WOW64')));

  LConfig := TFDConfig.Create;
  LConfig.ConnectionParams.Add('DriverID=FB');
  LConfig.ConnectionParams.Add('Database=' + TAppConfig.Get('DB_PATH',     'C:\data\minha-api.fdb'));
  LConfig.ConnectionParams.Add('User_Name=' + TAppConfig.Get('DB_USER',     'SYSDBA'));
  LConfig.ConnectionParams.Add('Password='  + TAppConfig.Get('DB_PASSWORD', 'masterkey'));
  LConfig.ConnectionParams.Add('CharacterSet=UTF8');
  LConfig.SQLDialect     := 'Firebird';
  LConfig.SQLDirectory   := 'QUERIES';
  LConfig.SetPoolIniConnections(TAppConfig.GetInt('POOL_INI_CONNECTIONS', 1));
  LConfig.SetPoolMaxConnections(TAppConfig.GetInt('POOL_MAX_CONNECTIONS', 5));
  LConfig.SetPoolWaitMaxAttemps(TAppConfig.GetInt('POOL_WAIT_MAX_ATTEMPS', 10));
  LConfig.SetPoolWaitMilliseconds(TAppConfig.GetInt('POOL_WAIT_MILLISECONDS', 50));
  // Fecha conexões ociosas além do limite (nunca abaixo de PoolIniConnections);
  // 0 = desligado (padrão). Ver README/CLAUDE.md da infra, seção "Pool de conexões".
  LConfig.SetPoolIdleTimeoutSeconds(TAppConfig.GetInt('POOL_IDLE_TIMEOUT_SECONDS', 0));
  LConfig.SetPoolIdleCheckIntervalMs(TAppConfig.GetInt('POOL_IDLE_CHECK_INTERVAL_MS', 30000));

  GFactory := TFDFactory.Create(LConfig, nil);
  TDBRegistry.RegisterFactory('meu_banco', GFactory);

  // Migrations
  SafeWriteln('Executando migrations...');
  LEngine := TDBMigrationEngine.Create(GFactory);
  try
    LEngine.Execute(MIGRATIONS);
  finally
    LEngine.Free;
  end;
  SafeWriteln('Migrations concluidas.');

  // Montar dependências
  GService := TExemploService.Create(TExemploRepository.Create(GFactory));

  // Health check — fora do Swagger e do MCP
  THealthCheck.Register(GFactory);
end;

procedure ConfigurarMiddlewares;
begin
  // Logger — deve ser o PRIMEIRO middleware em THorse.Use
  THorse.Use(TLoggerMiddleware.New);

  // Middleware de erros — usa THorse.OnError (não é um middleware em THorse.Use)
  TErrorHandlerMiddleware.Register;
  // Num serviço o console não existe: sem callback, os 500 não vão parar em
  // lugar nenhum e não há como investigar erro em produção. Para ativar,
  // acrescente Common.FileLog ao uses desta unit e aos dois .dpr, e troque a
  // chamada acima por:
  // TErrorHandlerMiddleware.Register(
  //   procedure(const ALine: string)
  //   begin
  //     FileLog(['exception', 'http'], ALine);
  //   end);

  // Rate limiting (opcional) — antes de RegisterRoutes
  // THorse.Use(TRateLimitMiddleware.New(60, 60));   // 60 req/min por IP

  // CORS (opcional) — antes de RegisterRoutes
  // THorse.Use(TCorsMiddleware.New);                          // dev: libera *
  // THorse.Use(TCorsMiddleware.New('https://app.example.com')); // produção

  // Autenticação Bearer com API key (opcional)
  // THorse.Use(TAuthMiddleware.Bearer(
  //   function(const AToken: string): Boolean
  //   begin
  //     Result := AToken = TAppConfig.Get('API_KEY', '');
  //   end,
  //   ['/health', '/swagger']));

  // Autenticação JWT HS256 (opcional) — alternativa ao Bearer simples
  // THorse.Use(TJwtMiddleware.New(
  //   TAppConfig.Get('JWT_SECRET', ''),
  //   ['/health', '/swagger']));
end;

procedure ConfigurarSwaggerEMcp;
var
  LTags: TStringList;
begin
  // Inicializar Swagger doc (deve vir antes de RegisterRoutes)
  TRouteDoc.Init('API Starter', '1.0.0', 'localhost:9000');

  // Registrar rotas — documenta Swagger e registra Horse simultaneamente
  TExemploController.RegisterRoutes(GService);

  // Registrar tools MCP (antes de Serve, enquanto o doc ainda existe)
  // /mcp — todas as tools (útil para debug / agente generalista)
  TMcpServer.Register(TRouteDoc.CurrentDoc, '/mcp',
    TAppConfig.Get('BASE_URL', 'http://localhost:9000'), 'API Starter', '1.0.0');

  // /mcp/<tag> — endpoints filtrados por domínio
  LTags := TStringList.Create;
  try
    LTags.Add('exemplos');
    TMcpServer.Register(TRouteDoc.CurrentDoc, '/mcp/exemplos',
      TAppConfig.Get('BASE_URL', 'http://localhost:9000'), 'API Starter', '1.0.0', nil, LTags);
  finally
    LTags.Free;
  end;

  // Servir Swagger UI + JSON (serializa e libera o doc interno)
  TRouteDoc.Serve('/swagger');
end;

{ TApp }

class procedure TApp.Bootstrap;
begin
  ConfigurarBanco;
  ConfigurarMiddlewares;
  ConfigurarSwaggerEMcp;
end;

class procedure TApp.StartHttp;
var
  LPort: Integer;
begin
  LPort := TAppConfig.GetInt('SERVER_PORT', 9000);

  // SafeWriteln, nunca Writeln: num binário sem console Writeln levantaria
  // EInOutError (105). SafeWriteln vira no-op ali (ver Common.SafeLog).
  SafeWriteln('API iniciada em http://localhost:' + IntToStr(LPort));
  SafeWriteln('Swagger UI: http://localhost:' + IntToStr(LPort) + '/swagger');

  // console -> bloqueia aqui;  serviço -> retorna já ouvindo (ver cabeçalho da unit)
  THorse.Listen(LPort);
end;

class procedure TApp.Shutdown;
begin
  if GShutdownDone then
    Exit;
  GShutdownDone := True;

  // 1) para de aceitar requisições e derruba as conexões pendentes
  try
    THorse.StopListenGraceful(5000);
  except
    on E: Exception do
      SafeWriteln('Falha ao parar o Horse: ' + E.Message);
  end;

  // 2) consumidores de mensageria e threads de background entram AQUI, antes
  //    das factories — uma thread que chama Factory.GetPool não pode sobreviver
  //    à factory que ela usa

  // 3) dependências e factory
  GService := nil;
  GFactory := nil;
end;

end.
