program Api.Starter;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

{$R *.res}
{$R 'sql\queries.res'}

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Stan.ExprFuncs,
  FireDAC.UI.Intf,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Phys,
  FireDAC.Phys.FB,
  FireDAC.DApt,
  Horse                  in 'modules\horse\src\Horse.pas',
  Common.Optionals       in 'infra\src\Common\Common.Optionals.pas',
  Common.SystemContext   in 'infra\src\Common\Common.SystemContext.pas',
  Common.ClockCache      in 'infra\src\Common\Common.ClockCache.pas',
  Common.Helpers         in 'infra\src\Common\Common.Helpers.pas',
  Common.JsonMapper      in 'infra\src\Common\Common.JsonMapper.pas',
  Common.OrderBy         in 'infra\src\Common\Common.OrderBy.pas',
  Common.DTO.Base        in 'infra\src\Common\Common.DTO.Base.pas',
  Common.Pagination      in 'infra\src\Common\Common.Pagination.pas',
  Common.Config          in 'infra\src\Common\Common.Config.pas',
  Common.RateLimitState  in 'infra\src\Common\Common.RateLimitState.pas',
  Db.Interfaces          in 'infra\src\Db\Db.Interfaces.pas',
  Db.Constants           in 'infra\src\Db\Db.Constants.pas',
  Db.SqlDialect          in 'infra\src\Db\Db.SqlDialect.pas',
  Db.SqlLoader           in 'infra\src\Db\Db.SqlLoader.pas',
  Db.Adapters.Registry   in 'infra\src\Db\Db.Adapters.Registry.pas',
  Db.Connection.Pool     in 'infra\src\Db\Db.Connection.Pool.pas',
  Db.Adapters.FireDAC    in 'infra\src\Db\Db.Adapters.FireDAC.pas',
  Db.Migrations          in 'infra\src\Db\Db.Migrations.pas',
  Exemplo.DTOs           in 'src\Domain\Exemplo\Exemplo.DTOs.pas',
  Exemplo.Repository     in 'src\Domain\Exemplo\Exemplo.Repository.pas',
  Exemplo.Service        in 'src\Domain\Exemplo\Exemplo.Service.pas',
  Exemplo.Controller     in 'src\Domain\Exemplo\Exemplo.Controller.pas',
  Swagger.Server         in 'infra\src\Swagger\Swagger.Server.pas',
  Swagger.Builder        in 'infra\src\Swagger\Swagger.Builder.pas',
  MCP.Server             in 'infra\src\MCP\MCP.Server.pas',
  MCP.Utils              in 'infra\src\MCP\MCP.Utils.pas',
  Horse.Middleware.Logger       in 'infra\src\Middleware\Horse.Middleware.Logger.pas',
  Horse.Middleware.ErrorHandler in 'infra\src\Middleware\Horse.Middleware.ErrorHandler.pas',
  Horse.Middleware.Auth         in 'infra\src\Middleware\Horse.Middleware.Auth.pas',
  Horse.Middleware.Cors         in 'infra\src\Middleware\Horse.Middleware.Cors.pas',
  Horse.Middleware.RateLimit    in 'infra\src\Middleware\Horse.Middleware.RateLimit.pas',
  Common.HealthCheck            in 'infra\src\Common\Common.HealthCheck.pas'
  ;

const
  MIGRATIONS: array[0..0] of TMigrationItem = (
    (Version: 1; ScriptName: 'MIG.0001'; ParamReplaceProc: nil; Terminator: '^'; IsDDL: True)
  );

var
  LConfig:         TFDConfig;
  LFactory:        IDBFactory;
  LEngine:         TDBMigrationEngine;
  LService:        IExemploService;
  LTags:           TStringList;
begin
  SetDllDirectory(PWideChar(TAppConfig.Get('FB_CLIENT_DIR',
    'C:\Program Files\Firebird\Firebird_2_5\WOW64')));
  try
    LConfig := TFDConfig.Create;
    LConfig.ConnectionParams.Add('DriverID=FB');
    LConfig.ConnectionParams.Add('Database=' + TAppConfig.Get('DB_PATH',     'C:\data\minha-api.fdb'));
    LConfig.ConnectionParams.Add('User_Name=' + TAppConfig.Get('DB_USER',     'SYSDBA'));
    LConfig.ConnectionParams.Add('Password='  + TAppConfig.Get('DB_PASSWORD', 'masterkey'));
    LConfig.ConnectionParams.Add('CharacterSet=UTF8');
    LConfig.SQLDialect     := 'Firebird';
    LConfig.SQLDirectory   := 'QUERIES';
    LConfig.SetPoolIniConnections(1);
    LConfig.SetPoolMaxConnections(5);
    LConfig.SetPoolWaitMaxAttemps(10);
    LConfig.SetPoolWaitMilliseconds(50);

    LFactory := TFDFactory.Create(LConfig, nil);
    TDBRegistry.RegisterFactory('meu_banco', LFactory);

    // Migrations
    Writeln('Executando migrations...');
    LEngine := TDBMigrationEngine.Create(LFactory);
    try
      LEngine.Execute(MIGRATIONS);
    finally
      LEngine.Free;
    end;
    Writeln('Migrations concluidas.');

    // Montar dependências
    LService := TExemploService.Create(TExemploRepository.Create(LFactory));

    // Health check — fora do Swagger e do MCP
    THealthCheck.Register(LFactory);

    // Logger — deve ser o PRIMEIRO middleware
    THorse.Use(TLoggerMiddleware.New);

    // Middleware de erros — deve vir após o Logger
    THorse.Use(TErrorHandlerMiddleware.New);

    // Rate limiting (opcional) — deve vir após o ErrorHandler; antes de RegisterRoutes
    // THorse.Use(TRateLimitMiddleware.New(60, 60));   // 60 req/min por IP

    // CORS (opcional) — deve vir após o ErrorHandler; antes de RegisterRoutes
    // THorse.Use(TCorsMiddleware.New);                          // dev: libera *
    // THorse.Use(TCorsMiddleware.New('https://app.example.com')); // produção

    // Autenticação Bearer (opcional) — deve vir após o ErrorHandler
    // THorse.Use(TAuthMiddleware.Bearer(
    //   function(const AToken: string): Boolean
    //   begin
    //     Result := AToken = TAppConfig.Get('API_KEY', '');
    //   end,
    //   ['/health', '/swagger']));

    // Inicializar Swagger doc (deve vir antes de RegisterRoutes)
    TRouteDoc.Init('API Starter', '1.0.0', 'localhost:9000');

    // Registrar rotas — documenta Swagger e registra Horse simultaneamente
    TExemploController.RegisterRoutes(LService);

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

    // Iniciar servidor
    var LPort := TAppConfig.GetInt('SERVER_PORT', 9000);
    Writeln('API iniciada em http://localhost:' + IntToStr(LPort));
    Writeln('Swagger UI: http://localhost:' + IntToStr(LPort) + '/swagger');
    THorse.Listen(LPort);

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
