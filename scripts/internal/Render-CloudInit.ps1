. "$PSScriptRoot\common.ps1"

$config = Get-LocalConfig
Ensure-OutputDir
Require-Config $config @('AWS_REGION', 'AWS_AZ', 'LIGHTSAIL_INSTANCE_NAME', 'LIGHTSAIL_BUNDLE_ID', 'LIGHTSAIL_BLUEPRINT_ID')
Require-Config $config @('VLESS_UUID', 'REALITY_PRIVATE_KEY', 'REALITY_PUBLIC_KEY', 'REALITY_SHORT_ID')

$workDir = Join-Path $Script:OutputDir 'rendered'
if (Test-Path -LiteralPath $workDir) { Remove-Item -LiteralPath $workDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$xrayTemplate = Get-Content (Join-Path $Script:RepoRoot 'server-config\xray-config.tpl.json') -Raw
$xrayConfig = Replace-Tokens $xrayTemplate $config @('VLESS_UUID', 'REALITY_PRIVATE_KEY', 'REALITY_SHORT_ID', 'REALITY_SERVER_NAME', 'REALITY_DEST')
Assert-NoUnrenderedTokens $xrayConfig 'xray-config.tpl.json'
Save-TextFileNoBom (Join-Path $workDir 'xray-config.json') $xrayConfig

$xrayService = Get-Content (Join-Path $Script:RepoRoot 'server-config\xray.service') -Raw
Save-TextFileNoBom (Join-Path $workDir 'xray.service') $xrayService

$cloudTemplate = Get-Content (Join-Path $Script:RepoRoot 'cloud-init\cloud-init.tpl.sh') -Raw
$cloud = Replace-Tokens $cloudTemplate $config @('XRAY_VERSION')
$cloud = $cloud.Replace('{{XRAY_CONFIG}}', (Get-Content (Join-Path $workDir 'xray-config.json') -Raw))
$cloud = $cloud.Replace('{{XRAY_SERVICE}}', (Get-Content (Join-Path $workDir 'xray.service') -Raw))
Assert-NoUnrenderedTokens $cloud 'cloud-init.tpl.sh'

$out = Join-Path $Script:OutputDir 'cloud-init.sh'
Save-TextFileNoBom $out $cloud
Write-Info "Rendered sensitive cloud-init to $out"
Write-Info 'This file contains proxy secrets and is ignored by git.'
