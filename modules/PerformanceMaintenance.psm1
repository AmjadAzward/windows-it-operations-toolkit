#Requires -Version 5.1


function Get-FolderSizeMB {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return 0
    }

    try {

        $size = (
            Get-ChildItem `
                -LiteralPath $Path `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue |
            Where-Object {
                -not $_.PSIsContainer
            } |
            Measure-Object `
                -Property Length `
                -Sum
        ).Sum

        if ($null -eq $size) {
            return 0
        }

        return [math]::Round(
            $size / 1MB,
            2
        )
    }
    catch {
        return 0
    }
}


function Remove-SafeFolderContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return [PSCustomObject]@{
            Path      = $Path
            BeforeMB  = 0
            AfterMB   = 0
            FreedMB   = 0
            Status    = "Not Found"
        }
    }

    $before = Get-FolderSizeMB -Path $Path

    try {

        Get-ChildItem `
            -LiteralPath $Path `
            -Force `
            -ErrorAction SilentlyContinue |
        Remove-Item `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        $after = Get-FolderSizeMB -Path $Path

        $freed = [math]::Round(
            $before - $after,
            2
        )

        if ($freed -lt 0) {
            $freed = 0
        }

        return [PSCustomObject]@{
            Path      = $Path
            BeforeMB  = $before
            AfterMB   = $after
            FreedMB   = $freed
            Status    = "Completed"
        }
    }
    catch {

        return [PSCustomObject]@{
            Path      = $Path
            BeforeMB  = $before
            AfterMB   = $before
            FreedMB   = 0
            Status    = "Partial / Access Denied"
        }
    }
}


function Clear-UserTempFiles {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " CLEAR USER TEMPORARY FILES"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    $tempPath = $env:TEMP

    Write-Host "Target:"
    Write-Host $tempPath
    Write-Host ""

    $before = Get-FolderSizeMB -Path $tempPath

    Write-Host (
        "Current temporary file size : {0:N2} MB" `
        -f $before
    )

    Write-Host ""

    $confirm = Read-Host "Clear user temporary files? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    $result = Remove-SafeFolderContents `
        -Path $tempPath

    Write-Host ""

    Write-Host (
        "Space recovered : {0:N2} MB" `
        -f $result.FreedMB
    ) -ForegroundColor Green

    Write-Host (
        "Status          : {0}" `
        -f $result.Status
    )
}


function Clear-WindowsTempFiles {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " CLEAR WINDOWS TEMPORARY FILES"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    $path = Join-Path `
        $env:WINDIR `
        "Temp"

    Write-Host "Target:"
    Write-Host $path
    Write-Host ""

    $before = Get-FolderSizeMB `
        -Path $path

    Write-Host (
        "Current Windows temp size : {0:N2} MB" `
        -f $before
    )

    Write-Host ""

    $confirm = Read-Host "Clear Windows temporary files? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    $result = Remove-SafeFolderContents `
        -Path $path

    Write-Host ""

    Write-Host (
        "Space recovered : {0:N2} MB" `
        -f $result.FreedMB
    ) -ForegroundColor Green

    Write-Host (
        "Status          : {0}" `
        -f $result.Status
    )
}


function Clear-DNSCache {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " CLEAR DNS CACHE"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    try {

        ipconfig /flushdns

        Write-Host ""
        Write-Host "DNS resolver cache cleared." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "Unable to clear DNS cache." `
            -ForegroundColor Red
    }
}


function Clear-WindowsUpdateCache {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " WINDOWS UPDATE DOWNLOAD CACHE"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "This removes downloaded Windows Update cache files."
    Write-Host "It does not uninstall installed updates."
    Write-Host ""

    $confirm = Read-Host "Continue? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    $downloadPath = Join-Path `
        $env:WINDIR `
        "SoftwareDistribution\Download"

    $before = Get-FolderSizeMB `
        -Path $downloadPath

    try {

        Stop-Service `
            -Name wuauserv `
            -Force `
            -ErrorAction SilentlyContinue

        Stop-Service `
            -Name bits `
            -Force `
            -ErrorAction SilentlyContinue

        $result = Remove-SafeFolderContents `
            -Path $downloadPath

        Start-Service `
            -Name bits `
            -ErrorAction SilentlyContinue

        Start-Service `
            -Name wuauserv `
            -ErrorAction SilentlyContinue

        Write-Host ""

        Write-Host (
            "Update cache before : {0:N2} MB" `
            -f $before
        )

        Write-Host (
            "Space recovered     : {0:N2} MB" `
            -f $result.FreedMB
        ) -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "Windows Update cache cleanup failed." `
            -ForegroundColor Red
    }
}


function Clear-RecycleBinSafe {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " EMPTY RECYCLE BIN"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Items in the Recycle Bin will be permanently removed."
    Write-Host ""

    $confirm = Read-Host "Empty Recycle Bin? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    try {

        Clear-RecycleBin `
            -Force `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Recycle Bin emptied." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "Unable to empty Recycle Bin." `
            -ForegroundColor Yellow

        Write-Host $_.Exception.Message
    }
}


function Clear-BrowserCaches {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " CLEAR BROWSER TEMPORARY CACHE"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "This cleans temporary browser cache only."
    Write-Host "Saved passwords, bookmarks, history and profiles are not targeted."
    Write-Host ""

    $confirm = Read-Host "Continue? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    $targets = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
    )

    $totalFreed = 0

    foreach ($target in $targets) {

        if (Test-Path $target) {

            $result = Remove-SafeFolderContents `
                -Path $target

            $totalFreed += $result.FreedMB

            Write-Host (
                "{0} : {1:N2} MB recovered" `
                -f $target, $result.FreedMB
            )
        }
    }

    Write-Host ""

    Write-Host (
        "Total recovered : {0:N2} MB" `
        -f $totalFreed
    ) -ForegroundColor Green
}


function Get-DiskSpaceHealth {
    [CmdletBinding()]
    param()

    $drives = Get-CimInstance `
        Win32_LogicalDisk `
        -Filter "DriveType=3" `
        -ErrorAction SilentlyContinue

    foreach ($drive in $drives) {

        $totalGB = [math]::Round(
            $drive.Size / 1GB,
            2
        )

        $freeGB = [math]::Round(
            $drive.FreeSpace / 1GB,
            2
        )

        $usedGB = [math]::Round(
            $totalGB - $freeGB,
            2
        )

        $freePercent = 0

        if ($drive.Size -gt 0) {

            $freePercent = [math]::Round(
                ($drive.FreeSpace / $drive.Size) * 100,
                1
            )
        }

        $status = "Healthy"

        if ($freePercent -lt 10) {
            $status = "Critical"
        }
        elseif ($freePercent -lt 20) {
            $status = "Low"
        }

        [PSCustomObject]@{
            Drive       = $drive.DeviceID
            TotalGB     = $totalGB
            UsedGB      = $usedGB
            FreeGB      = $freeGB
            FreePercent = $freePercent
            Status      = $status
        }
    }
}


function Show-DiskSpaceHealth {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " DISK SPACE HEALTH"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Get-DiskSpaceHealth |
        Format-Table `
            Drive,
            TotalGB,
            UsedGB,
            FreeGB,
            FreePercent,
            Status `
            -AutoSize
}


function Find-LargeFiles {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " LARGE FILE ANALYZER"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    $scanPath = Read-Host "Enter folder to scan"

    if (-not (Test-Path $scanPath)) {

        Write-Host ""
        Write-Host "Folder not found." `
            -ForegroundColor Red

        return
    }

    Write-Host ""
    Write-Host "Scanning..."
    Write-Host ""

    Get-ChildItem `
        -LiteralPath $scanPath `
        -File `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object `
        -First 20 `
        @{Name="SizeGB"; Expression={
            [math]::Round(
                $_.Length / 1GB,
                2
            )
        }},
        FullName |
    Format-Table -AutoSize
}


function Start-DriveOptimization {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " OPTIMIZE DRIVES"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Windows will choose the correct optimization method."
    Write-Host "SSDs normally receive TRIM; HDDs can be defragmented."
    Write-Host ""

    $confirm = Read-Host "Optimize system drive now? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    try {

        Optimize-Volume `
            -DriveLetter $env:SystemDrive.TrimEnd(":") `
            -Verbose `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Drive optimization completed." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "Unable to optimize drive." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


function Start-SystemFileCheck {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " SYSTEM FILE CHECKER"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "This scans protected Windows system files."
    Write-Host ""

    $confirm = Read-Host "Run SFC /scannow? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    sfc.exe /scannow
}


function Start-DISMHealthCheck {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " DISM WINDOWS IMAGE HEALTH CHECK"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    DISM.exe /Online /Cleanup-Image /ScanHealth
}


function Clear-EventArchiveFiles {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " EVENT LOG ARCHIVE CLEANUP"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "This removes archived .evtx files only."
    Write-Host "Active Windows Event Logs are not cleared."
    Write-Host ""

    $confirm = Read-Host "Continue? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    $logPath = "$env:WINDIR\System32\winevt\Logs"

    $files = Get-ChildItem `
        -Path $logPath `
        -Filter "Archive-*.evtx" `
        -ErrorAction SilentlyContinue

    if (-not $files) {

        Write-Host ""
        Write-Host "No archived event log files found." `
            -ForegroundColor Yellow

        return
    }

    $bytes = (
        $files |
        Measure-Object Length -Sum
    ).Sum

    $files |
        Remove-Item `
            -Force `
            -ErrorAction SilentlyContinue

    $freedMB = [math]::Round(
        $bytes / 1MB,
        2
    )

    Write-Host ""

    Write-Host (
        "Recovered : {0:N2} MB" `
        -f $freedMB
    ) -ForegroundColor Green
}


function Reset-MicrosoftStoreCache {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " MICROSOFT STORE CACHE RESET"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    try {

        Start-Process `
            -FilePath "wsreset.exe"

        Write-Host ""
        Write-Host "Microsoft Store cache reset started." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "Unable to start Store cache reset." `
            -ForegroundColor Red
    }
}


function Get-PerformanceHealthSummary {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " PERFORMANCE HEALTH SUMMARY"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    $os = Get-CimInstance `
        Win32_OperatingSystem `
        -ErrorAction SilentlyContinue

    $cpu = Get-CimInstance `
        Win32_Processor `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($os) {

        $totalRAM = [math]::Round(
            $os.TotalVisibleMemorySize / 1MB,
            2
        )

        $freeRAM = [math]::Round(
            $os.FreePhysicalMemory / 1MB,
            2
        )

        $usedRAM = [math]::Round(
            $totalRAM - $freeRAM,
            2
        )

        $memoryPercent = 0

        if ($totalRAM -gt 0) {

            $memoryPercent = [math]::Round(
                ($usedRAM / $totalRAM) * 100,
                1
            )
        }

        Write-Host (
            "Memory Usage       : {0}%" `
            -f $memoryPercent
        )

        Write-Host (
            "Used RAM           : {0:N2} GB" `
            -f $usedRAM
        )

        Write-Host (
            "Available RAM      : {0:N2} GB" `
            -f $freeRAM
        )
    }

    if ($cpu) {

        Write-Host (
            "CPU Load           : {0}%" `
            -f $cpu.LoadPercentage
        )
    }

    Write-Host ""
    Write-Host "Disk Space:" -ForegroundColor Cyan

    Get-DiskSpaceHealth |
        Format-Table `
            Drive,
            FreeGB,
            FreePercent,
            Status `
            -AutoSize

    Write-Host ""
    Write-Host "Highest Memory Processes:" -ForegroundColor Cyan

    Get-Process `
        -ErrorAction SilentlyContinue |
    Sort-Object WorkingSet64 -Descending |
    Select-Object `
        -First 10 `
        Name,
        Id,
        @{Name="MemoryMB"; Expression={
            [math]::Round(
                $_.WorkingSet64 / 1MB,
                2
            )
        }} |
    Format-Table -AutoSize
}


function Invoke-SafeMaintenance {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " SAFE PC MAINTENANCE"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "This maintenance routine will:"
    Write-Host ""
    Write-Host " - Clear user temporary files"
    Write-Host " - Clear Windows temporary files"
    Write-Host " - Flush DNS cache"
    Write-Host " - Reset Microsoft Store cache"
    Write-Host " - Optimize the Windows system drive"
    Write-Host ""
    Write-Host "It will NOT remove documents or installed applications."
    Write-Host ""

    $confirm = Read-Host "Run safe maintenance? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    Write-Host ""
    Write-Host "Cleaning user temporary files..."

    $userResult = Remove-SafeFolderContents `
        -Path $env:TEMP

    Write-Host (
        "Recovered {0:N2} MB" `
        -f $userResult.FreedMB
    )

    Write-Host ""
    Write-Host "Cleaning Windows temporary files..."

    $windowsTemp = Join-Path `
        $env:WINDIR `
        "Temp"

    $windowsResult = Remove-SafeFolderContents `
        -Path $windowsTemp

    Write-Host (
        "Recovered {0:N2} MB" `
        -f $windowsResult.FreedMB
    )

    Write-Host ""
    Write-Host "Flushing DNS cache..."

    ipconfig /flushdns | Out-Null

    Write-Host "DNS cache cleared."

    Write-Host ""
    Write-Host "Starting Microsoft Store cache reset..."

    try {
        Start-Process wsreset.exe
    }
    catch {}

    Write-Host ""
    Write-Host "Optimizing system drive..."

    try {

        Optimize-Volume `
            -DriveLetter $env:SystemDrive.TrimEnd(":") `
            -ErrorAction SilentlyContinue
    }
    catch {}

    $totalRecovered = [math]::Round(
        $userResult.FreedMB +
        $windowsResult.FreedMB,
        2
    )

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Green

    Write-Host " MAINTENANCE COMPLETED" `
        -ForegroundColor Green

    Write-Host "============================================================" `
        -ForegroundColor Green

    Write-Host ""

    Write-Host (
        "Temporary space recovered : {0:N2} MB" `
        -f $totalRecovered
    )

    Write-Host ""
}


function Show-PerformanceMaintenanceMenu {
    [CmdletBinding()]
    param()

    do {

        Clear-Host

        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " PC PERFORMANCE & MAINTENANCE"
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "1.  Clear User Temporary Files"
        Write-Host "2.  Clear Windows Temporary Files"
        Write-Host "3.  Clear DNS Cache"
        Write-Host "4.  Clear Windows Update Download Cache"
        Write-Host "5.  Empty Recycle Bin"
        Write-Host "6.  Clear Browser Temporary Cache"
        Write-Host "7.  Check Disk Space"
        Write-Host "8.  Analyze Large Files"
        Write-Host "9.  Startup Program Audit"
        Write-Host "10. Optimize Drives"
        Write-Host "11. Run System File Check"
        Write-Host "12. Run DISM Health Check"
        Write-Host "13. Clear Event Log Archive Files"
        Write-Host "14. Reset Microsoft Store Cache"
        Write-Host "15. Performance Health Summary"
        Write-Host "16. Run Safe Maintenance"
        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select an option"

        switch ($choice) {

            "1" {
                Clear-UserTempFiles
                Read-Host "Press ENTER to continue"
            }

            "2" {
                Clear-WindowsTempFiles
                Read-Host "Press ENTER to continue"
            }

            "3" {
                Clear-DNSCache
                Read-Host "Press ENTER to continue"
            }

            "4" {
                Clear-WindowsUpdateCache
                Read-Host "Press ENTER to continue"
            }

            "5" {
                Clear-RecycleBinSafe
                Read-Host "Press ENTER to continue"
            }

            "6" {
                Clear-BrowserCaches
                Read-Host "Press ENTER to continue"
            }

            "7" {
                Show-DiskSpaceHealth
                Read-Host "Press ENTER to continue"
            }

            "8" {
                Find-LargeFiles
                Read-Host "Press ENTER to continue"
            }

            "9" {

                if (Get-Command Show-StartupAudit -ErrorAction SilentlyContinue) {

                    Show-StartupAudit
                }
                else {

                    Write-Host ""
                    Write-Host "StartupAudit module is not loaded." `
                        -ForegroundColor Yellow
                }

                Read-Host "Press ENTER to continue"
            }

            "10" {
                Start-DriveOptimization
                Read-Host "Press ENTER to continue"
            }

            "11" {
                Start-SystemFileCheck
                Read-Host "Press ENTER to continue"
            }

            "12" {
                Start-DISMHealthCheck
                Read-Host "Press ENTER to continue"
            }

            "13" {
                Clear-EventArchiveFiles
                Read-Host "Press ENTER to continue"
            }

            "14" {
                Reset-MicrosoftStoreCache
                Read-Host "Press ENTER to continue"
            }

            "15" {
                Get-PerformanceHealthSummary
                Read-Host "Press ENTER to continue"
            }

            "16" {
                Invoke-SafeMaintenance
                Read-Host "Press ENTER to continue"
            }

            "0" {}

            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 1
            }
        }

    } while ($choice -ne "0")
}


Export-ModuleMember -Function `
    Get-FolderSizeMB, `
    Remove-SafeFolderContents, `
    Clear-UserTempFiles, `
    Clear-WindowsTempFiles, `
    Clear-DNSCache, `
    Clear-WindowsUpdateCache, `
    Clear-RecycleBinSafe, `
    Clear-BrowserCaches, `
    Get-DiskSpaceHealth, `
    Show-DiskSpaceHealth, `
    Find-LargeFiles, `
    Start-DriveOptimization, `
    Start-SystemFileCheck, `
    Start-DISMHealthCheck, `
    Clear-EventArchiveFiles, `
    Reset-MicrosoftStoreCache, `
    Get-PerformanceHealthSummary, `
    Invoke-SafeMaintenance, `
    Show-PerformanceMaintenanceMenu