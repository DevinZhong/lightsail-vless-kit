. "$PSScriptRoot\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('LIGHTSAIL_INSTANCE_NAME')

$ip = Invoke-Aws $config lightsail get-instance `
  --instance-name ([string]$config['LIGHTSAIL_INSTANCE_NAME']) `
  --query 'instance.publicIpAddress' `
  --output text

if ([string]::IsNullOrWhiteSpace($ip) -or $ip -eq 'None') {
  Die "Could not find public IP for instance: $($config['LIGHTSAIL_INSTANCE_NAME'])"
}
$ip.Trim()
