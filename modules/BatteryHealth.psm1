#Requires -Version 5.1

function Get-BatteryReportFallbackData {
    [CmdletBinding()]
    param()

    $result = [PSCustomObject]@{
        DesignCapacity_mWh     = $null
        FullChargeCapacity_mWh = $null
        CycleCount             = $null
    }

    $tempReport = Join-Path $env:TEMP (
        "ITOps_BatteryReport_{0}_{1}.html" -f `
            $env:COMPUTERNAME,
            (Get-Date -Format "yyyyMMddHHmmssfff")
    )

    try {
        & powercfg.exe /batteryreport /output $tempReport | Out-Null

        if (-not (Test-Path $tempReport)) {
            return $result
        }

        $html = Get-Content `
            -LiteralPath $tempReport `
            -Raw `
            -ErrorAction Stop

        #
        # DESIGN CAPACITY
        #
        if (
            $html -match `
            '(?is)DESIGN\s+CAPACITY.*?([\d,]+)\s*mWh'
        ) {
            $value = $matches[1] -replace ",", ""

            $parsedValue = 0

            if ([double]::TryParse($value, [ref]$parsedValue)) {
                $result.DesignCapacity_mWh = $parsedValue
            }
        }

        #
        # FULL CHARGE CAPACITY
        #
        if (
            $html -match `
            '(?is)FULL\s+CHARGE\s+CAPACITY.*?([\d,]+)\s*mWh'
        ) {
            $value = $matches[1] -replace ",", ""

            $parsedValue = 0

            if ([double]::TryParse($value, [ref]$parsedValue)) {
                $result.FullChargeCapacity_mWh = $parsedValue
            }
        }

        #
        # CYCLE COUNT
        #
        if (
            $html -match `
            '(?is)CYCLE\s+COUNT.*?(\d+)'
        ) {
            $parsedCycle = 0

            if ([int]::TryParse($matches[1], [ref]$parsedCycle)) {
                $result.CycleCount = $parsedCycle
            }
        }
    }
    catch {
        # Do not stop the main toolkit if batteryreport parsing fails.
    }
    finally {
        if (Test-Path $tempReport) {
            Remove-Item `
                -LiteralPath $tempReport `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    return $result
}


function Get-BatteryHealthData {
    [CmdletBinding()]
    param()

    $battery = Get-CimInstance `
        -ClassName Win32_Battery `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $battery) {
        return [PSCustomObject]@{
            Present                = $false
            Name                   = "No battery detected"
            Manufacturer           = $null
            Status                 = "N/A"
            DesignCapacity_mWh     = $null
            FullChargeCapacity_mWh = $null
            RemainingCapacity_mWh  = $null
            ChargePercent          = $null
            HealthPercent          = $null
            WearPercent            = $null
            CycleCount             = $null
        }
    }

    $designCapacity     = $null
    $fullChargeCapacity = $null
    $remainingCapacity  = $null
    $cycleCount         = $null

    #
    # DESIGN CAPACITY - WMI
    #
    try {
        $staticData = Get-CimInstance `
            -Namespace "root\wmi" `
            -ClassName "BatteryStaticData" `
            -ErrorAction Stop |
            Select-Object -First 1

        if (
            $staticData -and
            $null -ne $staticData.DesignedCapacity -and
            $staticData.DesignedCapacity -gt 0
        ) {
            $designCapacity = [double]$staticData.DesignedCapacity
        }
    }
    catch {
        $designCapacity = $null
    }

    #
    # FULL CHARGE CAPACITY - WMI
    #
    try {
        $fullData = Get-CimInstance `
            -Namespace "root\wmi" `
            -ClassName "BatteryFullChargedCapacity" `
            -ErrorAction Stop |
            Select-Object -First 1

        if (
            $fullData -and
            $null -ne $fullData.FullChargedCapacity -and
            $fullData.FullChargedCapacity -gt 0
        ) {
            $fullChargeCapacity =
                [double]$fullData.FullChargedCapacity
        }
    }
    catch {
        $fullChargeCapacity = $null
    }

    #
    # CURRENT REMAINING CAPACITY - WMI
    #
    try {
        $statusData = Get-CimInstance `
            -Namespace "root\wmi" `
            -ClassName "BatteryStatus" `
            -ErrorAction Stop |
            Select-Object -First 1

        if (
            $statusData -and
            $null -ne $statusData.RemainingCapacity
        ) {
            $remainingCapacity =
                [double]$statusData.RemainingCapacity
        }
    }
    catch {
        $remainingCapacity = $null
    }

    #
    # CYCLE COUNT - WMI
    #
    try {
        $cycleData = Get-CimInstance `
            -Namespace "root\wmi" `
            -ClassName "BatteryCycleCount" `
            -ErrorAction Stop |
            Select-Object -First 1

        if (
            $cycleData -and
            $null -ne $cycleData.CycleCount
        ) {
            $cycleCount = [int]$cycleData.CycleCount
        }
    }
    catch {
        $cycleCount = $null
    }

    #
    # FALLBACK:
    # Use Windows powercfg battery report if WMI does not
    # provide Design Capacity, Full Charge Capacity, or Cycle Count.
    #
    if (
        $null -eq $designCapacity -or
        $null -eq $fullChargeCapacity -or
        $null -eq $cycleCount
    ) {
        try {
            $fallbackData = Get-BatteryReportFallbackData

            if (
                $null -eq $designCapacity -and
                $null -ne $fallbackData.DesignCapacity_mWh
            ) {
                $designCapacity =
                    [double]$fallbackData.DesignCapacity_mWh
            }

            if (
                $null -eq $fullChargeCapacity -and
                $null -ne $fallbackData.FullChargeCapacity_mWh
            ) {
                $fullChargeCapacity =
                    [double]$fallbackData.FullChargeCapacity_mWh
            }

            if (
                $null -eq $cycleCount -and
                $null -ne $fallbackData.CycleCount
            ) {
                $cycleCount =
                    [int]$fallbackData.CycleCount
            }
        }
        catch {
            # Continue without fallback values.
        }
    }

    #
    # CURRENT CHARGE %
    #
    $chargePercent = $null

    if (
        $null -ne $remainingCapacity -and
        $null -ne $fullChargeCapacity -and
        $fullChargeCapacity -gt 0
    ) {
        $chargePercent = [math]::Round(
            ($remainingCapacity / $fullChargeCapacity) * 100,
            1
        )
    }
    elseif ($null -ne $battery.EstimatedChargeRemaining) {
        $chargePercent =
            [double]$battery.EstimatedChargeRemaining
    }

    #
    # BATTERY HEALTH %
    #
    $healthPercent = $null
    $wearPercent   = $null

    if (
        $null -ne $designCapacity -and
        $null -ne $fullChargeCapacity -and
        $designCapacity -gt 0
    ) {
        $healthPercent = [math]::Round(
            ($fullChargeCapacity / $designCapacity) * 100,
            1
        )

        #
        # Prevent unusual firmware values from creating
        # a negative wear figure.
        #
        if ($healthPercent -gt 100) {
            $wearPercent = 0
        }
        else {
            $wearPercent = [math]::Round(
                100 - $healthPercent,
                1
            )
        }
    }

    #
    # MANUFACTURER
    #
    $manufacturer = $null

    if ($battery.Manufacturer) {
        $manufacturer = $battery.Manufacturer
    }

    return [PSCustomObject]@{
        Present                = $true
        Name                   = $battery.Name
        Manufacturer           = $manufacturer
        Status                 = $battery.Status
        DesignCapacity_mWh     = $designCapacity
        FullChargeCapacity_mWh = $fullChargeCapacity
        RemainingCapacity_mWh  = $remainingCapacity
        ChargePercent          = $chargePercent
        HealthPercent          = $healthPercent
        WearPercent            = $wearPercent
        CycleCount             = $cycleCount
    }
}


function Show-BatteryHealthReport {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host " BATTERY HEALTH REPORT" `
        -ForegroundColor White

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Collecting battery information..." `
        -ForegroundColor DarkGray

    Write-Host ""

    $battery = Get-BatteryHealthData

    if (-not $battery.Present) {
        Write-Host `
            "No battery detected on this computer." `
            -ForegroundColor Yellow

        return
    }

    Write-Host (
        "Battery Name               : {0}" `
        -f $battery.Name
    )

    if ($battery.Manufacturer) {
        Write-Host (
            "Manufacturer             : {0}" `
            -f $battery.Manufacturer
        )
    }

    Write-Host (
        "Battery Status             : {0}" `
        -f $battery.Status
    )

    if ($null -ne $battery.DesignCapacity_mWh) {
        Write-Host (
            "Design Capacity            : {0:N0} mWh" `
            -f $battery.DesignCapacity_mWh
        )
    }
    else {
        Write-Host `
            "Design Capacity            : Unavailable" `
            -ForegroundColor Yellow
    }

    if ($null -ne $battery.FullChargeCapacity_mWh) {
        Write-Host (
            "Full Charge Capacity       : {0:N0} mWh" `
            -f $battery.FullChargeCapacity_mWh
        )
    }
    else {
        Write-Host `
            "Full Charge Capacity       : Unavailable" `
            -ForegroundColor Yellow
    }

    if ($null -ne $battery.RemainingCapacity_mWh) {
        Write-Host (
            "Current Remaining Capacity : {0:N0} mWh" `
            -f $battery.RemainingCapacity_mWh
        )
    }
    else {
        Write-Host `
            "Current Remaining Capacity : Unavailable"
    }

    if ($null -ne $battery.ChargePercent) {

        if ($battery.ChargePercent -ge 40) {
            $chargeColor = "Green"
        }
        elseif ($battery.ChargePercent -ge 20) {
            $chargeColor = "Yellow"
        }
        else {
            $chargeColor = "Red"
        }

        Write-Host (
            "Current Charge             : {0:N1}%" `
            -f $battery.ChargePercent
        ) -ForegroundColor $chargeColor
    }
    else {
        Write-Host `
            "Current Charge             : Unavailable"
    }

    if ($null -ne $battery.HealthPercent) {

        if ($battery.HealthPercent -ge 80) {
            $healthColor = "Green"
            $healthStatus = "GOOD"
        }
        elseif ($battery.HealthPercent -ge 60) {
            $healthColor = "Yellow"
            $healthStatus = "FAIR"
        }
        else {
            $healthColor = "Red"
            $healthStatus = "POOR"
        }

        Write-Host (
            "Battery Health             : {0:N1}% ({1})" `
            -f $battery.HealthPercent,
               $healthStatus
        ) -ForegroundColor $healthColor

        Write-Host (
            "Battery Wear               : {0:N1}%" `
            -f $battery.WearPercent
        )
    }
    else {
        Write-Host `
            "Battery Health             : Unavailable" `
            -ForegroundColor Yellow

        Write-Host `
            "Battery Wear               : Unavailable"
    }

    if ($null -ne $battery.CycleCount) {
        Write-Host (
            "Cycle Count                : {0}" `
            -f $battery.CycleCount
        )
    }
    else {
        Write-Host `
            "Cycle Count                : Unavailable"
    }

    Write-Host ""
    Write-Host "Battery Health Formula:" `
        -ForegroundColor Cyan

    Write-Host `
        "Full Charge Capacity / Design Capacity x 100"

    Write-Host ""
}


function Export-WindowsBatteryReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

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

    $fileName = "{0}_BatteryReport_{1}.html" -f `
        $env:COMPUTERNAME,
        (Get-Date -Format "yyyyMMdd_HHmmss")

    $reportPath = Join-Path `
        $reportsFolder `
        $fileName

    Write-Host ""
    Write-Host `
        "Generating Windows battery report..." `
        -ForegroundColor Cyan

    try {
        & powercfg.exe `
            /batteryreport `
            /output $reportPath |
            Out-Null
    }
    catch {
        Write-Host ""
        Write-Host (
            "Battery report generation failed: {0}" `
            -f $_.Exception.Message
        ) -ForegroundColor Red

        return
    }

    if (Test-Path $reportPath) {
        Write-Host ""
        Write-Host `
            "Battery report created successfully:" `
            -ForegroundColor Green

        Write-Host $reportPath
        Write-Host ""

        $open = Read-Host `
            "Open the report now? [Y/N]"

        if ($open -match "^[Yy]$") {
            Start-Process $reportPath
        }

        return $reportPath
    }
    else {
        Write-Host `
            "Battery report could not be generated." `
            -ForegroundColor Red
    }
}


function Show-BatteryMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    do {
        Clear-Host

        Write-Host `
            "============================================================" `
            -ForegroundColor Cyan

        Write-Host `
            " BATTERY HEALTH & REPORT" `
            -ForegroundColor White

        Write-Host `
            "============================================================" `
            -ForegroundColor Cyan

        Write-Host ""
        Write-Host "1. Battery Health Summary"
        Write-Host "2. Generate Windows Battery Report"
        Write-Host "0. Back"
        Write-Host ""

        $batteryChoice = Read-Host `
            "Select an option"

        switch ($batteryChoice) {

            "1" {
                Show-BatteryHealthReport

                Write-Host ""

                Read-Host `
                    "Press ENTER to continue"
            }

            "2" {
                Export-WindowsBatteryReport `
                    -ProjectRoot $ProjectRoot |
                    Out-Null

                Write-Host ""

                Read-Host `
                    "Press ENTER to continue"
            }

            "0" {
                # Return to main menu.
            }

            default {
                Write-Host `
                    "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 1
            }
        }

    } while ($batteryChoice -ne "0")
}


Export-ModuleMember -Function `
    Get-BatteryReportFallbackData, `
    Get-BatteryHealthData, `
    Show-BatteryHealthReport, `
    Export-WindowsBatteryReport, `
    Show-BatteryMenu