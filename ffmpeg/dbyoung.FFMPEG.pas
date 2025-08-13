unit dbyoung.FFMPEG;
{
  功能：FFMPEG Pascal Header (FFMPEG build : 2025-07-13)
  作者：dbyoung@sina.com
  时间：2020-10-01
}

interface

uses Winapi.Windows, Winapi.Direct3D9, Winapi.D3DX9, System.Threading, Vcl.Graphics;

{$I dbyoung.FFMPEG.inc}

var
  { avcodec }
  av_init_packet                 : procedure(pkt: PAVPacket); cdecl;
  av_packet_rescale_ts           : procedure(pkt: PAVPacket; tb_src, tb_dst: TAVRational); cdecl;
  av_packet_unref                : procedure(pkt: PAVPacket); cdecl;
  avcodec_find_decoder_by_name   : function(const name: PAnsiChar): PAVCodec; cdecl;
  avcodec_get_hw_config          : function(const codec: PAVCodec; index: Integer): PAVCodecHWConfig; cdecl;
  avcodec_parameters_to_context  : function(codec: PAVCodecContext; const par: PAVCodecParameters): Integer; cdecl;
  avcodec_receive_frame          : function(avctx: PAVCodecContext; frame: PAVFrame): Integer; cdecl;
  avcodec_send_packet            : function(avctx: PAVCodecContext; const avpkt: PAVPacket): Integer; cdecl;
  avcodec_alloc_context3         : function(const codec: PAVCodec): PAVCodecContext; cdecl;
  avcodec_find_encoder_by_name   : function(const name: PAnsiChar): PAVCodec; cdecl;
  avcodec_free_context           : procedure(avctx: PPAVCodecContext); cdecl;
  avcodec_open2                  : function(avctx: PAVCodecContext; const codec: PAVCodec; options: PPAVDictionary): Integer; cdecl;
  avcodec_parameters_from_context: function(par: PAVCodecParameters; const codec: PAVCodecContext): Integer; cdecl;
  avcodec_receive_packet         : function(avctx: PAVCodecContext; avpkt: PAVPacket): Integer; cdecl;
  avcodec_send_frame             : function(avctx: PAVCodecContext; const frame: PAVFrame): Integer; cdecl;
  avcodec_find_decoder           : function(id: TAVCodecID): PAVCodec; cdecl;
  av_packet_free                 : procedure(pkt: PPAVPacket); cdecl;

  { avformat }
  av_read_frame                 : function(s: PAVFormatContext; pkt: PAVPacket): Integer; cdecl;
  avformat_close_input          : procedure(s: PPAVFormatContext); cdecl;
  avformat_find_stream_info     : function(ic: PAVFormatContext; options: PPAVDictionary): Integer; cdecl;
  avformat_open_input           : function(ps: PPAVFormatContext; const url: PAnsiChar; const fmt: PAVInputFormat; options: PPAVDictionary): Integer; cdecl;
  av_find_best_stream           : function(ic: PAVFormatContext; type_: TAVMediaType; wanted_stream_nb, related_stream: Integer; decoder_ret: PPAVCodec; flags: Integer): Integer; cdecl;
  av_write_frame                : function(s: PAVFormatContext; pkt: PAVPacket): Integer; cdecl;
  av_write_trailer              : function(s: PAVFormatContext): Integer; cdecl;
  avformat_alloc_output_context2: function(ctx: PPAVFormatContext; oformat: PAVOutputFormat; const format_name, filename: PAnsiChar): Integer; cdecl;
  avformat_network_deinit       : function: Integer; cdecl;
  avformat_network_init         : function: Integer; cdecl;
  avformat_write_header         : function(s: PAVFormatContext; options: PPAVDictionary): Integer; cdecl;
  avio_closep                   : function(s: PPAVIOContext): Integer; cdecl;
  avio_open                     : function(s: PPAVIOContext; const url: PAnsiChar; flags: Integer): Integer; cdecl;

  { avutil }
  av_buffer_ref                : function(const buf: PAVBufferRef): PAVBufferRef; cdecl;
  av_buffer_unref              : procedure(const buf: PPAVBufferRef); cdecl;
  av_hwdevice_ctx_create       : function(device_ctx: PPAVBufferRef; type_: TAVHWDeviceType; const device: PAnsiChar; opts: PAVDictionary; flags: Integer): Integer; cdecl;
  av_hwdevice_find_type_by_name: function(const name: PAnsiChar): TAVHWDeviceType; cdecl;
  av_hwframe_transfer_data     : function(dst: PAVFrame; const src: PAVFrame; flags: Integer): Integer; cdecl;
  av_frame_alloc               : function(): PAVFrame; cdecl;
  av_frame_free                : procedure(frame: PPAVFrame); cdecl;
  av_frame_get_buffer          : function(frame: PAVFrame; align: Integer): Integer; cdecl;
  av_frame_make_writable       : function(frame: PAVFrame): Integer; cdecl;

  { swscale }
  sws_freeContext: procedure(swsContext: PSwsContext); cdecl;
  sws_getContext : function(srcW, srcH: Integer; srcFormat: TAVPixelFormat; dstW, dstH: Integer; dstFormat: TAVPixelFormat; flags: Integer; srcFilter, dstFilter: PSwsFilter; param: PDouble): PSwsContext; cdecl;
  sws_scale      : function(c: PSwsContext; const srcSlice: PPByte; const srcStride: PInteger; srcSliceY, srcSliceH: Integer; const dst: PPByte; const dstStride: PInteger): Integer; cdecl;

procedure InitFFMPEG;
procedure FreeFFMPEG;

function AddDllDirectory(strDllPath: PChar): BOOL; stdcall; external kernel32;

{ 图像垂直镜像 }
procedure VertiMirror(bmp: TBitmap);

{ 绘制文字的大小、间隔 }
function GetTextFontSize(const iFrameHeight: Integer): Integer;
function GetTextSpace(const iFrameHeight: Integer): Integer;

{$REGION '◆◆◆ FFMPEG 硬件加速视频解码相关 ◆◆◆'}
const
  hw_type_names: array [0 .. 13] of PAnsiChar = ('cuda', 'drm', 'dxva2', 'd3d11va', 'd3d12va', 'opencl', 'qsv', 'vaapi', 'vdpau', 'videotoolbox', 'mediacodec', 'vulkan', 'amf', 'ohcodec');
  c_strHWType                                 = 'dxva2';

type
  PDXVA2DevicePriv = ^DXVA2DevicePriv;
  DXVA2DevicePriv = record
    d3dlib: HMODULE;
    dxva2lib: HMODULE;
    device_handle: THandle;
    d3d9: IDIRECT3D9;
    d3d9device: IDIRECT3DDEVICE9;
  end;

var
  hw_device_ctx: PAVBufferRef;
  hw_pix_fmt   : TAVPixelFormat;

function FindHWDecoder(const strName: string; var type_: TAVHWDeviceType): Boolean; { 寻找硬件解码器 }
function GetSupportHWConfig(decoder: PAVCodec; type_: TAVHWDeviceType): Boolean;    { 查询硬件是否支持此格式视频硬解 }
function InitHWDecoder(var pcct: PAVCodecContext; type_: TAVHWDeviceType): Boolean; { 初始化硬解解码器 }
function ResetD3D(const iWidth, iHeight: Integer; d3d: IDirect3DDevice9; const hWnd: THandle): Boolean;
{$ENDREGION}

implementation

const
  c_strAvcodecVer               = '62';
  c_strAvformatVer              = '62';
  c_strAvutilVer                = '60';
  c_strSwscaleVer               = '9';
  LOAD_LIBRARY_SEARCH_USER_DIRS = $00001000;

var
  hAvcodec : HMODULE;
  hAvformat: HMODULE;
  hAvutil  : HMODULE;
  hSwscale : HMODULE;

procedure InitFFMPEG();
begin
  hAvcodec                         := LoadLibraryEx(PChar('avcodec-' + c_strAvcodecVer + '.dll'), 0, LOAD_LIBRARY_SEARCH_USER_DIRS);
  @av_init_packet                  := GetProcAddress(hAvcodec, 'av_init_packet');
  @av_packet_rescale_ts            := GetProcAddress(hAvcodec, 'av_packet_rescale_ts');
  @av_packet_unref                 := GetProcAddress(hAvcodec, 'av_packet_unref');
  @avcodec_find_decoder_by_name    := GetProcAddress(hAvcodec, 'avcodec_find_decoder_by_name');
  @avcodec_get_hw_config           := GetProcAddress(hAvcodec, 'avcodec_get_hw_config');
  @avcodec_parameters_to_context   := GetProcAddress(hAvcodec, 'avcodec_parameters_to_context');
  @avcodec_receive_frame           := GetProcAddress(hAvcodec, 'avcodec_receive_frame');
  @avcodec_send_packet             := GetProcAddress(hAvcodec, 'avcodec_send_packet');
  @avcodec_alloc_context3          := GetProcAddress(hAvcodec, 'avcodec_alloc_context3');
  @avcodec_find_encoder_by_name    := GetProcAddress(hAvcodec, 'avcodec_find_encoder_by_name');
  @avcodec_free_context            := GetProcAddress(hAvcodec, 'avcodec_free_context');
  @avcodec_open2                   := GetProcAddress(hAvcodec, 'avcodec_open2');
  @avcodec_parameters_from_context := GetProcAddress(hAvcodec, 'avcodec_parameters_from_context');
  @avcodec_receive_packet          := GetProcAddress(hAvcodec, 'avcodec_receive_packet');
  @avcodec_send_frame              := GetProcAddress(hAvcodec, 'avcodec_send_frame');
  @avcodec_find_decoder            := GetProcAddress(hAvcodec, 'avcodec_find_decoder');
  @av_packet_free                  := GetProcAddress(hAvcodec, 'av_packet_free');

  hAvformat                       := LoadLibraryEx(PChar('avformat-' + c_strAvformatVer + '.dll'), 0, LOAD_LIBRARY_SEARCH_USER_DIRS);
  @av_read_frame                  := GetProcAddress(hAvformat, 'av_read_frame');
  @avformat_close_input           := GetProcAddress(hAvformat, 'avformat_close_input');
  @avformat_find_stream_info      := GetProcAddress(hAvformat, 'avformat_find_stream_info');
  @avformat_open_input            := GetProcAddress(hAvformat, 'avformat_open_input');
  @av_find_best_stream            := GetProcAddress(hAvformat, 'av_find_best_stream');
  @av_write_frame                 := GetProcAddress(hAvformat, 'av_write_frame');
  @av_write_trailer               := GetProcAddress(hAvformat, 'av_write_trailer');
  @avformat_alloc_output_context2 := GetProcAddress(hAvformat, 'avformat_alloc_output_context2');
  @avformat_network_deinit        := GetProcAddress(hAvformat, 'avformat_network_deinit');
  @avformat_network_init          := GetProcAddress(hAvformat, 'avformat_network_init');
  @avformat_write_header          := GetProcAddress(hAvformat, 'avformat_write_header');
  @avio_closep                    := GetProcAddress(hAvformat, 'avio_closep');
  @avio_open                      := GetProcAddress(hAvformat, 'avio_open');

  hAvutil                        := LoadLibraryEx(PChar('avutil-' + c_strAvutilVer + '.dll'), 0, LOAD_LIBRARY_SEARCH_USER_DIRS);
  @av_buffer_ref                 := GetProcAddress(hAvutil, 'av_buffer_ref');
  @av_buffer_unref               := GetProcAddress(hAvutil, 'av_buffer_unref');
  @av_hwdevice_ctx_create        := GetProcAddress(hAvutil, 'av_hwdevice_ctx_create');
  @av_hwdevice_find_type_by_name := GetProcAddress(hAvutil, 'av_hwdevice_find_type_by_name');
  @av_hwframe_transfer_data      := GetProcAddress(hAvutil, 'av_hwframe_transfer_data');
  @av_frame_alloc                := GetProcAddress(hAvutil, 'av_frame_alloc');
  @av_frame_free                 := GetProcAddress(hAvutil, 'av_frame_free');
  @av_frame_get_buffer           := GetProcAddress(hAvutil, 'av_frame_get_buffer');
  @av_frame_make_writable        := GetProcAddress(hAvutil, 'av_frame_make_writable');

  hSwscale         := LoadLibraryEx(PChar('swscale-' + c_strSwscaleVer + '.dll'), 0, LOAD_LIBRARY_SEARCH_USER_DIRS);
  @sws_freeContext := GetProcAddress(hSwscale, 'sws_freeContext');
  @sws_getContext  := GetProcAddress(hSwscale, 'sws_getContext');
  @sws_scale       := GetProcAddress(hSwscale, 'sws_scale');
end;

procedure FreeFFMPEG;
begin
  FreeLibrary(hAvcodec);
  FreeLibrary(hAvformat);
  FreeLibrary(hAvutil);
  FreeLibrary(hSwscale);
end;

{ 寻找硬件解码器 }
function FindHWDecoder(const strName: string; var type_: TAVHWDeviceType): Boolean;
var
  chrName: PAnsiChar;
begin
  chrName := PAnsiChar(AnsiString(strName));
  type_   := av_hwdevice_find_type_by_name(chrName);
  Result  := type_ <> AV_HWDEVICE_type_NONE;
end;

{ 查询硬件是否支持此格式视频硬解 }
function GetSupportHWConfig(decoder: PAVCodec; type_: TAVHWDeviceType): Boolean;
var
  I     : Integer;
  config: PAVCodecHWConfig;
begin
  Result := False;
  I      := 0;
  while True do
  begin
    config := avcodec_get_hw_config(decoder, I);
    if not Assigned(config) then
      Exit;

    if ((config.methods and AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX) <> 0) and (config.device_type = type_) then
    begin
      hw_pix_fmt := config.pix_fmt;
      Result     := True;
      Break;
    end;
    Inc(I);
  end;
end;

function hw_decoder_init(ctx: PAVCodecContext; const itype: TAVHWDeviceType): Integer;
var
  err: Integer;
begin
  { 初始化硬件加速上下文 }
  err := av_hwdevice_ctx_create(@hw_device_ctx, itype, c_strHWType, nil, 0);
  if err < 0 then
  begin
    Result := err;
    Exit;
  end;

  { 设定硬件 GPU 加速 }
  ctx.hw_device_ctx := av_buffer_ref(hw_device_ctx);
  Result            := err;
end;

function get_hw_format(s: PAVCodecContext; const pix_fmts: PAVPixelFormat): TAVPixelFormat; cdecl;
var
  p: PAVPixelFormat;
begin
  p := pix_fmts;
  while p^ <> AV_PIX_FMT_NONE do
  begin
    if p^ = hw_pix_fmt then
    begin
      Result := p^;
      Exit;
    end;
    Inc(p);
  end;

  Result := AV_PIX_FMT_NONE;
end;

{ 初始化硬解解码器 }
function InitHWDecoder(var pcct: PAVCodecContext; type_: TAVHWDeviceType): Boolean;
begin
  pcct^.thread_count := 16;
  pcct^.get_format   := @get_hw_format;
  Result             := hw_decoder_init(pcct, type_) >= 0;
end;

function ResetD3D(const iWidth, iHeight: Integer; d3d: IDirect3DDevice9; const hWnd: THandle): Boolean;
var
  d3dpp: TD3DPresentParameters;
begin
  FillChar(d3dpp, SizeOf(TD3DPresentParameters), 0);
  d3dpp.Windowed               := True;
  d3dpp.hDeviceWindow          := hWnd;
  d3dpp.SwapEffect             := D3DSWAPEFFECT_DISCARD;
  d3dpp.BackBufferFormat       := D3DFMT_UNKNOWN;
  d3dpp.BackBufferWidth        := iWidth;
  d3dpp.BackBufferHeight       := iHeight;
  d3dpp.PresentationInterval   := D3DPRESENT_INTERVAL_IMMEDIATE;
  d3dpp.BackBufferCount        := 1;
  d3dpp.EnableAutoDepthStencil := True;
  d3dpp.AutoDepthStencilFormat := D3DFMT_D24S8;
  Result                       := SUCCEEDED(d3d.Reset(d3dpp));
end;

procedure VertiLineSSE2(Line1, Line2: PByte; Count: Integer);
{$IFDEF WIN32}
asm
@@LOOP:
  MOVDQA  XMM0, [EAX]
  MOVDQA  XMM1, [EDX]
  MOVDQA  [EAX], XMM1
  MOVDQA  [EDX], XMM0

  ADD     EAX, 16
  ADD     EDX, 16
  DEC     ECX
  JNZ     @@LOOP
end;
{$ELSE IF WIN64}
asm
@@LOOP:
  MOVDQA  XMM0, [RCX]
  MOVDQA  XMM1, [RDX]
  MOVDQA  [RCX], XMM1
  MOVDQA  [RDX], XMM0

  ADD     RCX, 16
  ADD     RDX, 16
  DEC     R8
  JNZ     @@LOOP
end;
{$ENDIF}

{ 图像垂直镜像 }
procedure VertiMirror(bmp: TBitmap);
var
  StartScanLineSrc: PByte;
  StartScanLineDst: PByte;
  bmpWidthBytes   : NativeInt;
  Y               : Integer;
  iStep           : Integer;
begin
  StartScanLineSrc := bmp.ScanLine[0];
  StartScanLineDst := bmp.ScanLine[bmp.Height - 1];
  bmpWidthBytes    := NativeInt(bmp.ScanLine[1]) - NativeInt(bmp.ScanLine[0]);
  iStep            := bmp.Width div 4;

  for Y := 0 to bmp.Height div 2 - 1 do
  begin
    VertiLineSSE2(StartScanLineSrc, StartScanLineDst, iStep);
    Inc(StartScanLineSrc, bmpWidthBytes);
    DEC(StartScanLineDst, bmpWidthBytes);
  end;
end;

function GetTextFontSize(const iFrameHeight: Integer): Integer;
begin
  Result := Round(iFrameHeight * 0.0428 + 8);
end;

function GetTextSpace(const iFrameHeight: Integer): Integer;
begin
  Result := Round(iFrameHeight * 0.0636 + 13);
end;

end.
