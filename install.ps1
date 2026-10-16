# sranime-cli Windows Universal Installer
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

# Determine app directory
$appDir = "$HOME\.sranime-cli"
if (Test-Path "$scriptDir\sranime-cli") {
    $appDir = $scriptDir
} else {
    Write-Host "==> Downloading sranime-cli to $appDir..." -ForegroundColor Cyan
    if (Get-Command git -ErrorAction SilentlyContinue) {
        if (Test-Path "$appDir\.git") {
            git -C $appDir pull --quiet
        } else {
            git clone --depth 1 https://github.com/srajanbuilds/sranime-cli.git $appDir --quiet
        }
    } else {
        New-Item -ItemType Directory -Path $appDir -Force | Out-Null
        $zipPath = "$env:TEMP\sranime-cli.zip"
        Invoke-WebRequest -Uri "https://github.com/srajanbuilds/sranime-cli/archive/refs/heads/main.zip" -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath "$env:TEMP\sranime-ext" -Force
        Copy-Item -Path "$env:TEMP\sranime-ext\sranime-cli-main\*" -Destination $appDir -Recurse -Force
        Remove-Item -Path $zipPath, "$env:TEMP\sranime-ext" -Recurse -Force
    }
}

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
"%BASH_BIN%" "$appDir\sranime-cli" %*
"@

$shShim = @"
#!/bin/sh
# sranime-cli Git Bash / WSL Shim
if [ "`$WSL_INTEROP" ]; then
  "`$(wslpath -u '$appDir\sranime-cli')" "`$@"
else
  "`$(cygpath -u '$appDir\sranime-cli')" "`$@"
fi
"@

$utf8WithoutBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$targetDir\sranime-cli.cmd", $cmdShim.Replace("`r`n", "`n"), $utf8WithoutBom)
[System.IO.File]::WriteAllText("$targetDir\sranime-cli", $shShim.Replace("`r`n", "`n"), $utf8WithoutBom)

# Ensure targetDir is in User PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$targetDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$targetDir", "User")
    $env:Path = "$env:Path;$targetDir"
}

Write-Host "==> sranime-cli installed successfully!" -ForegroundColor Green
Write-Host "==> Run 'sranime-cli' from any PowerShell, CMD, or Git Bash terminal!" -ForegroundColor Cyan
