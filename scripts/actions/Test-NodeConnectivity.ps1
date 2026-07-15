param(
  [switch]$SshCheck,
  [switch]$V2rayNProfileCheck,
  [switch]$RequireTcp,
  [string[]]$V2rayNDirs = @(
    'C:\Program Files\v2rayN',
    "$env:USERPROFILE\Apps\v2rayN",
    "$env:LOCALAPPDATA\v2rayN"
  )
)

. "$PSScriptRoot\..\internal\common.ps1"

$config = Get-LocalConfig
Require-Config $config @('LIGHTSAIL_INSTANCE_NAME')
$failed = $false

function Test-TcpPort {
  param([string]$HostName, [int]$Port, [int]$TimeoutMs = 5000)
  $client = [Net.Sockets.TcpClient]::new()
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $task = $client.ConnectAsync($HostName, $Port)
    $ok = $task.Wait($TimeoutMs)
    $sw.Stop()
    if ($ok -and $client.Connected) {
      return [pscustomobject]@{ Ok = $true; Milliseconds = $sw.ElapsedMilliseconds; Error = '' }
    }
    return [pscustomobject]@{ Ok = $false; Milliseconds = $sw.ElapsedMilliseconds; Error = 'timeout' }
  } catch {
    $sw.Stop()
    $message = $_.Exception.Message
    if ($_.Exception.InnerException) { $message = $_.Exception.InnerException.Message }
    return [pscustomobject]@{ Ok = $false; Milliseconds = $sw.ElapsedMilliseconds; Error = $message }
  } finally {
    $client.Dispose()
  }
}

Write-Info "Checking Lightsail instance: $($config['LIGHTSAIL_INSTANCE_NAME'])"
$instanceJson = Invoke-Aws $config lightsail get-instance `
  --instance-name ([string]$config['LIGHTSAIL_INSTANCE_NAME']) `
  --query 'instance.{name:name,state:state.name,ip:publicIpAddress,blueprint:blueprintId,bundle:bundleId}' `
  --output json

$instance = $instanceJson | ConvertFrom-Json
$ip = [string]$instance.ip

Write-Host ''
Write-Host 'Instance:'
Write-Host "  name:      $($instance.name)"
Write-Host "  state:     $($instance.state)"
Write-Host "  public IP: $ip"
Write-Host "  blueprint: $($instance.blueprint)"
Write-Host "  bundle:    $($instance.bundle)"

if ([string]::IsNullOrWhiteSpace($ip) -or $ip -eq 'null') {
  Die 'Instance has no public IP yet.'
}

Write-Host ''
Write-Info 'Testing direct TCP reachability from this Windows network...'
$tcpResults = @{}
foreach ($port in @(22, 443)) {
  $result = Test-TcpPort -HostName $ip -Port $port -TimeoutMs 5000
  $tcpResults[$port] = [bool]$result.Ok
  $status = if ($result.Ok) { "OK $($result.Milliseconds)ms" } else { "FAILED $($result.Error) $($result.Milliseconds)ms" }
  Write-Host ("  TCP {0}: {1}" -f $port, $status)
}

if ($RequireTcp -and -not $tcpResults[443]) { $failed = $true }

if ($SshCheck -and $tcpResults[22]) {
  Write-Host ''
  Write-Info 'Checking server-side Xray status over SSH...'
  Require-Config $config @('SSH_KEY_NAME')
  $keyPath = Join-Path $env:USERPROFILE ".ssh\$($config['SSH_KEY_NAME']).pem"
  if (-not (Test-Path -LiteralPath $keyPath)) {
    Write-Warn "SSH key file not found: $keyPath"
    $failed = $true
  } else {
    $remoteCommand = @(
      'printf ''XRAY_ACTIVE=%s\n'' "$(systemctl is-active xray 2>/dev/null || true)"',
      'printf ''LISTEN_443=%s\n'' "$(sudo ss -lntp 2>/dev/null | grep -c '':443'')"',
      'sudo jq -e ''.inbounds[0].settings.clients[0].id | strings | select(length > 0)'' /usr/local/etc/xray/config.json >/dev/null && printf ''UUID_SET=true\n'' || printf ''UUID_SET=false\n''',
      'sudo jq -e ''.inbounds[0].streamSettings.realitySettings.privateKey | strings | select(length > 0)'' /usr/local/etc/xray/config.json >/dev/null && printf ''REALITY_PRIVATE_KEY_SET=true\n'' || printf ''REALITY_PRIVATE_KEY_SET=false\n''',
      'sudo jq -e ''.inbounds[0].streamSettings.realitySettings.shortIds[0] | strings | select(length > 0)'' /usr/local/etc/xray/config.json >/dev/null && printf ''SHORT_ID_SET=true\n'' || printf ''SHORT_ID_SET=false\n''',
      'sudo jq -e ''.inbounds[0].streamSettings.realitySettings.serverNames[0] | strings | select(length > 0)'' /usr/local/etc/xray/config.json >/dev/null && printf ''SNI_SET=true\n'' || printf ''SNI_SET=false\n''',
      'sudo jq -e ''.inbounds[0].streamSettings.realitySettings.dest | strings | select(length > 0)'' /usr/local/etc/xray/config.json >/dev/null && printf ''DEST_SET=true\n'' || printf ''DEST_SET=false\n'''
    ) -join '; '
    $sshArgs = @('-o','BatchMode=yes','-o','StrictHostKeyChecking=accept-new','-i',$keyPath,"ubuntu@$ip",$remoteCommand)
    $remoteOutput = & ssh @sshArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
      $failed = $true
      Write-Warn 'SSH server-side check failed:'
      $remoteOutput | ForEach-Object { Write-Host "  $_" }
    } else {
      $remote = @{}
      foreach ($line in $remoteOutput) {
        $lineText = [string]$line
        $idx = $lineText.IndexOf('=')
        if ($idx -gt 0) { $remote[$lineText.Substring(0, $idx)] = $lineText.Substring($idx + 1) }
      }
      $listenCount = 0
      if ($remote.ContainsKey('LISTEN_443')) { [void][int]::TryParse([string]$remote['LISTEN_443'], [ref]$listenCount) }
      $checks = [ordered]@{
        'xray active' = ($remote.ContainsKey('XRAY_ACTIVE') -and $remote['XRAY_ACTIVE'] -eq 'active')
        'listening 443' = ($listenCount -gt 0)
        'uuid configured' = ($remote.ContainsKey('UUID_SET') -and $remote['UUID_SET'] -eq 'true')
        'Reality private key configured' = ($remote.ContainsKey('REALITY_PRIVATE_KEY_SET') -and $remote['REALITY_PRIVATE_KEY_SET'] -eq 'true')
        'short id configured' = ($remote.ContainsKey('SHORT_ID_SET') -and $remote['SHORT_ID_SET'] -eq 'true')
        'sni configured' = ($remote.ContainsKey('SNI_SET') -and $remote['SNI_SET'] -eq 'true')
        'dest configured' = ($remote.ContainsKey('DEST_SET') -and $remote['DEST_SET'] -eq 'true')
      }
      foreach ($name in $checks.Keys) {
        $status = if ($checks[$name]) { 'OK' } else { 'FAILED' }
        if (-not $checks[$name]) { $failed = $true }
        Write-Host ("  {0}: {1}" -f $name, $status)
      }
    }
  }
} elseif ($SshCheck) {
  Write-Warn 'Skipping SSH server-side check because TCP 22 is not reachable.'
  $failed = $true
}

if ($V2rayNProfileCheck) {
  Write-Host ''
  Write-Info 'Checking local v2rayN profile database for this server IP...'
  $foundDb = $false
  $foundProfile = $false
  foreach ($dir in $V2rayNDirs) {
    if ([string]::IsNullOrWhiteSpace($dir)) { continue }
    $db = Join-Path $dir 'guiConfigs\guiNDB.db'
    if (-not (Test-Path -LiteralPath $db)) { continue }
    $foundDb = $true
    Write-Host "  db: $db"
    $py = Join-Path $Script:OutputDir 'check-v2rayn-profile.py'
    $pyText = @(
      'import sqlite3, sys',
      'path, ip = sys.argv[1], sys.argv[2]',
      'con = sqlite3.connect(path)',
      'try:',
      '    rows = con.execute("select Remarks, Address, Port, Sni from ProfileItem where Address = ?", (ip,)).fetchall()',
      '    for row in rows:',
      '        print("PROFILE\t%s\t%s\t%s\t%s" % row)',
      'finally:',
      '    con.close()'
    ) -join "`n"
    Save-TextFileNoBom $py ($pyText + "`n")
    $rows = & python $py $db $ip
    if ($rows) {
      $foundProfile = $true
      $rows | ForEach-Object { Write-Host "  $_" }
    }
  }
  if (-not $foundDb) { Write-Warn 'No v2rayN guiNDB.db found in known locations.' }
  if ($foundDb -and -not $foundProfile) { Write-Warn "No v2rayN profile found for current server IP: $ip" }
}

Write-Host ''
if (-not $tcpResults[443]) {
  Write-Host 'TCP 443 is not reachable from this Windows network. This IP is not usable as a direct v2rayN node right now.'
} else {
  Write-Host 'TCP 443 is reachable. If v2rayN still times out, inspect local v2rayN generated config and core logs.'
}
Write-Host ''
Write-Host 'SSH command:'
if ($config.ContainsKey('SSH_KEY_NAME') -and -not [string]::IsNullOrWhiteSpace([string]$config['SSH_KEY_NAME'])) {
  Write-Host ('  ssh -i "$env:USERPROFILE\.ssh\{0}.pem" ubuntu@{1}' -f $config['SSH_KEY_NAME'], $ip)
} else {
  Write-Host ('  ssh ubuntu@{0}' -f $ip)
}

if ($failed) { exit 1 }
