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
  PascalCommon.Optionals       in 'modules\pascal-common-faa\src\PascalCommon.Optionals.pas',
  PascalCommon.SystemContext   in 'modules\pascal-common-faa\src\PascalCommon.SystemContext.pas',
  PascalCommon.ClockCache      in 'modules\pascal-common-faa\src\PascalCommon.ClockCache.pas',
  Common.Helpers         in 'infra\src\Common\Common.Helpers.pas',
  Common.JsonMapper      in 'infra\src\Common\Common.JsonMapper.pas',
  Common.OrderBy         in 'infra\src\Common\Common.OrderBy.pas',
  Common.DTO.Base        in 'infra\src\Common\Common.DTO.Base.pas',
  Common.Pagination      in 'infra\src\Common\Common.Pagination.pas',
  Common.Config          in 'infra\src\Common\Common.Config.pas',
  Common.RateLimitState  in 'infra\src\Common\Common.RateLimitState.pas',
  Common.SafeLog         in 'infra\src\Common\Common.SafeLog.pas',
  PascalDb.Version         in 'modules\pascal-db-faa\src\PascalDb.Version.pas',
  PascalDb.Interfaces      in 'modules\pascal-db-faa\src\PascalDb.Interfaces.pas',
  PascalDb.SqlSources      in 'modules\pascal-db-faa\src\PascalDb.SqlSources.pas',
  PascalDb.SqlLoader       in 'modules\pascal-db-faa\src\PascalDb.SqlLoader.pas',
  PascalDb.SqlDialect      in 'modules\pascal-db-faa\src\PascalDb.SqlDialect.pas',
  PascalDb.Registry        in 'modules\pascal-db-faa\src\PascalDb.Registry.pas',
  PascalDb.Pool            in 'modules\pascal-db-faa\src\PascalDb.Pool.pas',
  PascalDb.Adapter.Base    in 'modules\pascal-db-faa\src\PascalDb.Adapter.Base.pas',
  PascalDb.Adapter.DataSet in 'modules\pascal-db-faa\src\PascalDb.Adapter.DataSet.pas',
  PascalDb.Adapter.FireDAC in 'modules\pascal-db-faa\adapters\firedac\PascalDb.Adapter.FireDAC.pas',
  PascalDb.Migrations      in 'modules\pascal-db-faa\src\PascalDb.Migrations.pas',
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
