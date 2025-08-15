FFMPEG HW Acceleration VIDEO DECODE FOR DELPHI12.3 (DXVA2)

FFMPEG build : 2025-08-14

test01 : GDI Render
test02 : DX  Render

Win32 decode H264.mp4
Win64 decode H265.mp4

Notice : 
  1、ffmpeg(Win64) files larger than 100M, zip to cuda.7z. please unzip it before use；
  2、use Google libyuv replace ffmpeg sws_scale, let H264 decode take off；
  3、ffmpeg decode H265, use GDI render, have problem.using DX rendering is not a problem. 
     this is the decoding bug of FFMPEG. It's not a bug with the Delphi program.
     so decoding H265 format videos can only be done using DX rendering. whether it's Win32 or Win64

  1、ffmpeg(Win64) 文件大于 100M，使用前请先解压 cuda.7z；
  2、使用 Google 的 libyuv 开源库，替换 ffmpeg 的 sws_scale，让 H264 解码起飞；
  3、ffmpeg 解码 H265.mp4，使用 GDI 渲染，存在问题。使用 DX 渲染则没有问题。
     这是 FFMPEG 的解码 BUG。不是 Delphi 程序的 BUG。
     所以使用 FFMPEG 解码 H265 格式视频，只能使用 DX 渲染。无论是 Win32 还是 Win64。
