$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$HostDir  = Join-Path $RepoRoot "native-host"

dotnet build $HostDir -c Release | Out-Null

$exe = Get-ChildItem -Path (Join-Path $HostDir "bin\Release") -Filter "YtVlcHost.exe" -Recurse |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $exe) { throw "YtVlcHost.exe not found" }

$log = Join-Path $RepoRoot "nm-host.log"
Remove-Item $log -ErrorAction SilentlyContinue

$p = New-Object System.Diagnostics.Process
$p.StartInfo.FileName = $exe.FullName
$p.StartInfo.UseShellExecute = $false
$p.StartInfo.RedirectStandardInput = $true
$p.StartInfo.RedirectStandardOutput = $true
$p.Start() | Out-Null

$msg = [Text.Encoding]::UTF8.GetBytes('{ "url":"https://www.youtube.com/watch?v=qPKd99Pa2iU" }')
$len = [BitConverter]::GetBytes($msg.Length)

$p.StandardInput.BaseStream.Write($len,0,4)
$p.StandardInput.BaseStream.Write($msg,0,$msg.Length)
$p.StandardInput.BaseStream.Flush()

$hdr = New-Object byte[] 4
$null = $p.StandardOutput.BaseStream.Read($hdr,0,4)
$rlen = [BitConverter]::ToInt32($hdr,0)
$buf = New-Object byte[] $rlen
$null = $p.StandardOutput.BaseStream.Read($buf,0,$rlen)
[Text.Encoding]::UTF8.GetString($buf)

Start-Sleep -Seconds 2
$p.Kill()

Get-Content $log -Tail 200