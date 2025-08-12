unit dbyoung.FFDEC;

interface

uses Winapi.Windows, Winapi.Direct3D9, Winapi.DXTypes, System.Classes, System.SysUtils, System.Math, System.Threading, Vcl.Graphics, Vcl.Forms, dbyoung.FFMPEG, Winapi.D3DX9;

{ TVideoDecode }
type
  TVideoDecode = class(TThread)
  private
    Fpfct         : PAVFormatContext;
    Fpcct         : PAVCodecContext;
    FiVideoIndex  : Integer;
    FpGPUFrame    : PAVFrame;
    Favp          : TAVPacket;
    FhDrawUI      : THandle;
    Fswsct        : PSwsContext;
    FintST        : Cardinal;
    FintFrameCount: Integer;
    FintRate      : Integer;
    Fpriv         : PDXVA2DevicePriv;
    FDXFont       : ID3DXFont;
    procedure VideoDecode(DecCT: PAVCodecContext; pkt: TAVPacket; pGPUVideoframe: PAVFrame);
    procedure dxPlay(pGPUVideoframe: PAVFrame; DecCT: PAVCodecContext; const hWnd: THandle);
    procedure CreateFont(d3d: IDirect3DDevice9);
    procedure RenderText;
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
  FhDrawUI        := hDrawUI;

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

  { 7.1 解码准备 --- 初始化临时帧临时变量 }
  FpGPUFrame := av_frame_alloc();

  { 7.1 解码准备 --- 用于计算帧率 }
  FintST         := GetTickCount;
  FintFrameCount := 0;
end;

destructor TVideoDecode.Destroy;
begin
  { 7.6 销毁解码资源 }
  avcodec_free_context(@Fpcct);
  av_frame_free(@FpGPUFrame);
  avformat_close_input(@Fpfct);
  av_buffer_unref(@hw_device_ctx);
  if Fswsct <> nil then
    sws_freeContext(Fswsct);
  if FDXFont <> nil then
    FDXFont := nil;

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

procedure TVideoDecode.CreateFont(d3d: IDirect3DDevice9);
var
  FontDesc: TD3DXFontDesc;
begin
  ZeroMemory(@FontDesc, SizeOf(FontDesc));
  FontDesc.Height := Round(Fpcct^.Height * 0.042 + 8);
  FontDesc.Width  := 0;
  FontDesc.Weight := FW_NORMAL;
  FontDesc.Italic := False;
  StrCopy(FontDesc.FaceName, '宋体');
  D3DXCreateFontIndirect(d3d, FontDesc, FDXFont);
end;

{ 绘制速率 }
procedure TVideoDecode.RenderText;
var
  iSpace: Integer;
  rct01 : TRect;
  rct02 : TRect;
  rct03 : TRect;
  rct04 : TRect;
begin
  iSpace := Round(Fpcct^.Height * 0.043 + 7);

  rct01 := Rect(20, 0 * iSpace + 20, 1800, 120);
  rct02 := Rect(20, 1 * iSpace + 20, 1800, 220);
  rct03 := Rect(20, 2 * iSpace + 20, 1800, 320);
  rct04 := Rect(20, 3 * iSpace + 20, 1800, 420);
  FDXFont.DrawTextW(nil, PChar('作者(Auth)：dbyoung@sina.com'),                                          -1, @rct01, DT_LEFT or DT_TOP, D3DCOLOR_XRGB(255, 0, 0));
  FDXFont.DrawTextW(nil, PChar('大小(Size)：' + InttoStr(Fpcct^.Width) + 'X' + InttoStr(Fpcct^.Height)), -1, @rct02, DT_LEFT or DT_TOP, D3DCOLOR_XRGB(0, 255, 0));
  FDXFont.DrawTextW(nil, PChar('用时(Time)：' + InttoStr((GetTickCount - FintST) div 1000) + '秒'),      -1, @rct03, DT_LEFT or DT_TOP, D3DCOLOR_XRGB(0, 0, 255));
  FDXFont.DrawTextW(nil, PChar('速率(Rate)：' + InttoStr(FintRate) + '帧/秒'),                           -1, @rct04, DT_LEFT or DT_TOP, D3DCOLOR_XRGB(255, 255, 0));
end;

var
  FbD3DReset : Boolean      = False;
  FSelfObject: TVideoDecode = nil;

procedure TimerProc(hWnd: THandle; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
begin
  KillTimer(Application.MainForm.Handle, idEvent);
  FbD3DReset := ResetD3D(FSelfObject.Fpcct^.Width, FSelfObject.Fpcct^.Height, FSelfObject.Fpriv^.d3d9device, FSelfObject.FhDrawUI);
end;

procedure TVideoDecode.dxPlay(pGPUVideoframe: PAVFrame; DecCT: PAVCodecContext; const hWnd: THandle);
var
  device_ctx: PAVHWDeviceContext;
  BackBuffer: IDIRECT3DSURFACE9;
  SourceRect: TRect;
  surface   : IDIRECT3DSURFACE9;
begin
  { 重置 D3D 设备，将渲染表面指向我们的窗体 }
  if not FbD3DReset then
  begin
    device_ctx  := PAVHWDeviceContext(DecCT^.hw_device_ctx^.data); // 设备上下文信息
    Fpriv       := PDXVA2DevicePriv(device_ctx^.user_opaque);      // DX 设备信息
    FSelfObject := Self;                                           // 保存下当前对象
    SetTimer(Application.MainForm.Handle, 1000, 1, @TimerProc);    // 重置 D3D 设备
    CreateFont(Fpriv^.d3d9device);                                 // 用于 DX 界面上绘制文本
  end;

  if FbD3DReset then
  begin
    { 开始渲染 }
    Fpriv^.d3d9device.BeginScene;
    BackBuffer := nil;
    surface    := IDIRECT3DSURFACE9(pGPUVideoframe^.data[3]); // 待绘制的数据
    Fpriv^.d3d9device.Clear(0, nil, D3DCLEAR_TARGET, D3DCOLOR_XRGB(0, 0, 0), 1.0, 0);
    Fpriv^.d3d9device.GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_MONO, BackBuffer);
    SourceRect := Rect(0, 0, DecCT^.Width, DecCT^.Height);
    Fpriv^.d3d9device.StretchRect(surface, @SourceRect, BackBuffer, nil, D3DTEXF_LINEAR);
    RenderText;
    Fpriv^.d3d9device.EndScene;
    Fpriv^.d3d9device.Present(nil, nil, 0, nil);

    { 释放临时资源 }
    BackBuffer._Release;
    BackBuffer := nil;
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

      if TAVPixelFormat(pGPUVideoframe^.Format) <> hw_pix_fmt then
        Break;

      { 7.4 计算帧率。0.000001+ 避免分母为零 }
      Inc(FintFrameCount);
      FintRate := Round(1000 * FintFrameCount / (0.000001 + GetTickCount - FintST));

      { DX 渲染 }
      dxPlay(pGPUVideoframe, DecCT, FhDrawUI);
    end;
  end;
end;

end.
