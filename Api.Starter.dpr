program Api.Starter;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

{$R *.res}
{$R 'sql\queries.res'}

{
  Binário console — desenvolvimento e testes. O binário de produção é
  Api.Starter.Svc.dpr (serviço Windows); os dois compartilham Api.Starter.App.
  Todo código de inicialização vive lá, nunca aqui.
  Ver CLAUDE.md, seção "Console + serviço Windows (mesmo código, dois binários)".
}

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
  Common.SafeLog         in 'infra\src\Common\Common.SafeLog.pas',
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
  Horse.Middleware.Jwt          in 'infra\src\Middleware\Horse.Middleware.Jwt.pas',
  Horse.Middleware.Cors         in 'infra\src\Middleware\Horse.Middleware.Cors.pas',
  Horse.Middleware.RateLimit    in 'infra\src\Middleware\Horse.Middleware.RateLimit.pas',
  Common.HealthCheck            in 'infra\src\Common\Common.HealthCheck.pas',
  Api.Starter.App               in 'src\Api.Starter.App.pas'
  ;

begin
  // Só no console: num serviço o relatório de leaks é um diálogo modal na
  // sessão 0 (invisível) e o processo trava no stop.
  ReportMemoryLeaksOnShutdown := True;

  try
    TApp.Bootstrap;
    TApp.StartHttp;   // IsConsole = True -> bloqueia aqui até o Horse parar
    TApp.Shutdown;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
