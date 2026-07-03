param(
  [string]$ServerIp
)

. "$PSScriptRoot\common.ps1"

$config = Get-LocalConfig
Ensure-OutputDir
if (-not [string]::IsNullOrWhiteSpace($ServerIp)) { $config['SERVER_IP'] = $ServerIp }
Require-Config $config @('SERVER_IP', 'NODE_NAME', 'VLESS_UUID', 'REALITY_PUBLIC_KEY', 'REALITY_SHORT_ID', 'REALITY_SERVER_NAME', 'REALITY_FINGERPRINT')

$nodeName = [uri]::EscapeDataString([string]$config['NODE_NAME'])
$vlessUrl = ('vless://{0}@{1}:443?encryption=none&security=reality&sni={2}&fp={3}&pbk={4}&sid={5}&spx=%2F&type=tcp&flow=xtls-rprx-vision#{6}-reality' -f `
  $config['VLESS_UUID'], $config['SERVER_IP'], $config['REALITY_SERVER_NAME'], $config['REALITY_FINGERPRINT'], $config['REALITY_PUBLIC_KEY'], $config['REALITY_SHORT_ID'], $nodeName)

Save-TextFileNoBom (Join-Path $Script:OutputDir 'vless-reality-url.txt') ($vlessUrl + "`n")

$vlessJsonTemplate = Get-Content (Join-Path $Script:RepoRoot 'client-config\vless-reality.json.tpl') -Raw
$vlessJson = Replace-Tokens $vlessJsonTemplate $config @('SERVER_IP', 'NODE_NAME', 'VLESS_UUID', 'REALITY_PUBLIC_KEY', 'REALITY_SHORT_ID', 'REALITY_SERVER_NAME', 'REALITY_FINGERPRINT')
Assert-NoUnrenderedTokens $vlessJson 'vless-reality.json.tpl'
Save-TextFileNoBom (Join-Path $Script:OutputDir 'vless-reality.json') $vlessJson

$subscription = @($vlessUrl)

if (Is-TrueValue ([string]$config['HYSTERIA_ENABLED'])) {
  Require-Config $config @('HYSTERIA_PASSWORD', 'HYSTERIA_SNI')
  $hyUrl = ('hysteria2://{0}@{1}:443/?insecure=1&sni={2}#{3}-hy2' -f $config['HYSTERIA_PASSWORD'], $config['SERVER_IP'], $config['HYSTERIA_SNI'], $nodeName)
  Save-TextFileNoBom (Join-Path $Script:OutputDir 'hysteria2-url.txt') ($hyUrl + "`n")
  $hyTemplate = Get-Content (Join-Path $Script:RepoRoot 'client-config\hysteria2.yaml.tpl') -Raw
  $hyConfig = Replace-Tokens $hyTemplate $config @('SERVER_IP', 'NODE_NAME', 'HYSTERIA_PASSWORD', 'HYSTERIA_SNI')
  Assert-NoUnrenderedTokens $hyConfig 'hysteria2.yaml.tpl'
  Save-TextFileNoBom (Join-Path $Script:OutputDir 'hysteria2.yaml') $hyConfig
  $subscription += $hyUrl
}

$subText = ($subscription -join "`n") + "`n"
Save-TextFileNoBom (Join-Path $Script:OutputDir 'subscription.txt') $subText
$subBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($subText))
Save-TextFileNoBom (Join-Path $Script:OutputDir 'subscription.base64.txt') ($subBase64 + "`n")
Write-Info 'Rendered local client files under output/.'
Write-Info 'These files contain proxy credentials and are ignored by git.'
