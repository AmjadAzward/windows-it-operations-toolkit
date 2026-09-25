function Get-SmartDiagnosis {
    [CmdletBinding()]
    param()

    $issues = New-Object System.Collections.Generic.List[object]

    $os = Get-CimInstance Win32_OperatingSystem
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"

    $memoryUsed = if ($os.TotalVisibleMemorySize) {
        [math]::Round((1 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize)) * 100, 1)
    } else { 0 }

    $diskFree = if ($drive.Size) {
        [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
    } else { 0 }

    if ($memoryUsed -ge 90) {
        $issues.Add([pscustomobject]@{
            Severity = "FAIL"
            Area = "Memory"
            Finding = "Memory utilization is critically high at $memoryUsed%."
            Recommendation = "Review top RAM-consuming processes and close or investigate unnecessary applications."
        })
    } elseif ($memoryUsed -ge 80) {
        $issues.Add([pscustomobject]@{
            Severity = "WARN"
            Area = "Memory"
            Finding = "Memory utilization is elevated at $memoryUsed%."
            Recommendation = "Review the top memory processes and monitor for sustained high usage."
        })
    }

    if ($diskFree -lt 10) {
        $issues.Add([pscustomobject]@{
            Severity = "FAIL"
            Area = "Storage"
            Finding = "$env:SystemDrive free space is critically low at $diskFree%."
            Recommendation = "Free disk space, review large files, temporary files, logs, and unused applications."
        })
    } elseif ($diskFree -lt 20) {
        $issues.Add([pscustomobject]@{
            Severity = "WARN"
            Area = "Storage"
            Finding = "$env:SystemDrive free space is below 20% at $diskFree%."
            Recommendation = "Plan cleanup before available space becomes critical."
        })
    }

    $pendingReboot =
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")

    if ($pendingReboot) {
        $issues.Add([pscustomobject]@{
            Severity = "WARN"
            Area = "Windows"
            Finding = "A system reboot is pending."
            Recommendation = "Schedule a restart after saving work and confirming business impact."
        })
    }

    $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
    if ($wu -and $wu.Status -ne "Running") {
        $issues.Add([pscustomobject]@{
            Severity = "WARN"
            Area = "Windows Update"
            Finding = "Windows Update service is $($wu.Status)."
            Recommendation = "Check update policy and service state before manually starting it."
        })
    }

    $internetOK = Test-Connection "1.1.1.1" -Count 1 -Quiet -ErrorAction SilentlyContinue
    try {
        Resolve-DnsName "www.microsoft.com" -ErrorAction Stop | Out-Null
        $dnsOK = $true
    } catch {
        $dnsOK = $false
    }

    if (-not $internetOK) {
        $issues.Add([pscustomobject]@{
            Severity = "FAIL"
            Area = "Network"
            Finding = "External IP connectivity test failed."
            Recommendation = "Check the active adapter, gateway, DHCP address, Wi-Fi/Ethernet link, VPN, proxy, and upstream connectivity."
        })
    } elseif (-not $dnsOK) {
        $issues.Add([pscustomobject]@{
            Severity = "FAIL"
            Area = "DNS"
            Finding = "Internet IP connectivity works, but DNS resolution failed."
            Recommendation = "Review configured DNS servers, test alternate DNS, then consider flushing the DNS cache."
        })
    }

    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if (-not $mp.AntivirusEnabled -or -not $mp.RealTimeProtectionEnabled) {
            $issues.Add([pscustomobject]@{
                Severity = "FAIL"
                Area = "Security"
                Finding = "Microsoft Defender antivirus or real-time protection is not fully enabled."
                Recommendation = "Review endpoint protection configuration and organizational security policy."
            })
        }
    } catch {
        $issues.Add([pscustomobject]@{
            Severity = "INFO"
            Area = "Security"
            Finding = "Microsoft Defender status could not be queried."
            Recommendation = "Confirm whether another antivirus product is installed or security cmdlets are unavailable."
        })
    }

    $recentEvents = @(
        Get-WinEvent -FilterHashtable @{
            LogName = @("System","Application")
            Level = 1,2
            StartTime = (Get-Date).AddHours(-24)
        } -ErrorAction SilentlyContinue
    )

    if ($recentEvents.Count -ge 25) {
        $issues.Add([pscustomobject]@{
            Severity = "WARN"
            Area = "Event Logs"
            Finding = "$($recentEvents.Count) critical/error events were detected in the last 24 hours."
            Recommendation = "Review the top event providers and repeated Event IDs for recurring failures."
        })
    }

    if ($issues.Count -eq 0) {
        $health = "HEALTHY"
    } elseif (@($issues | Where-Object Severity -eq "FAIL").Count -gt 0) {
        $health = "CRITICAL"
    } else {
        $health = "WARNING"
    }

    Write-Host "SMART DIAGNOSIS" -ForegroundColor Cyan
    Write-Host "==============="
    Write-Host ""
    $healthColor = switch ($health) {
        "HEALTHY" { "Green" }
        "WARNING" { "Yellow" }
        default { "Red" }
    }
    Write-Host "Overall Device Health: $health" -ForegroundColor $healthColor
    Write-Host ""

    if ($issues.Count -eq 0) {
        Write-StatusLine -Status "PASS" -Label "Automated Findings" -Value "No major issues detected"
        return @()
    }

    foreach ($issue in $issues) {
        Write-StatusLine -Status $issue.Severity -Label $issue.Area -Value $issue.Finding
        Write-Host "       Recommendation: $($issue.Recommendation)" -ForegroundColor DarkGray
        Write-Host ""
    }

    return $issues
}

Export-ModuleMember -Function Get-SmartDiagnosis
