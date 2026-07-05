param(
  [ValidateSet('', 'SwitchRegion', 'Create', 'Rebuild', 'Delete', 'Test', 'AddBypassRoute', 'RemoveBypassRoute', 'ApplyV2rayNRouting', 'TestV2rayNCore', 'GenerateSecrets', 'EnsureKeyPair', 'RepairPem', 'Exit')]
  [string]$Action = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Script {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [string[]]$Arguments = @()
  )

  $scriptPath = Join-Path (Join-Path $PSScriptRoot 'actions') $ScriptName
  if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Script not found: $scriptPath" }
  & $scriptPath @Arguments
}

function Read-Choice {
  param(
    [string]$Prompt,
    [object[]]$Items,
    [int]$DefaultIndex = 0
  )

  if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
    for ($i = 0; $i -lt $Items.Count; $i++) {
      Write-Host ("{0}. {1}" -f ($i + 1), $Items[$i].Label)
    }
    while ($true) {
      $answer = (Read-Host $Prompt).Trim()
      if ([string]::IsNullOrWhiteSpace($answer)) { return [string]$Items[$DefaultIndex].Value }
      if ($answer -match '^\d+$') {
        $idx = [int]$answer - 1
        if ($idx -ge 0 -and $idx -lt $Items.Count) { return [string]$Items[$idx].Value }
      }
      foreach ($item in $Items) {
        if ($answer -eq [string]$item.Value) { return [string]$item.Value }
      }
      Write-Host "Invalid choice: $answer" -ForegroundColor Yellow
    }
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
    Write-Host "[WARN] Arrow-key menu failed, falling back to text input: $($_.Exception.Message)" -ForegroundColor Yellow
    for ($i = 0; $i -lt $Items.Count; $i++) {
      Write-Host ("{0}. {1}" -f ($i + 1), $Items[$i].Label)
    }
    return Read-Choice -Prompt $Prompt -Items $Items -DefaultIndex $DefaultIndex
  } finally {
    try { [Console]::CursorVisible = $true } catch { }
  }
}

$actions = @(
  [pscustomobject]@{ Value = 'SwitchRegion'; Label = 'Switch region / rebuild node' },
  [pscustomobject]@{ Value = 'Test'; Label = 'Test current node connectivity' },
  [pscustomobject]@{ Value = 'Create'; Label = 'Create node from current .env.local' },
  [pscustomobject]@{ Value = 'Rebuild'; Label = 'Rebuild current-region node' },
  [pscustomobject]@{ Value = 'Delete'; Label = 'Delete current node' },
  [pscustomobject]@{ Value = 'AddBypassRoute'; Label = 'Add direct route for current node IP' },
  [pscustomobject]@{ Value = 'RemoveBypassRoute'; Label = 'Remove direct route for current node IP' },
  [pscustomobject]@{ Value = 'ApplyV2rayNRouting'; Label = 'Apply recommended v2rayN routing' },
  [pscustomobject]@{ Value = 'TestV2rayNCore'; Label = 'Test local v2rayN core config' },
  [pscustomobject]@{ Value = 'GenerateSecrets'; Label = 'Generate or repair local proxy secrets' },
  [pscustomobject]@{ Value = 'EnsureKeyPair'; Label = 'Ensure Lightsail key pair for current region' },
  [pscustomobject]@{ Value = 'RepairPem'; Label = 'Repair local PEM key formatting' },
  [pscustomobject]@{ Value = 'Exit'; Label = 'Exit' }
)

if ([string]::IsNullOrWhiteSpace($Action)) {
  $Action = Read-Choice -Prompt 'Select Lightsail proxy action:' -Items $actions -DefaultIndex 0
}

switch ($Action) {
  'SwitchRegion' { Invoke-Script 'Switch-LightsailRegion.ps1' }
  'Create' { Invoke-Script 'New-LightsailProxy.ps1' }
  'Rebuild' { Invoke-Script 'Rebuild-LightsailProxy.ps1' }
  'Delete' { Invoke-Script 'Remove-LightsailProxy.ps1' }
  'Test' { Invoke-Script 'Test-NodeConnectivity.ps1' -Arguments @('-SshCheck', '-RequireTcp') }
  'AddBypassRoute' { Invoke-Script 'Add-NodeBypassRoute.ps1' }
  'RemoveBypassRoute' { Invoke-Script 'Remove-NodeBypassRoute.ps1' }
  'ApplyV2rayNRouting' { Invoke-Script 'Set-V2rayNRecommendedRouting.ps1' -Arguments @('-Apply') }
  'TestV2rayNCore' { Invoke-Script 'Test-V2rayNCore.ps1' }
  'GenerateSecrets' { Invoke-Script 'Generate-Secrets.ps1' }
  'EnsureKeyPair' { Invoke-Script 'New-LightsailKeyPair.ps1' }
  'RepairPem' { Invoke-Script 'Repair-LightsailPem.ps1' }
  'Exit' { Write-Host 'Bye.' }
  default { throw "Unsupported action: $Action" }
}