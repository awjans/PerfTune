@ECHO OFF
SETLOCAL

%~dp0Elevate.exe powershell.exe -ExecutionPolicy Bypass -File %~dpn0.ps1

ENDLOCAL