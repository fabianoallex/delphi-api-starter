unit Exemplo.Controller;

interface

uses
  Exemplo.DTOs,
  Exemplo.Service;

type
  TExemploController = class
  public
    class procedure RegisterRoutes(AService: IExemploService);
  end;

implementation

uses
  System.SysUtils,
  Horse,
  Swagger.Builder,
  Common.JsonMapper,
  Common.Pagination,
  Exemplo.Repository;

function BuildItemsJson(const AItems: TArray<IExemploResponseDTO>): string;
var
  LItem: IExemploResponseDTO;
  LFirst: Boolean;
begin
  Result := '[';
  LFirst := True;
  for LItem in AItems do
  begin
    if not LFirst then Result := Result + ',';
    Result := Result + TJsonMapper.ToJson<IExemploResponseDTO>(LItem);
    LFirst := False;
  end;
  Result := Result + ']';
end;

class procedure TExemploController.RegisterRoutes(AService: IExemploService);
begin
  TRouteDoc.Get('/exemplos')
    .Summary('Listar exemplos (paginado)')
    .Tag('exemplos')
    .QueryParam('page',    'Página (padrão: 1)',                      qptInteger)
    .QueryParam('limit',   'Itens por página (padrão: 20, máx: 100)', qptInteger)
    .QueryParam('search',  'Filtro por nome (parcial, opcional)')
    .QueryParam('orderBy', TExemploRepository.OrderBySpec.DocHint)
    .ResponsePaged<IExemploResponseDTO>('200', 'Lista paginada de exemplos')
    .Register(
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TNextProc)
      var
        LDto: IExemploFindDTO;
        LResult: TExemploPageResult;
      begin
        LDto := TExemploFindDTO.Create;
        LDto.Page    := ParseQueryInt(Req.Query['page']);
        LDto.Limit   := ParseQueryInt(Req.Query['limit']);
        LDto.Search  := ParseQueryStr(Req.Query['search']);
        LDto.OrderBy := ParseQueryStr(Req.Query['orderBy']);
        LResult := AService.Find(LDto);
        Res.ContentType('application/json; charset=utf-8')
           .Send(LResult.Meta.WrapJson(BuildItemsJson(LResult.Items)));
      end);

  TRouteDoc.Get('/exemplos/:id')
    .Summary('Buscar exemplo por ID')
    .Tag('exemplos')
    .PathParam('id', 'ID do exemplo', qptInteger)
    .Response<IExemploResponseDTO>('200', 'Exemplo encontrado')
    .NoContent('404', 'Exemplo não encontrado')
    .Register(
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TNextProc)
      var
        LId: Integer;
        LItem: IExemploResponseDTO;
      begin
        LId := StrToIntDef(Req.Params['id'], 0);
        LItem := AService.FindById(LId);
        if not Assigned(LItem) then
        begin
          Res.Status(404).Send('Exemplo não encontrado.');
          Exit;
        end;
        Res.ContentType('application/json; charset=utf-8')
           .Send(TJsonMapper.ToJson<IExemploResponseDTO>(LItem));
      end);

  TRouteDoc.Post('/exemplos')
    .Summary('Criar exemplo')
    .Tag('exemplos')
    .Body<IExemploInsertDTO>('Dados do novo exemplo')
    .Response<IExemploResponseDTO>('201', 'Exemplo criado')
    .Register(
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TNextProc)
      var
        LDto: IExemploInsertDTO;
        LResult: IExemploResponseDTO;
      begin
        LDto := TJsonMapper.FromJson<IExemploInsertDTO>(Req.Body);
        LResult := AService.Insert(LDto);
        Res.Status(201)
           .ContentType('application/json; charset=utf-8')
           .Send(TJsonMapper.ToJson<IExemploResponseDTO>(LResult));
      end);

  TRouteDoc.Patch('/exemplos/:id')
    .Summary('Atualizar exemplo (parcial)')
    .Tag('exemplos')
    .PathParam('id', 'ID do exemplo', qptInteger)
    .Body<IExemploUpdateDTO>('Campos a atualizar')
    .NoContent('204', 'Atualizado com sucesso')
    .NoContent('404', 'Exemplo não encontrado')
    .Register(
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TNextProc)
      var
        LId: Integer;
        LDto: IExemploUpdateDTO;
      begin
        LId := StrToIntDef(Req.Params['id'], 0);
        LDto := TJsonMapper.FromJson<IExemploUpdateDTO>(Req.Body);
        AService.Update(LId, LDto);
        Res.Status(204).Send('');
      end);

  TRouteDoc.Delete('/exemplos/:id')
    .Summary('Excluir exemplo')
    .Tag('exemplos')
    .PathParam('id', 'ID do exemplo', qptInteger)
    .NoContent('204', 'Excluído com sucesso')
    .NoContent('404', 'Exemplo não encontrado')
    .Register(
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TNextProc)
      var
        LId: Integer;
      begin
        LId := StrToIntDef(Req.Params['id'], 0);
        AService.Delete(LId);
        Res.Status(204).Send('');
      end);
end;

end.
