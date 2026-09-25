function Get-BatteryHealthData {
    [CmdletBinding()]
    param()

    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $battery) {
        return [PSCustomObject]@{
            Present                 = $false
            Name                    = "No battery detected"
            Manufacturer            = $null
            Chemistry               = $null
            DesignCapacity_mWh      = $null
            FullChargeCapacity_mWh  = $null
            RemainingCapacity_mWh   = $null
            ChargePercent           = $null
            HealthPercent           = $null
            WearPercent             = $null
            CycleCount              = $null
            Status                  = $null
        }
    }

    $designCapacity = $null
    $fullChargeCapacity = $null
    $remainingCapacity = $null
    $cycleCount = $null

    try {
        $static = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop |
            Select-Object -First 1

        if ($static) {
            $designCapacity = [double]$static.DesignedCapacity
        }
    } catch {}

    try {
        $full = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop |
            Select-Object -First 1

        if ($full) {
            $fullChargeCapacity = [double]$full.FullChargedCapacity
        }
    } catch {}

    try {
        $status = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction Stop |
            Where-Object { $_.PowerOnline -ne $null } |
            Select-Object -First 1

        if ($status) {
            $remainingCapacity = [double]$status.RemainingCapacity
        }
    } catch {}

    # Some systems expose cycle count through BatteryCycleCount.
    try {
        $cycle = Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount -ErrorAction Stop |
            Select-Object -First 1

        if ($cycle -and $null -ne $cycle.CycleCount) {
            $cycleCount = [int]$cycle.CycleCount
        }
    } catch {}

    $chargePercent = $null
    if ($fullChargeCapacity -and $remainingCapacity -and $fullChargeCapacity -gt 0) {
        $chargePercent = [math]::Round(($remainingCapacity / $fullChargeCapacity) * 100, 1)
    } elseif ($null -ne $battery.EstimatedChargeRemaining) {
        $chargePercent = [double]$battery.EstimatedChargeRemaining
    }

    $healthPercent = $null
    $wearPercent = $null

    if ($designCapacity -and $fullChargeCapacity -and $designCapacity -gt 0) {
        $healthPercent = [math]::Round(($fullChargeCapacity / $designCapacity) * 100, 1)
        $wearPercent = [math]::Round(100 - $healthPercent, 1)
    }

    [PSCustomObject]@{
        Present                 = $true
        Name                    = $battery.Name
        Manufacturer            = $battery.Manufacturer
        Chemistry               = $battery.Chemistry
        DesignCapacity_mWh      = if ($designCapacity) {[math]::Round($designCapacity,0)} else {$null}
        FullChargeCapacity_mWh  = if ($fullChargeCapacity) {[math]::Round($fullChargeCapacity,0)} else {$null}
        RemainingCapacity_mWh   = if ($remainingCapacity) {[math]::Round($remainingCapacity,0)} else {$null}
        ChargePercent           = $chargePercent
        HealthPercent           = $healthPercent
        WearPercent             = $wearPercent
        CycleCount              = $cycleCount
        Status                  = $battery.Status
    }
}

function Show-BatteryHealthReport {
    [CmdletBinding()]
    param()

    Clear-Host
    Write-Host "BATTERY HEALTH REPORT" -ForegroundColor Cyan
    Write-Host "====================="

    $data = Get-BatteryHealthData

    if (-not $data.Present) {
        Write-StatusLine -Status "INFO" -Label "Battery" -Value "No battery detected"
        return
    }

    Write-StatusLine -Status "INFO" -Label "Battery Name" -Value "$($data.Name)"

    if ($data.DesignCapacity_mWh) {
        Write-StatusLine -Status "INFO" -Label "Design Capacity" -Value "$($data.DesignCapacity_mWh) mWh"
    } else {
        Write-StatusLine -Status "WARN" -Label "Design Capacity" -Value "Unavailable"
    }

    if ($data.FullChargeCapacity_mWh) {
        Write-StatusLine -Status "INFO" -Label "Full Charge Capacity" -Value "$($data.FullChargeCapacity_mWh) mWh"
    } else {
        Write-StatusLine -Status "WARN" -Label "Full Charge Capacity" -Value "Unavailable"
    }

    if ($data.RemainingCapacity_mWh) {
        Write-StatusLine -Status "INFO" -Label "Current Remaining Capacity" -Value "$($data.RemainingCapacity_mWh) mWh"
    } else {
        Write-StatusLine -Status "WARN" -Label "Current Remaining Capacity" -Value "Unavailable"
    }

    if ($null -ne $data.ChargePercent) {
        $chargeState = if ($data.ChargePercent -ge 40) {"PASS"} elseif ($data.ChargePercent -ge 20) {"WARN"} else {"FAIL"}
        Write-StatusLine -Status $chargeState -Label "Current Charge" -Value "$($data.ChargePercent)%"
    }

    if ($null -ne $data.HealthPercent) {
        $healthState = if ($data.HealthPercent -ge 80) {"PASS"} elseif ($data.HealthPercent -ge 60) {"WARN"} else {"FAIL"}
        Write-StatusLine -Status $healthState -Label "Battery Health" -Value "$($data.HealthPercent)%"
        Write-StatusLine -Status "INFO" -Label "Battery Wear" -Value "$($data.WearPercent)%"
    } else {
        Write-StatusLine -Status "WARN" -Label "Battery Health" -Value "Unavailable"
    }

    if ($null -ne $data.CycleCount) {
        Write-StatusLine -Status "INFO" -Label "Cycle Count" -Value "$($data.CycleCount)"
    } else {
        Write-StatusLine -Status "INFO" -Label "Cycle Count" -Value "Unavailable on this device"
    }

    Write-Host ""
    Write-Host "Battery Health Formula:" -ForegroundColor White
    Write-Host "Full Charge Capacity / Design Capacity x 100" -ForegroundColor DarkGray

    return $data
}

function Export-WindowsBatteryReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    $reports = Join-Path $ProjectRoot "reports"
    if (-not (Test-Path $reports)) {
        New-Item -ItemType Directory -Path $reports | Out-Null
    }

    $output = Join-Path $reports ("{0}_WindowsBatteryReport_{1}.html" -f $env:COMPUTERNAME,(Get-Date -Format "yyyyMMdd_HHmmss"))

    try {
        & powercfg.exe /batteryreport /output $output | Out-Null

        if (Test-Path $output) {
            Write-Host "Windows battery report created:" -ForegroundColor Green
            Write-Host $output
            Write-ToolkitLog "Windows battery report generated: $output" "INFO"
            return $output
        }

        throw "Battery report was not generated."
    } catch {
        Write-Host "Unable to generate Windows battery report: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-BatteryMenu {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    do {
        Clear-Host
        Write-Host "BATTERY TOOLS" -ForegroundColor Cyan
        Write-Host "============="
        Write-Host "1. Battery Health Summary"
        Write-Host "2. Generate Native Windows Battery Report"
        Write-Host "0. Back"

        $choice = Read-Host "Select"

        switch ($choice) {
            "1" {
                Show-BatteryHealthReport | Out-Null
                Read-Host "Press ENTER"
            }
            "2" {
                Export-WindowsBatteryReport -ProjectRoot $ProjectRoot | Out-Null
                Read-Host "Press ENTER"
            }
        }
    } while ($choice -ne "0")
}

Export-ModuleMember -Function *
