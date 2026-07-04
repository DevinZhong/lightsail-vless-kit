param(
  [switch]$Force
)

. "$PSScriptRoot\internal\common.ps1"

$secretsPath = Join-Path $Script:RepoRoot 'secrets.local.env'
$existing = Read-DotEnvFile $secretsPath

function Existing-OrNew {
  param([string]$Name, [scriptblock]$Factory)
  if (-not $Force -and $existing.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace([string]$existing[$Name])) {
    return [string]$existing[$Name]
  }
  return & $Factory
}

$xray = Get-Command xray -ErrorAction SilentlyContinue
if (-not $xray) { $xray = Get-Command xray.exe -ErrorAction SilentlyContinue }
if (-not $xray) {
  Die 'xray/xray.exe is required in PATH to generate REALITY x25519 keys. Install Xray locally or generate REALITY keys elsewhere and fill secrets.local.env manually.'
}

$vlessUuid = Existing-OrNew 'VLESS_UUID' { [guid]::NewGuid().ToString() }

$realityPrivate = $null
$realityPublic = $null
if (-not $Force -and $existing.ContainsKey('REALITY_PRIVATE_KEY') -and $existing.ContainsKey('REALITY_PUBLIC_KEY') -and
    -not [string]::IsNullOrWhiteSpace([string]$existing['REALITY_PRIVATE_KEY']) -and
    -not [string]::IsNullOrWhiteSpace([string]$existing['REALITY_PUBLIC_KEY'])) {
  $realityPrivate = [string]$existing['REALITY_PRIVATE_KEY']
  $realityPublic = [string]$existing['REALITY_PUBLIC_KEY']
} else {
  $rawKeyOutput = (& $xray.Source x25519 2>&1 | Out-String).Trim()

  # Xray releases have used both "Private key/Public key" and
  # "PrivateKey/Password (PublicKey)" labels. Accept both.
  $privateMatch = [regex]::Match($rawKeyOutput, '(?im)^\s*Private\s*Key\s*:\s*(\S+)\s*$')
  $publicMatch = [regex]::Match($rawKeyOutput, '(?im)^\s*(?:Public\s*Key|Password\s*\(\s*PublicKey\s*\))\s*:\s*(\S+)\s*$')

  if (-not $privateMatch.Success -or -not $publicMatch.Success) {
    Die 'Could not parse xray x25519 output. Run `xray x25519` manually and fill REALITY_PRIVATE_KEY / REALITY_PUBLIC_KEY in secrets.local.env.'
  }

  $realityPrivate = $privateMatch.Groups[1].Value.Trim()
  $realityPublic = $publicMatch.Groups[1].Value.Trim()
}

$shortId = Existing-OrNew 'REALITY_SHORT_ID' { Get-RandomHex 8 }

$text = @"
# Local proxy secrets. Do not commit.
VLESS_UUID=$vlessUuid
REALITY_PRIVATE_KEY=$realityPrivate
REALITY_PUBLIC_KEY=$realityPublic
REALITY_SHORT_ID=$shortId
"@
Save-TextFileNoBom $secretsPath $text
Write-Info "Wrote $secretsPath"
Write-Info 'Do not commit or share this file.'
