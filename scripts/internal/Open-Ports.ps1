. "$PSScriptRoot\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('LIGHTSAIL_INSTANCE_NAME', 'SSH_ALLOWED_CIDR')

function Open-Port {
  param([string]$Protocol, [int]$FromPort, [int]$ToPort, [string]$Cidr)
  Write-Info "Opening $Protocol $FromPort-$ToPort for $Cidr on $($config['LIGHTSAIL_INSTANCE_NAME'])"
  $portInfo = @{
    fromPort = $FromPort
    toPort = $ToPort
    protocol = $Protocol
    cidrs = @($Cidr)
  } | ConvertTo-Json -Compress
  Invoke-Aws $config lightsail open-instance-public-ports `
    --instance-name ([string]$config['LIGHTSAIL_INSTANCE_NAME']) `
    --port-info $portInfo | Out-Null
}

Open-Port tcp 443 443 '0.0.0.0/0'
Open-Port tcp 22 22 ([string]$config['SSH_ALLOWED_CIDR'])
Write-Info 'Requested Lightsail firewall updates.'
