unit Exemplo.Service;

interface

uses
  Exemplo.DTOs,
  Exemplo.Repository;

type

  IExemploService = interface
    ['{A7B8C9D0-E1F2-3A4B-5C6D-7E8F9A0B1C2D}']
    function Find(ADto: IExemploFindDTO): TExemploPageResult;
    function FindById(const AId: Integer): IExemploResponseDTO;
    function Insert(ADto: IExemploInsertDTO): IExemploResponseDTO;
    procedure Update(const AId: Integer; ADto: IExemploUpdateDTO);
    procedure Delete(const AId: Integer);
  end;

  TExemploService = class(TInterfacedObject, IExemploService)
  private
    FRepository: IExemploRepository;
  public
    constructor Create(ARepository: IExemploRepository);
    function Find(ADto: IExemploFindDTO): TExemploPageResult;
    function FindById(const AId: Integer): IExemploResponseDTO;
    function Insert(ADto: IExemploInsertDTO): IExemploResponseDTO;
    procedure Update(const AId: Integer; ADto: IExemploUpdateDTO);
    procedure Delete(const AId: Integer);
  end;

implementation

uses
  System.SysUtils;

{ TExemploService }

constructor TExemploService.Create(ARepository: IExemploRepository);
begin
  FRepository := ARepository;
end;

function TExemploService.Find(ADto: IExemploFindDTO): TExemploPageResult;
begin
  Result := FRepository.Find(ADto);
end;

function TExemploService.FindById(const AId: Integer): IExemploResponseDTO;
begin
  if AId <= 0 then
    raise Exception.Create('ID inválido.');
  Result := FRepository.FindById(AId);
end;

function TExemploService.Insert(ADto: IExemploInsertDTO): IExemploResponseDTO;
begin
  if Trim(ADto.Nome) = '' then
    raise Exception.Create('Nome é obrigatório.');
  Result := FRepository.Insert(ADto);
end;

procedure TExemploService.Update(const AId: Integer; ADto: IExemploUpdateDTO);
begin
  if Assigned(ADto.Nome) and ADto.Nome.HasValue and (Trim(ADto.Nome.Value) = '') then
    raise Exception.Create('Nome não pode ser vazio.');
  FRepository.Update(AId, ADto);
end;

procedure TExemploService.Delete(const AId: Integer);
begin
  FRepository.Delete(AId);
end;

end.
