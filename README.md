# BasicPDF
Basic PDF file creation library

Sample function:
```
procedure TForm1.Button1Click(Sender: TObject);
var
  PDF: TBasicPDF;
begin
  PDF := TBasicPDF.Create;
  try
    PDF.AddText('Hello, World!', 100, 100); // X=100, Y=100 (from top-left)
    PDF.SaveToFile('HelloWorld.pdf');       // coordinates in points (1 point = 1/72 inch)
  finally
    PDF.Free;
  end;
end;
```
