param(
  [Parameter(Mandatory=$true)]
  [string]$ExtensionId,

  [string]$HostName = "com.ytvlc.player"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$HostDir  = Join-Path $RepoRoot "native-host"
$DistDir  = Join-Path $RepoRoot "dist"
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

Write-Host "Building native host..."
dotnet build $HostDir -c Release

# Find the built EXE (supports net10/net11 etc)
$exe = Get-ChildItem -Path (Join-Path $HostDir "bin\Release") -Filter "YtVlcHost.exe" -Recurse |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $exe) { throw "YtVlcHost.exe not found under native-host\bin\Release" }

$exeEsc = ($exe.FullName -replace "\\","\\\\")

$manifestPath = Join-Path $DistDir "ytvlc-host.json"
$manifest = @"
{
  "name": "$HostName",
  "description": "YouTube to VLC bridge",
  "path": "$exeEsc",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$ExtensionId/"
  ]
}
"@
[System.IO.File]::WriteAllText($manifestPath, $manifest, (New-Object System.Text.UTF8Encoding($false)))
(Get-Content $manifestPath -Raw | ConvertFrom-Json) | Out-Null

$regKey = "HKCU\Software\Google\Chrome\NativeMessagingHosts\$HostName"

Write-Host "Registering native host manifest:"
Write-Host "  $manifestPath"
reg add $regKey /ve /t REG_SZ /d $manifestPath /f /reg:32 | Out-Null
reg add $regKey /ve /t REG_SZ /d $manifestPath /f /reg:64 | Out-Null

Write-Host ""
Write-Host "OK. Next:"
Write-Host "1) Load extension from: $($RepoRoot)\extension (chrome://extensions → Developer mode → Load unpacked)"
Write-Host "2) Ensure the extension ID matches what you passed: $ExtensionId"
Write-Host "3) Open a YouTube watch page and click the extension icon."