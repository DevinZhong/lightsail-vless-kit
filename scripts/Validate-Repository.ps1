[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Replace-TestTokens {
  param([string]$Text, [hashtable]$Values)
  foreach ($name in $Values.Keys) {
    $Text = $Text.Replace("{{$name}}", [string]$Values[$name])
  }
  return $Text
}

function Assert-NoTemplateTokens {
  param([string]$Text, [string]$Name)
  if ($Text -match '\{\{[A-Z0-9_]+\}\}') {
    throw "Unrendered template token in ${Name}: $($Matches[0])"
  }
}

$parseErrors = @()
Get-ChildItem -LiteralPath (Join-Path $repoRoot 'scripts') -Recurse -Filter '*.ps1' | ForEach-Object {
  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
  if ($errors) { $parseErrors += $errors }
}
if ($parseErrors) {
  $details = $parseErrors | ForEach-Object { "{0}:{1}: {2}" -f $_.Extent.File, $_.Extent.StartLineNumber, $_.Message }
  throw ($details -join [Environment]::NewLine)
}

$envExample = Get-Content -LiteralPath (Join-Path $repoRoot '.env.example') -Raw
Assert-True ($envExample -match '(?m)^XRAY_VERSION=\d+\.\d+\.\d+$') '.env.example must pin XRAY_VERSION to an explicit release.'

$menu = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\Manage-LightsailProxy.ps1') -Raw
Assert-True ($menu -match "'Preflight'") 'The main menu must expose the preflight action.'
Assert-True ($menu -match "'SetLanguage'") 'The main menu must expose interface language settings.'
Assert-True ((Test-Path -LiteralPath (Join-Path $repoRoot 'scripts\actions\Test-LightsailPreflight.ps1'))) 'The preflight action must exist.'

$values = @{
  SERVER_IP = '203.0.113.10'
  NODE_NAME = 'template-test'
  VLESS_UUID = '00000000-0000-4000-8000-000000000000'
  REALITY_PRIVATE_KEY = 'test-private-key'
  REALITY_PUBLIC_KEY = 'test-public-key'
  REALITY_SHORT_ID = '0123456789abcdef'
  REALITY_SERVER_NAME = 'www.example.com'
  REALITY_DEST = 'www.example.com:443'
  REALITY_FINGERPRINT = 'chrome'
  XRAY_VERSION = '26.3.27'
}

$xrayTemplate = Get-Content -LiteralPath (Join-Path $repoRoot 'server-config\xray-config.tpl.json') -Raw
$xrayConfig = Replace-TestTokens $xrayTemplate $values
Assert-NoTemplateTokens $xrayConfig 'xray-config.tpl.json'
$null = $xrayConfig | ConvertFrom-Json -ErrorAction Stop

$clientTemplate = Get-Content -LiteralPath (Join-Path $repoRoot 'client-config\vless-reality.json.tpl') -Raw
$clientConfig = Replace-TestTokens $clientTemplate $values
Assert-NoTemplateTokens $clientConfig 'vless-reality.json.tpl'
$null = $clientConfig | ConvertFrom-Json -ErrorAction Stop

$service = Get-Content -LiteralPath (Join-Path $repoRoot 'server-config\xray.service') -Raw
$cloudTemplate = Get-Content -LiteralPath (Join-Path $repoRoot 'cloud-init\cloud-init.tpl.sh') -Raw
$cloudInit = Replace-TestTokens $cloudTemplate $values
$cloudInit = $cloudInit.Replace('{{XRAY_CONFIG}}', $xrayConfig).Replace('{{XRAY_SERVICE}}', $service)
Assert-NoTemplateTokens $cloudInit 'cloud-init.tpl.sh'
Assert-True ($cloudInit -match 'Xray release checksum verification failed') 'cloud-init must verify the Xray release checksum.'

Write-Host 'Repository validation passed.' -ForegroundColor Green
