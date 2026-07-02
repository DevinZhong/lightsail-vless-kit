. "$PSScriptRoot\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('LIGHTSAIL_INSTANCE_NAME')

Write-Info "Checking Lightsail instance: $($config['LIGHTSAIL_INSTANCE_NAME'])"
$instanceJson = Invoke-Aws $config lightsail get-instance `
  --instance-name ([string]$config['LIGHTSAIL_INSTANCE_NAME']) `
  --query 'instance.{name:name,state:state.name,ip:publicIpAddress,blueprint:blueprintId,bundle:bundleId}' `
  --output json

$instance = $instanceJson | ConvertFrom-Json
$ip = [string]$instance.ip

Write-Host ''
Write-Host 'Instance:'
Write-Host "  name:      $($instance.name)"
Write-Host "  state:     $($instance.state)"
Write-Host "  public IP: $ip"
Write-Host "  blueprint: $($instance.blueprint)"
Write-Host "  bundle:    $($instance.bundle)"

if ([string]::IsNullOrWhiteSpace($ip) -or $ip -eq 'null') {
  Die 'Instance has no public IP yet.'
}

Write-Host ''
Write-Info 'Testing TCP reachability from this Windows network...'
foreach ($port in @(22, 443)) {
  $result = Test-NetConnection -ComputerName $ip -Port $port -WarningAction SilentlyContinue
  $status = if ($result.TcpTestSucceeded) { 'OK' } else { 'FAILED' }
  Write-Host ("  TCP {0}: {1}" -f $port, $status)
}

Write-Host ''
Write-Host 'If TCP 443 is FAILED, check Lightsail firewall and server bootstrap logs.'
Write-Host 'If TCP 443 is OK but v2rayN still shows -1ms, check Xray service status and client Reality parameters.'
Write-Host ''
Write-Host 'SSH command:'
Write-Host ('  ssh -i "$env:USERPROFILE\.ssh\personal-fixed-exit-lightsail.pem" ubuntu@{0}' -f $ip)