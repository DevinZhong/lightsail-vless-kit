param(
  [string]$ServerIp
)

. "$PSScriptRoot\common.ps1"

if ([string]::IsNullOrWhiteSpace($ServerIp)) {
  $ServerIp = (& "$PSScriptRoot\Get-InstanceIp.ps1").Trim()
}
if ([string]::IsNullOrWhiteSpace($ServerIp)) { Die 'Server IP is empty.' }

$prefix = "$ServerIp/32"
$routes = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix $prefix -ErrorAction SilentlyContinue)
if ($routes.Count -eq 0) {
  Write-Warn "No bypass route found for $prefix"
  return
}

foreach ($route in $routes) {
  Write-Info "Removing bypass route: $prefix via $($route.NextHop) on ifIndex $($route.InterfaceIndex)"
  Remove-NetRoute -DestinationPrefix $prefix -InterfaceIndex $route.InterfaceIndex -NextHop $route.NextHop -Confirm:$false -ErrorAction Stop
}