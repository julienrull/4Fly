@ECHO OFF
REM set_env folder time
set folder=%1
set time=%2
set count=%3

REM Go to working dir
PUSHD .\%folder%
REM Clean old files
DEL .\*.m4s .\*.txt .\init.mp4 .\media.m3u8 .\save\*.m4s .\save\*.txt

REM Create FFmpeg segments
ffmpeg -y -i test.mp4 -c copy -hls_segment_type fmp4 -hls_flags split_by_time -hls_time %time% -hls_playlist_type vod -hls_segment_filename "seg-%%d.m4s" media.m3u8
MOVE *.m4s save
REM Clear path
POPD
REM Create new segment with custom encoder
call fragment.bat %folder% %count% %time% 
