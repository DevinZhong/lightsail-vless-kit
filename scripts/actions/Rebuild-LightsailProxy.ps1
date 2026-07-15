param(
  [switch]$Yes,
  [int]$WaitSeconds = 45,
  [int]$DeleteTimeoutSeconds = 360
)

. "$PSScriptRoot\..\internal\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('LIGHTSAIL_INSTANCE_NAME')

function Wait-InstanceDeleted {
  param([hashtable]$Config, [string]$InstanceName, [int]$TimeoutSeconds)
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $state = Invoke-Aws $Config lightsail get-instance --instance-name $InstanceName --query 'instance.state.name' --output text 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$state)) { return }
    Write-Info "Waiting for instance deletion: $InstanceName state=$state"
    Start-Sleep -Seconds 10
  }
  Die "Timed out waiting for instance deletion: $InstanceName"
}

if (-not $Yes) {
  Write-Warn 'This will delete the current Lightsail instance and create a new one with the same local secrets.'
  Write-Warn 'The server IP and generated client URL will change.'
  $answer = Read-Host 'Type REBUILD to continue'
  if ($answer -ne 'REBUILD') { Die 'Rebuild cancelled.' }
}

& "$PSScriptRoot\Remove-LightsailProxy.ps1" -Yes
if ($LASTEXITCODE -ne 0) { Die 'Delete request failed.' }
Wait-InstanceDeleted -Config $config -InstanceName ([string]$config['LIGHTSAIL_INSTANCE_NAME']) -TimeoutSeconds $DeleteTimeoutSeconds
if ($WaitSeconds -gt 0) {
  Write-Info "Waiting $WaitSeconds seconds after deletion before creating the replacement instance..."
  Start-Sleep -Seconds $WaitSeconds
}
& "$PSScriptRoot\New-LightsailProxy.ps1"
