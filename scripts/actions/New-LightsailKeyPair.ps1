param(
  [string]$Region,
  [string]$KeyPairName,
  [string]$KeyPath,
  [switch]$Force,
  [switch]$NoUpdateEnv,
  [switch]$RecreateIfLocalPemMissing
)

. "$PSScriptRoot\..\internal\common.ps1"

$config = Get-LocalConfig
$envPath = Join-Path $Script:RepoRoot '.env.local'

if ([string]::IsNullOrWhiteSpace($Region)) {
  Require-Config $config @('AWS_REGION')
  $Region = [string]$config['AWS_REGION']
}

if ([string]::IsNullOrWhiteSpace($KeyPairName)) {
  $KeyPairName = "personal-fixed-exit-lightsail-$Region"
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  $KeyPath = Join-Path $env:USERPROFILE ".ssh\$KeyPairName.pem"
}

$awsConfig = $config.Clone()
$awsConfig['AWS_REGION'] = $Region

function Set-EnvValue {
  param(
    [string]$Path,
    [string]$Name,
    [string]$Value
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    Die "Cannot update missing env file: $Path"
  }

  $lines = [System.Collections.Generic.List[string]]::new()
  $found = $false
  foreach ($line in [IO.File]::ReadAllLines($Path)) {
    if ($line -match "^\s*$([regex]::Escape($Name))\s*=") {
      $lines.Add("$Name=$Value")
      $found = $true
    } else {
      $lines.Add($line)
    }
  }
  if (-not $found) { $lines.Add("$Name=$Value") }

  [IO.File]::WriteAllText($Path, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
}

function Update-EnvKeyName {
  if ($NoUpdateEnv) { return }
  Set-EnvValue $envPath 'SSH_KEY_NAME' $KeyPairName
  Write-Info "Updated .env.local: SSH_KEY_NAME=$KeyPairName"
}

function Format-PemPrivateKey {
  param([string]$Pem)

  $raw = $Pem.Trim() -replace "`r", ''
  $beginMatch = [regex]::Match($raw, '-----BEGIN [^-]+ PRIVATE KEY-----')
  $endMatch = [regex]::Match($raw, '-----END [^-]+ PRIVATE KEY-----')
  if (-not $beginMatch.Success -or -not $endMatch.Success) { return '' }

  $header = $beginMatch.Value
  $footer = $endMatch.Value
  $bodyStart = $beginMatch.Index + $beginMatch.Length
  $bodyLength = $endMatch.Index - $bodyStart
  if ($bodyLength -le 0) { return '' }

  $body = $raw.Substring($bodyStart, $bodyLength) -replace '\s+', ''
  if ($body -notmatch '^[A-Za-z0-9+/=]+$') { return '' }

  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add($header)
  for ($i = 0; $i -lt $body.Length; $i += 64) {
    $len = [Math]::Min(64, $body.Length - $i)
    $lines.Add($body.Substring($i, $len))
  }
  $lines.Add($footer)
  return ($lines -join "`n") + "`n"
}

function ConvertTo-PemPrivateKey {
  param([string]$Raw)

  if ([string]::IsNullOrWhiteSpace($Raw)) { return '' }

  $candidate = $Raw.Trim()
  $candidate = $candidate.Replace('\n', "`n").Replace('\r', '')
  if ($candidate -match '-----BEGIN .* PRIVATE KEY-----') { return Format-PemPrivateKey $candidate }

  try {
    $bytes = [Convert]::FromBase64String(($candidate -replace '\s+', ''))
    $decoded = [Text.Encoding]::UTF8.GetString($bytes).Trim()
    $decoded = $decoded.Replace('\n', "`n").Replace('\r', '')
    if ($decoded -match '-----BEGIN .* PRIVATE KEY-----') { return Format-PemPrivateKey $decoded }
  } catch {
    return ''
  }

  return ''
}

try {
  $existing = Invoke-Aws $awsConfig lightsail get-key-pair `
    --key-pair-name $KeyPairName `
    --query 'keyPair.name' `
    --output text 2>$null
} catch {
  $existing = $null
}

if ($existing -eq $KeyPairName) {
  Write-Info "Lightsail key pair already exists in ${Region}: $KeyPairName"
  if (Test-Path -LiteralPath $KeyPath) {
    Update-EnvKeyName
    Write-Info "Local PEM already exists: $KeyPath"
    return
  }

  if (-not $RecreateIfLocalPemMissing) {
    Update-EnvKeyName
    Write-Warn "Local PEM is missing: $KeyPath"
    Write-Warn 'Lightsail only returns the private key when the key pair is first created.'
    Write-Warn 'Use -RecreateIfLocalPemMissing only if you are sure no instance depends on this key pair.'
    return
  }

  Write-Warn "Local PEM is missing, recreating unused Lightsail key pair: $KeyPairName"
  Invoke-Aws $awsConfig lightsail delete-key-pair --key-pair-name $KeyPairName | Out-Null
}

$keyDir = Split-Path -Parent $KeyPath
if (-not (Test-Path -LiteralPath $keyDir)) {
  New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
}

if ((Test-Path -LiteralPath $KeyPath) -and -not $Force) {
  Die "Local PEM already exists: $KeyPath. Pass -Force to overwrite it after confirming it is safe."
}

Write-Info "Creating Lightsail key pair $KeyPairName in $Region..."
$rawPrivateKey = Invoke-Aws $awsConfig lightsail create-key-pair `
  --key-pair-name $KeyPairName `
  --query 'privateKeyBase64' `
  --output text

$privateKey = ConvertTo-PemPrivateKey $rawPrivateKey
if ([string]::IsNullOrWhiteSpace($privateKey)) {
  Die 'AWS did not return a usable PEM private key. It may have returned an unexpected privateKeyBase64 format.'
}

[IO.File]::WriteAllText($KeyPath, $privateKey, [Text.Encoding]::ASCII)
Update-EnvKeyName

Write-Host ''
Write-Host 'Lightsail key pair created.'
Write-Host "Region:       $Region"
Write-Host "Key pair:     $KeyPairName"
Write-Host "Local PEM:    $KeyPath"
Write-Host ''
Write-Host 'Next check:'
Write-Host "  ssh-keygen -y -f `"$KeyPath`""