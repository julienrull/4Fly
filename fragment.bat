@ECHO OFF
SET folder=%1
SET count=%2
SET duration=%3
DEL .\%folder%\*.m4s .\%folder%\*.txt .\%folder%\save\*.txt
call mp4dump.exe --verbosity 3 .\%folder%\test.mp4 > .\%folder%\test.txt
FOR /l %%x IN (0, 1, %count%) DO (
	call .\encoder.exe %folder% %%x %duration%
	call mp4dump.exe --verbosity 3 .\%folder%\seg-%%x.m4s > .\%folder%\seg-%%x.txt
	call mp4dump.exe --verbosity 3 .\%folder%\save\seg-%%x.m4s > .\%folder%\save\seg-%%x.txt
) 
