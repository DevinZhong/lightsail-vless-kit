param(
  [string]$V2rayNDir = 'C:\Program Files\v2rayN',
  [string]$TestUrl = 'https://api.ipify.org',
  [int]$RequestTimeoutSec = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$xray = Join-Path $V2rayNDir 'bin\xray\xray.exe'
$assetDir = Join-Path $V2rayNDir 'bin'
$config = Join-Path $V2rayNDir 'binConfigs\config.json'
$outputDir = Resolve-Path (Join-Path $PSScriptRoot '..\output')
$testConfig = Join-Path $outputDir 'v2rayn-xray-test.config.json'
$stdoutLog = Join-Path $outputDir 'v2rayn-xray-test.out.log'
$stderrLog = Join-Path $outputDir 'v2rayn-xray-test.err.log'
$curlLog = Join-Path $outputDir 'v2rayn-curl-test.log'

if (-not (Test-Path -LiteralPath $xray)) { throw "xray.exe not found: $xray" }
if (-not (Test-Path -LiteralPath $config)) { throw "v2rayN generated config not found: $config" }
if (-not (Test-Path -LiteralPath (Join-Path $assetDir 'geosite.dat'))) { throw "geosite.dat not found under asset dir: $assetDir" }

$cfg = Get-Content -LiteralPath $config -Raw | ConvertFrom-Json
if (-not $cfg.log) { $cfg | Add-Member -MemberType NoteProperty -Name log -Value ([pscustomobject]@{}) }
$cfg.log.loglevel = 'debug'
$cfg | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testConfig -Encoding utf8NoBOM

$env:XRAY_LOCATION_ASSET = $assetDir
Write-Host "[INFO] Using Xray asset dir: $assetDir"
Write-Host "[INFO] Using temporary debug config: $testConfig"
Write-Host '[INFO] Validating temporary Xray config...'
& $xray run -test -config $testConfig | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Xray config validation failed.' }

$inbound = @($cfg.inbounds | Where-Object { $_.protocol -in @('mixed', 'http', 'socks') } | Select-Object -First 1)[0]
if (-not $inbound) { throw 'No mixed/http/socks inbound found in v2rayN config.' }
$port = [int]$inbound.port
$proxy = "http://127.0.0.1:$port"

$alreadyListening = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue
if ($alreadyListening.TcpTestSucceeded) {
  throw "Local port $port is already in use. Exit v2rayN/Xray first, then retry."
}

Write-Host "[INFO] Starting Xray with debug config. Local proxy: $proxy"
Remove-Item -LiteralPath $stdoutLog,$stderrLog,$curlLog -Force -ErrorAction SilentlyContinue
$proc = Start-Process -FilePath $xray -ArgumentList @('run', '-config', $testConfig) -NoNewWindow -PassThru -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
try {
  Start-Sleep -Seconds 2
  if ($proc.HasExited) {
    Write-Host '[ERROR] Xray exited early.'
    throw "Xray exited with code $($proc.ExitCode)."
  }

  Write-Host "[INFO] Testing through local proxy with curl.exe: $TestUrl"
  & curl.exe -v --ssl-no-revoke --proxy $proxy --connect-timeout $RequestTimeoutSec --max-time $RequestTimeoutSec $TestUrl *> $curlLog
  $code = $LASTEXITCODE
  if ($code -ne 0) { throw "curl.exe failed with exit code $code." }

  Write-Host '[OK] Proxy request succeeded.'
  Get-Content -LiteralPath $curlLog -Tail 20
} finally {
  if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force
    Start-Sleep -Milliseconds 500
  }
  Write-Host "[INFO] Xray stdout log: $stdoutLog"
  Write-Host "[INFO] Xray stderr log: $stderrLog"
  Write-Host "[INFO] curl log: $curlLog"
  Write-Host '[INFO] Xray stdout tail:'
  Get-Content -LiteralPath $stdoutLog -Tail 180 -ErrorAction SilentlyContinue
  Write-Host '[INFO] Xray stderr tail:'
  Get-Content -LiteralPath $stderrLog -Tail 80 -ErrorAction SilentlyContinue
  Write-Host '[INFO] curl tail:'
  Get-Content -LiteralPath $curlLog -Tail 80 -ErrorAction SilentlyContinue
}