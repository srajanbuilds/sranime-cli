# sranime-cli Windows Global Installer
# Configures global command shims so you can run 'sranime-cli' from any terminal

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

# Target directory in user PATH
$targetDir = "$HOME\scoop\shims"
if (-not (Test-Path $targetDir)) {
    $targetDir = "$HOME\.local\bin"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
}

$cmdShim = @"
@rem sranime-cli Windows Shim
@echo off
setlocal
set "BASH_BIN=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH_BIN%" set "BASH_BIN=%USERPROFILE%\scoop\apps\git\current\bin\bash.exe"
if not exist "%BASH_BIN%" (
  set "BASH_BIN=bash"
)
"%BASH_BIN%" "$scriptDir\sranime-cli" %*
"@

$shShim = @"
#!/bin/sh
# sranime-cli Git Bash / WSL Shim
if [ "`$WSL_INTEROP" ]; then
  "`$(wslpath -u '$scriptDir\sranime-cli')" "`$@"
else
  "`$(cygpath -u '$scriptDir\sranime-cli')" "`$@"
fi
"@

$utf8WithoutBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$targetDir\sranime-cli.cmd", $cmdShim.Replace("`r`n", "`n"), $utf8WithoutBom)
[System.IO.File]::WriteAllText("$targetDir\sranime-cli", $shShim.Replace("`r`n", "`n"), $utf8WithoutBom)

Write-Host "==> sranime-cli installed successfully to $targetDir!" -ForegroundColor Green
Write-Host "==> You can now run 'sranime-cli' directly from PowerShell, CMD, or Git Bash!" -ForegroundColor Cyan