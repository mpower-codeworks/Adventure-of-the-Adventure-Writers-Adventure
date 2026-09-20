@echo off
cls
setlocal
cd /d "%~dp0"

if exist AAWA.SYSTEM del AAWA.SYSTEM
if exist aawa.map del aawa.map
if exist aawa.lbl del aawa.lbl

echo Building AAWA...
cl65 -t apple2 ^
  -C aawa.cfg ^
  -m aawa.map ^
  -Ln aawa.lbl ^
  -o AAWA.SYSTEM ^
  aawa.s
if errorlevel 1 goto error

echo.
echo Built AAWA.SYSTEM
exit /b 0

:error
echo.
echo BUILD FAILED
exit /b 1
