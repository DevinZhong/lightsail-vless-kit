. "$PSScriptRoot\..\internal\common.ps1"

$failed = $false
$envPath = Join-Path $Script:RepoRoot '.env.local'
$secretsPath = Join-Path $Script:RepoRoot 'secrets.local.env'

function Report-Check {
  param([string]$Name, [bool]$Ok, [string]$Detail = '')
  $status = if ($Ok) { 'OK' } else { 'FAILED' }
  $color = if ($Ok) { 'Green' } else { 'Yellow' }
  Write-Host ("{0,-28} {1} {2}" -f $Name, $status, $Detail) -ForegroundColor $color
  if (-not $Ok) { $script:failed = $true }
}

Write-Host '环境预检 / Preflight' -ForegroundColor Cyan
Report-Check -Name '.env.local' -Ok (Test-Path -LiteralPath $envPath) -Detail '复制 .env.example 后填写部署参数'
Report-Check -Name 'secrets.local.env' -Ok (Test-Path -LiteralPath $secretsPath) -Detail '可先通过 GenerateSecrets 生成'

if (Test-Path -LiteralPath $envPath) {
  $config = Get-LocalConfig
  foreach ($name in @('AWS_REGION', 'AWS_AZ', 'LIGHTSAIL_INSTANCE_NAME', 'LIGHTSAIL_BUNDLE_ID', 'LIGHTSAIL_BLUEPRINT_ID')) {
    $value = if ($config.ContainsKey($name)) { [string]$config[$name] } else { '' }
    Report-Check -Name "配置 $name" -Ok (-not [string]::IsNullOrWhiteSpace($value)) -Detail $value
  }
  $aws = Get-Command aws -ErrorAction SilentlyContinue
  Report-Check -Name 'AWS CLI' -Ok ($null -ne $aws) -Detail $(if ($aws) { $aws.Source } else { '请安装 AWS CLI v2' })
  if ($aws) {
    try {
      $identity = Invoke-Aws $config sts get-caller-identity --query 'Account' --output text 2>$null
      Report-Check -Name 'AWS 登录态' -Ok ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($identity)) -Detail $(if ($LASTEXITCODE -eq 0) { "account $identity" } else { '运行 aws configure sso 或 aws configure' })
    } catch {
      Report-Check -Name 'AWS 登录态' -Ok $false -Detail '运行 aws configure sso 或 aws configure'
    }
  }
  $xray = Get-Command xray,xray.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  $hasSecrets = Test-Path -LiteralPath $secretsPath
  Report-Check -Name 'Xray 密钥生成工具' -Ok ($hasSecrets -or $null -ne $xray) -Detail $(if ($xray) { '已找到 xray' } else { '仅在需要生成 Reality 密钥时必需' })
}

if ($failed) { exit 1 }
Write-Host '预检通过。/ Preflight passed.' -ForegroundColor Green
