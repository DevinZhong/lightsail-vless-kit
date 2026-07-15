. "$PSScriptRoot\..\internal\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('AWS_REGION', 'AWS_AZ', 'LIGHTSAIL_INSTANCE_NAME', 'LIGHTSAIL_BUNDLE_ID', 'LIGHTSAIL_BLUEPRINT_ID')
Require-Config $config @('VLESS_UUID', 'REALITY_PRIVATE_KEY', 'REALITY_PUBLIC_KEY', 'REALITY_SHORT_ID')

Write-Info 'Ensuring the configured Lightsail SSH key pair is available locally...'
& "$PSScriptRoot\New-LightsailKeyPair.ps1"
if ($LASTEXITCODE -ne 0) { Die 'Lightsail SSH key pair preparation failed.' }
$config = Get-LocalConfig
Require-Config $config @('SSH_KEY_NAME')
$keyPath = Join-Path $env:USERPROFILE ".ssh\$($config['SSH_KEY_NAME']).pem"
if (-not (Test-Path -LiteralPath $keyPath)) {
  Die "Local SSH key is unavailable: $keyPath. Do not recreate an existing key pair unless no instance uses it."
}

try {
  $existing = Invoke-Aws $config lightsail get-instance `
    --instance-name ([string]$config['LIGHTSAIL_INSTANCE_NAME']) `
    --query 'instance.name' `
    --output text 2>$null
} catch { $existing = $null }
if ($existing -eq [string]$config['LIGHTSAIL_INSTANCE_NAME']) {
  Die "Lightsail instance already exists: $($config['LIGHTSAIL_INSTANCE_NAME']). Delete it first or choose another name."
}

& "$PSScriptRoot\..\internal\Render-CloudInit.ps1"
$cloudInitPath = Join-Path $Script:OutputDir 'cloud-init.sh'

$args = @(
  'lightsail', 'create-instances',
  '--instance-names', [string]$config['LIGHTSAIL_INSTANCE_NAME'],
  '--availability-zone', [string]$config['AWS_AZ'],
  '--blueprint-id', [string]$config['LIGHTSAIL_BLUEPRINT_ID'],
  '--bundle-id', [string]$config['LIGHTSAIL_BUNDLE_ID'],
  '--user-data', "file://$cloudInitPath",
  '--ip-address-type', 'ipv4'
)
if ($config.ContainsKey('SSH_KEY_NAME') -and -not [string]::IsNullOrWhiteSpace([string]$config['SSH_KEY_NAME'])) {
  $args += @('--key-pair-name', [string]$config['SSH_KEY_NAME'])
}

Write-Info "Creating Lightsail instance $($config['LIGHTSAIL_INSTANCE_NAME']) in $($config['AWS_AZ'])..."
Invoke-Aws $config @args | Out-Null

Write-Info 'Waiting for instance state to become running before changing firewall ports...'
$state = $null
for ($i = 0; $i -lt 60; $i++) {
  $state = Invoke-Aws $config lightsail get-instance `
    --instance-name ([string]$config['LIGHTSAIL_INSTANCE_NAME']) `
    --query 'instance.state.name' `
    --output text 2>$null
  if ($state -eq 'running') { break }
  Write-Info "Current instance state: $state"
  Start-Sleep -Seconds 5
}
if ($state -ne 'running') { Write-Warn "Instance state is still '$state'. Firewall updates will retry if Lightsail is still transitioning." }

& "$PSScriptRoot\..\internal\Open-Ports.ps1"

Write-Info 'Waiting for instance to expose a public IP...'
$serverIp = $null
for ($i = 0; $i -lt 60; $i++) {
  try { $serverIp = (& "$PSScriptRoot\..\internal\Get-InstanceIp.ps1").Trim() } catch { $serverIp = $null }
  if (-not [string]::IsNullOrWhiteSpace($serverIp)) { break }
  Start-Sleep -Seconds 5
}
if ([string]::IsNullOrWhiteSpace($serverIp)) { Die 'Instance did not get a public IP in time.' }

try { & "$PSScriptRoot\..\internal\Wait-Ssh.ps1" -HostName $serverIp -Port 22 -TimeoutSeconds 300 } catch { Write-Warn 'SSH was not reachable yet. cloud-init may still be running.' }

& "$PSScriptRoot\..\internal\Render-ClientConfigs.ps1" -ServerIp $serverIp

Write-Host ''
Write-Host 'Instance created.'
Write-Host "Public IP: $serverIp"
Write-Host ''
Write-Host 'Client files:'
Write-Host '  output/vless-reality-url.txt'
Write-Host '  output/subscription.txt'
Write-Host ''
Write-Host 'Server checks after SSH is ready:'
Write-Host '  sudo systemctl status xray'
Write-Host '  sudo journalctl -u xray -e'
Write-Host '  sudo tail -n 200 /var/log/proxy-bootstrap.log'
