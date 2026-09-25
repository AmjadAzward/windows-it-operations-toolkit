function Get-SystemHealth {
    param([switch]$Detailed)
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $uptime = (Get-Date) - $os.LastBootUpTime
    $freePct = if($drive.Size){[math]::Round(($drive.FreeSpace/$drive.Size)*100,1)}else{0}
    $total = [math]::Round($os.TotalVisibleMemorySize/1MB,2)
    $free = [math]::Round($os.FreePhysicalMemory/1MB,2)
    $usedPct = if($total){[math]::Round((($total-$free)/$total)*100,1)}else{0}

    Write-Host "SYSTEM HEALTH" -ForegroundColor Cyan
    Write-StatusLine INFO "Computer" $env:COMPUTERNAME
    Write-StatusLine INFO "Windows" "$($os.Caption) $($os.Version)"
    Write-StatusLine INFO "CPU" $cpu.Name
    Write-StatusLine INFO "Uptime" ("{0}d {1}h {2}m" -f $uptime.Days,$uptime.Hours,$uptime.Minutes)
    Write-StatusLine ($(if($freePct-ge20){"PASS"}elseif($freePct-ge10){"WARN"}else{"FAIL"})) "$env:SystemDrive Free Space" "$freePct%"
    Write-StatusLine ($(if($usedPct-lt80){"PASS"}elseif($usedPct-lt90){"WARN"}else{"FAIL"})) "Memory Usage" "$usedPct%"

    $pending = (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
               (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")
    Write-StatusLine ($(if($pending){"WARN"}else{"PASS"})) "Pending Reboot" $(if($pending){"YES"}else{"NO"})

    if($Detailed){
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select DeviceID,@{N="SizeGB";E={[math]::Round($_.Size/1GB,2)}},
        @{N="FreeGB";E={[math]::Round($_.FreeSpace/1GB,2)}},
        @{N="FreePercent";E={if($_.Size){[math]::Round(($_.FreeSpace/$_.Size)*100,1)}else{0}}} |
        Format-Table -AutoSize
    }
}
Export-ModuleMember -Function *
