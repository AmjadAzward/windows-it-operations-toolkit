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
    "BatteryHealth.psm1",
    "ReportGenerator.psm1",
    "Dashboard.psm1",
    "SmartDiagnosis.psm1",
    "WindowsUpdateTools.psm1",
    "UserAudit.psm1",
    "StartupAudit.psm1",
    "WifiTools.psm1",
    "PortTools.psm1",
    "CrashTools.psm1",
    "SystemExtras.psm1",
    "CaseLogger.psm1",
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
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "        WINDOWS IT OPERATIONS TOOLKIT v5.1.1" -ForegroundColor White
    Write-Host "              ADVANCED TECHNICIAN CONSOLE" -ForegroundColor DarkGray
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host " Computer : $env:COMPUTERNAME"
    Write-Host " User     : $env:USERNAME"
    Write-Host " Admin    : $(if (Test-IsAdministrator) {'YES'} else {'NO'})"
    Write-Host "================================================================" -ForegroundColor Cyan
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

    Write-Host "SMART DIAGNOSTICS" -ForegroundColor Yellow
    Write-Host " 1. Smart Health Diagnosis"
    Write-Host " 2. Run Full Diagnostic"
    Write-Host " 3. Performance / Top Processes"
    Write-Host " 4. Network Diagnostics"
    Write-Host " 5. Wi-Fi Diagnostics"
    Write-Host " 6. Windows Update Diagnostics"
    Write-Host " 7. Crash / BSOD Analyzer"
    Write-Host ""
    Write-Host "SYSTEM & SECURITY" -ForegroundColor Yellow
    Write-Host " 8. Hardware Inventory"
    Write-Host " 9. Software Inventory"
    Write-Host "10. Security Health"
    Write-Host "11. User / Local Admin Audit"
    Write-Host "12. Startup Programs Audit"
    Write-Host "13. Advanced System Checks"
    Write-Host "14. Event Log Analyzer"
    Write-Host "15. Port & Connection Tools"
    Write-Host "16. Battery Health & Report"
    Write-Host ""
    Write-Host "SUPPORT & REMEDIATION" -ForegroundColor Yellow
    Write-Host "17. Printer Support"
    Write-Host "18. Service Monitoring"
    Write-Host "19. Windows Repair Tools"
    Write-Host ""
    Write-Host "ENTERPRISE SUPPORT" -ForegroundColor Yellow
    Write-Host "20. Active Directory Tools"
    Write-Host "21. Microsoft 365 / Graph Tools"
    Write-Host ""
    Write-Host "REPORTING & CASE MANAGEMENT" -ForegroundColor Yellow
    Write-Host "22. Generate HTML Support Report"
    Write-Host "23. Generate IT Dashboard"
    Write-Host "24. Technician Case Log"
    Write-Host "25. Open Reports Folder"
    Write-Host "26. Open Logs Folder"
    Write-Host "27. Open Cases Folder"
    Write-Host " 0. Exit"
    Write-Host ""

    $choice = Read-Host "Select an option"

    switch ($choice) {
        "1"  { Invoke-Safe { Show-Header; Get-SmartDiagnosis } "Smart Diagnosis"; Pause-Toolkit }
        "2"  {
            Invoke-Safe {
                Show-Header
                Write-Host "FULL DIAGNOSTIC" -ForegroundColor Cyan
                Write-Host "==============="
                Get-SystemHealth
                Write-Host ""
                Get-SmartDiagnosis | Out-Null
                Write-Host ""
                Get-ProcessHealth -Top 10
                Write-Host ""
                Get-NetworkDiagnostics
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
            } "Full Diagnostic"
            Pause-Toolkit
        }
        "3"  { Invoke-Safe { Show-Header; Get-ProcessHealth -Top 15 } "Performance Diagnostics"; Pause-Toolkit }
        "4"  { Invoke-Safe { Show-Header; Get-NetworkDiagnostics -Detailed } "Network Diagnostics"; Pause-Toolkit }
        "5"  { Invoke-Safe { Show-Header; Get-WifiDiagnostics } "Wi-Fi Diagnostics"; Pause-Toolkit }
        "6"  { Invoke-Safe { Show-WindowsUpdateMenu } "Windows Update Tools" }
        "7"  { Invoke-Safe { Show-Header; Get-CrashDiagnostics } "Crash Diagnostics"; Pause-Toolkit }
        "8"  { Invoke-Safe { Show-Header; Get-HardwareInventory -Display } "Hardware Inventory"; Pause-Toolkit }
        "9"  { Invoke-Safe { Show-Header; Get-SoftwareInventory -Display } "Software Inventory"; Pause-Toolkit }
        "10" { Invoke-Safe { Show-Header; Get-SecurityHealth -Detailed } "Security Health"; Pause-Toolkit }
        "11" { Invoke-Safe { Show-UserAuditMenu } "User Audit" }
        "12" { Invoke-Safe { Show-Header; Get-StartupAudit } "Startup Audit"; Pause-Toolkit }
        "13" { Invoke-Safe { Show-Header; Get-SystemExtras } "Advanced System Checks"; Pause-Toolkit }
        "14" { Invoke-Safe { Show-Header; Get-RecentCriticalEvents -Hours 24 -MaxEvents 50 } "Event Log Analyzer"; Pause-Toolkit }
        "15" { Invoke-Safe { Show-PortToolsMenu } "Port Tools" }
        "16" { Invoke-Safe { Show-BatteryMenu -ProjectRoot $ProjectRoot } "Battery Tools" }
        "17" { Invoke-Safe { Show-PrinterSupportMenu } "Printer Support" }
        "18" { Invoke-Safe { Show-ServiceToolsMenu } "Service Monitoring" }
        "19" { Invoke-Safe { Show-WindowsRepairMenu } "Windows Repair" }
        "20" { Invoke-Safe { Show-ActiveDirectoryMenu } "Active Directory Tools" }
        "21" { Invoke-Safe { Show-Microsoft365Menu } "Microsoft 365 Tools" }
        "22" {
            Invoke-Safe {
                Show-Header
                $report = New-ITSupportReport -ProjectRoot $ProjectRoot
                Write-Host "Report created:" -ForegroundColor Green
                Write-Host $report
            } "HTML Support Report"
            Pause-Toolkit
        }
        "23" {
            Invoke-Safe {
                Show-Header
                $dash = New-ITDashboard -ProjectRoot $ProjectRoot
                Write-Host "Dashboard created:" -ForegroundColor Green
                Write-Host $dash
                Start-Process $dash
            } "IT Dashboard"
            Pause-Toolkit
        }
        "24" { Invoke-Safe { New-SupportCaseLog -ProjectRoot $ProjectRoot | Out-Null } "Case Log"; Pause-Toolkit }
        "25" { Start-Process explorer.exe (Join-Path $ProjectRoot "reports") }
        "26" { Start-Process explorer.exe (Join-Path $ProjectRoot "logs") }
        "27" {
            $cases = Join-Path $ProjectRoot "cases"
            if (-not (Test-Path $cases)) { New-Item -ItemType Directory -Path $cases | Out-Null }
            Start-Process explorer.exe $cases
        }
        "0" { Write-ToolkitLog "Toolkit closed." "INFO" }
        default { Write-Host "Invalid selection." -ForegroundColor Red; Start-Sleep 1 }
    }

} while ($choice -ne "0")
