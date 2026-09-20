@echo off
cls
setlocal
cd /d "%~dp0"

if exist AAWA.SYSTEM del AAWA.SYSTEM
if exist aawa.o del aawa.o
if exist aawa.map del aawa.map
if exist aawa.lbl del aawa.lbl

echo Building AAWA 011 raw ProDOS SYS...
ca65 -t apple2 ^
  -o aawa.o ^
  AAWA.s
if errorlevel 1 goto error

ld65 ^
  -C aawa_raw.cfg ^
  -m aawa.map ^
  -Ln aawa.lbl ^
  -o AAWA.SYSTEM ^
  aawa.o
if errorlevel 1 goto error

del aawa.o

echo.
echo Built raw AAWA.SYSTEM
for %%A in (AAWA.SYSTEM) do echo Size: %%~zA bytes
echo ProDOS file type on disk must be SYS ($FF).
exit /b 0

:error
echo.
echo BUILD FAILED
exit /b 1
