function New-ITDashboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $output = Join-Path $ProjectRoot ("dashboard\ITDashboard_{0}.html" -f $env:COMPUTERNAME)

    # -----------------------------
    # Collect system information
    # -----------------------------
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"

    $uptime = (Get-Date) - $os.LastBootUpTime
    $memoryUsed = if ($os.TotalVisibleMemorySize) {
        [math]::Round((1 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize)) * 100, 1)
    } else { 0 }

    $diskFree = if ($drive.Size) {
        [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
    } else { 0 }

    $diskFreeGB = [math]::Round($drive.FreeSpace / 1GB, 1)
    $diskTotalGB = [math]::Round($drive.Size / 1GB, 1)

    $pendingReboot =
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")

    # -----------------------------
    # Network
    # -----------------------------
    $networkConfig = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4Address -and $_.NetAdapter.Status -eq "Up" } |
        Select-Object -First 1

    $ipv4 = if ($networkConfig) { ($networkConfig.IPv4Address | Select-Object -First 1).IPAddress } else { "Not detected" }
    $gateway = if ($networkConfig) { ($networkConfig.IPv4DefaultGateway | Select-Object -First 1).NextHop } else { "Not detected" }
    $adapter = if ($networkConfig) { $networkConfig.InterfaceAlias } else { "Not detected" }
    $dnsServers = if ($networkConfig) { $networkConfig.DnsServer.ServerAddresses -join ", " } else { "Not detected" }

    $internetOK = Test-Connection "1.1.1.1" -Count 1 -Quiet -ErrorAction SilentlyContinue
    try {
        Resolve-DnsName "www.microsoft.com" -ErrorAction Stop | Out-Null
        $dnsOK = $true
    } catch {
        $dnsOK = $false
    }

    # -----------------------------
    # Security
    # -----------------------------
    $defenderEnabled = $null
    $realtimeEnabled = $null
    $signatureVersion = "Unavailable"

    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $defenderEnabled = $mp.AntivirusEnabled
        $realtimeEnabled = $mp.RealTimeProtectionEnabled
        $signatureVersion = $mp.AntivirusSignatureVersion
    } catch {}

    $firewallProfiles = @()
    try {
        $firewallProfiles = @(Get-NetFirewallProfile -ErrorAction Stop)
    } catch {}

    $firewallEnabledCount = @($firewallProfiles | Where-Object { $_.Enabled }).Count
    $firewallTotalCount = @($firewallProfiles).Count

    $bitlocker = "Unavailable"
    try {
        $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        $bitlocker = [string]$bl.ProtectionStatus
    } catch {}

    # -----------------------------
    # Services
    # -----------------------------
    $serviceNames = @("wuauserv","BITS","Spooler","WinDefend","EventLog","Dhcp","Dnscache")
    $services = foreach ($name in $serviceNames) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc) {
            [PSCustomObject]@{
                Service = $svc.DisplayName
                Name = $svc.Name
                Status = [string]$svc.Status
            }
        }
    }

    # -----------------------------
    # Processes
    # -----------------------------
    $topMemory = Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 10 Name, Id,
            @{N="RAM_MB";E={[math]::Round($_.WorkingSet64 / 1MB, 1)}},
            @{N="CPU_Seconds";E={if ($_.CPU) {[math]::Round($_.CPU,1)} else {0}}}

    $topCPU = Get-Process -ErrorAction SilentlyContinue |
        Sort-Object CPU -Descending |
        Select-Object -First 10 Name, Id,
            @{N="CPU_Seconds";E={if ($_.CPU) {[math]::Round($_.CPU,1)} else {0}}},
            @{N="RAM_MB";E={[math]::Round($_.WorkingSet64 / 1MB, 1)}}

    # -----------------------------
    # Event logs
    # -----------------------------
    $events = @(
        Get-WinEvent -FilterHashtable @{
            LogName = @("System","Application")
            Level = 1,2
            StartTime = (Get-Date).AddHours(-24)
        } -ErrorAction SilentlyContinue
    )

    $criticalCount = $events.Count

    $eventProviders = $events |
        Group-Object ProviderName |
        Sort-Object Count -Descending |
        Select-Object -First 8 @{N="Provider";E={$_.Name}}, Count

    $recentEvents = $events |
        Select-Object -First 12 TimeCreated, LogName, Id, LevelDisplayName, ProviderName,
            @{N="Message";E={
                $m = $_.Message -replace "`r|`n"," "
                if ($m.Length -gt 140) { $m.Substring(0,140) + "..." } else { $m }
            }}

    # -----------------------------
    # Software / battery
    # -----------------------------
    $softwareCount = 0
    try {
        $softwareCount = @(Get-InstalledSoftware).Count
    } catch {}

    $batteryData = $null
    try {
        $batteryData = Get-BatteryHealthData
    } catch {}

    $batteryText = if ($batteryData -and $batteryData.Present) {
        if ($null -ne $batteryData.HealthPercent) {
            "$($batteryData.HealthPercent)% health"
        } elseif ($null -ne $batteryData.ChargePercent) {
            "$($batteryData.ChargePercent)% charge"
        } else {
            "Detected"
        }
    } else {
        "N/A"
    }

    # -----------------------------
    # Health labels
    # -----------------------------
    function Get-HealthClass {
        param([string]$Type, [double]$Value)

        switch ($Type) {
            "Memory" {
                if ($Value -lt 80) { "good" }
                elseif ($Value -lt 90) { "warn" }
                else { "bad" }
            }
            "DiskFree" {
                if ($Value -ge 20) { "good" }
                elseif ($Value -ge 10) { "warn" }
                else { "bad" }
            }
            "Events" {
                if ($Value -lt 10) { "good" }
                elseif ($Value -lt 25) { "warn" }
                else { "bad" }
            }
            default { "neutral" }
        }
    }

    $memoryClass = Get-HealthClass "Memory" $memoryUsed
    $diskClass = Get-HealthClass "DiskFree" $diskFree
    $eventsClass = Get-HealthClass "Events" $criticalCount
    $rebootClass = if ($pendingReboot) { "warn" } else { "good" }
    $networkClass = if ($internetOK -and $dnsOK) { "good" } else { "bad" }
    $defenderClass = if ($defenderEnabled -and $realtimeEnabled) { "good" } else { "warn" }

    # -----------------------------
    # Helper HTML
    # -----------------------------
    function Convert-ObjectTableToHtml {
        param(
            [Parameter(Mandatory)]$Data,
            [string]$EmptyMessage = "No data available."
        )

        if (-not $Data -or @($Data).Count -eq 0) {
            return "<div class='empty'>$EmptyMessage</div>"
        }

        $table = ($Data | ConvertTo-Html -Fragment) -join "`n"
        return "<div class='table-wrap'>$table</div>"
    }

    function Get-ServiceTableHtml {
        if (-not $services) {
            return "<div class='empty'>No service data available.</div>"
        }

        $rows = foreach ($svc in $services) {
            $cls = if ($svc.Status -eq "Running") { "pill-good" } else { "pill-warn" }
            "<tr><td>$([System.Net.WebUtility]::HtmlEncode($svc.Service))</td><td><span class='pill $cls'>$($svc.Status)</span></td></tr>"
        }

        return "<div class='table-wrap'><table><thead><tr><th>Service</th><th>Status</th></tr></thead><tbody>$($rows -join '')</tbody></table></div>"
    }

    # -----------------------------
    # HTML styling
    # -----------------------------
    $css = @"
<style>
:root{
  --bg:#0b1220;
  --panel:#121c2e;
  --panel2:#172338;
  --text:#e8eef7;
  --muted:#91a0b5;
  --border:#26364f;
  --good:#22c55e;
  --warn:#f59e0b;
  --bad:#ef4444;
  --neutral:#3b82f6;
}
*{box-sizing:border-box}
body{
  margin:0;
  font-family:Segoe UI,Arial,sans-serif;
  background:linear-gradient(180deg,#0b1220,#101827);
  color:var(--text);
}
.wrapper{max-width:1500px;margin:auto;padding:28px}
.header{
  display:flex;justify-content:space-between;gap:20px;align-items:flex-start;
  margin-bottom:22px
}
h1{font-size:30px;margin:0 0 6px}
.subtitle{color:var(--muted);font-size:14px}
.badge{
  border:1px solid var(--border);background:var(--panel);padding:8px 12px;
  border-radius:999px;color:var(--muted);font-size:13px
}
.grid{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(190px,1fr));
  gap:14px;
}
.card{
  background:var(--panel);
  border:1px solid var(--border);
  border-radius:14px;
  padding:18px;
  box-shadow:0 10px 30px rgba(0,0,0,.18);
}
.card-title{color:var(--muted);font-size:13px;margin-bottom:9px}
.card-value{font-size:30px;font-weight:700;line-height:1.1}
.card-sub{margin-top:7px;color:var(--muted);font-size:12px}
.good{border-left:4px solid var(--good)}
.warn{border-left:4px solid var(--warn)}
.bad{border-left:4px solid var(--bad)}
.neutral{border-left:4px solid var(--neutral)}
.section{
  background:var(--panel);
  border:1px solid var(--border);
  border-radius:14px;
  padding:20px;
  margin-top:18px;
  min-width:0;
  overflow:hidden;
}
.section h2{font-size:18px;margin:0 0 16px}
.two-col{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:18px;
}
.info-grid{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(230px,1fr));
  gap:10px 18px
}
.info-item{
  background:var(--panel2);
  border:1px solid var(--border);
  border-radius:10px;
  padding:12px
}
.info-label{font-size:12px;color:var(--muted);margin-bottom:4px}
.info-value{font-size:14px;font-weight:600;word-break:break-word}
table{
  border-collapse:collapse;
  width:100%;
  min-width:760px;
  background:transparent;
  font-size:13px;
  table-layout:fixed;
}
.table-wrap{
  width:100%;
  max-width:100%;
  overflow-x:auto;
  overflow-y:hidden;
  border:1px solid var(--border);
  border-radius:10px;
}
th,td{
  padding:10px 11px;
  border-bottom:1px solid var(--border);
  text-align:left;
  vertical-align:top;
  overflow-wrap:anywhere;
  word-break:break-word;
  white-space:normal
}
th{color:#b8c6da;font-weight:600;background:#111a2a}
tr:hover td{background:#142034}
th:last-child,td:last-child{max-width:520px}
.pill{
  display:inline-block;
  padding:4px 9px;
  border-radius:999px;
  font-size:11px;
  font-weight:700
}
.pill-good{background:rgba(34,197,94,.15);color:#86efac}
.pill-warn{background:rgba(245,158,11,.15);color:#fcd34d}
.pill-bad{background:rgba(239,68,68,.15);color:#fca5a5}
.empty{color:var(--muted);padding:10px 0}
.footer{
  margin:24px 0 4px;
  color:var(--muted);
  font-size:12px;
  text-align:center
}
@media(max-width:900px){
  .two-col{grid-template-columns:1fr}
  .header{flex-direction:column}
}
</style>
"@

    $topMemoryHtml = Convert-ObjectTableToHtml $topMemory
    $topCPUHtml = Convert-ObjectTableToHtml $topCPU
    $providersHtml = Convert-ObjectTableToHtml $eventProviders "No critical/error event providers found."
    $recentEventsHtml = Convert-ObjectTableToHtml $recentEvents "No recent critical/error events found."
    $servicesHtml = Get-ServiceTableHtml

    $firewallText = if ($firewallTotalCount -gt 0) {
        "$firewallEnabledCount / $firewallTotalCount profiles enabled"
    } else {
        "Unavailable"
    }

    $defenderText = if ($null -eq $defenderEnabled) {
        "Unavailable"
    } elseif ($defenderEnabled -and $realtimeEnabled) {
        "Protected"
    } else {
        "Attention required"
    }

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Windows IT Operations Dashboard - $env:COMPUTERNAME</title>
$css
</head>
<body>
<div class="wrapper">

<div class="header">
  <div>
    <h1>Windows IT Operations Dashboard</h1>
    <div class="subtitle">$env:COMPUTERNAME &bull; Generated $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</div>
  </div>
  <div class="badge">Toolkit v5.1</div>
</div>

<div class="grid">
  <div class="card $memoryClass">
    <div class="card-title">Memory Used</div>
    <div class="card-value">$memoryUsed%</div>
    <div class="card-sub">$([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB installed</div>
  </div>

  <div class="card $diskClass">
    <div class="card-title">$env:SystemDrive Free Space</div>
    <div class="card-value">$diskFree%</div>
    <div class="card-sub">$diskFreeGB GB free of $diskTotalGB GB</div>
  </div>

  <div class="card neutral">
    <div class="card-title">Uptime</div>
    <div class="card-value">$($uptime.Days)d $($uptime.Hours)h</div>
    <div class="card-sub">Last boot: $($os.LastBootUpTime)</div>
  </div>

  <div class="card $eventsClass">
    <div class="card-title">Critical / Error Events</div>
    <div class="card-value">$criticalCount</div>
    <div class="card-sub">Last 24 hours</div>
  </div>

  <div class="card $rebootClass">
    <div class="card-title">Pending Reboot</div>
    <div class="card-value">$(if($pendingReboot){"YES"}else{"NO"})</div>
    <div class="card-sub">Windows restart requirement</div>
  </div>

  <div class="card $networkClass">
    <div class="card-title">Network Health</div>
    <div class="card-value">$(if($internetOK -and $dnsOK){"ONLINE"}else{"ISSUE"})</div>
    <div class="card-sub">Internet + DNS check</div>
  </div>

  <div class="card $defenderClass">
    <div class="card-title">Endpoint Security</div>
    <div class="card-value">$defenderText</div>
    <div class="card-sub">Microsoft Defender</div>
  </div>

  <div class="card neutral">
    <div class="card-title">Installed Applications</div>
    <div class="card-value">$softwareCount</div>
    <div class="card-sub">Detected from uninstall registry</div>
  </div>

  <div class="card $(if($batteryData -and $batteryData.Present -and $null -ne $batteryData.HealthPercent){if($batteryData.HealthPercent -ge 80){"good"}elseif($batteryData.HealthPercent -ge 60){"warn"}else{"bad"}}else{"neutral"})">
    <div class="card-title">Battery Health</div>
    <div class="card-value">$(if($batteryData -and $batteryData.Present -and $null -ne $batteryData.HealthPercent){"$($batteryData.HealthPercent)%"}else{"N/A"})</div>
    <div class="card-sub">Full charge capacity vs design capacity</div>
  </div>
</div>

<div class="section">
  <h2>Device Overview</h2>
  <div class="info-grid">
    <div class="info-item"><div class="info-label">Computer Name</div><div class="info-value">$env:COMPUTERNAME</div></div>
    <div class="info-item"><div class="info-label">Manufacturer / Model</div><div class="info-value">$($cs.Manufacturer) $($cs.Model)</div></div>
    <div class="info-item"><div class="info-label">Serial Number</div><div class="info-value">$($bios.SerialNumber)</div></div>
    <div class="info-item"><div class="info-label">Operating System</div><div class="info-value">$($os.Caption) $($os.Version)</div></div>
    <div class="info-item"><div class="info-label">CPU</div><div class="info-value">$($cpu.Name)</div></div>
    <div class="info-item"><div class="info-label">Installed RAM</div><div class="info-value">$([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB</div></div>
    <div class="info-item"><div class="info-label">Battery</div><div class="info-value">$batteryText</div></div>
    <div class="info-item"><div class="info-label">Current User</div><div class="info-value">$env:USERNAME</div></div>
  </div>
</div>

<div class="section">
  <h2>Battery Health</h2>
  <div class="info-grid">
    <div class="info-item"><div class="info-label">Battery</div><div class="info-value">$(if($batteryData -and $batteryData.Present){$batteryData.Name}else{"No battery detected"})</div></div>
    <div class="info-item"><div class="info-label">Design Capacity</div><div class="info-value">$(if($batteryData -and $batteryData.DesignCapacity_mWh){"$($batteryData.DesignCapacity_mWh) mWh"}else{"Unavailable"})</div></div>
    <div class="info-item"><div class="info-label">Full Charge Capacity</div><div class="info-value">$(if($batteryData -and $batteryData.FullChargeCapacity_mWh){"$($batteryData.FullChargeCapacity_mWh) mWh"}else{"Unavailable"})</div></div>
    <div class="info-item"><div class="info-label">Current Remaining Capacity</div><div class="info-value">$(if($batteryData -and $batteryData.RemainingCapacity_mWh){"$($batteryData.RemainingCapacity_mWh) mWh"}else{"Unavailable"})</div></div>
    <div class="info-item"><div class="info-label">Current Charge</div><div class="info-value">$(if($batteryData -and $null -ne $batteryData.ChargePercent){"$($batteryData.ChargePercent)%"}else{"Unavailable"})</div></div>
    <div class="info-item"><div class="info-label">Battery Health</div><div class="info-value">$(if($batteryData -and $null -ne $batteryData.HealthPercent){"$($batteryData.HealthPercent)%"}else{"Unavailable"})</div></div>
    <div class="info-item"><div class="info-label">Battery Wear</div><div class="info-value">$(if($batteryData -and $null -ne $batteryData.WearPercent){"$($batteryData.WearPercent)%"}else{"Unavailable"})</div></div>
    <div class="info-item"><div class="info-label">Cycle Count</div><div class="info-value">$(if($batteryData -and $null -ne $batteryData.CycleCount){$batteryData.CycleCount}else{"Unavailable"})</div></div>
  </div>
</div>

<div class="section">
  <h2>Network</h2>
  <div class="info-grid">
    <div class="info-item"><div class="info-label">Active Adapter</div><div class="info-value">$adapter</div></div>
    <div class="info-item"><div class="info-label">IPv4 Address</div><div class="info-value">$ipv4</div></div>
    <div class="info-item"><div class="info-label">Default Gateway</div><div class="info-value">$gateway</div></div>
    <div class="info-item"><div class="info-label">DNS Servers</div><div class="info-value">$dnsServers</div></div>
    <div class="info-item"><div class="info-label">Internet Test</div><div class="info-value">$(if($internetOK){"PASS"}else{"FAIL"})</div></div>
    <div class="info-item"><div class="info-label">DNS Resolution</div><div class="info-value">$(if($dnsOK){"PASS"}else{"FAIL"})</div></div>
  </div>
</div>

<div class="section">
  <h2>Security Status</h2>
  <div class="info-grid">
    <div class="info-item"><div class="info-label">Defender Antivirus</div><div class="info-value">$(if($null-eq$defenderEnabled){"Unavailable"}elseif($defenderEnabled){"Enabled"}else{"Disabled"})</div></div>
    <div class="info-item"><div class="info-label">Real-Time Protection</div><div class="info-value">$(if($null-eq$realtimeEnabled){"Unavailable"}elseif($realtimeEnabled){"Enabled"}else{"Disabled"})</div></div>
    <div class="info-item"><div class="info-label">Defender Signature</div><div class="info-value">$signatureVersion</div></div>
    <div class="info-item"><div class="info-label">Windows Firewall</div><div class="info-value">$firewallText</div></div>
    <div class="info-item"><div class="info-label">BitLocker</div><div class="info-value">$bitlocker</div></div>
    <div class="info-item"><div class="info-label">Pending Reboot</div><div class="info-value">$(if($pendingReboot){"Yes"}else{"No"})</div></div>
  </div>
</div>

<div class="two-col">
  <div class="section">
    <h2>Top Memory Processes</h2>
    $topMemoryHtml
  </div>
  <div class="section">
    <h2>Top CPU Processes</h2>
    $topCPUHtml
  </div>
</div>

<div class="section">
  <h2>Core Windows Services</h2>
  $servicesHtml
</div>

<div class="two-col">
  <div class="section">
    <h2>Top Error Sources - Last 24 Hours</h2>
    $providersHtml
  </div>
  <div class="section">
    <h2>Recent Critical / Error Events</h2>
    $recentEventsHtml
  </div>
</div>

<div class="footer">
  Local diagnostic dashboard generated by Windows IT Operations Toolkit v5.1.
  Values are captured at generation time and do not update automatically.
</div>

</div>
</body>
</html>
"@

    # UTF-8 avoids the previous "â€¢" encoding issue.
    $html | Set-Content -Path $output -Encoding UTF8

    Write-ToolkitLog -Message "IT dashboard generated: $output" -Level "INFO"
    return $output
}

Export-ModuleMember -Function New-ITDashboard
