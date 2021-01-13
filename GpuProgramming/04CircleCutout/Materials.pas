unit Materials;

interface

uses
  System.Classes,
  System.SysUtils,
  FMX.Types3D,
  FMX.Graphics,
  FMX.Materials,
  FMX.MaterialSources;

type
  TCircleCutoutMaterialSource = class(TMaterialSource)
  private
    FImage: TBitmap;
    procedure SetImage(const AValue: TBitmap);
    procedure HandleImageChanged(Sender: TObject);
  protected
    function CreateMaterial: TMaterial; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Image: TBitmap read FImage write SetImage;
  end;

type
  TCircleCutoutMaterial = class(TCustomMaterial)
  private class var
    FShaderArch: TContextShaderArch;
    FVertexShaderData: TBytes;
    FPixelShaderData: TBytes;
    FMatrixIndex: Integer;
    FMatrixSize: Integer;
  private
    FTexture: TTexture; // Reference
    procedure SetTexture(const AValue: TTexture);
  private
    class procedure LoadShaders; static;
    class function LoadShader(const AResourceName: String): TBytes; static;
  protected
    procedure DoInitialize; override;
    procedure DoApply(const Context: TContext3D); override;
  public
    property Texture: TTexture read FTexture write SetTexture;
  end;

implementation

uses
  System.Types,
  {$IF Defined(MSWINDOWS)}
  FMX.Context.DX9,
  FMX.Context.DX11;
  {$ELSEIF Defined(ANDROID)}
  FMX.Context.GLES;
  {$ELSEIF Defined(IOS)}
  FMX.Context.GLES,
  FMX.Context.Metal;
  {$ELSEIF Defined(MACOS)}
  FMX.Context.Mac,
  FMX.Context.Metal;
  {$ELSE}
    {$MESSAGE Error 'Unsupported platform'}
  {$ENDIF}

{$R 'Shaders\Shaders.res'}

{ TCircleCutoutMaterialSource }

constructor TCircleCutoutMaterialSource.Create(AOwner: TComponent);
begin
  inherited;
  FImage := TTextureBitmap.Create;
  FImage.OnChange := HandleImageChanged;
end;

function TCircleCutoutMaterialSource.CreateMaterial: TMaterial;
begin
  Result := TCircleCutoutMaterial.Create;
end;

destructor TCircleCutoutMaterialSource.Destroy;
begin
  FImage.Free;
  inherited;
end;

procedure TCircleCutoutMaterialSource.HandleImageChanged(Sender: TObject);
begin
  if (not FImage.IsEmpty) then
    TCircleCutoutMaterial(Material).Texture := TTextureBitmap(FImage).Texture;
end;

procedure TCircleCutoutMaterialSource.SetImage(const AValue: TBitmap);
begin
  FImage.Assign(AValue);
end;

{ TCircleCutoutMaterial }

procedure TCircleCutoutMaterial.DoApply(const Context: TContext3D);
begin
  inherited;
  Context.SetShaderVariable('Texture', FTexture);
end;

procedure TCircleCutoutMaterial.DoInitialize;
begin
  inherited;
  if (FShaderArch = TContextShaderArch.Undefined) then
    LoadShaders;

  FVertexShader := TShaderManager.RegisterShaderFromData('CircleCutout.fvs',
    TContextShaderKind.VertexShader, '', [
    TContextShaderSource.Create(FShaderArch, FVertexShaderData,
    [TContextShaderVariable.Create('MVPMatrix', TContextShaderVariableKind.Matrix,
      FMatrixIndex, FMatrixSize)])
  ]);

  FPixelShader := TShaderManager.RegisterShaderFromData('CircleCutout.fps',
    TContextShaderKind.PixelShader, '', [
    TContextShaderSource.Create(FShaderArch, FPixelShaderData,
    [TContextShaderVariable.Create('Texture', TContextShaderVariableKind.Texture, 0, 0)])
  ]);
end;

class function TCircleCutoutMaterial.LoadShader(const AResourceName: String): TBytes;
begin
  var Stream := TResourceStream.Create(HInstance, AResourceName, RT_RCDATA);
  try
    SetLength(Result, Stream.Size);
    Stream.ReadBuffer(Result, Length(Result));
  finally
    Stream.Free;
  end;
end;

class procedure TCircleCutoutMaterial.LoadShaders;
begin
  var Suffix := '';
  var ContextClass := TContextManager.DefaultContextClass;

  {$IF Defined(MSWINDOWS)}
  if (ContextClass.InheritsFrom(TCustomDX9Context)) then
  begin
    FShaderArch := TContextShaderArch.DX9;
    FMatrixIndex := 0;
    FMatrixSize := 4;
    Suffix := 'DX9';
  end
  else if (ContextClass.InheritsFrom(TCustomDX11Context)) then
  begin
    FShaderArch := TContextShaderArch.DX11;
    FMatrixIndex := 0;
    FMatrixSize := 64;
    Suffix := 'DX11';
  end;
  {$ELSE}
  if (ContextClass.InheritsFrom(TCustomContextOpenGL)) then
  begin
    FShaderArch := TContextShaderArch.GLSL;
    FMatrixIndex := 0;
    FMatrixSize := 4;
    Suffix := 'GL';
  end;
  {$ENDIF}

  {$IF Defined(MACOS)}
  if (ContextClass.InheritsFrom(TCustomContextMetal)) then
  begin
    FShaderArch := TContextShaderArch.Metal;
    FMatrixIndex := 1;
    FMatrixSize := 4;
    Suffix := 'MTL';
  end;
  {$ENDIF}

  if (FShaderArch = TContextShaderArch.Undefined) then
    raise EContext3DException.Create('Unknown or unsupported 3D context class');

  FVertexShaderData := LoadShader('VERTEX_SHADER_' + Suffix);
  FPixelShaderData := LoadShader('PIXEL_SHADER_' + Suffix);
end;

procedure TCircleCutoutMaterial.SetTexture(const AValue: TTexture);
begin
  FTexture := AValue;
  DoChange;
end;

end.
