param(
  [string]$V2rayNDir = '',
  [string]$TestUrl = 'https://api.ipify.org',
  [int]$RequestTimeoutSec = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-Utf8NoBomContent {
  param(
    [Parameter(Mandatory = $true)][string]$LiteralPath,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($LiteralPath, $Value, $encoding)
}

if ([string]::IsNullOrWhiteSpace($V2rayNDir)) {
  $candidates = @(
    "$env:USERPROFILE\Apps\v2rayN",
    'C:\Program Files\v2rayN',
    "$env:LOCALAPPDATA\v2rayN"
  )
  $V2rayNDir = @($candidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'v2rayN.exe') } | Select-Object -First 1)[0]
  if ([string]::IsNullOrWhiteSpace($V2rayNDir)) { $V2rayNDir = $candidates[0] }
}

$xray = Join-Path $V2rayNDir 'bin\xray\xray.exe'
$assetDir = Join-Path $V2rayNDir 'bin'
$config = Join-Path $V2rayNDir 'binConfigs\config.json'
$outputDir = Resolve-Path (Join-Path $PSScriptRoot '..\..\output')
$testConfig = Join-Path $outputDir 'v2rayn-xray-test.config.json'
$stdoutLog = Join-Path $outputDir 'v2rayn-xray-test.out.log'
$stderrLog = Join-Path $outputDir 'v2rayn-xray-test.err.log'
$curlLog = Join-Path $outputDir 'v2rayn-curl-test.log'

if (-not (Test-Path -LiteralPath $xray)) { throw "xray.exe not found: $xray" }
if (-not (Test-Path -LiteralPath $config)) { throw "v2rayN generated config not found: $config" }
if (-not (Test-Path -LiteralPath (Join-Path $assetDir 'geosite.dat'))) { throw "geosite.dat not found under asset dir: $assetDir" }

function Get-V2rayNOutboundHost {
  param([object]$Config)
  foreach ($outbound in @($Config.outbounds)) {
    if ($outbound.settings -and $outbound.settings.vnext -and @($outbound.settings.vnext).Count -gt 0) {
      return [string]@($outbound.settings.vnext)[0].address
    }
    if ($outbound.settings -and $outbound.settings.servers -and @($outbound.settings.servers).Count -gt 0) {
      return [string]@($outbound.settings.servers)[0].address
    }
  }
  return ''
}

function Get-LatestOutputHost {
  $urlPath = Join-Path $PSScriptRoot '..\..\output\vless-reality-url.txt'
  if (-not (Test-Path -LiteralPath $urlPath)) { return '' }
  $url = Get-Content -LiteralPath $urlPath -Raw
  if ($url -match '@([^:]+):') { return $Matches[1] }
  return ''
}
$cfg = Get-Content -LiteralPath $config -Raw | ConvertFrom-Json
$currentOutboundHost = Get-V2rayNOutboundHost -Config $cfg
$latestOutputHost = Get-LatestOutputHost
if (-not [string]::IsNullOrWhiteSpace($currentOutboundHost)) {
  Write-Host "[INFO] v2rayN generated config outbound host: $currentOutboundHost"
}
if (-not [string]::IsNullOrWhiteSpace($latestOutputHost)) {
  Write-Host "[INFO] Latest generated VLESS URL host: $latestOutputHost"
  if ($currentOutboundHost -and $currentOutboundHost -ne $latestOutputHost) {
    Write-Host "[WARN] v2rayN is not currently using the latest generated node. Re-import/select the node whose address is $latestOutputHost."
  }
}
if (-not $cfg.log) { $cfg | Add-Member -MemberType NoteProperty -Name log -Value ([pscustomobject]@{}) }
$cfg.log.loglevel = 'debug'
Set-Utf8NoBomContent -LiteralPath $testConfig -Value ($cfg | ConvertTo-Json -Depth 100)

$env:XRAY_LOCATION_ASSET = $assetDir
Write-Host "[INFO] Using v2rayN dir: $V2rayNDir"
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