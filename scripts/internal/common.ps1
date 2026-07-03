Set-StrictMode -Version Latest

$Script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$Script:OutputDir = Join-Path $Script:RepoRoot 'output'

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Die {
  param([string]$Message)
  throw "[ERROR] $Message"
}

function Read-DotEnvFile {
  param([string]$Path)
  $result = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $result }

  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }
    $idx = $trimmed.IndexOf('=')
    if ($idx -lt 1) { continue }
    $key = $trimmed.Substring(0, $idx).Trim()
    $value = $trimmed.Substring($idx + 1).Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    $result[$key] = $value
  }
  return $result
}

function Get-LocalConfig {
  $envPath = Join-Path $Script:RepoRoot '.env.local'
  $fallbackEnvPath = Join-Path $Script:RepoRoot '.env'
  $secretsPath = Join-Path $Script:RepoRoot 'secrets.local.env'

  if (Test-Path -LiteralPath $envPath) {
    $config = Read-DotEnvFile $envPath
  } elseif (Test-Path -LiteralPath $fallbackEnvPath) {
    $config = Read-DotEnvFile $fallbackEnvPath
  } else {
    Die 'Missing .env.local. Copy .env.example to .env.local and edit it first.'
  }

  $secrets = Read-DotEnvFile $secretsPath
  foreach ($key in $secrets.Keys) { $config[$key] = $secrets[$key] }
  return $config
}

function Require-Config {
  param(
    [hashtable]$Config,
    [string[]]$Names
  )
  foreach ($name in $Names) {
    if (-not $Config.ContainsKey($name) -or [string]::IsNullOrWhiteSpace([string]$Config[$name])) {
      Die "Required config value is empty: $name"
    }
  }
}

function Is-TrueValue {
  param([string]$Value)
  return $Value -in @('true', 'TRUE', '1', 'yes', 'YES', 'y', 'Y')
}

function Ensure-OutputDir {
  New-Item -ItemType Directory -Force -Path $Script:OutputDir | Out-Null
}

function Replace-Tokens {
  param(
    [string]$Text,
    [hashtable]$Values,
    [string[]]$Names
  )
  foreach ($name in $Names) {
    $value = ''
    if ($Values.ContainsKey($name)) { $value = [string]$Values[$name] }
    $Text = $Text.Replace("{{$name}}", $value)
  }
  return $Text
}

function Assert-NoUnrenderedTokens {
  param([string]$Text, [string]$Name)
  if ($Text -match '\{\{[A-Z0-9_]+\}\}') {
    Die "Unrendered template token found in ${Name}: $($Matches[0])"
  }
}

function Invoke-Aws {
  param(
    [hashtable]$Config,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AwsArgs
  )
  $args = @()
  if ($Config.ContainsKey('AWS_PROFILE') -and -not [string]::IsNullOrWhiteSpace([string]$Config['AWS_PROFILE'])) {
    $args += @('--profile', [string]$Config['AWS_PROFILE'])
  }
  if ($Config.ContainsKey('AWS_REGION') -and -not [string]::IsNullOrWhiteSpace([string]$Config['AWS_REGION'])) {
    $args += @('--region', [string]$Config['AWS_REGION'])
  }
  $args += $AwsArgs
  & aws @args
}

function Get-RandomHex {
  param([int]$Bytes)
  $buffer = [byte[]]::new($Bytes)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
  return -join ($buffer | ForEach-Object { $_.ToString('x2') })
}

function Save-TextFileNoBom {
  param([string]$Path, [string]$Text)
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}
