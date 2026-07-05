. "$PSScriptRoot\common.ps1"

Ensure-OutputDir

function New-Rule {
  param(
    [string]$Id,
    [string]$Remarks,
    [string]$OutboundTag,
    [string[]]$Domain = @(),
    [string[]]$Ip = @(),
    [string]$Port = '',
    [string]$Network = ''
  )

  $rule = [ordered]@{
    Id = $Id
    OutboundTag = $OutboundTag
    Enabled = $true
    Remarks = $Remarks
  }
  if ($Domain.Count -gt 0) { $rule.Domain = $Domain }
  if ($Ip.Count -gt 0) { $rule.Ip = $Ip }
  if (-not [string]::IsNullOrWhiteSpace($Port)) { $rule.Port = $Port }
  if (-not [string]::IsNullOrWhiteSpace($Network)) { $rule.Network = $Network }
  return [pscustomobject]$rule
}

$rules = @(
  New-Rule -Id '1000000000000000001' -Remarks '[personal-fixed-exit] Block QUIC UDP 443' -OutboundTag 'block' -Port '443' -Network 'udp'
  New-Rule -Id '1000000000000000002' -Remarks '[personal-fixed-exit] AI strict proxy' -OutboundTag 'proxy' -Domain @(
    'domain:openai.com',
    'domain:chatgpt.com',
    'domain:oaistatic.com',
    'domain:oaiusercontent.com',
    'domain:auth0.com',
    'domain:anthropic.com',
    'domain:claude.ai',
    'domain:perplexity.ai'
  )
  New-Rule -Id '1000000000000000003' -Remarks '[personal-fixed-exit] Google strict proxy' -OutboundTag 'proxy' -Domain @(
    'geosite:google',
    'domain:google.com',
    'domain:gstatic.com',
    'domain:googleapis.com',
    'domain:googleusercontent.com',
    'domain:youtube.com',
    'domain:ytimg.com'
  )
  New-Rule -Id '1000000000000000004' -Remarks '[personal-fixed-exit] GitHub strict proxy' -OutboundTag 'proxy' -Domain @(
    'domain:github.com',
    'domain:githubusercontent.com',
    'domain:githubassets.com',
    'domain:ghcr.io'
  )
  New-Rule -Id '1000000000000000005' -Remarks '[personal-fixed-exit] Developer registries proxy' -OutboundTag 'proxy' -Domain @(
    'domain:npmjs.org',
    'domain:npmjs.com',
    'domain:registry.npmjs.org',
    'domain:pypi.org',
    'domain:pythonhosted.org',
    'domain:files.pythonhosted.org'
  )
  New-Rule -Id '1000000000000000006' -Remarks '[personal-fixed-exit] Private direct' -OutboundTag 'direct' -Domain @('geosite:private') -Ip @('geoip:private')
  New-Rule -Id '1000000000000000007' -Remarks '[personal-fixed-exit] China direct' -OutboundTag 'direct' -Domain @('geosite:cn') -Ip @('geoip:cn')
)

$rulesPath = Join-Path $Script:OutputDir 'v2rayn-routing-rules.json'
$bundlePath = Join-Path $Script:OutputDir 'v2rayn-routing-bundle.json'
$notesPath = Join-Path $Script:OutputDir 'v2rayn-routing-notes.txt'

Save-TextFileNoBom $rulesPath (($rules | ConvertTo-Json -Depth 20) + "`n")

$bundle = [ordered]@{
  remarks = 'personal-fixed-exit recommended routing'
  domainStrategy = 'AsIs'
  defaultOutbound = 'proxy'
  rules = $rules
}
Save-TextFileNoBom $bundlePath (($bundle | ConvertTo-Json -Depth 20) + "`n")

$notes = @(
  'v2rayN routing notes',
  '',
  'VLESS share URLs only contain node connection parameters. Routing rules cannot be embedded into the VLESS URL.',
  '',
  'Generated files:',
  '- output/v2rayn-routing-rules.json: rule array using the same shape as v2rayN RoutingItem.RuleSet.',
  '- output/v2rayn-routing-bundle.json: self-describing bundle with remarks, domainStrategy, defaultOutbound, and rules.',
  '',
  'Recommended manual settings in v2rayN:',
  '- System proxy: auto configure system proxy',
  '- Routing: V4 whitelist / bypass mainland, or import/adapt the generated rules if your v2rayN version supports rule import',
  '- TUN: enable only when you need command-line or non-browser apps to go through the node',
  '- IPv6: off until your local network is known stable',
  '',
  'Alternative automated local update after importing the node and closing v2rayN:',
  '  .\scripts\Set-V2rayNRecommendedRouting.ps1 -Apply',
  '',
  'If the node IP changed and the imported profile address is known:',
  '  .\scripts\Set-V2rayNRecommendedRouting.ps1 -ProfileAddress ''<server-ip>'' -Apply'
) -join "`n"
Save-TextFileNoBom $notesPath ($notes + "`n")

Write-Info 'Rendered v2rayN routing helper files under output/.'
Write-Host "  output/v2rayn-routing-rules.json"
Write-Host "  output/v2rayn-routing-bundle.json"
Write-Host "  output/v2rayn-routing-notes.txt"