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
    "PerformanceMaintenance.psm1",
    "PeripheralDiagnostics.psm1"
)

Write-Host ""
Write-Host "Loading toolkit modules..." -ForegroundColor DarkGray

foreach ($module in $moduleFiles) {

    $modulePath = Join-Path $ModulesPath $module

    if (-not (Test-Path $modulePath)) {

        Write-Host ""
        Write-Host "Missing module:" -ForegroundColor Red
        Write-Host $modulePath -ForegroundColor Red
        Write-Host ""

        Read-Host "Press ENTER to exit"

        exit 1
    }

    try {

        Import-Module `
            -Name $modulePath `
            -Force `
            -Global `
            -ErrorAction Stop
    }
    catch {

        Write-Host ""
        Write-Host "Failed to load module:" -ForegroundColor Red
        Write-Host $module -ForegroundColor Yellow
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        Read-Host "Press ENTER to exit"

        exit 1
    }
}


#
# Explicit Battery Module Verification
#
$batteryModulePath = Join-Path `
    $ModulesPath `
    "BatteryHealth.psm1"

try {

    Import-Module `
        -Name $batteryModulePath `
        -Force `
        -Global `
        -ErrorAction Stop

    $batteryCommand = Get-Command `
        -Name "Show-BatteryMenu" `
        -CommandType Function `
        -ErrorAction SilentlyContinue

    if (-not $batteryCommand) {

        throw "Show-BatteryMenu function was not exported by BatteryHealth.psm1"
    }
}
catch {

    Write-Host ""
    Write-Host "Battery module failed to load." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""

    if (Test-Path $batteryModulePath) {

        Write-Host "Battery module path:" `
            -ForegroundColor Yellow

        Write-Host $batteryModulePath
    }

    Write-Host ""
    Read-Host "Press ENTER to exit"

    exit 1
}


#
# Verify Peripheral Diagnostics Module
#
$peripheralModulePath = Join-Path `
    $ModulesPath `
    "PeripheralDiagnostics.psm1"

try {

    $peripheralCommand = Get-Command `
        -Name "Show-PeripheralDiagnosticsMenu" `
        -CommandType Function `
        -ErrorAction SilentlyContinue

    if (-not $peripheralCommand) {

        Import-Module `
            -Name $peripheralModulePath `
            -Force `
            -Global `
            -ErrorAction Stop

        $peripheralCommand = Get-Command `
            -Name "Show-PeripheralDiagnosticsMenu" `
            -CommandType Function `
            -ErrorAction SilentlyContinue
    }

    if (-not $peripheralCommand) {

        throw "Show-PeripheralDiagnosticsMenu was not exported by PeripheralDiagnostics.psm1"
    }
}
catch {

    Write-Host ""
    Write-Host "Peripheral Diagnostics module failed to load." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""
    Read-Host "Press ENTER to exit"

    exit 1
}


#
# Initialize Toolkit
#
try {

    Initialize-Toolkit `
        -ProjectRoot $ProjectRoot
}
catch {

    Write-Host ""
    Write-Host "Toolkit initialization failed." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""
    Read-Host "Press ENTER to exit"

    exit 1
}


function Show-Header {

    Clear-Host

    Write-Host "================================================================" `
        -ForegroundColor Cyan

    Write-Host "        WINDOWS IT OPERATIONS TOOLKIT v5.2" `
        -ForegroundColor White

    Write-Host "              ADVANCED TECHNICIAN CONSOLE" `
        -ForegroundColor DarkGray

    Write-Host "================================================================" `
        -ForegroundColor Cyan

    Write-Host " Computer : $env:COMPUTERNAME"
    Write-Host " User     : $env:USERNAME"

    if (Test-IsAdministrator) {

        Write-Host " Admin    : YES" `
            -ForegroundColor Green
    }
    else {

        Write-Host " Admin    : NO" `
            -ForegroundColor Yellow
    }

    Write-Host "================================================================" `
        -ForegroundColor Cyan

    Write-Host ""
}


function Pause-Toolkit {

    Write-Host ""

    Read-Host "Press ENTER to return to the menu"
}


function Invoke-Safe {

    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {

        & $Action

        try {

            Write-ToolkitLog `
                "$Name completed." `
                "INFO"
        }
        catch {

            # Logging failure should not stop toolkit.
        }
    }
    catch {

        Write-Host ""
        Write-Host "ERROR: $($_.Exception.Message)" `
            -ForegroundColor Red

        Write-Host ""

        try {

            Write-ToolkitLog `
                "$Name failed: $($_.Exception.Message)" `
                "ERROR"
        }
        catch {

            # Ignore secondary logging errors.
        }
    }
}


do {

    Show-Header


    Write-Host "SMART DIAGNOSTICS" `
        -ForegroundColor Yellow

    Write-Host " 1. Smart Health Diagnosis"
    Write-Host " 2. Run Full Diagnostic"
    Write-Host " 3. Performance / Top Processes"
    Write-Host " 4. Network Diagnostics"
    Write-Host " 5. Wi-Fi Diagnostics"
    Write-Host " 6. Windows Update Diagnostics"
    Write-Host " 7. Crash / BSOD Analyzer"

    Write-Host ""


    Write-Host "SYSTEM & SECURITY" `
        -ForegroundColor Yellow

    Write-Host " 8. Hardware Inventory"
    Write-Host " 9. Software Inventory"
    Write-Host "10. Security Health"
    Write-Host "11. User / Local Admin Audit"
    Write-Host "12. Startup Programs Audit"
    Write-Host "13. Advanced System Checks"
    Write-Host "14. Event Log Analyzer"
    Write-Host "15. Port & Connection Tools"
    Write-Host "16. Battery Health & Report"
    Write-Host "17. Hardware & Peripheral Tests"

    Write-Host ""


    Write-Host "SUPPORT & REMEDIATION" `
        -ForegroundColor Yellow

    Write-Host "18. Printer Support"
    Write-Host "19. Service Monitoring"
    Write-Host "20. Windows Repair Tools"
    Write-Host "21. PC Performance & Maintenance"

    Write-Host ""


    Write-Host "ENTERPRISE SUPPORT" `
        -ForegroundColor Yellow

    Write-Host "22. Active Directory Tools"
    Write-Host "23. Microsoft 365 / Graph Tools"

    Write-Host ""


    Write-Host "REPORTING & CASE MANAGEMENT" `
        -ForegroundColor Yellow

    Write-Host "24. Generate HTML Support Report"
    Write-Host "25. Generate IT Dashboard"
    Write-Host "26. Technician Case Management"
    Write-Host "27. Open Reports Folder"
    Write-Host "28. Open Logs Folder"
    Write-Host "29. Open Cases Folder"

    Write-Host ""
    Write-Host " 0. Exit"
    Write-Host ""

    $choice = Read-Host "Select an option"


    switch ($choice) {


        "1" {

            Invoke-Safe {

                Show-Header

                Get-SmartDiagnosis

            } "Smart Diagnosis"

            Pause-Toolkit
        }


        "2" {

            Invoke-Safe {

                Show-Header

                Write-Host "FULL DIAGNOSTIC" `
                    -ForegroundColor Cyan

                Write-Host "==============="
                Write-Host ""

                Get-SystemHealth

                Write-Host ""

                Get-SmartDiagnosis |
                    Out-Null

                Write-Host ""

                Get-ProcessHealth `
                    -Top 10

                Write-Host ""

                Get-NetworkDiagnostics

                Write-Host ""

                Get-HardwareInventory `
                    -SummaryOnly

                Write-Host ""

                Get-SoftwareInventory `
                    -Summary

                Write-Host ""

                Get-SecurityHealth

                Write-Host ""

                Get-CriticalServiceStatus

                Write-Host ""

                Get-RecentCriticalEvents `
                    -Hours 24 `
                    -MaxEvents 15 `
                    -Compact

            } "Full Diagnostic"

            Pause-Toolkit
        }


        "3" {

            Invoke-Safe {

                Show-Header

                Get-ProcessHealth `
                    -Top 15

            } "Performance Diagnostics"

            Pause-Toolkit
        }


        "4" {

            Invoke-Safe {

                Show-Header

                Get-NetworkDiagnostics `
                    -Detailed

            } "Network Diagnostics"

            Pause-Toolkit
        }


        "5" {

            Invoke-Safe {

                Show-Header

                Get-WifiDiagnostics

            } "Wi-Fi Diagnostics"

            Pause-Toolkit
        }


        "6" {

            Invoke-Safe {

                Show-WindowsUpdateMenu

            } "Windows Update Tools"
        }


        "7" {

            Invoke-Safe {

                Show-Header

                Get-CrashDiagnostics

            } "Crash Diagnostics"

            Pause-Toolkit
        }


        "8" {

            Invoke-Safe {

                Show-Header

                Get-HardwareInventory `
                    -Display

            } "Hardware Inventory"

            Pause-Toolkit
        }


        "9" {

            Invoke-Safe {

                Show-Header

                Get-SoftwareInventory `
                    -Display

            } "Software Inventory"

            Pause-Toolkit
        }


        "10" {

            Invoke-Safe {

                Show-Header

                Get-SecurityHealth `
                    -Detailed

            } "Security Health"

            Pause-Toolkit
        }


        "11" {

            Invoke-Safe {

                Show-UserAuditMenu

            } "User Audit"
        }


        "12" {

            Invoke-Safe {

                Show-StartupAuditMenu

            } "Startup Audit"
        }


        "13" {

            Invoke-Safe {

                Show-Header

                Get-SystemExtras

            } "Advanced System Checks"

            Pause-Toolkit
        }


        "14" {

            Invoke-Safe {

                Show-Header

                Get-RecentCriticalEvents `
                    -Hours 24 `
                    -MaxEvents 50

            } "Event Log Analyzer"

            Pause-Toolkit
        }


        "15" {

            Invoke-Safe {

                Show-PortToolsMenu

            } "Port Tools"
        }


        "16" {

            Invoke-Safe {

                $batteryFunction = Get-Command `
                    -Name "Show-BatteryMenu" `
                    -CommandType Function `
                    -ErrorAction SilentlyContinue

                if (-not $batteryFunction) {

                    Import-Module `
                        -Name $batteryModulePath `
                        -Force `
                        -Global `
                        -ErrorAction Stop

                    $batteryFunction = Get-Command `
                        -Name "Show-BatteryMenu" `
                        -CommandType Function `
                        -ErrorAction SilentlyContinue
                }

                if (-not $batteryFunction) {

                    throw "Battery Health module is loaded but Show-BatteryMenu is unavailable."
                }

                Show-BatteryMenu `
                    -ProjectRoot $ProjectRoot

            } "Battery Health"
        }


        "17" {

            Invoke-Safe {

                $peripheralFunction = Get-Command `
                    -Name "Show-PeripheralDiagnosticsMenu" `
                    -CommandType Function `
                    -ErrorAction SilentlyContinue

                if (-not $peripheralFunction) {

                    Import-Module `
                        -Name $peripheralModulePath `
                        -Force `
                        -Global `
                        -ErrorAction Stop

                    $peripheralFunction = Get-Command `
                        -Name "Show-PeripheralDiagnosticsMenu" `
                        -CommandType Function `
                        -ErrorAction SilentlyContinue
                }

                if (-not $peripheralFunction) {

                    throw "Peripheral Diagnostics module loaded but Show-PeripheralDiagnosticsMenu is unavailable."
                }

                Show-PeripheralDiagnosticsMenu

            } "Hardware & Peripheral Tests"
        }


        "18" {

            Invoke-Safe {

                Show-PrinterSupportMenu

            } "Printer Support"
        }


        "19" {

            Invoke-Safe {

                Show-ServiceToolsMenu

            } "Service Monitoring"
        }


        "20" {

            Invoke-Safe {

                Show-WindowsRepairMenu

            } "Windows Repair"
        }


        "21" {

            Invoke-Safe {

                Show-PerformanceMaintenanceMenu

            } "PC Performance & Maintenance"
        }


        "22" {

            Invoke-Safe {

                Show-ActiveDirectoryMenu

            } "Active Directory Tools"
        }


        "23" {

            Invoke-Safe {

                Show-Microsoft365Menu

            } "Microsoft 365 Tools"
        }


        "24" {

            Invoke-Safe {

                Show-Header

                $report = New-ITSupportReport `
                    -ProjectRoot $ProjectRoot

                Write-Host ""
                Write-Host "Report created:" `
                    -ForegroundColor Green

                Write-Host $report

            } "HTML Support Report"

            Pause-Toolkit
        }


        "25" {

            Invoke-Safe {

                Show-Header

                $dash = New-ITDashboard `
                    -ProjectRoot $ProjectRoot

                Write-Host ""
                Write-Host "Dashboard created:" `
                    -ForegroundColor Green

                Write-Host $dash

                if (Test-Path $dash) {

                    Start-Process $dash
                }

            } "IT Dashboard"

            Pause-Toolkit
        }


        "26" {

            Invoke-Safe {

                Show-SupportCaseMenu `
                    -ProjectRoot $ProjectRoot

            } "Case Management"
        }


        "27" {

            $reportsFolder = Join-Path `
                $ProjectRoot `
                "reports"

            if (-not (Test-Path $reportsFolder)) {

                New-Item `
                    -Path $reportsFolder `
                    -ItemType Directory `
                    -Force |
                Out-Null
            }

            Start-Process `
                explorer.exe `
                $reportsFolder
        }


        "28" {

            $logsFolder = Join-Path `
                $ProjectRoot `
                "logs"

            if (-not (Test-Path $logsFolder)) {

                New-Item `
                    -Path $logsFolder `
                    -ItemType Directory `
                    -Force |
                Out-Null
            }

            Start-Process `
                explorer.exe `
                $logsFolder
        }


        "29" {

            $casesFolder = Join-Path `
                $ProjectRoot `
                "cases"

            if (-not (Test-Path $casesFolder)) {

                New-Item `
                    -Path $casesFolder `
                    -ItemType Directory `
                    -Force |
                Out-Null
            }

            Start-Process `
                explorer.exe `
                $casesFolder
        }


        "0" {

            try {

                Write-ToolkitLog `
                    "Toolkit closed." `
                    "INFO"
            }
            catch {

                # Ignore logging errors during shutdown.
            }

            Write-Host ""
            Write-Host "Toolkit closed." `
                -ForegroundColor Cyan
        }


        default {

            Write-Host ""
            Write-Host "Invalid selection." `
                -ForegroundColor Red

            Start-Sleep `
                -Seconds 1
        }
    }

} while ($choice -ne "0")