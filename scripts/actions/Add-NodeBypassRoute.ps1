param(
  [string]$ServerIp
)

. "$PSScriptRoot\..\internal\common.ps1"

if ([string]::IsNullOrWhiteSpace($ServerIp)) {
  $ServerIp = (& "$PSScriptRoot\..\internal\Get-InstanceIp.ps1").Trim()
}
if ([string]::IsNullOrWhiteSpace($ServerIp)) { Die 'Server IP is empty.' }

$routes = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' |
  Where-Object { $_.NextHop -ne '0.0.0.0' -and $_.InterfaceAlias -notmatch 'tun|wintun|tap|vpn|loopback|sing|clash|mihomo|hiddify' } |
  Sort-Object RouteMetric, InterfaceMetric

$route = @($routes | Select-Object -First 1)[0]
if (-not $route) {
  Die 'Could not find a non-TUN IPv4 default route. Connect to Wi-Fi/Ethernet first or add the route manually.'
}

$prefix = "$ServerIp/32"
Write-Info "Adding bypass route: $prefix via $($route.NextHop) on $($route.InterfaceAlias) (ifIndex $($route.InterfaceIndex))"
New-NetRoute -DestinationPrefix $prefix -InterfaceIndex $route.InterfaceIndex -NextHop $route.NextHop -RouteMetric 1 -ErrorAction Stop | Out-Null

Write-Info 'Route added. Verify with:'
Write-Host "  Test-NetConnection $ServerIp -Port 443 | Select-Object InterfaceAlias,SourceAddress,TcpTestSucceeded"