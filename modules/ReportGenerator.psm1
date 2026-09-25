function New-ITSupportReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $output = Join-Path $ProjectRoot ("reports\{0}_ITSupportReport_{1}.html" -f $env:COMPUTERNAME,(Get-Date -Format "yyyyMMdd_HHmmss"))

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

    $pendingReboot =
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")

    # Network
    $network = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4Address -and $_.NetAdapter.Status -eq "Up" } |
        Select-Object -First 1

    $adapter = if ($network) { $network.InterfaceAlias } else { "Not detected" }
    $ipv4 = if ($network) { ($network.IPv4Address | Select-Object -First 1).IPAddress } else { "Not detected" }
    $gateway = if ($network) { ($network.IPv4DefaultGateway | Select-Object -First 1).NextHop } else { "Not detected" }
    $dnsServers = if ($network) { $network.DnsServer.ServerAddresses -join ", " } else { "Not detected" }

    $internetOK = Test-Connection "1.1.1.1" -Count 1 -Quiet -ErrorAction SilentlyContinue
    try {
        Resolve-DnsName "www.microsoft.com" -ErrorAction Stop | Out-Null
        $dnsOK = $true
    } catch { $dnsOK = $false }

    # Security
    $defenderEnabled = $null
    $realtimeEnabled = $null
    $signatureVersion = "Unavailable"
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $defenderEnabled = $mp.AntivirusEnabled
        $realtimeEnabled = $mp.RealTimeProtectionEnabled
        $signatureVersion = $mp.AntivirusSignatureVersion
    } catch {}

    $firewallText = "Unavailable"
    try {
        $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
        $enabled = @($profiles | Where-Object { $_.Enabled }).Count
        $firewallText = "$enabled / $($profiles.Count) profiles enabled"
    } catch {}

    $bitlocker = "Unavailable"
    try {
        $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        $bitlocker = [string]$bl.ProtectionStatus
    } catch {}

    # Services
    $services = foreach ($name in @("wuauserv","BITS","Spooler","WinDefend","EventLog","Dhcp","Dnscache")) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc) {
            [PSCustomObject]@{
                Service = $svc.DisplayName
                Name = $svc.Name
                Status = [string]$svc.Status
                StartType = [string]$svc.StartType
            }
        }
    }

    # Processes
    $topMemory = Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 12 Name, Id,
            @{N="RAM_MB";E={[math]::Round($_.WorkingSet64/1MB,1)}},
            @{N="CPU_Seconds";E={if($_.CPU){[math]::Round($_.CPU,1)}else{0}}}

    $topCPU = Get-Process -ErrorAction SilentlyContinue |
        Sort-Object CPU -Descending |
        Select-Object -First 12 Name, Id,
            @{N="CPU_Seconds";E={if($_.CPU){[math]::Round($_.CPU,1)}else{0}}},
            @{N="RAM_MB";E={[math]::Round($_.WorkingSet64/1MB,1)}}

    # Events
    $events = @(
        Get-WinEvent -FilterHashtable @{
            LogName = @("System","Application")
            Level = 1,2
            StartTime = (Get-Date).AddHours(-24)
        } -ErrorAction SilentlyContinue
    )

    $eventProviders = $events |
        Group-Object ProviderName |
        Sort-Object Count -Descending |
        Select-Object -First 10 @{N="Provider";E={$_.Name}}, Count

    $recentEvents = $events |
        Select-Object -First 20 TimeCreated, LogName, Id, LevelDisplayName, ProviderName,
        @{N="Message";E={
            $m = $_.Message -replace "`r|`n"," "
            if ($m.Length -gt 220) { $m.Substring(0,220) + "..." } else { $m }
        }}

    $software = @(Get-InstalledSoftware | Select-Object -First 250)

    function HealthClass {
        param([string]$Type,[double]$Value)
        switch($Type) {
            "Memory" {
                if($Value -lt 80){"good"}elseif($Value -lt 90){"warn"}else{"bad"}
            }
            "Disk" {
                if($Value -ge 20){"good"}elseif($Value -ge 10){"warn"}else{"bad"}
            }
            "Events" {
                if($Value -lt 10){"good"}elseif($Value -lt 25){"warn"}else{"bad"}
            }
            default {"neutral"}
        }
    }

    function TableHtml {
        param($Data,[string]$Empty="No data available.")
        if(-not $Data -or @($Data).Count -eq 0) {
            return "<div class='empty'>$Empty</div>"
        }
        $tbl = ($Data | ConvertTo-Html -Fragment) -join "`n"
        return "<div class='table-wrap'>$tbl</div>"
    }

    $memClass = HealthClass "Memory" $memoryUsed
    $diskClass = HealthClass "Disk" $diskFree
    $eventClass = HealthClass "Events" $events.Count
    $netClass = if($internetOK -and $dnsOK){"good"}else{"bad"}
    $secClass = if($defenderEnabled -and $realtimeEnabled){"good"}else{"warn"}
    $rebootClass = if($pendingReboot){"warn"}else{"good"}

    $servicesHtml = TableHtml $services
    $memHtml = TableHtml $topMemory
    $cpuHtml = TableHtml $topCPU
    $providersHtml = TableHtml $eventProviders "No critical/error providers found."
    $eventsHtml = TableHtml $recentEvents "No recent critical/error events found."
    $softwareHtml = TableHtml $software

    $css = @"
<style>
:root{
 --bg:#f3f6fb;--panel:#ffffff;--text:#1f2937;--muted:#64748b;--border:#dbe3ee;
 --good:#16a34a;--warn:#d97706;--bad:#dc2626;--blue:#2563eb;
}
*{box-sizing:border-box}
body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:var(--bg);color:var(--text)}
.page{max-width:1450px;margin:0 auto;padding:30px}
.hero{
 background:linear-gradient(135deg,#0f172a,#1e3a8a);
 color:white;padding:28px;border-radius:16px;margin-bottom:20px
}
.hero h1{margin:0 0 7px;font-size:28px}.hero p{margin:0;color:#dbeafe}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px}
.card{background:white;border:1px solid var(--border);border-radius:13px;padding:17px;box-shadow:0 5px 18px rgba(15,23,42,.06)}
.card.good{border-top:4px solid var(--good)}.card.warn{border-top:4px solid var(--warn)}
.card.bad{border-top:4px solid var(--bad)}.card.neutral{border-top:4px solid var(--blue)}
.k{font-size:12px;color:var(--muted);margin-bottom:7px}.v{font-size:27px;font-weight:700}.s{font-size:12px;color:var(--muted);margin-top:6px}
.section{background:white;border:1px solid var(--border);border-radius:13px;padding:20px;margin-top:18px;overflow:hidden;min-width:0}
.section h2{margin:0 0 15px;font-size:18px}
.info{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px}
.info>div{background:#f8fafc;border:1px solid var(--border);border-radius:9px;padding:11px}
.label{font-size:11px;color:var(--muted);margin-bottom:3px}.value{font-weight:600;overflow-wrap:anywhere}
.two{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.table-wrap{max-width:100%;overflow-x:auto;border:1px solid var(--border);border-radius:9px}
table{border-collapse:collapse;width:100%;min-width:760px;table-layout:fixed;font-size:12px}
th,td{padding:9px;border-bottom:1px solid var(--border);text-align:left;vertical-align:top;overflow-wrap:anywhere;word-break:break-word;white-space:normal}
th{background:#eef3f9;color:#334155}
.empty{color:var(--muted);padding:12px}
.footer{font-size:11px;color:var(--muted);text-align:center;margin:24px}
@media(max-width:900px){.two{grid-template-columns:1fr}.page{padding:14px}}
@media print{
 body{background:white}.page{max-width:none;padding:0}.hero{border-radius:0}
 .section,.card{box-shadow:none;break-inside:avoid}.table-wrap{overflow:visible}
 table{min-width:0;font-size:9px}.footer{margin-top:10px}
}
</style>
"@

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>IT Support Report - $env:COMPUTERNAME</title>
$css
</head>
<body>
<div class="page">

<div class="hero">
  <h1>Windows IT Support & Health Report</h1>
  <p>$env:COMPUTERNAME &bull; Generated $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") &bull; Toolkit v4.2</p>
</div>

<div class="grid">
  <div class="card $memClass"><div class="k">Memory Used</div><div class="v">$memoryUsed%</div><div class="s">$([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB installed</div></div>
  <div class="card $diskClass"><div class="k">$env:SystemDrive Free</div><div class="v">$diskFree%</div><div class="s">$([math]::Round($drive.FreeSpace/1GB,1)) GB available</div></div>
  <div class="card neutral"><div class="k">Uptime</div><div class="v">$($uptime.Days)d $($uptime.Hours)h</div><div class="s">Last boot $($os.LastBootUpTime)</div></div>
  <div class="card $eventClass"><div class="k">Critical / Error Events</div><div class="v">$($events.Count)</div><div class="s">Last 24 hours</div></div>
  <div class="card $netClass"><div class="k">Network</div><div class="v">$(if($internetOK -and $dnsOK){"Healthy"}else{"Issue"})</div><div class="s">Internet and DNS test</div></div>
  <div class="card $secClass"><div class="k">Endpoint Security</div><div class="v">$(if($defenderEnabled -and $realtimeEnabled){"Protected"}else{"Check"})</div><div class="s">Defender real-time status</div></div>
  <div class="card $rebootClass"><div class="k">Pending Reboot</div><div class="v">$(if($pendingReboot){"YES"}else{"NO"})</div><div class="s">Windows restart requirement</div></div>
</div>

<div class="section">
<h2>Executive Summary</h2>
<div class="info">
  <div><div class="label">Device</div><div class="value">$($cs.Manufacturer) $($cs.Model)</div></div>
  <div><div class="label">Serial Number</div><div class="value">$($bios.SerialNumber)</div></div>
  <div><div class="label">Operating System</div><div class="value">$($os.Caption) $($os.Version)</div></div>
  <div><div class="label">CPU</div><div class="value">$($cpu.Name)</div></div>
  <div><div class="label">Current User</div><div class="value">$env:USERNAME</div></div>
  <div><div class="label">Installed RAM</div><div class="value">$([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB</div></div>
</div>
</div>

<div class="section">
<h2>Network Summary</h2>
<div class="info">
  <div><div class="label">Active Adapter</div><div class="value">$adapter</div></div>
  <div><div class="label">IPv4 Address</div><div class="value">$ipv4</div></div>
  <div><div class="label">Default Gateway</div><div class="value">$gateway</div></div>
  <div><div class="label">DNS Servers</div><div class="value">$dnsServers</div></div>
  <div><div class="label">Internet Test</div><div class="value">$(if($internetOK){"PASS"}else{"FAIL"})</div></div>
  <div><div class="label">DNS Resolution</div><div class="value">$(if($dnsOK){"PASS"}else{"FAIL"})</div></div>
</div>
</div>

<div class="section">
<h2>Security Summary</h2>
<div class="info">
  <div><div class="label">Defender Antivirus</div><div class="value">$(if($null-eq$defenderEnabled){"Unavailable"}elseif($defenderEnabled){"Enabled"}else{"Disabled"})</div></div>
  <div><div class="label">Real-Time Protection</div><div class="value">$(if($null-eq$realtimeEnabled){"Unavailable"}elseif($realtimeEnabled){"Enabled"}else{"Disabled"})</div></div>
  <div><div class="label">Signature Version</div><div class="value">$signatureVersion</div></div>
  <div><div class="label">Windows Firewall</div><div class="value">$firewallText</div></div>
  <div><div class="label">BitLocker</div><div class="value">$bitlocker</div></div>
  <div><div class="label">Pending Reboot</div><div class="value">$(if($pendingReboot){"Yes"}else{"No"})</div></div>
</div>
</div>

<div class="two">
  <div class="section"><h2>Top Memory Processes</h2>$memHtml</div>
  <div class="section"><h2>Top CPU Processes</h2>$cpuHtml</div>
</div>

<div class="section"><h2>Core Windows Services</h2>$servicesHtml</div>

<div class="two">
  <div class="section"><h2>Top Error Sources - Last 24 Hours</h2>$providersHtml</div>
  <div class="section"><h2>Recent Critical / Error Events</h2>$eventsHtml</div>
</div>

<div class="section"><h2>Installed Software</h2>$softwareHtml</div>

<div class="footer">
Generated locally by Windows IT Operations Toolkit v4.2. This is a point-in-time diagnostic snapshot.
</div>

</div>
</body>
</html>
"@

    $html | Set-Content -Path $output -Encoding UTF8
    Write-ToolkitLog -Message "Enhanced HTML report generated: $output" -Level "INFO"
    return $output
}

Export-ModuleMember -Function New-ITSupportReport
