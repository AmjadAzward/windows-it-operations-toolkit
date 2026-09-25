#Requires -Version 5.1


function Convert-RAMSerialNumber {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$SerialNumber
    )

    if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
        return "Unavailable"
    }

    $clean = $SerialNumber.Trim()

    $invalidValues = @(
        "00000000",
        "0000000000000000",
        "FFFFFFFF",
        "FFFFFFFFFFFFFFFF",
        "Unknown",
        "UNKNOWN",
        "N/A",
        "NA",
        "None",
        "Not Specified",
        "To Be Filled By O.E.M.",
        "To Be Filled By OEM"
    )

    if ($invalidValues -contains $clean) {
        return "Unavailable"
    }

    if ($clean -match "^[0]+$") {
        return "Unavailable"
    }

    if ($clean -match "^[F]+$") {
        return "Unavailable"
    }

    return $clean
}


function Convert-DiskSerialNumber {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$SerialNumber
    )

    if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
        return "Unavailable"
    }

    $clean = $SerialNumber.Trim()
    $clean = $clean.TrimEnd(".", ",", ";")

    if ([string]::IsNullOrWhiteSpace($clean)) {
        return "Unavailable"
    }

    return $clean
}


function Get-MemoryDiagnosticResult {
    [CmdletBinding()]
    param()

    try {

        $events = Get-WinEvent `
            -FilterHashtable @{
                LogName      = "System"
                ProviderName = "Microsoft-Windows-MemoryDiagnostics-Results"
            } `
            -MaxEvents 5 `
            -ErrorAction Stop

        if (-not $events) {
            throw "No result found."
        }

        $event = $events |
            Sort-Object TimeCreated -Descending |
            Select-Object -First 1

        $status = "RESULT AVAILABLE"

        if (
            $event.Message -match "no errors" -or
            $event.Message -match "no memory errors" -or
            $event.Message -match "detected no errors"
        ) {
            $status = "PASSED"
        }
        elseif (
            $event.Message -match "hardware problems" -or
            $event.Message -match "memory errors" -or
            $event.Message -match "detected errors"
        ) {
            $status = "FAILED"
        }

        return [PSCustomObject]@{
            Status      = $status
            TimeCreated = $event.TimeCreated
            EventID     = $event.Id
            Message     = $event.Message
        }
    }
    catch {

        return [PSCustomObject]@{
            Status      = "NOT TESTED"
            TimeCreated = $null
            EventID     = $null
            Message     = "No recent Windows Memory Diagnostic result found."
        }
    }
}


function Start-WindowsMemoryDiagnostic {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " WINDOWS MEMORY DIAGNOSTIC" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Windows Memory Diagnostic performs the RAM test during reboot." `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Before continuing:" -ForegroundColor Cyan
    Write-Host " - Save all open work"
    Write-Host " - Close important applications"
    Write-Host " - The computer may need to restart"
    Write-Host ""

    $confirm = Read-Host "Open Windows Memory Diagnostic now? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        Write-Host ""
        Write-Host "Memory diagnostic cancelled." -ForegroundColor Yellow
        return
    }

    try {

        Start-Process `
            -FilePath "mdsched.exe" `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Windows Memory Diagnostic opened." -ForegroundColor Green
        Write-Host ""
        Write-Host "Choose one of the Windows options:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Restart now and check for problems"
        Write-Host "  Check for problems the next time I start my computer"
        Write-Host ""
        Write-Host "After the test and reboot, return to this toolkit and use:"
        Write-Host ""
        Write-Host "  Hardware Inventory > RAM Health Test > Check Last Result"
        Write-Host ""
    }
    catch {

        Write-Host ""
        Write-Host "Unable to start Windows Memory Diagnostic." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Show-MemoryDiagnosticResult {
    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " RAM HEALTH TEST RESULT" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    $result = Get-MemoryDiagnosticResult

    if ($result.Status -eq "PASSED") {

        Write-Host "Memory Diagnostic : PASSED" `
            -ForegroundColor Green
    }
    elseif ($result.Status -eq "FAILED") {

        Write-Host "Memory Diagnostic : FAILED" `
            -ForegroundColor Red
    }
    elseif ($result.Status -eq "NOT TESTED") {

        Write-Host "Memory Diagnostic : NOT TESTED" `
            -ForegroundColor Yellow
    }
    else {

        Write-Host (
            "Memory Diagnostic : {0}" `
            -f $result.Status
        ) -ForegroundColor Yellow
    }

    if ($result.TimeCreated) {

        Write-Host (
            "Last Test         : {0}" `
            -f $result.TimeCreated
        )
    }

    if ($result.EventID) {

        Write-Host (
            "Event ID          : {0}" `
            -f $result.EventID
        )
    }

    Write-Host ""
    Write-Host "Result:" -ForegroundColor Cyan
    Write-Host $result.Message
    Write-Host ""
}


function Show-RAMHealthMenu {
    [CmdletBinding()]
    param()

    do {

        Clear-Host

        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " RAM HEALTH TEST" -ForegroundColor White
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Check Last Memory Test Result"
        Write-Host "2. Start Windows Memory Diagnostic"
        Write-Host "3. View RAM Module Information"
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select an option"

        switch ($choice) {

            "1" {

                Show-MemoryDiagnosticResult

                Read-Host "Press ENTER to continue"
            }

            "2" {

                Start-WindowsMemoryDiagnostic

                Read-Host "Press ENTER to continue"
            }

            "3" {

                Clear-Host
                Show-RAMInventory

                Read-Host "Press ENTER to continue"
            }

            "0" {
                # Return
            }

            default {

                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 1
            }
        }

    } while ($choice -ne "0")
}


function Get-RAMInventory {
    [CmdletBinding()]
    param()

    $memoryDiagnostic = Get-MemoryDiagnosticResult

    $ramModules = Get-CimInstance `
        -ClassName Win32_PhysicalMemory `
        -ErrorAction SilentlyContinue

    $results = foreach ($module in $ramModules) {

        $partNumber = "Unavailable"

        if (-not [string]::IsNullOrWhiteSpace($module.PartNumber)) {
            $partNumber = $module.PartNumber.Trim()
        }

        $serialNumber = Convert-RAMSerialNumber `
            -SerialNumber $module.SerialNumber

        $manufacturer = "Unavailable"

        if (-not [string]::IsNullOrWhiteSpace($module.Manufacturer)) {
            $manufacturer = $module.Manufacturer.Trim()
        }

        $bank = $module.BankLabel

        if ([string]::IsNullOrWhiteSpace($bank)) {
            $bank = "Unknown"
        }

        $slot = $module.DeviceLocator

        if ([string]::IsNullOrWhiteSpace($slot)) {
            $slot = "Unknown"
        }

        $moduleStatus = "Detected"

        if (
            $module.Status -and
            $module.Status -ne "OK"
        ) {
            $moduleStatus = $module.Status
        }
        elseif ($memoryDiagnostic.Status -eq "FAILED") {
            $moduleStatus = "Check Required"
        }
        elseif ($memoryDiagnostic.Status -eq "PASSED") {
            $moduleStatus = "Detected / Memory Test Passed"
        }
        elseif ($memoryDiagnostic.Status -eq "NOT TESTED") {
            $moduleStatus = "Detected / Not Tested"
        }

        [PSCustomObject]@{
            Bank             = $bank
            Slot             = $slot
            Manufacturer     = $manufacturer
            PartNumber       = $partNumber
            SerialNumber     = $serialNumber

            CapacityGB       = [math]::Round(
                $module.Capacity / 1GB,
                2
            )

            SpeedMHz         = $module.Speed
            ConfiguredMHz    = $module.ConfiguredClockSpeed
            FormFactor       = $module.FormFactor
            SMBIOSMemoryType = $module.SMBIOSMemoryType
            Status           = $moduleStatus
        }
    }

    return $results
}


function Get-RAMSummary {
    [CmdletBinding()]
    param()

    $ramModules = Get-CimInstance `
        -ClassName Win32_PhysicalMemory `
        -ErrorAction SilentlyContinue

    $os = Get-CimInstance `
        -ClassName Win32_OperatingSystem `
        -ErrorAction SilentlyContinue

    $installedBytes = 0

    foreach ($module in $ramModules) {

        if ($module.Capacity) {
            $installedBytes += [double]$module.Capacity
        }
    }

    $installedGB = 0

    if ($installedBytes -gt 0) {

        $installedGB = [math]::Round(
            $installedBytes / 1GB,
            2
        )
    }

    $usableGB = 0

    if (
        $os -and
        $os.TotalVisibleMemorySize
    ) {

        $usableGB = [math]::Round(
            ($os.TotalVisibleMemorySize * 1KB) / 1GB,
            2
        )
    }

    $reservedGB = 0

    if (
        $installedGB -gt 0 -and
        $usableGB -gt 0
    ) {

        $reservedGB = [math]::Round(
            $installedGB - $usableGB,
            2
        )

        if ($reservedGB -lt 0) {
            $reservedGB = 0
        }
    }

    $diagnostic = Get-MemoryDiagnosticResult

    return [PSCustomObject]@{
        InstalledRAMGB     = $installedGB
        UsableRAMGB        = $usableGB
        HardwareReservedGB = $reservedGB
        ModuleCount        = @($ramModules).Count
        DiagnosticStatus   = $diagnostic.Status
        DiagnosticTime     = $diagnostic.TimeCreated
        DiagnosticMessage  = $diagnostic.Message
    }
}


function Get-StorageHealth {
    [CmdletBinding()]
    param()

    $physicalDisks = Get-PhysicalDisk `
        -ErrorAction SilentlyContinue

    $results = foreach ($disk in $physicalDisks) {

        $reliability = $null

        try {

            $reliability = $disk |
                Get-StorageReliabilityCounter `
                    -ErrorAction Stop
        }
        catch {

            $reliability = $null
        }

        $temperature = $null
        $wear = $null
        $powerOnHours = $null
        $readErrors = $null
        $writeErrors = $null

        if ($reliability) {

            if ($null -ne $reliability.Temperature) {
                $temperature = $reliability.Temperature
            }

            if ($null -ne $reliability.Wear) {
                $wear = $reliability.Wear
            }

            if ($null -ne $reliability.PowerOnHours) {
                $powerOnHours = $reliability.PowerOnHours
            }

            if ($null -ne $reliability.ReadErrorsTotal) {
                $readErrors = $reliability.ReadErrorsTotal
            }

            if ($null -ne $reliability.WriteErrorsTotal) {
                $writeErrors = $reliability.WriteErrorsTotal
            }
        }

        [PSCustomObject]@{
            FriendlyName = $disk.FriendlyName

            SerialNumber = Convert-DiskSerialNumber `
                -SerialNumber $disk.SerialNumber

            MediaType = $disk.MediaType
            BusType   = $disk.BusType

            SizeGB = [math]::Round(
                $disk.Size / 1GB,
                2
            )

            HealthStatus = $disk.HealthStatus

            OperationalStatus = (
                $disk.OperationalStatus -join ", "
            )

            TemperatureC     = $temperature
            WearPercent      = $wear
            PowerOnHours     = $powerOnHours
            ReadErrorsTotal  = $readErrors
            WriteErrorsTotal = $writeErrors
        }
    }

    return $results
}


function Convert-DiskSerialNumber {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$SerialNumber
    )

    if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
        return "Unavailable"
    }

    $clean = $SerialNumber.Trim()
    $clean = $clean.TrimEnd(".", ",", ";")

    if ([string]::IsNullOrWhiteSpace($clean)) {
        return "Unavailable"
    }

    return $clean
}


function Get-CPUInventory {
    [CmdletBinding()]
    param()

    $cpus = Get-CimInstance `
        -ClassName Win32_Processor `
        -ErrorAction SilentlyContinue

    foreach ($cpu in $cpus) {

        [PSCustomObject]@{
            Name            = $cpu.Name
            Manufacturer    = $cpu.Manufacturer
            Cores           = $cpu.NumberOfCores
            LogicalCPUs     = $cpu.NumberOfLogicalProcessors
            MaxClockMHz     = $cpu.MaxClockSpeed
            CurrentClockMHz = $cpu.CurrentClockSpeed
            Socket          = $cpu.SocketDesignation
            ProcessorID     = $cpu.ProcessorId
        }
    }
}


function Get-SystemInventory {
    [CmdletBinding()]
    param()

    $system = Get-CimInstance `
        -ClassName Win32_ComputerSystem `
        -ErrorAction SilentlyContinue

    $bios = Get-CimInstance `
        -ClassName Win32_BIOS `
        -ErrorAction SilentlyContinue

    $os = Get-CimInstance `
        -ClassName Win32_OperatingSystem `
        -ErrorAction SilentlyContinue

    $ramSummary = Get-RAMSummary

    [PSCustomObject]@{
        ComputerName       = $env:COMPUTERNAME
        Manufacturer       = $system.Manufacturer
        Model              = $system.Model
        SystemType         = $system.SystemType
        InstalledRAMGB     = $ramSummary.InstalledRAMGB
        UsableRAMGB        = $ramSummary.UsableRAMGB
        HardwareReservedGB = $ramSummary.HardwareReservedGB
        SerialNumber       = $bios.SerialNumber
        BIOSVersion        = $bios.SMBIOSBIOSVersion
        OS                 = $os.Caption
        OSVersion          = $os.Version
        BuildNumber        = $os.BuildNumber
    }
}


function Show-RAMInventory {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "RAM MODULES" -ForegroundColor Cyan
    Write-Host "==========="
    Write-Host ""

    $ram = Get-RAMInventory
    $summary = Get-RAMSummary

    if (-not $ram) {

        Write-Host "No RAM information found." `
            -ForegroundColor Yellow

        return
    }

    $ram |
        Format-Table `
            Bank,
            Slot,
            Manufacturer,
            PartNumber,
            SerialNumber,
            CapacityGB,
            SpeedMHz,
            Status `
            -AutoSize

    Write-Host ""

    Write-Host (
        "Installed RAM        : {0:N2} GB" `
        -f $summary.InstalledRAMGB
    )

    Write-Host (
        "Usable RAM           : {0:N2} GB" `
        -f $summary.UsableRAMGB
    )

    Write-Host (
        "Hardware Reserved    : {0:N2} GB" `
        -f $summary.HardwareReservedGB
    )

    Write-Host (
        "Memory Modules       : {0}" `
        -f $summary.ModuleCount
    )

    Write-Host ""

    if ($summary.DiagnosticStatus -eq "PASSED") {

        Write-Host (
            "Memory Diagnostic   : {0}" `
            -f $summary.DiagnosticStatus
        ) -ForegroundColor Green
    }
    elseif ($summary.DiagnosticStatus -eq "FAILED") {

        Write-Host (
            "Memory Diagnostic   : {0}" `
            -f $summary.DiagnosticStatus
        ) -ForegroundColor Red
    }
    else {

        Write-Host (
            "Memory Diagnostic   : {0}" `
            -f $summary.DiagnosticStatus
        ) -ForegroundColor Yellow
    }

    if ($summary.DiagnosticTime) {

        Write-Host (
            "Last Memory Test    : {0}" `
            -f $summary.DiagnosticTime
        )
    }

    Write-Host (
        "Diagnostic Result    : {0}" `
        -f $summary.DiagnosticMessage
    )
}


function Show-StorageHealth {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "STORAGE HEALTH" -ForegroundColor Cyan
    Write-Host "=============="
    Write-Host ""

    $storage = Get-StorageHealth

    if (-not $storage) {

        Write-Host "Storage health information unavailable." `
            -ForegroundColor Yellow

        return
    }

    foreach ($disk in $storage) {

        Write-Host "------------------------------------------------------------"

        Write-Host (
            "Drive Name         : {0}" `
            -f $disk.FriendlyName
        )

        Write-Host (
            "Serial Number      : {0}" `
            -f $disk.SerialNumber
        )

        Write-Host (
            "Media Type         : {0}" `
            -f $disk.MediaType
        )

        Write-Host (
            "Bus Type           : {0}" `
            -f $disk.BusType
        )

        Write-Host (
            "Capacity           : {0:N2} GB" `
            -f $disk.SizeGB
        )

        $healthColor = "White"

        if ($disk.HealthStatus -eq "Healthy") {
            $healthColor = "Green"
        }
        elseif (
            $disk.HealthStatus -eq "Warning" -or
            $disk.HealthStatus -eq "Unknown"
        ) {
            $healthColor = "Yellow"
        }
        elseif ($disk.HealthStatus -eq "Unhealthy") {
            $healthColor = "Red"
        }

        Write-Host (
            "Health Status      : {0}" `
            -f $disk.HealthStatus
        ) -ForegroundColor $healthColor

        Write-Host (
            "Operational Status : {0}" `
            -f $disk.OperationalStatus
        )

        if ($null -ne $disk.TemperatureC) {

            Write-Host (
                "Temperature       : {0} C" `
                -f $disk.TemperatureC
            )
        }
        else {
            Write-Host "Temperature       : Unavailable"
        }

        if ($null -ne $disk.WearPercent) {

            Write-Host (
                "Wear              : {0}%" `
                -f $disk.WearPercent
            )
        }
        else {
            Write-Host "Wear              : Unavailable"
        }

        if ($null -ne $disk.PowerOnHours) {

            Write-Host (
                "Power On Hours    : {0}" `
                -f $disk.PowerOnHours
            )
        }
        else {
            Write-Host "Power On Hours    : Unavailable"
        }

        if ($null -ne $disk.ReadErrorsTotal) {

            Write-Host (
                "Read Errors       : {0}" `
                -f $disk.ReadErrorsTotal
            )
        }
        else {
            Write-Host "Read Errors       : Unavailable"
        }

        if ($null -ne $disk.WriteErrorsTotal) {

            Write-Host (
                "Write Errors      : {0}" `
                -f $disk.WriteErrorsTotal
            )
        }
        else {
            Write-Host "Write Errors      : Unavailable"
        }

        Write-Host ""
    }
}


function Get-HardwareInventory {
    [CmdletBinding()]
    param(
        [switch]$SummaryOnly,
        [switch]$Display
    )

    $system = Get-SystemInventory
    $cpu = Get-CPUInventory
    $ram = Get-RAMInventory
    $ramSummary = Get-RAMSummary
    $storage = Get-StorageHealth
    $memoryDiagnostic = Get-MemoryDiagnosticResult

    if ($SummaryOnly) {

        Write-Host "SYSTEM" -ForegroundColor Cyan
        Write-Host "======"

        Write-Host (
            "Manufacturer      : {0}" `
            -f $system.Manufacturer
        )

        Write-Host (
            "Model             : {0}" `
            -f $system.Model
        )

        Write-Host (
            "Serial            : {0}" `
            -f $system.SerialNumber
        )

        Write-Host (
            "Installed RAM     : {0:N2} GB" `
            -f $system.InstalledRAMGB
        )

        Write-Host (
            "Usable RAM        : {0:N2} GB" `
            -f $system.UsableRAMGB
        )

        Write-Host (
            "Hardware Reserved : {0:N2} GB" `
            -f $system.HardwareReservedGB
        )

        Write-Host (
            "Memory Test       : {0}" `
            -f $memoryDiagnostic.Status
        )

        if ($storage) {

            $disk = $storage |
                Select-Object -First 1

            Write-Host (
                "Primary Disk      : {0}" `
                -f $disk.FriendlyName
            )

            Write-Host (
                "Disk Health       : {0}" `
                -f $disk.HealthStatus
            )
        }

        return
    }

    if ($Display) {

        Clear-Host

        Write-Host "============================================================" `
            -ForegroundColor Cyan

        Write-Host " HARDWARE INVENTORY & HEALTH" `
            -ForegroundColor White

        Write-Host "============================================================" `
            -ForegroundColor Cyan

        Write-Host ""

        Write-Host "SYSTEM INFORMATION" `
            -ForegroundColor Cyan

        Write-Host "=================="
        Write-Host ""

        $system |
            Format-List

        Write-Host ""

        Write-Host "PROCESSOR" `
            -ForegroundColor Cyan

        Write-Host "========="
        Write-Host ""

        $cpu |
            Format-Table `
                Name,
                Cores,
                LogicalCPUs,
                MaxClockMHz,
                CurrentClockMHz `
                -AutoSize

        Show-RAMInventory
        Show-StorageHealth

        Write-Host ""
        Write-Host "RAM HEALTH TEST" -ForegroundColor Cyan
        Write-Host "==============="
        Write-Host ""
        Write-Host "1. Open RAM Health Test Menu"
        Write-Host "0. Return to Main Menu"
        Write-Host ""

        $hardwareChoice = Read-Host "Select an option"

        if ($hardwareChoice -eq "1") {
            Show-RAMHealthMenu
        }

        return
    }

    return [PSCustomObject]@{
        System           = $system
        CPU              = $cpu
        RAM              = $ram
        RAMSummary       = $ramSummary
        Storage          = $storage
        MemoryDiagnostic = $memoryDiagnostic
    }
}


Export-ModuleMember -Function Convert-RAMSerialNumber, Convert-DiskSerialNumber, Get-MemoryDiagnosticResult, Start-WindowsMemoryDiagnostic, Show-MemoryDiagnosticResult, Show-RAMHealthMenu, Get-RAMInventory, Get-RAMSummary, Get-StorageHealth, Get-CPUInventory, Get-SystemInventory, Show-RAMInventory, Show-StorageHealth, Get-HardwareInventory