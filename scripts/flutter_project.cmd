@echo off
setlocal

set "PROJECT_ROOT=%~dp0.."
set "APPDATA=%PROJECT_ROOT%\.dart_appdata"
set "LOCALAPPDATA=%PROJECT_ROOT%\.dart_localappdata"
set "PUB_CACHE=%LOCALAPPDATA%\Pub\Cache"

if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%PUB_CACHE%" mkdir "%PUB_CACHE%"

"D:\Flutter\flutter\bin\flutter.bat" %*
exit /b %ERRORLEVEL%
