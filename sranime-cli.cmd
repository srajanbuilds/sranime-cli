@rem sranime-cli Windows Shim
@echo off
setlocal
set "BASH_BIN=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH_BIN%" set "BASH_BIN=%USERPROFILE%\scoop\apps\git\current\bin\bash.exe"
if not exist "%BASH_BIN%" (
  set "BASH_BIN=bash"
)
"%BASH_BIN%" "%~dp0sranime-cli" %*
