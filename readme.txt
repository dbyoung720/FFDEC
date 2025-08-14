FFMPEG HW Acceleration VIDEO DECODE FOR DELPHI12.3 (DXVA2)

FFMPEG build : 2025-07-13

test01 : GDI Render
test02 : DX  Render

Win32 decode H264.mp4
Win64 decode H265.mp4

Notice : 
  ffmpeg(x64) files larger than 100M, zip to cuda.7z. please unzip it before use；
  use Google libyuv replace ffmpeg sws_scale, let H264 decode take off；
  ffmpeg(x64) 文件大于 100M，使用前请先解压 cuda.7z；
  使用 Google 的 libyuv 开源库，替换 ffmpeg 的 sws_scale，让 H264 解码起飞；