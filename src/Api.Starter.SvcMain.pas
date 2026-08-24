unit Api.Starter.SvcMain;

{
  TService do template. Só o projeto Api.Starter.Svc.dproj referencia esta unit —
  o projeto console não a compila.

  Instalação (prompt como Administrador, na pasta do exe):
    Api.Starter.Svc.exe /install
    Api.Starter.Svc.exe /uninstall

  Depois de instalar, vale configurar partida automática e recuperação:
    sc.exe config  ApiStarterService start= auto
    sc.exe failure ApiStarterService reset= 86400 actions= restart/60000/restart/60000/restart/60000

  Renomeie o serviço editando Name/DisplayName em Api.Starter.SvcMain.dfm.
}

interface

uses
  Winapi.Windows,
  Winapi.WinSvc,     // SERVICE_CONTROL_STOP (EVENTLOG_ERROR_TYPE vem de Winapi.Windows)
  System.SysUtils,
  System.Classes,
  Vcl.SvcMgr;

type
  TApiStarterService = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  private
    FBootstrap: TThread;
  public
    function GetServiceController: TServiceController; override;
  end;

var
  ApiStarterService: TApiStarterService;

implementation

{$R *.dfm}

uses
  Api.Starter.App;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ApiStarterService.Controller(CtrlCode);
end;

function TApiStarterService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TApiStarterService.ServiceStart(Sender: TService; var Started: Boolean);
begin
  { O diretório corrente de um serviço é C:\Windows\System32, não a pasta do exe.
    O .env está a salvo (Common.Config resolve por ParamStr(0)), mas LOG_DIR é
    usado como veio: com o padrão relativo 'logs' o serviço criaria
    C:\Windows\System32\logs — e como LocalSystem tem permissão de escrita lá,
    isso falha em silêncio, com os logs no lugar errado.
    Prefira também LOG_DIR absoluto no .env. }
  SetCurrentDir(ExtractFilePath(ParamStr(0)));

  { Bootstrap fora do OnStart: banco, migrations e (quando houver) conexão com
    fila podem passar do timeout do SCM (~30s), e o serviço seria marcado como
    falho. Retornando Started := True na hora, o SCM fica satisfeito e a
    inicialização continua em background. }
  FBootstrap := TThread.CreateAnonymousThread(
    procedure
    begin
      try
        TApp.Bootstrap;
        TApp.StartHttp;   // IsConsole = False aqui -> Listen retorna já ouvindo
      except
        on E: Exception do
        begin
          { Event Viewer: num serviço é o único canal que sobrevive a um LOG_DIR
            mal configurado. Se o projeto usar Common.FileLog, logue também em
            FileLog(['exception', ...]) antes desta linha. }
          Self.LogMessage(
            Format('%s: falha no bootstrap: %s: %s',
              [Self.Name, E.ClassName, E.Message]),
            EVENTLOG_ERROR_TYPE);
          Self.Controller(SERVICE_CONTROL_STOP);
        end;
      end;
    end);
  FBootstrap.FreeOnTerminate := False;
  FBootstrap.Start;

  Started := True;
end;

procedure TApiStarterService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  try
    // se o bootstrap ainda estiver rodando, espera terminar antes de desmontar
    if Assigned(FBootstrap) then
    begin
      FBootstrap.WaitFor;
      FreeAndNil(FBootstrap);
    end;

    TApp.Shutdown;
  except
    on E: Exception do
      Self.LogMessage(
        Format('%s: falha no shutdown: %s: %s', [Self.Name, E.ClassName, E.Message]),
        EVENTLOG_ERROR_TYPE);
  end;

  Stopped := True;
end;

end.
