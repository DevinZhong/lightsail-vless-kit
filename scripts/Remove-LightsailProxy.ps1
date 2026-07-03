param(
  [switch]$Yes
)

. "$PSScriptRoot\internal\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('LIGHTSAIL_INSTANCE_NAME')
$name = [string]$config['LIGHTSAIL_INSTANCE_NAME']

if (-not $Yes) {
  Write-Warn "This will delete Lightsail instance: $name"
  Write-Warn 'This does not delete local secrets, SSH private keys, or output client files.'
  $answer = Read-Host 'Type DELETE to continue'
  if ($answer -ne 'DELETE') { Die 'Delete cancelled.' }
}

Write-Info "Deleting Lightsail instance: $name"
Invoke-Aws $config lightsail delete-instance --instance-name $name | Out-Null
Write-Info 'Delete requested. It may take a short while for AWS to finish removing the instance.'