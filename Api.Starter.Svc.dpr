program Api.Starter.Svc;

(* SEM {$APPTYPE CONSOLE} — é isso que faz IsConsole = False e, por consequência,
  THorse.Listen retornar em vez de bloquear (ver cabeçalho de Api.Starter.App.pas).
  No .dproj correspondente, DCC_ConsoleTarget precisa ser false em TODAS as
  configurações: com true o Listen volta a bloquear, dentro da thread de
  bootstrap, e o `net stop` trava esperando o WaitFor. *)

{$STRONGLINKTYPES ON}

{$R *.res}
{$R 'sql\queries.res'}

{
  Binário de produção — serviço Windows. Compartilha Api.Starter.App com o
  binário console (Api.Starter.dpr); todo código de inicialização vive lá.
  Ver CLAUDE.md, seção "Console + serviço Windows (mesmo código, dois binários)".

    Api.Starter.Svc.exe /install
    Api.Starter.Svc.exe /uninstall
}

uses
  Vcl.SvcMgr,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Stan.ExprFuncs,
  FireDAC.UI.Intf,
  FireDAC.ConsoleUI.Wait,   // wait handler sem UI — correto também em serviço.
                            // NÃO troque por FireDAC.VCLUI.Wait: tentaria UI na sessão 0.
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
  Api.Starter.App               in 'src\Api.Starter.App.pas',
  Api.Starter.SvcMain           in 'src\Api.Starter.SvcMain.pas' {ApiStarterService: TService}
  ;

begin
  // ReportMemoryLeaksOnShutdown NÃO entra aqui: o relatório é um diálogo modal
  // na sessão 0 (invisível) e travaria o stop do serviço.

  if not Vcl.SvcMgr.Application.DelayInitialize or Vcl.SvcMgr.Application.Installing then
    Vcl.SvcMgr.Application.Initialize;
  Vcl.SvcMgr.Application.CreateForm(TApiStarterService, ApiStarterService);
  Vcl.SvcMgr.Application.Run;
end.
