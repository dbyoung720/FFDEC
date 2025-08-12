unit Unit1;

interface

uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses dbyoung.FFDEC;

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
var
  strCurrPath: string;
begin
  strCurrPath := ExtractFilePath(ParamStr(0));
  TVideoDecode.Create(strCurrPath + 'dll\ffmpeg\', strCurrPath + 'h264.mp4', Handle);
end;

end.
