unit BasicPDF;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections;

type
  TBasicPDF = class
  private
    FStream: TStream;
    FObjects: TList<Integer>;
    FContent: TStringList;
    FPageWidth: Integer;  // A4 width in points (595)
    FPageHeight: Integer; // A4 height in points (842)
    procedure WriteHeader;
    procedure WriteObject1; // Catalog
    procedure WriteObject2; // Pages
    procedure WriteObject3; // Page
    procedure WriteObject4; // Content stream
    procedure WriteObject5; // Font
    procedure WriteXRefTable(XRefOffset: Int64);
    procedure WriteTrailer(XRefOffset: Int64);
    procedure WriteLineToStream(const S: string);
    function EscapeText(const AText: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddText(const AText: string; X, Y: Integer);
    procedure SaveToFile(const AFileName: string);
  end;

implementation

{ TBasicPDF }

constructor TBasicPDF.Create;
begin
  inherited;
  FContent := TStringList.Create;
  FObjects := TList<Integer>.Create;
  FPageWidth := 595;  // A4 width in points (1 point = 1/72 inch)
  FPageHeight := 842; // A4 height in points
  FContent.Add('BT'); // Begin text
end;

destructor TBasicPDF.Destroy;
begin
  FContent.Free;
  FObjects.Free;
  inherited;
end;

procedure TBasicPDF.WriteLineToStream(const S: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.ASCII.GetBytes(S + #13#10);
  if Assigned(FStream) then
    FStream.WriteBuffer(Bytes[0], Length(Bytes));
end;

function TBasicPDF.EscapeText(const AText: string): string;
begin
  Result := AText.Replace('\', '\\', [rfReplaceAll])
                .Replace('(', '\(', [rfReplaceAll])
                .Replace(')', '\)', [rfReplaceAll]);
end;

procedure TBasicPDF.AddText(const AText: string; X, Y: Integer);
var
  AdjustedY: Integer;
begin
  // Adjust Y coordinate to start from the top
  AdjustedY := FPageHeight - Y;
  FContent.Add(Format('/F1 12 Tf %d %d Td (%s) Tj', [X, AdjustedY, EscapeText(AText)]));
end;

procedure TBasicPDF.WriteHeader;
const
  Header = '%PDF-1.4'#13#10'%'#$E2#$E3#$CF#$D3#13#10;
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.ASCII.GetBytes(Header);
  FStream.WriteBuffer(Bytes[0], Length(Bytes));
end;

procedure TBasicPDF.WriteObject1;
begin
  FObjects.Add(FStream.Position);
  WriteLineToStream('1 0 obj');
  WriteLineToStream('<<');
  WriteLineToStream('/Type /Catalog');
  WriteLineToStream('/Pages 2 0 R');
  WriteLineToStream('>>');
  WriteLineToStream('endobj');
end;

procedure TBasicPDF.WriteObject2;
begin
  FObjects.Add(FStream.Position);
  WriteLineToStream('2 0 obj');
  WriteLineToStream('<<');
  WriteLineToStream('/Type /Pages');
  WriteLineToStream('/Kids [3 0 R]');
  WriteLineToStream('/Count 1');
  WriteLineToStream('>>');
  WriteLineToStream('endobj');
end;

procedure TBasicPDF.WriteObject3;
begin
  FObjects.Add(FStream.Position);
  WriteLineToStream('3 0 obj');
  WriteLineToStream('<<');
  WriteLineToStream('/Type /Page');
  WriteLineToStream('/Parent 2 0 R');
  WriteLineToStream('/Contents 4 0 R');
  WriteLineToStream('/Resources <<');
  WriteLineToStream('/Font <<');
  WriteLineToStream('/F1 5 0 R');
  WriteLineToStream('>>');
  WriteLineToStream('>>');
  WriteLineToStream(Format('/MediaBox [0 0 %d %d]', [FPageWidth, FPageHeight])); // A4 size
  WriteLineToStream('>>');
  WriteLineToStream('endobj');
end;

procedure TBasicPDF.WriteObject4;
var
  Content: string;
  Bytes: TBytes;
begin
  FContent.Add('ET'); // End text
  Content := FContent.Text;

  FObjects.Add(FStream.Position);
  WriteLineToStream('4 0 obj');
  WriteLineToStream('<<');
  WriteLineToStream('/Length ' + IntToStr(Length(Content)));
  WriteLineToStream('>>');
  WriteLineToStream('stream');
  Bytes := TEncoding.ASCII.GetBytes(Content);
  FStream.WriteBuffer(Bytes[0], Length(Bytes));
  WriteLineToStream('endstream');
  WriteLineToStream('endobj');
end;

procedure TBasicPDF.WriteObject5;
begin
  FObjects.Add(FStream.Position);
  WriteLineToStream('5 0 obj');
  WriteLineToStream('<<');
  WriteLineToStream('/Type /Font');
  WriteLineToStream('/Subtype /Type1');
  WriteLineToStream('/BaseFont /Helvetica');
  WriteLineToStream('>>');
  WriteLineToStream('endobj');
end;

procedure TBasicPDF.WriteXRefTable(XRefOffset: Int64);
var
  i: Integer;
  OffsetStr: string;
begin
  WriteLineToStream('xref');
  WriteLineToStream('0 6'); // 6 entries: 0-5

  // Entry for object 0 (free)
  WriteLineToStream('0000000000 65535 f ');

  // Entries for objects 1-5
  for i := 0 to FObjects.Count - 1 do
  begin
    OffsetStr := Format('%.10d', [FObjects[i]]);
    WriteLineToStream(OffsetStr + ' 00000 n ');
  end;
end;

procedure TBasicPDF.WriteTrailer(XRefOffset: Int64);
begin
  WriteLineToStream('trailer');
  WriteLineToStream('<<');
  WriteLineToStream('/Size 6');
  WriteLineToStream('/Root 1 0 R');
  WriteLineToStream('>>');
  WriteLineToStream('startxref');
  WriteLineToStream(IntToStr(XRefOffset));
  WriteLineToStream('%%EOF');
end;

procedure TBasicPDF.SaveToFile(const AFileName: string);
var
  FileStream: TFileStream;
  XRefOffset: Int64;
begin
  FileStream := TFileStream.Create(AFileName, fmCreate);
  try
    FStream := FileStream;
    FObjects.Clear;

    WriteHeader;

    // Write objects 1-5
    WriteObject1; // Catalog
    WriteObject2; // Pages
    WriteObject3; // Page
    WriteObject4; // Content stream
    WriteObject5; // Font

    // Write xref table
    XRefOffset := FileStream.Position;
    WriteXRefTable(XRefOffset);

    // Write trailer
    WriteTrailer(XRefOffset);
  finally
    FileStream.Free;
  end;
end;

end.
