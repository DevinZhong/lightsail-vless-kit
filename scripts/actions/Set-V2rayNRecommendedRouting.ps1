param(
  [string[]]$V2rayNDirs = @(
    "$env:USERPROFILE\v2rayN",
    "$env:USERPROFILE\Apps\v2rayN",
    'C:\Program Files\v2rayN',
    "$env:LOCALAPPDATA\v2rayN"
  ),
  [string]$ProfileAddress = '',
  [string]$RealityServerName = 'www.cloudflare.com',
  [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$outputDir = Resolve-Path (Join-Path $PSScriptRoot '..\..\output')
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
function Set-Utf8NoBomContent {
  param(
    [Parameter(Mandatory = $true)][string]$LiteralPath,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($LiteralPath, $Value, $encoding)
}

function Get-ExistingConfigDirs {
  $seen = @{}
  foreach ($dir in $V2rayNDirs) {
    if ([string]::IsNullOrWhiteSpace($dir)) { continue }
    $full = [System.IO.Path]::GetFullPath($dir)
    $candidateRoots = @($full)
    if ([System.IO.Path]::GetFileName($full) -ieq 'guiConfigs') {
      $candidateRoots += [System.IO.Path]::GetDirectoryName($full)
    }

    foreach ($root in $candidateRoots) {
      if ([string]::IsNullOrWhiteSpace($root)) { continue }
      if ($seen.ContainsKey($root)) { continue }
      $seen[$root] = $true

      $db = Join-Path $root 'guiConfigs\guiNDB.db'
      $json = Join-Path $root 'guiConfigs\guiNConfig.json'
      if (-not ((Test-Path -LiteralPath $db) -and (Test-Path -LiteralPath $json))) { continue }

      [pscustomobject]@{
        Dir = $root
        Db = $db
        Json = $json
      }
    }
  }
}

$targets = @(Get-ExistingConfigDirs)
if ($targets.Count -eq 0) {
  throw 'No v2rayN guiConfigs directory found. Pass -V2rayNDirs with the v2rayN install or user-data path.'
}

if ([string]::IsNullOrWhiteSpace($ProfileAddress)) {
  Write-Host '[WARN] -ProfileAddress is empty. The script will only manage routing/TUN settings and will not update any node SNI.'
  Write-Host '[WARN] Pass -ProfileAddress <node-ip-or-host> to update matching v2rayN profiles.'
}

Write-Host "[INFO] Found $($targets.Count) v2rayN config directory/directories."
foreach ($target in $targets) {
  Write-Host "[INFO] - $($target.Dir)"
}

if (-not $Apply) {
  Write-Host ''
  Write-Host '[DRY-RUN] No files will be changed. Re-run with -Apply after closing v2rayN.'
}

$pyPath = Join-Path $outputDir "set-v2rayn-routing-$stamp.py"
$payloadPath = Join-Path $outputDir "set-v2rayn-routing-$stamp.json"

$payload = [pscustomobject]@{
  apply = [bool]$Apply
  stamp = $stamp
  profileAddress = $ProfileAddress
  realityServerName = $RealityServerName
  targets = $targets
}
Set-Utf8NoBomContent -LiteralPath $payloadPath -Value ($payload | ConvertTo-Json -Depth 20)

$py = @'
import hashlib
import json
import os
import shutil
import sqlite3
import sys

payload_path = sys.argv[1]
with open(payload_path, "r", encoding="utf-8") as f:
    payload = json.load(f)

apply = bool(payload["apply"])
stamp = payload["stamp"]
profile_address = payload["profileAddress"]
reality_server_name = payload["realityServerName"]

def rule(remarks, outbound, domains=None, ips=None, port=None, network=None, protocol=None):
    item = {
        "Id": str(int(hashlib.sha256(f"{remarks}|{outbound}".encode("utf-8")).hexdigest()[:15], 16) % 9000000000000000000 + 1000000000000000000),
        "OutboundTag": outbound,
        "Enabled": True,
        "Remarks": remarks,
    }
    if domains:
        item["Domain"] = domains
    if ips:
        item["Ip"] = ips
    if port:
        item["Port"] = port
    if network:
        item["Network"] = network
    if protocol:
        item["Protocol"] = protocol
    return item

managed_rules = [
    rule("[personal-fixed-exit] AI strict proxy", "proxy", domains=[
        "domain:openai.com",
        "domain:chatgpt.com",
        "domain:oaistatic.com",
        "domain:oaiusercontent.com",
        "domain:auth0.com",
        "domain:anthropic.com",
        "domain:claude.ai",
        "domain:perplexity.ai",
    ]),
    rule("[personal-fixed-exit] Google strict proxy", "proxy", domains=[
        "geosite:google",
        "domain:google.com",
        "domain:gstatic.com",
        "domain:googleapis.com",
        "domain:googleusercontent.com",
        "domain:youtube.com",
        "domain:ytimg.com",
    ]),
    rule("[personal-fixed-exit] GitHub strict proxy", "proxy", domains=[
        "domain:github.com",
        "domain:githubusercontent.com",
        "domain:githubassets.com",
        "domain:ghcr.io",
    ]),
    rule("[personal-fixed-exit] Developer registries proxy", "proxy", domains=[
        "domain:npmjs.org",
        "domain:npmjs.com",
        "domain:registry.npmjs.org",
        "domain:pypi.org",
        "domain:pythonhosted.org",
        "domain:files.pythonhosted.org",
    ]),
]

def backup(path):
    dst = f"{path}.{stamp}.bak"
    shutil.copy2(path, dst)
    return dst

def update_json(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        cfg = json.load(f)
    tun = cfg.setdefault("TunModeItem", {})
    changed = []
    desired = {
        "EnableTun": True,
        "AutoRoute": True,
        "StrictRoute": True,
        "EnableIPv6Address": False,
    }
    for key, value in desired.items():
        if tun.get(key) != value:
            tun[key] = value
            changed.append(f"TunModeItem.{key}={value}")
    routing = cfg.setdefault("RoutingBasicItem", {})
    if routing.get("DomainStrategy") != "AsIs":
        routing["DomainStrategy"] = "AsIs"
        changed.append("RoutingBasicItem.DomainStrategy=AsIs")
    if apply and changed:
        backup(path)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(cfg, f, ensure_ascii=False, indent=2)
            f.write("\n")
    return changed

def update_db(path):
    con = sqlite3.connect(path)
    try:
        cur = con.cursor()
        profile_rows = cur.execute(
            "select IndexId, Remarks, Address, Port, Sni, CoreType from ProfileItem order by Remarks"
        ).fetchall()
        matches = [r for r in profile_rows if profile_address and str(r[2]) == profile_address]
        active = cur.execute(
            "select Id, Remarks, RuleSet, RuleNum from RoutingItem where IsActive = 1 limit 1"
        ).fetchone()

        changes = []
        if profile_address and matches:
            for row in matches:
                if row[4] != reality_server_name:
                    changes.append(f"ProfileItem {row[1]} Sni: {row[4]} -> {reality_server_name}")
            if apply:
                cur.execute(
                    "update ProfileItem set Sni = ? where Address = ?",
                    (reality_server_name, profile_address),
                )
        elif not profile_address:
            changes.append("Profile SNI update skipped because ProfileAddress is empty")
        else:
            changes.append(f"No ProfileItem matched Address={profile_address}")

        if active:
            rid, remarks, ruleset, _ = active
            rules = json.loads(ruleset or "[]")
            rules = [r for r in rules if not str(r.get("Remarks", "")).startswith("[personal-fixed-exit]")]
            insert_at = 0
            if rules and rules[0].get("Network") == "udp" and str(rules[0].get("Port")) == "443":
                insert_at = 1
            rules[insert_at:insert_at] = managed_rules
            changes.append(f"RoutingItem {remarks}: ensure {len(managed_rules)} managed proxy rules")
            if apply:
                cur.execute(
                    "update RoutingItem set RuleSet = ?, RuleNum = ? where Id = ?",
                    (json.dumps(rules, ensure_ascii=False, separators=(",", ":")), len(rules), rid),
                )
        else:
            changes.append("No active RoutingItem found")

        if apply:
            backup(path)
            con.commit()
        return profile_rows, active, changes
    finally:
        con.close()

for target in payload["targets"]:
    print(f"[INFO] Config dir: {target['Dir']}")
    try:
        profile_rows, active, db_changes = update_db(target["Db"])
        json_changes = update_json(target["Json"])

        for row in profile_rows:
            print(f"[INFO] Profile: remarks={row[1]!r}, address={row[2]}:{row[3]}, sni={row[4]!r}, coreType={row[5]!r}")
        if active:
            print(f"[INFO] Active routing: {active[1]!r}")
        for change in db_changes + json_changes:
            print(f"[CHANGE] {change}")
    except sqlite3.OperationalError as exc:
        print(f"[WARN] Skip {target['Dir']}: {exc}")

print("[OK] Applied." if apply else "[OK] Dry-run complete.")
'@

Set-Utf8NoBomContent -LiteralPath $pyPath -Value $py

python $pyPath $payloadPath
if ($LASTEXITCODE -ne 0) {
  throw "Python helper failed with exit code $LASTEXITCODE."
}

if ($Apply) {
  Write-Host ''
  Write-Host '[NEXT] Restart v2rayN as Administrator, then enable: System Proxy = Auto configure, Routing = V4-Whitelist / bypass mainland, TUN = on.'
  Write-Host '[NEXT] If v2rayN asks to restart as administrator for TUN, approve it.'
}
