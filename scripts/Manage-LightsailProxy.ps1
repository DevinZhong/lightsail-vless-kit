param(
  [ValidateSet('', 'Preflight', 'SwitchRegion', 'Create', 'Rebuild', 'Delete', 'Test', 'AddBypassRoute', 'RemoveBypassRoute', 'ApplyV2rayNRouting', 'TestV2rayNCore', 'GenerateSecrets', 'EnsureKeyPair', 'RepairPem', 'SetLanguage', 'Exit')]
  [string]$Action = '',
  [ValidateSet('zh-CN', 'en-US')][string]$Language = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\internal\common.ps1"
. "$PSScriptRoot\internal\ui.ps1"
if (-not [string]::IsNullOrWhiteSpace($Language)) { Set-UiLanguage -Language $Language }
$uiLanguage = Initialize-UiLanguage

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

$labels = if ($uiLanguage -eq 'zh-CN') {
  @{ Preflight='环境预检（推荐首次运行）'; SwitchRegion='切换区域 / 重建节点'; Test='测试当前节点连通性'; Create='按当前 .env.local 创建节点'; Rebuild='重建当前区域节点'; Delete='删除当前节点'; AddBypassRoute='为当前节点 IP 添加直连路由'; RemoveBypassRoute='移除当前节点 IP 的直连路由'; ApplyV2rayNRouting='应用推荐 v2rayN 路由'; TestV2rayNCore='测试本地 v2rayN Core 配置'; GenerateSecrets='生成或修复本地代理密钥'; EnsureKeyPair='确保当前区域的 Lightsail 密钥对'; RepairPem='修复本地 PEM 密钥格式'; SetLanguage='切换界面语言 / Language'; Exit='退出' }
} else {
  @{ Preflight='Preflight checks (recommended first)'; SwitchRegion='Switch region / rebuild node'; Test='Test current node connectivity'; Create='Create node from current .env.local'; Rebuild='Rebuild current-region node'; Delete='Delete current node'; AddBypassRoute='Add direct route for current node IP'; RemoveBypassRoute='Remove direct route for current node IP'; ApplyV2rayNRouting='Apply recommended v2rayN routing'; TestV2rayNCore='Test local v2rayN core config'; GenerateSecrets='Generate or repair local proxy secrets'; EnsureKeyPair='Ensure Lightsail key pair for current region'; RepairPem='Repair local PEM key formatting'; SetLanguage='Switch interface language / 语言'; Exit='Exit' }
}
$actions = @('Preflight','SwitchRegion','Test','Create','Rebuild','Delete','AddBypassRoute','RemoveBypassRoute','ApplyV2rayNRouting','TestV2rayNCore','GenerateSecrets','EnsureKeyPair','RepairPem','SetLanguage','Exit') | ForEach-Object { [pscustomobject]@{ Value = $_; Label = $labels[$_] } }

if ([string]::IsNullOrWhiteSpace($Action)) {
  $prompt = if ($uiLanguage -eq 'zh-CN') { '请选择 Lightsail 节点操作：' } else { 'Select Lightsail proxy action:' }
  $Action = Read-Choice -Prompt $prompt -Items $actions -DefaultIndex 0
}

switch ($Action) {
  'Preflight' { Invoke-Script 'Test-LightsailPreflight.ps1' }
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
  'SetLanguage' {
    $answer = (Read-Host '1. 简体中文  2. English').Trim()
    Set-UiLanguage -Language $(if ($answer -eq '2') { 'en-US' } else { 'zh-CN' })
  }
  'Exit' { Write-Host 'Bye.' }
  default { throw "Unsupported action: $Action" }
}
