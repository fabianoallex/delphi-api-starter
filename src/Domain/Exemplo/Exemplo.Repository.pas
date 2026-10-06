unit Exemplo.Repository;

interface

uses
  System.SysUtils,
  PascalDb.Interfaces,
  PascalCommon.Optionals,
  Common.OrderBy,
  Exemplo.DTOs;

type

  IExemploRepository = interface
    ['{F6A7B8C9-D0E1-2F3A-4B5C-6D7E8F9A0B1C}']
    function Find(ADto: IExemploFindDTO): TExemploPageResult;
    function FindById(const AId: Integer): IExemploResponseDTO;
    function Insert(ADto: IExemploInsertDTO): IExemploResponseDTO;
    function Update(const AId: Integer; ADto: IExemploUpdateDTO): Boolean;  // False = id inexistente
    function Delete(const AId: Integer): Boolean;                            // False = id inexistente
  end;

  TExemploRepository = class(TInterfacedObject, IExemploRepository)
  private
    FFactory: IDBFactory;
    function BuildResponseDTO(AResult: IQueryResult): IExemploResponseDTO;
  public
    constructor Create(AFactory: IDBFactory);

    /// <summary>
    /// Especificação de ordenação do endpoint GET /exemplos.
    /// Usar no controller para gerar o DocHint do QueryParam 'orderBy'.
    /// </summary>
    class function OrderBySpec: TOrderBySpec;

    function Find(ADto: IExemploFindDTO): TExemploPageResult;
    function FindById(const AId: Integer): IExemploResponseDTO;
    function Insert(ADto: IExemploInsertDTO): IExemploResponseDTO;
    function Update(const AId: Integer; ADto: IExemploUpdateDTO): Boolean;  // False = id inexistente
    function Delete(const AId: Integer): Boolean;                            // False = id inexistente
  end;

implementation

uses
  PascalDb.SqlLoader,
  Common.Pagination;

{ TExemploRepository }

constructor TExemploRepository.Create(AFactory: IDBFactory);
begin
  FFactory := AFactory;
end;

class function TExemploRepository.OrderBySpec: TOrderBySpec;
begin
  Result := TOrderBySpec.New
    .Allow('id',   'ID')
    .Allow('nome', 'NOME')
    .Default('id');
end;

function TExemploRepository.BuildResponseDTO(AResult: IQueryResult): IExemploResponseDTO;
var
  LDto: TExemploResponseDTO;
begin
  LDto := TExemploResponseDTO.Create;
  LDto.Id   := AResult.Integers['ID'];
  LDto.Nome := AResult.Strings['NOME'];
  Result := LDto;
end;

function TExemploRepository.Find(ADto: IExemploFindDTO): TExemploPageResult;
var
  LScope: IScopeTransaction;
  LQuery: IQuery;
  LResult: IQueryResult;
  LParams: TPageParams;
  LHasSearch: Boolean;
  LFindSql, LCountSql: TSQLResult;
  LOrderByExpr: string;
begin
  if not Assigned(ADto) then                     // único Assigned legítimo: o DTO inteiro
    raise Exception.Create('[ADto: IExemploFindDTO] não pode ser nil');

  LParams    := TPageParams.From(ADto.Page, ADto.Limit);
  LHasSearch := ADto.Search.HasValue and (Trim(ADto.Search.Value) <> '');

  LOrderByExpr := '';
  if ADto.OrderBy.HasValue then
    LOrderByExpr := ADto.OrderBy.Value;

  LFindSql := FFactory.SqlLoader['EXEMPLO.FIND']
    .ReplaceLiteral('LIMIT',    IntToStr(LParams.Limit))
    .ReplaceLiteral('OFFSET',   IntToStr(LParams.Offset))
    .ReplaceLiteral('ORDER_BY', OrderBySpec.Build(LOrderByExpr))
    .ProcessTag('SEARCH', LHasSearch);

  LCountSql := FFactory.SqlLoader['EXEMPLO.FIND_COUNT']
    .ProcessTag('SEARCH', LHasSearch);

  Result.Items    := [];
  Result.Meta.Page  := LParams.Page;
  Result.Meta.Limit := LParams.Limit;
  Result.Meta.Total := 0;

  // Count
  LScope := FFactory.GetPool.AcquireQuery(LQuery);
  LScope.StartTransaction;
  try
    LQuery.Sql := LCountSql.SQL;
    if LHasSearch then LQuery.Params.Strings['SEARCH'] := ADto.Search.Value;
    LResult := LQuery.Open;
    if not LResult.IsEmpty then
      Result.Meta.Total := LResult.Integers['TOTAL'];
    LScope.Commit;
  except
    LScope.Rollback;
    raise;
  end;

  // Data
  LScope := FFactory.GetPool.AcquireQuery(LQuery);
  LScope.StartTransaction;
  try
    LQuery.Sql := LFindSql.SQL;
    if LHasSearch then LQuery.Params.Strings['SEARCH'] := ADto.Search.Value;
    LResult := LQuery.Open;
    while not LResult.Eof do
    begin
      Result.Items := Result.Items + [BuildResponseDTO(LResult)];
      LResult.Next;
    end;
    LScope.Commit;
  except
    LScope.Rollback;
    raise;
  end;
end;

function TExemploRepository.FindById(const AId: Integer): IExemploResponseDTO;
var
  LScope: IScopeTransaction;
  LQuery: IQuery;
  LResult: IQueryResult;
begin
  Result := nil;
  LScope := FFactory.GetPool.AcquireQuery(LQuery);
  LScope.StartTransaction;
  try
    LQuery.Sql := FFactory.SqlLoader['EXEMPLO.FIND_BY_ID'].SQL;
    LQuery.Params.Integers['ID'] := AId;
    LResult := LQuery.Open;
    if not LResult.IsEmpty then
      Result := BuildResponseDTO(LResult);
    LScope.Commit;
  except
    LScope.Rollback;
    raise;
  end;
end;

function TExemploRepository.Insert(ADto: IExemploInsertDTO): IExemploResponseDTO;
var
  LScope: IScopeTransaction;
  LQuery: IQuery;
  LResult: IQueryResult;
begin
  Result := nil;
  LScope := FFactory.GetPool.AcquireQuery(LQuery);
  LScope.StartTransaction;
  try
    LQuery.Sql := FFactory.SqlLoader['EXEMPLO.INSERT'].SQL;
    LQuery.Params.Strings['NOME'] := ADto.Nome;
    LResult := LQuery.Open;
    if not LResult.IsEmpty then
      Result := BuildResponseDTO(LResult);
    LScope.Commit;
  except
    LScope.Rollback;
    raise;
  end;
end;

function TExemploRepository.Update(const AId: Integer; ADto: IExemploUpdateDTO): Boolean;
var
  LScope: IScopeTransaction;
  LQuery: IQuery;
begin
  if not Assigned(ADto) then                     // único Assigned legítimo: o DTO inteiro
    raise Exception.Create('[ADto: IExemploUpdateDTO] não pode ser nil');

  // Roda mesmo sem campo para mudar (o SET tem "ID = ID" fora das tags):
  // assim PATCH {} num id inexistente também responde 404.
  LScope := FFactory.GetPool.AcquireQuery(LQuery);
  LScope.StartTransaction;
  try
    LQuery.Sql := FFactory.SqlLoader['EXEMPLO.UPDATE']
      .ProcessTag('NOME', ADto.Nome.HasValue)
      .SQL;

    LQuery.Params.OptStrings['NOME'] := ADto.Nome;
    LQuery.Params.Integers['ID'] := AId;
    Result := LQuery.ExecSql > 0;                 // linhas afetadas (0 = não achou)
    LScope.Commit;
  except
    LScope.Rollback;
    raise;
  end;
end;

function TExemploRepository.Delete(const AId: Integer): Boolean;
var
  LScope: IScopeTransaction;
  LQuery: IQuery;
begin
  LScope := FFactory.GetPool.AcquireQuery(LQuery);
  LScope.StartTransaction;
  try
    LQuery.Sql := FFactory.SqlLoader['EXEMPLO.DELETE'].SQL;
    LQuery.Params.Integers['ID'] := AId;
    Result := LQuery.ExecSql > 0;                 // linhas afetadas (0 = não achou)
    LScope.Commit;
  except
    LScope.Rollback;
    raise;
  end;
end;

end.
