Set-StrictMode -Version Latest

$Script:UiSettingsPath = Join-Path $Script:RepoRoot '.lightsail-vless-kit.user.json'

function Get-UiLanguage {
  if (Test-Path -LiteralPath $Script:UiSettingsPath) {
    try {
      $settings = Get-Content -LiteralPath $Script:UiSettingsPath -Raw | ConvertFrom-Json -ErrorAction Stop
      if ($settings.language -in @('zh-CN', 'en-US')) { return [string]$settings.language }
    } catch { }
  }
  if ($PSUICulture -like 'zh-*') { return 'zh-CN' }
  return 'en-US'
}

function Set-UiLanguage {
  param([ValidateSet('zh-CN', 'en-US')][string]$Language)
  $json = [pscustomobject]@{ language = $Language } | ConvertTo-Json
  Save-TextFileNoBom -Path $Script:UiSettingsPath -Text ($json + "`n")
}

function Initialize-UiLanguage {
  if (Test-Path -LiteralPath $Script:UiSettingsPath) { return Get-UiLanguage }
  $suggested = Get-UiLanguage
  Write-Host ''
  Write-Host '选择界面语言 / Select interface language:' -ForegroundColor Cyan
  Write-Host ('  1. 简体中文{0}' -f $(if ($suggested -eq 'zh-CN') { '（默认）' } else { '' }))
  Write-Host ('  2. English{0}' -f $(if ($suggested -eq 'en-US') { ' (default)' } else { '' }))
  $answer = (Read-Host 'Enter / 输入 1 或 2').Trim()
  $language = if ($answer -eq '2') { 'en-US' } elseif ($answer -eq '1') { 'zh-CN' } else { $suggested }
  Set-UiLanguage -Language $language
  return $language
}
