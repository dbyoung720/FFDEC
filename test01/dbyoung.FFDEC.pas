unit dbyoung.FFDEC;

interface

uses Winapi.Windows, System.Classes, System.SysUtils, System.Math, System.Threading, Vcl.Graphics, Vcl.Forms, dbyoung.FFMPEG;

{ TVideoDecode }
type
  TVideoDecode = class(TThread)
  private
    Fpfct         : PAVFormatContext;
    Fpcct         : PAVCodecContext;
    FiVideoIndex  : Integer;
    FpCPUFrame    : PAVFrame;
    FpGPUFrame    : PAVFrame;
    FBmp32        : TBitmap;
    FpBits        : Pointer;
    Favp          : TAVPacket;
    FDrawUICanvas : TCanvas;
    Fswsct        : PSwsContext;
    FintST        : Cardinal;
    FintFrameCount: Integer;
    FintRate      : Integer;
    Filine        : Integer;
    FiSpace       : Integer;
    FiFontSize    : Integer;
    procedure FrameToBitmap(const frame: PAVFrame);
    procedure VideoDecode(DecCT: PAVCodecContext; pkt: TAVPacket; pGPUVideoframe: PAVFrame);
    procedure UpdateUI;
  protected
    procedure Execute; override;
  public
    constructor Create(const strFFMPEGDLLPath, strVideoFileName: string; const hDrawUI: THandle); overload;
    destructor Destroy; override;
  end;

implementation

{ TVideoDecode }

type
  TBMPAccess         = class(TBitmap);
  TBitmapImageAccess = class(TBitmapImage);

constructor TVideoDecode.Create(const strFFMPEGDLLPath, strVideoFileName: string; const hDrawUI: THandle);
var
  decoder: PAVCodec;
  type_  : TAVHWDeviceType;
begin
  inherited Create(False);
  FreeOnTerminate := True;

  { 动态加载 FFMPEG DLL }
  AddDllDirectory(PChar(strFFMPEGDLLPath));
  InitFFMPEG();

  { 文件是否存在 }
  if not FileExists(strVideoFileName) then
    Exit;

  { + 寻找硬件解码器 }
  if not FindHWDecoder(c_strHWType, type_) then
    Exit;

  { 1. 打开文件 }
  Fpfct := nil;
  if avformat_open_input(@Fpfct, PAnsiChar(AnsiString(strVideoFileName)), nil, nil) <> 0 then
    Exit;

  { 2. 文件中是否包含流 }
  if avformat_find_stream_info(Fpfct, nil) < 0 then
    Exit;

  { 3. 查找是否包含视频流 }
  FiVideoIndex := av_find_best_stream(Fpfct, AVMEDIA_TYPE_VIDEO, -1, -1, nil, 0);
  if FiVideoIndex < 0 then
    Exit;

  { 4. 寻找解码器 }
  decoder := avcodec_find_decoder(Fpfct^.streams[FiVideoIndex]^.codecpar^.codec_id);
  if decoder = nil then
    Exit;

  { + 查询硬件是否支持此格式视频硬解 }
  if not GetSupportHWConfig(decoder, type_) then
    Exit;

  { 5.0 初始化解码器 }
  Fpcct := avcodec_alloc_context3(decoder);
  if Fpcct = nil then
    Exit;

  { 5.1 将视频流里面的参数复制到 AVCodecContext 的上下文当中 }
  if avcodec_parameters_to_context(Fpcct, Fpfct^.streams[FiVideoIndex]^.codecpar) < 0 then
    Exit;

  { + 初始化硬解解码器 }
  if not InitHWDecoder(Fpcct, type_) then
    Exit;

  { 6. 打开解码器 }
  if avcodec_open2(Fpcct, decoder, nil) < 0 then
    Exit;

  { 7.1 解码准备 --- 创建临时画布，用于解码后的图片绘制到界面 }
  FDrawUICanvas        := TCanvas.Create;
  FDrawUICanvas.Handle := GetDC(hDrawUI);

  { 7.1 解码准备 --- 创建临时位图，设置输出图片为 32bit 位图 }
  FBmp32             := TBitmap.Create;
  FBmp32.PixelFormat := pf32bit;
  FBmp32.Width       := Fpcct^.Width;
  FBmp32.Height      := Fpcct^.Height;
  Filine             := TBitmapImageAccess(TBMPAccess(FBmp32).FImage).FDIB.dsBm.bmWidthBytes;
  FpBits             := TBitmapImageAccess(TBMPAccess(FBmp32).FImage).FDIB.dsBm.bmBits;

  { 7.1 解码准备 --- 初始化临时帧临时变量 }
  FpGPUFrame := av_frame_alloc();
  FpCPUFrame := av_frame_alloc();

  { 7.1 解码准备 --- 用于计算帧率 }
  FintST         := GetTickCount;
  FintFrameCount := 0;

  { 7.1 解码准备 --- 界面绘制，文字大小、间隔 }
  FiFontSize := GetTextFontSize(Fpcct^.Height);
  FiSpace    := GetTextSpace(Fpcct^.Height);
end;

destructor TVideoDecode.Destroy;
begin
  { 7.6 销毁解码资源 }
  avcodec_free_context(@Fpcct);
  av_frame_free(@FpGPUFrame);
  av_frame_free(@FpCPUFrame);
  avformat_close_input(@Fpfct);
  av_buffer_unref(@hw_device_ctx);
  if Fswsct <> nil then
    sws_freeContext(Fswsct);

  { 7.6 销毁位图资源 }
  FBmp32.Free;

  { 7.6 销毁画布资源 }
  DeleteDC(FDrawUICanvas.Handle);
  FDrawUICanvas.Free;

  FreeFFMPEG;
  inherited;
end;

procedure TVideoDecode.Execute;
begin
  { 7.2 开始解码 }
  while av_read_frame(Fpfct, @Favp) >= 0 do
  begin
    if Terminated then
      Exit;

    if Favp.stream_index = FiVideoIndex then
      VideoDecode(Fpcct, Favp, FpGPUFrame);
  end;
end;

procedure TVideoDecode.VideoDecode(DecCT: PAVCodecContext; pkt: TAVPacket; pGPUVideoframe: PAVFrame);
var
  ret: Integer;
begin
  if avcodec_send_packet(DecCT, @pkt) = 0 then
  begin
    while True do
    begin
      if Terminated then
        Break;

      ret := avcodec_receive_frame(DecCT, pGPUVideoframe);
      if (ret = AVERROR_EAGAIN) or (ret = AVERROR_EOF) then
        Break;

      if ret < 0 then
        Break;

      if TAVPixelFormat(pGPUVideoframe^.format) <> hw_pix_fmt then
        Break;

      { 硬解码转换 GPU 显存 ---> CPU 内存 }
      ret := av_hwframe_transfer_data(FpCPUFrame, pGPUVideoframe, 0);
      if ret < 0 then
        Break;

      { 7.3 得到一帧视频。一帧视频解码到位图 }
      FrameToBitmap(FpCPUFrame);

      { 7.4 计算帧率。0.000001 + 避免分母为零 }
      Inc(FintFrameCount);
      FintRate := Round(1000 * FintFrameCount / (0.000001 + GetTickCount - FintST));

      { 7.5 绘制到界面 }
      Synchronize(UpdateUI);
    end;
  end;
end;

procedure TVideoDecode.FrameToBitmap(const frame: PAVFrame);
begin
  { 只初始化一次，不用次次创建，提高效率 }
  if Fswsct = nil then
    Fswsct := sws_getContext(Fpcct^.Width, Fpcct^.Height, frame^.format, Fpcct^.Width, Fpcct^.Height, AV_PIX_FMT_RGB32, SWS_BICUBIC, nil, nil, nil);

  { 获取到位图。sws_scale 函数效率低下, libyuv 效率较高 }
  if frame^.format = AV_PIX_FMT_NV12 then
  begin
    libYUV_NV12ToARGB(frame^.data[0], frame^.linesize[0], frame^.data[1], frame^.linesize[1], FpBits, Filine, frame^.Width, -frame^.Height);
  end
  else if frame^.format = AV_PIX_FMT_P010LE then
  begin
    libYUV_P010LEToARGB(frame, FpBits, Filine, frame^.Width, -frame^.Height);
  end
  else
  begin
    sws_scale(Fswsct, @frame^.data, @frame^.linesize, 0, frame^.Height, @FpBits, @Filine); { 获取到位图 }
    VertiMirror(FBmp32);                                                                   { 图像垂直翻转 }
  end;
end;

procedure TVideoDecode.UpdateUI;
begin
  { 绘制解码速率 }
  FBmp32.Canvas.Brush.Style := bsClear;
  FBmp32.Canvas.Font.Size   := FiFontSize;
  FBmp32.Canvas.Font.Name   := '宋体';
  FBmp32.Canvas.Font.Color  := clRed;
  FBmp32.Canvas.TextOut(20, 20 + FiSpace * 0, '作者(Auth)：dbyoung@sina.com');
  FBmp32.Canvas.Font.Color := clGreen;
  FBmp32.Canvas.TextOut(20, 20 + FiSpace * 1, '大小(Size)：' + InttoStr(Fpcct^.Width) + 'X' + InttoStr(Fpcct^.Height));
  FBmp32.Canvas.Font.Color := clBlue;
  FBmp32.Canvas.TextOut(20, 20 + FiSpace * 2, '用时(Time)：' + InttoStr((GetTickCount - FintST) div 1000) + '秒');
  FBmp32.Canvas.Font.Color := clYellow;
  FBmp32.Canvas.TextOut(20, 20 + FiSpace * 3, '速率(Rate)：' + InttoStr(FintRate) + '帧/秒');

  { 绘制到界面 }
  FDrawUICanvas.StretchDraw(FDrawUICanvas.ClipRect, FBmp32);
end;

end.
