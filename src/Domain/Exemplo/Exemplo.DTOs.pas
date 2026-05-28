{$CODEPAGE UTF8}
unit Exemplo.DTOs;

interface

uses
  Common.Optionals,
  Common.DTO.Base,
  Common.Pagination,
  Common.JsonMapper,
  Swagger.Attributes;

type

  { Response }

  IExemploResponseDTO = interface(IResponseDTOBase)
    ['{B2C3D4E5-F6A7-8B9C-0D1E-2F3A4B5C6D7E}']
    function GetId: Integer;
    function GetNome: string;
    property Id: Integer read GetId;
    property Nome: string read GetNome;
  end;

  TExemploResponseDTO = class(TResponseDTOBase, IExemploResponseDTO)
  private
    FId: Integer;
    FNome: string;
  public
    class constructor Create;
    [SwagProp('ID do exemplo', '1')]
    function GetId: Integer;

    procedure SetId(const AValue: Integer);

    [SwagProp('Nome do exemplo', 'Exemplo 1')]
    function GetNome: string;

    procedure SetNome(const AValue: string);
    property Id: Integer read GetId write SetId;
    property Nome: string read GetNome write SetNome;
  end;

  { Find (paginado) }

  IExemploFindDTO = interface(IFindPaginationDTOBase)
    ['{C3D4E5F6-A7B8-9C0D-1E2F-3A4B5C6D7E8F}']
  end;

  TExemploFindDTO = class(TFindPaginationDTOBase, IExemploFindDTO)
  public
    class constructor Create;
  end;

  { Insert }

  IExemploInsertDTO = interface(IInsertDTOBase)
    ['{D4E5F6A7-B8C9-0D1E-2F3A-4B5C6D7E8F9A}']
    function GetNome: string;
    property Nome: string read GetNome;
  end;

  TExemploInsertDTO = class(TInsertDTOBase, IExemploInsertDTO)
  private
    FNome: string;
  public
    class constructor Create;
    [SwagProp('Nome do exemplo', 'Exemplo 1')]
    function GetNome: string;
    procedure SetNome(const AValue: string);
    property Nome: string read GetNome write SetNome;
  end;

  { Update (PATCH — todos opcionais) }

  IExemploUpdateDTO = interface(IUpdateDTOBase)
    ['{E5F6A7B8-C9D0-1E2F-3A4B-5C6D7E8F9A0B}']
    function GetNome: IOptString;
    procedure SetNome(AValue: IOptString);
    property Nome: IOptString read GetNome write SetNome;
  end;

  TExemploUpdateDTO = class(TUpdateDTOBase, IExemploUpdateDTO)
  private
    FNome: IOptString;
  public
    class constructor Create;
    [SwagProp('Novo nome do exemplo (opcional)', 'Exemplo 1')]
    function GetNome: IOptString;
    procedure SetNome(AValue: IOptString);
    property Nome: IOptString read GetNome write SetNome;
  end;

  { Resultado paginado retornado pelo service }

  TExemploPageResult = record
    Items: TArray<IExemploResponseDTO>;
    Meta:  TPageMeta;
  end;

implementation

{ TExemploResponseDTO }

class constructor TExemploResponseDTO.Create;
begin
  TJsonMapper.RegisterMapping<IExemploResponseDTO, TExemploResponseDTO>;
end;

function TExemploResponseDTO.GetId: Integer;
begin
  Result := FId;
end;

procedure TExemploResponseDTO.SetId(const AValue: Integer);
begin
  FId := AValue;
end;

function TExemploResponseDTO.GetNome: string;
begin
  Result := FNome;
end;

procedure TExemploResponseDTO.SetNome(const AValue: string);
begin
  FNome := AValue;
end;

{ TExemploFindDTO }

class constructor TExemploFindDTO.Create;
begin
  TJsonMapper.RegisterMapping<IExemploFindDTO, TExemploFindDTO>;
end;

{ TExemploInsertDTO }

class constructor TExemploInsertDTO.Create;
begin
  TJsonMapper.RegisterMapping<IExemploInsertDTO, TExemploInsertDTO>;
end;

function TExemploInsertDTO.GetNome: string;
begin
  Result := FNome;
end;

procedure TExemploInsertDTO.SetNome(const AValue: string);
begin
  FNome := AValue;
end;

{ TExemploUpdateDTO }

class constructor TExemploUpdateDTO.Create;
begin
  TJsonMapper.RegisterMapping<IExemploUpdateDTO, TExemploUpdateDTO>;
end;

function TExemploUpdateDTO.GetNome: IOptString;
begin
  Result := TOptionals.Safe(FNome);
end;

procedure TExemploUpdateDTO.SetNome(AValue: IOptString);
begin
  FNome := AValue;
end;

end.
