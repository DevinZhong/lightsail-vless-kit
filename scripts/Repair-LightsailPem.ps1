param(
  [string]$KeyPath = "$env:USERPROFILE\.ssh\personal-fixed-exit-lightsail.pem"
)

Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $KeyPath)) {
  throw "Key file not found: $KeyPath"
}

$raw = [IO.File]::ReadAllText($KeyPath).Trim()
$raw = $raw -replace "`r", ""

$beginMatch = [regex]::Match($raw, '-----BEGIN [^-]+ PRIVATE KEY-----')
$endMatch = [regex]::Match($raw, '-----END [^-]+ PRIVATE KEY-----')

if (-not $beginMatch.Success -or -not $endMatch.Success) {
  throw 'Cannot find PEM BEGIN/END markers. Do not paste the key content; check the first and last visible markers.'
}

$header = $beginMatch.Value
$footer = $endMatch.Value
$bodyStart = $beginMatch.Index + $beginMatch.Length
$bodyLength = $endMatch.Index - $bodyStart
if ($bodyLength -le 0) {
  throw 'PEM body is empty or malformed.'
}

$body = $raw.Substring($bodyStart, $bodyLength)
$body = $body -replace '\s+', ''

if ($body -notmatch '^[A-Za-z0-9+/=]+$') {
  throw 'PEM body contains characters outside normal base64 alphabet.'
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add($header)
for ($i = 0; $i -lt $body.Length; $i += 64) {
  $len = [Math]::Min(64, $body.Length - $i)
  $lines.Add($body.Substring($i, $len))
}
$lines.Add($footer)

$fixed = ($lines -join "`n") + "`n"
try {
  [IO.File]::WriteAllText($KeyPath, $fixed, [Text.Encoding]::ASCII)
} catch {
  throw "Failed to write repaired PEM. Check file ACL/write permission for ${KeyPath}. Original error: $($_.Exception.Message)"
}

Write-Host "Reformatted PEM: $KeyPath"
Write-Host "Line count: $($lines.Count)"
Write-Host 'Now verify with: ssh-keygen -y -f "$env:USERPROFILE\.ssh\personal-fixed-exit-lightsail.pem"'