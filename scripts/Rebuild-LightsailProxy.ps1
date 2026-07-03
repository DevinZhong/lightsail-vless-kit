param(
  [switch]$Yes,
  [int]$WaitSeconds = 45
)

. "$PSScriptRoot\internal\common.ps1"

if (-not $Yes) {
  Write-Warn 'This will delete the current Lightsail instance and create a new one with the same local secrets.'
  Write-Warn 'The server IP and generated client URL will change.'
  $answer = Read-Host 'Type REBUILD to continue'
  if ($answer -ne 'REBUILD') { Die 'Rebuild cancelled.' }
}

& "$PSScriptRoot\Remove-LightsailProxy.ps1" -Yes
Write-Info "Waiting $WaitSeconds seconds before creating the replacement instance..."
Start-Sleep -Seconds $WaitSeconds
& "$PSScriptRoot\New-LightsailProxy.ps1"