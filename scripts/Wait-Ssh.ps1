param(
  [string]$HostName,
  [int]$Port = 22,
  [int]$TimeoutSeconds = 300
)

. "$PSScriptRoot\common.ps1"

if ([string]::IsNullOrWhiteSpace($HostName)) {
  $HostName = (& "$PSScriptRoot\Get-InstanceIp.ps1").Trim()
}

Write-Info "Waiting for TCP ${HostName}:${Port} for up to ${TimeoutSeconds}s..."
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
  try {
    $client = [System.Net.Sockets.TcpClient]::new()
    $iar = $client.BeginConnect($HostName, $Port, $null, $null)
    if ($iar.AsyncWaitHandle.WaitOne(3000, $false)) {
      $client.EndConnect($iar)
      $client.Close()
      Write-Info "TCP ${HostName}:${Port} is reachable."
      exit 0
    }
    $client.Close()
  } catch {}
  Start-Sleep -Seconds 5
}
Die "Timed out waiting for TCP ${HostName}:${Port}"
