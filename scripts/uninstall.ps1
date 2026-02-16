param(
  [string]$HostName = "com.ytvlc.player"
)

$regKey = "HKCU\Software\Google\Chrome\NativeMessagingHosts\$HostName"
reg delete $regKey /f /reg:32 2>$null | Out-Null
reg delete $regKey /f /reg:64 2>$null | Out-Null

$RepoRoot = Split-Path -Parent $PSScriptRoot
Remove-Item (Join-Path $RepoRoot "dist") -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Removed native host registration and dist/"