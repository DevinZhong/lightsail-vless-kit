. "$PSScriptRoot\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('LIGHTSAIL_INSTANCE_NAME', 'SSH_ALLOWED_CIDR')

function Open-Port {
  param([string]$Protocol, [int]$FromPort, [int]$ToPort, [string]$Cidr)
  $portInfo = @{
    fromPort = $FromPort
    toPort = $ToPort
    protocol = $Protocol
    cidrs = @($Cidr)
  } | ConvertTo-Json -Compress

  for ($i = 1; $i -le 30; $i++) {
    Write-Info "Opening $Protocol $FromPort-$ToPort for $Cidr on $($config['LIGHTSAIL_INSTANCE_NAME']) (attempt $i/30)"
    $output = Invoke-Aws $config lightsail open-instance-public-ports `
      --instance-name ([string]$config['LIGHTSAIL_INSTANCE_NAME']) `
      --port-info $portInfo 2>&1
    if ($LASTEXITCODE -eq 0) { return }

    $message = ($output | Out-String).Trim()
    if ($message -match 'in transition|pending|OperationFailureException') {
      Write-Warn 'Lightsail is not ready for firewall changes yet. Retrying in 10 seconds.'
      Start-Sleep -Seconds 10
      continue
    }

    Die "Failed to open $Protocol $FromPort-$ToPort on $($config['LIGHTSAIL_INSTANCE_NAME']): $message"
  }

  Die "Timed out opening $Protocol $FromPort-$ToPort on $($config['LIGHTSAIL_INSTANCE_NAME'])."
}

Open-Port tcp 443 443 '0.0.0.0/0'
Open-Port tcp 22 22 ([string]$config['SSH_ALLOWED_CIDR'])
Write-Info 'Requested Lightsail firewall updates.'