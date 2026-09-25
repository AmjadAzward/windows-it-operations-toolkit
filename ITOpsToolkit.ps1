#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $ProjectRoot "modules"

$moduleFiles = @(
    "Common.psm1",
    "SystemHealth.psm1",
    "ProcessHealth.psm1",
    "NetworkTools.psm1",
    "HardwareInventory.psm1",
    "SoftwareInventory.psm1",
    "SecurityHealth.psm1",
    "PrinterTools.psm1",
    "ServiceTools.psm1",
    "WindowsRepair.psm1",
    "EventLogs.psm1",
    "ActiveDirectoryTools.psm1",
    "Microsoft365Tools.psm1",
    "ReportGenerator.psm1",
    "Dashboard.psm1"
)

foreach ($module in $moduleFiles) {
    $modulePath = Join-Path $ModulesPath $module
    if (-not (Test-Path $modulePath)) {
        Write-Host "Missing module: $modulePath" -ForegroundColor Red
        exit 1
    }
    Import-Module $modulePath -Force
}

Initialize-Toolkit -ProjectRoot $ProjectRoot

function Show-Header {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "        WINDOWS IT OPERATIONS TOOLKIT v4.2" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " Computer : $env:COMPUTERNAME"
    Write-Host " User     : $env:USERNAME"
    Write-Host " Admin    : $(if (Test-IsAdministrator) {'YES'} else {'NO'})"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pause-Toolkit {
    Write-Host ""
    Read-Host "Press ENTER to return to the menu"
}

function Invoke-Safe {
    param([scriptblock]$Action,[string]$Name)
    try {
        & $Action
        Write-ToolkitLog "$Name completed." "INFO"
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-ToolkitLog "$Name failed: $($_.Exception.Message)" "ERROR"
    }
}

do {
    Show-Header
    Write-Host "DIAGNOSTICS & SUPPORT" -ForegroundColor Yellow
    Write-Host " 1. Run Optimized Full Diagnostic"
    Write-Host " 2. System Health"
    Write-Host " 3. Top CPU / RAM Processes"
    Write-Host " 4. Network Diagnostics"
    Write-Host " 5. Hardware Inventory"
    Write-Host " 6. Software Inventory"
    Write-Host " 7. Security Health"
    Write-Host " 8. Printer Support"
    Write-Host " 9. Service Monitoring"
    Write-Host "10. Windows Repair Tools"
    Write-Host "11. Event Log Analyzer"
    Write-Host ""
    Write-Host "ENTERPRISE SUPPORT" -ForegroundColor Yellow
    Write-Host "12. Active Directory Tools"
    Write-Host "13. Microsoft 365 / Graph Tools"
    Write-Host ""
    Write-Host "REPORTING & DASHBOARD" -ForegroundColor Yellow
    Write-Host "14. Generate HTML Support Report"
    Write-Host "15. Generate Enhanced IT Dashboard"
    Write-Host "16. Open Reports Folder"
    Write-Host "17. Open Logs Folder"
    Write-Host " 0. Exit"
    Write-Host ""

    $choice = Read-Host "Select an option"

    switch ($choice) {
        "1" {
            Invoke-Safe {
                Show-Header
                Write-Host "OPTIMIZED FULL DIAGNOSTIC" -ForegroundColor Cyan
                Write-Host "========================="
                Get-SystemHealth -Detailed:$false
                Write-Host ""
                Get-ProcessHealth -Top 10
                Write-Host ""
                Get-NetworkDiagnostics -Detailed:$false
                Write-Host ""
                Get-HardwareInventory -SummaryOnly
                Write-Host ""
                Get-SoftwareInventory -Summary
                Write-Host ""
                Get-SecurityHealth
                Write-Host ""
                Get-CriticalServiceStatus
                Write-Host ""
                Get-RecentCriticalEvents -Hours 24 -MaxEvents 15 -Compact
            } "Optimized Full Diagnostic"
            Pause-Toolkit
        }
        "2" { Invoke-Safe { Show-Header; Get-SystemHealth -Detailed } "System Health"; Pause-Toolkit }
        "3" { Invoke-Safe { Show-Header; Get-ProcessHealth -Top 15 } "Process Health"; Pause-Toolkit }
        "4" { Invoke-Safe { Show-Header; Get-NetworkDiagnostics -Detailed } "Network Diagnostics"; Pause-Toolkit }
        "5" { Invoke-Safe { Show-Header; Get-HardwareInventory -Display } "Hardware Inventory"; Pause-Toolkit }
        "6" { Invoke-Safe { Show-Header; Get-SoftwareInventory -Display } "Software Inventory"; Pause-Toolkit }
        "7" { Invoke-Safe { Show-Header; Get-SecurityHealth -Detailed } "Security Health"; Pause-Toolkit }
        "8" { Invoke-Safe { Show-PrinterSupportMenu } "Printer Support" }
        "9" { Invoke-Safe { Show-ServiceToolsMenu } "Service Monitoring" }
        "10" { Invoke-Safe { Show-WindowsRepairMenu } "Windows Repair" }
        "11" { Invoke-Safe { Show-Header; Get-RecentCriticalEvents -Hours 24 -MaxEvents 50 } "Event Log Analyzer"; Pause-Toolkit }
        "12" { Invoke-Safe { Show-ActiveDirectoryMenu } "Active Directory Tools" }
        "13" { Invoke-Safe { Show-Microsoft365Menu } "Microsoft 365 Tools" }
        "14" {
            Invoke-Safe {
                Show-Header
                $report = New-ITSupportReport -ProjectRoot $ProjectRoot
                Write-Host "Report created:" -ForegroundColor Green
                Write-Host $report
            } "HTML Support Report"
            Pause-Toolkit
        }
        "15" {
            Invoke-Safe {
                Show-Header
                $dash = New-ITDashboard -ProjectRoot $ProjectRoot
                Write-Host "Dashboard created:" -ForegroundColor Green
                Write-Host $dash
                Start-Process $dash
            } "Local IT Dashboard"
            Pause-Toolkit
        }
        "16" { Start-Process explorer.exe (Join-Path $ProjectRoot "reports") }
        "17" { Start-Process explorer.exe (Join-Path $ProjectRoot "logs") }
        "0" { Write-ToolkitLog "Toolkit closed." "INFO" }
        default { Write-Host "Invalid selection." -ForegroundColor Red; Start-Sleep 1 }
    }

} while ($choice -ne "0")
