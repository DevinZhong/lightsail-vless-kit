param(
  [ValidateSet('', 'Tokyo', 'Singapore', 'Seoul', 'Sydney', 'Oregon', 'Virginia', 'Custom')]
  [string]$TargetLocation = '',
  [string]$TargetRegion = '',
  [string]$TargetAz = '',
  [string]$TargetInstanceName = '',
  [string]$TargetNodeName = '',
  [string]$TargetStaticIpName = '',
  [int]$DeleteTimeoutSeconds = 360,
  [int]$PostDeleteDelaySeconds = 15,
  [switch]$Yes,
  [switch]$ApplyV2rayNRouting
)

. "$PSScriptRoot\..\internal\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('AWS_REGION', 'LIGHTSAIL_INSTANCE_NAME', 'AWS_AZ')
Ensure-OutputDir

$locationPresets = [ordered]@{
  Tokyo = @{
    Region = 'ap-northeast-1'
    Az = 'ap-northeast-1a'
    Slug = 'tokyo'
    NodeLabel = 'tokyo'
  }
  Singapore = @{
    Region = 'ap-southeast-1'
    Az = 'ap-southeast-1a'
    Slug = 'singapore'
    NodeLabel = 'singapore'
  }
  Seoul = @{
    Region = 'ap-northeast-2'
    Az = 'ap-northeast-2a'
    Slug = 'seoul'
    NodeLabel = 'seoul'
  }
  Sydney = @{
    Region = 'ap-southeast-2'
    Az = 'ap-southeast-2a'
    Slug = 'sydney'
    NodeLabel = 'sydney'
  }
  Oregon = @{
    Region = 'us-west-2'
    Az = 'us-west-2a'
    Slug = 'oregon'
    NodeLabel = 'oregon'
  }
  Virginia = @{
    Region = 'us-east-1'
    Az = 'us-east-1a'
    Slug = 'virginia'
    NodeLabel = 'virginia'
  }
}

function Read-Choice {
  param(
    [string]$Prompt,
    [string[]]$Choices,
    [string]$Default = ''
  )

  while ($true) {
    $suffix = if ([string]::IsNullOrWhiteSpace($Default)) { '' } else { " [$Default]" }
    $answer = (Read-Host "$Prompt$suffix").Trim()
    if ([string]::IsNullOrWhiteSpace($answer) -and -not [string]::IsNullOrWhiteSpace($Default)) {
      return $Default
    }

    foreach ($choice in $Choices) {
      if ($answer -eq $choice) { return $choice }
      if ($answer -match '^\d+$') {
        $idx = [int]$answer - 1
        if ($idx -ge 0 -and $idx -lt $Choices.Count) { return $Choices[$idx] }
      }
    }

    Write-Warn "Invalid choice: $answer"
  }
}

function Read-MenuChoice {
  param(
    [string]$Prompt,
    [object[]]$Items,
    [int]$DefaultIndex = 0
  )

  if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
    foreach ($item in $Items) { Write-Host $item.Label }
    return Read-Choice -Prompt $Prompt -Choices @($Items | ForEach-Object { $_.Value }) -Default ([string]$Items[$DefaultIndex].Value)
  }

  $selected = [Math]::Max(0, [Math]::Min($DefaultIndex, $Items.Count - 1))

  try {
    [Console]::Clear()
    Write-Host $Prompt -ForegroundColor Cyan
    Write-Host 'Use Up/Down arrows and press Enter.' -ForegroundColor DarkGray
    $top = [Console]::CursorTop

    function Write-MenuItems {
      param([int]$SelectedIndex)

      $width = [Math]::Max(40, [Console]::WindowWidth - 1)
      for ($i = 0; $i -lt $Items.Count; $i++) {
        if (($top + $i) -ge [Console]::BufferHeight) { throw 'Console buffer is too short for menu rendering.' }
        [Console]::SetCursorPosition(0, $top + $i)
        $prefix = if ($i -eq $SelectedIndex) { '> ' } else { '  ' }
        $line = ($prefix + $Items[$i].Label)
        if ($line.Length -lt $width) { $line = $line.PadRight($width) }
        if ($i -eq $SelectedIndex) {
          Write-Host $line -ForegroundColor Black -BackgroundColor Cyan -NoNewline
        } else {
          Write-Host $line -NoNewline
        }
      }
    }

    [Console]::CursorVisible = $false
    while ($true) {
      Write-MenuItems -SelectedIndex $selected
      $key = [Console]::ReadKey($true)
      switch ($key.Key) {
        'UpArrow' { if ($selected -gt 0) { $selected-- } else { $selected = $Items.Count - 1 } }
        'DownArrow' { if ($selected -lt ($Items.Count - 1)) { $selected++ } else { $selected = 0 } }
        'Enter' {
          [Console]::SetCursorPosition(0, [Math]::Min($top + $Items.Count, [Console]::BufferHeight - 1))
          Write-Host ''
          return [string]$Items[$selected].Value
        }
      }
    }
  } catch {
    Write-Warn "Arrow-key menu failed, falling back to text input: $($_.Exception.Message)"
    foreach ($item in $Items) { Write-Host $item.Label }
    return Read-Choice -Prompt $Prompt -Choices @($Items | ForEach-Object { $_.Value }) -Default ([string]$Items[$DefaultIndex].Value)
  } finally {
    try { [Console]::CursorVisible = $true } catch { }
  }
}

function Read-Value {
  param(
    [string]$Prompt,
    [string]$Default = '',
    [switch]$Required
  )

  while ($true) {
    $suffix = if ([string]::IsNullOrWhiteSpace($Default)) { '' } else { " [$Default]" }
    $answer = Read-Host "$Prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $Default }
    $answer = $answer.Trim()

    if (-not $Required -or -not [string]::IsNullOrWhiteSpace($answer)) { return $answer }
    Write-Warn "$Prompt is required."
  }
}

function Resolve-TargetConfig {
  $hasExplicitTarget =
    -not [string]::IsNullOrWhiteSpace($TargetLocation) -or
    -not [string]::IsNullOrWhiteSpace($TargetRegion) -or
    -not [string]::IsNullOrWhiteSpace($TargetAz) -or
    -not [string]::IsNullOrWhiteSpace($TargetInstanceName) -or
    -not [string]::IsNullOrWhiteSpace($TargetNodeName) -or
    -not [string]::IsNullOrWhiteSpace($TargetStaticIpName)

  if ([string]::IsNullOrWhiteSpace($TargetLocation)) {
    if ($hasExplicitTarget) {
      $TargetLocation = 'Custom'
    } else {
      Write-Host ''
      $choices = @($locationPresets.Keys) + @('Custom')
      $menuItems = @()
      foreach ($choice in $choices) {
        if ($choice -eq 'Custom') {
          $menuItems += [pscustomobject]@{ Value = $choice; Label = 'Custom' }
        } else {
          $preset = $locationPresets[$choice]
          $menuItems += [pscustomobject]@{ Value = $choice; Label = ("{0} ({1} / {2})" -f $choice, $preset.Region, $preset.Az) }
        }
      }
      $TargetLocation = Read-MenuChoice -Prompt 'Select target Lightsail region:' -Items $menuItems -DefaultIndex 0
    }
  }

  if ($TargetLocation -ne 'Custom') {
    $preset = $locationPresets[$TargetLocation]
    if ([string]::IsNullOrWhiteSpace($TargetRegion)) { $TargetRegion = [string]$preset.Region }
    if ([string]::IsNullOrWhiteSpace($TargetAz)) { $TargetAz = [string]$preset.Az }
    if ([string]::IsNullOrWhiteSpace($TargetInstanceName)) { $TargetInstanceName = "proxy-$($preset.Slug)-01" }
    if ([string]::IsNullOrWhiteSpace($TargetNodeName)) { $TargetNodeName = "aws-$($preset.NodeLabel)-clean" }
    if ([string]::IsNullOrWhiteSpace($TargetStaticIpName)) { $TargetStaticIpName = "proxy-$($preset.Slug)-static-01" }

    if (-not $hasExplicitTarget) {
      Write-Host ''
      Write-Host "Review target defaults for $TargetLocation. Press Enter to accept, or type a new value." -ForegroundColor Cyan
      $TargetRegion = Read-Value -Prompt 'AWS_REGION' -Default $TargetRegion -Required
      $TargetAz = Read-Value -Prompt 'AWS_AZ' -Default $TargetAz -Required
      $TargetInstanceName = Read-Value -Prompt 'LIGHTSAIL_INSTANCE_NAME' -Default $TargetInstanceName -Required
      $TargetNodeName = Read-Value -Prompt 'NODE_NAME' -Default $TargetNodeName -Required
      $TargetStaticIpName = Read-Value -Prompt 'LIGHTSAIL_STATIC_IP_NAME' -Default $TargetStaticIpName -Required
    }
  } else {
    Write-Host ''
    Write-Host 'Enter custom target settings.' -ForegroundColor Cyan
    $TargetRegion = Read-Value -Prompt 'AWS_REGION' -Default $TargetRegion -Required
    $TargetAz = Read-Value -Prompt 'AWS_AZ' -Default $TargetAz -Required
    $TargetInstanceName = Read-Value -Prompt 'LIGHTSAIL_INSTANCE_NAME' -Default $TargetInstanceName -Required
    $TargetNodeName = Read-Value -Prompt 'NODE_NAME' -Default $TargetNodeName -Required
    $TargetStaticIpName = Read-Value -Prompt 'LIGHTSAIL_STATIC_IP_NAME' -Default $TargetStaticIpName -Required
  }

  [pscustomobject]@{
    Location = $TargetLocation
    Region = $TargetRegion
    Az = $TargetAz
    InstanceName = $TargetInstanceName
    NodeName = $TargetNodeName
    StaticIpName = $TargetStaticIpName
  }
}

$target = Resolve-TargetConfig
$TargetLocation = $target.Location
$TargetRegion = $target.Region
$TargetAz = $target.Az
$TargetInstanceName = $target.InstanceName
$TargetNodeName = $target.NodeName
$TargetStaticIpName = $target.StaticIpName

$sourceRegion = [string]$config['AWS_REGION']
$sourceAz = [string]$config['AWS_AZ']
$sourceName = [string]$config['LIGHTSAIL_INSTANCE_NAME']
$envPath = Join-Path $Script:RepoRoot '.env.local'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$envBackupPath = Join-Path $Script:OutputDir "env-before-switch-$stamp.local"

function Set-EnvValue {
  param(
    [string]$Path,
    [string]$Name,
    [string]$Value
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    Die "Cannot update missing env file: $Path"
  }

  $lines = [System.Collections.Generic.List[string]]::new()
  $found = $false
  foreach ($line in [IO.File]::ReadAllLines($Path)) {
    if ($line -match "^\s*$([regex]::Escape($Name))\s*=") {
      $lines.Add("$Name=$Value")
      $found = $true
    } else {
      $lines.Add($line)
    }
  }
  if (-not $found) { $lines.Add("$Name=$Value") }
  [IO.File]::WriteAllText($Path, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
}

function Test-LightsailInstanceExists {
  param(
    [hashtable]$SourceConfig,
    [string]$InstanceName
  )

  $name = Invoke-Aws $SourceConfig lightsail get-instance `
    --instance-name $InstanceName `
    --query 'instance.name' `
    --output text 2>$null

  return ($LASTEXITCODE -eq 0 -and $name -eq $InstanceName)
}

function Wait-InstanceDeleted {
  param(
    [hashtable]$SourceConfig,
    [string]$InstanceName,
    [int]$TimeoutSeconds
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $state = Invoke-Aws $SourceConfig lightsail get-instance `
      --instance-name $InstanceName `
      --query 'instance.state.name' `
      --output text 2>$null

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$state)) {
      Write-Info "Old instance is no longer visible: $InstanceName"
      return
    }

    Write-Info "Waiting for old instance deletion: $InstanceName state=$state"
    Start-Sleep -Seconds 10
  }

  Die "Timed out waiting for old instance deletion: $InstanceName"
}

if (-not $Yes) {
  Write-Host ''
  Write-Warn 'This migration deletes the current Lightsail instance before creating the replacement.'
  Write-Warn "Current target: $sourceName in $sourceRegion / $sourceAz"
  Write-Warn "New target:     $TargetInstanceName in $TargetRegion / $TargetAz"
  Write-Warn 'Local secrets are kept, but the server IP and v2rayN import URL will change.'
  $answer = Read-Host 'Type SWITCH to continue'
  if ($answer -ne 'SWITCH') { Die 'Switch cancelled.' }
}

Copy-Item -LiteralPath $envPath -Destination $envBackupPath -Force
Write-Info "Backed up current .env.local to $envBackupPath"

if (Test-LightsailInstanceExists -SourceConfig $config -InstanceName $sourceName) {
  Write-Info "Deleting old Lightsail instance: $sourceName ($sourceRegion)"
  & "$PSScriptRoot\Remove-LightsailProxy.ps1" -Yes
  if ($LASTEXITCODE -ne 0) { Die 'Old instance delete command failed.' }
  Wait-InstanceDeleted -SourceConfig $config -InstanceName $sourceName -TimeoutSeconds $DeleteTimeoutSeconds
} else {
  Write-Warn "Current configured instance does not exist, skipping delete: $sourceName ($sourceRegion)"
}
if ($PostDeleteDelaySeconds -gt 0) {
  Write-Info "Waiting $PostDeleteDelaySeconds seconds before switching config..."
  Start-Sleep -Seconds $PostDeleteDelaySeconds
}

Write-Info 'Updating .env.local to target region settings...'
Set-EnvValue $envPath 'AWS_REGION' $TargetRegion
Set-EnvValue $envPath 'AWS_AZ' $TargetAz
Set-EnvValue $envPath 'LIGHTSAIL_INSTANCE_NAME' $TargetInstanceName
Set-EnvValue $envPath 'NODE_NAME' $TargetNodeName
Set-EnvValue $envPath 'LIGHTSAIL_STATIC_IP_NAME' $TargetStaticIpName
Set-EnvValue $envPath 'USE_STATIC_IP' 'false'
Set-EnvValue $envPath 'SERVER_IP' ''

Write-Info 'Ensuring target-region Lightsail key pair exists and updating SSH_KEY_NAME...'
& "$PSScriptRoot\New-LightsailKeyPair.ps1" -Region $TargetRegion -RecreateIfLocalPemMissing
if ($LASTEXITCODE -ne 0) { Die 'Lightsail key pair preparation failed.' }

$attempt = 1
while ($true) {
  Write-Info "Creating target-region Lightsail proxy node (attempt $attempt)..."
  & "$PSScriptRoot\New-LightsailProxy.ps1"
  if ($LASTEXITCODE -ne 0) { Die 'New Lightsail proxy creation failed.' }

  Write-Info 'Running post-deploy connectivity checks...'
  $checkExit = 1
  for ($checkAttempt = 1; $checkAttempt -le 12; $checkAttempt++) {
    Write-Info "Post-deploy validation attempt $checkAttempt/12..."
    & "$PSScriptRoot\Test-NodeConnectivity.ps1" -SshCheck -RequireTcp
    $checkExit = $LASTEXITCODE
    if ($checkExit -eq 0) { break }
    if ($checkAttempt -lt 12) {
      Write-Warn 'Validation is not ready yet. Waiting 30 seconds before retrying.'
      Start-Sleep -Seconds 30
    }
  }
  if ($checkExit -eq 0) { break }

  Write-Warn 'Post-deploy validation failed. The instance may be healthy on AWS but not directly reachable from this network.'
  if ($Yes) { Die 'Validation failed in non-interactive mode. Delete/rebuild manually or rerun without -Yes to choose retry.' }

  $answer = Read-Host 'Type RETRY to delete this instance and rebuild in the same region, or press Enter to stop here'
  if ($answer -ne 'RETRY') {
    Die 'Stopped after validation failure. Current instance was left running for inspection.'
  }

  $currentConfig = Get-LocalConfig
  $currentName = [string]$currentConfig['LIGHTSAIL_INSTANCE_NAME']
  Write-Info "Deleting failed instance before retry: $currentName"
  & "$PSScriptRoot\Remove-LightsailProxy.ps1" -Yes
  if ($LASTEXITCODE -ne 0) { Die 'Failed to delete the failed instance before retry.' }
  Wait-InstanceDeleted -SourceConfig $currentConfig -InstanceName $currentName -TimeoutSeconds $DeleteTimeoutSeconds
  if ($PostDeleteDelaySeconds -gt 0) {
    Write-Info "Waiting $PostDeleteDelaySeconds seconds before retry..."
    Start-Sleep -Seconds $PostDeleteDelaySeconds
  }
  $attempt++
}

Write-Info 'Generating v2rayN routing helper files...'
& "$PSScriptRoot\..\internal\Render-V2rayNRoutingRules.ps1"
if ($LASTEXITCODE -ne 0) { Die 'v2rayN routing helper generation failed.' }

$urlPath = Join-Path $Script:OutputDir 'vless-reality-url.txt'
$subPath = Join-Path $Script:OutputDir 'subscription.txt'
$url = ''
if (Test-Path -LiteralPath $urlPath) {
  $url = ([IO.File]::ReadAllText($urlPath)).Trim()
}

Write-Host ''
Write-Host 'Switch complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Import this URL into v2rayN:' -ForegroundColor Cyan
Write-Host $url
Write-Host ''
Write-Host 'Generated files:'
Write-Host "  $urlPath"
Write-Host "  $subPath"
Write-Host "  $(Join-Path $Script:OutputDir 'v2rayn-routing-rules.json')"
Write-Host "  $(Join-Path $Script:OutputDir 'v2rayn-routing-bundle.json')"
Write-Host "  $(Join-Path $Script:OutputDir 'v2rayn-routing-notes.txt')"
Write-Host ''
Write-Host 'v2rayN note:'
Write-Host '  VLESS URLs cannot embed routing rules. Import the node URL first, then import/adapt the generated routing JSON if your v2rayN version supports it.'
Write-Host '  Or close v2rayN and run: .\scripts\Manage-LightsailProxy.ps1 -Action ApplyV2rayNRouting'

if ($ApplyV2rayNRouting) {
  Write-Host ''
  Write-Warn 'Applying v2rayN routing requires v2rayN to be closed. If files are locked, this step may fail safely.'
  & "$PSScriptRoot\Set-V2rayNRecommendedRouting.ps1" -Apply
}