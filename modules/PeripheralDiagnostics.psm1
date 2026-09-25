#Requires -Version 5.1


function Get-PnpStatusText {
    param(
        [AllowNull()]
        [int]$ConfigManagerErrorCode
    )

    if ($null -eq $ConfigManagerErrorCode) {
        return "Unknown"
    }

    switch ($ConfigManagerErrorCode) {

        0  { return "OK" }
        1  { return "Device not configured correctly" }
        10 { return "Device cannot start" }
        12 { return "Insufficient resources" }
        14 { return "Restart required" }
        18 { return "Driver reinstall required" }
        22 { return "Device disabled" }
        24 { return "Device not present / not working" }
        28 { return "Drivers not installed" }
        31 { return "Windows cannot load driver" }
        32 { return "Driver disabled" }
        39 { return "Driver corrupted / missing" }
        43 { return "Device reported a problem" }

        default {
            return "Device Manager Code $ConfigManagerErrorCode"
        }
    }
}


function Get-PnpHealthStatus {
    param(
        [AllowNull()]
        [int]$ErrorCode
    )

    if ($null -eq $ErrorCode) {
        return "INFO"
    }

    if ($ErrorCode -eq 0) {
        return "PASS"
    }

    return "WARN"
}


function Show-DisplayCheck {

    Clear-Host

    Write-Host "DISPLAY / GPU CHECK" -ForegroundColor Cyan
    Write-Host "==================="
    Write-Host ""

    try {

        $gpus = Get-CimInstance `
            Win32_VideoController `
            -ErrorAction Stop

        foreach ($gpu in $gpus) {

            $status = Get-PnpHealthStatus `
                -ErrorCode $gpu.ConfigManagerErrorCode

            Write-StatusLine `
                -Status $status `
                -Label "GPU" `
                -Value "$($gpu.Name)"

            Write-StatusLine `
                -Status "INFO" `
                -Label "Driver Version" `
                -Value "$($gpu.DriverVersion)"

            Write-StatusLine `
                -Status $status `
                -Label "Device Status" `
                -Value (
                    Get-PnpStatusText `
                        -ConfigManagerErrorCode $gpu.ConfigManagerErrorCode
                )

            if ($gpu.CurrentHorizontalResolution) {

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "Resolution" `
                    -Value "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution)"
            }

            if ($gpu.CurrentRefreshRate) {

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "Refresh Rate" `
                    -Value "$($gpu.CurrentRefreshRate) Hz"
            }

            Write-Host ""
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Display / GPU" `
            -Value "Unable to query display adapter"
    }
}


function Show-MonitorCheck {

    Clear-Host

    Write-Host "MONITOR DETECTION" -ForegroundColor Cyan
    Write-Host "================="
    Write-Host ""

    try {

        $monitors = Get-CimInstance `
            -Namespace root\wmi `
            -ClassName WmiMonitorID `
            -ErrorAction Stop

        if (-not $monitors) {

            Write-StatusLine `
                -Status "WARN" `
                -Label "Monitor" `
                -Value "No monitor detected"

            return
        }

        $count = 0

        foreach ($monitor in $monitors) {

            $count++

            $manufacturer = ""

            if ($monitor.ManufacturerName) {

                $manufacturer = (
                    $monitor.ManufacturerName |
                    Where-Object { $_ -ne 0 } |
                    ForEach-Object { [char]$_ }
                ) -join ""
            }

            $product = ""

            if ($monitor.UserFriendlyName) {

                $product = (
                    $monitor.UserFriendlyName |
                    Where-Object { $_ -ne 0 } |
                    ForEach-Object { [char]$_ }
                ) -join ""
            }

            if ([string]::IsNullOrWhiteSpace($product)) {
                $product = "Unknown Monitor"
            }

            Write-StatusLine `
                -Status "PASS" `
                -Label "Monitor $count" `
                -Value "$manufacturer $product"
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Monitor Detection" `
            -Value "Unavailable"
    }
}


function Show-USBCheck {

    Clear-Host

    Write-Host "USB CONTROLLER / PORT CHECK" -ForegroundColor Cyan
    Write-Host "==========================="
    Write-Host ""

    try {

        $controllers = Get-CimInstance `
            Win32_USBController `
            -ErrorAction Stop

        foreach ($controller in $controllers) {

            $status = Get-PnpHealthStatus `
                -ErrorCode $controller.ConfigManagerErrorCode

            Write-StatusLine `
                -Status $status `
                -Label "USB Controller" `
                -Value "$($controller.Name)"

            Write-StatusLine `
                -Status $status `
                -Label "USB Status" `
                -Value (
                    Get-PnpStatusText `
                        -ConfigManagerErrorCode $controller.ConfigManagerErrorCode
                )

            Write-Host ""
        }

        $usbDevices = Get-PnpDevice `
            -PresentOnly `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.InstanceId -like "USB*"
            }

        Write-StatusLine `
            -Status "INFO" `
            -Label "Connected USB Devices" `
            -Value "$(@($usbDevices).Count)"

        Write-Host ""
        Write-Host "Note:" -ForegroundColor Yellow
        Write-Host "Windows can verify USB controllers and connected devices."
        Write-Host "A physical USB port can only be fully tested by connecting a known-good device."
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "USB" `
            -Value "Unable to query USB controllers"
    }
}


function Show-AudioCheck {

    Clear-Host

    Write-Host "AUDIO DEVICE CHECK" -ForegroundColor Cyan
    Write-Host "=================="
    Write-Host ""

    try {

        $audioDevices = Get-CimInstance `
            Win32_SoundDevice `
            -ErrorAction Stop

        if (-not $audioDevices) {

            Write-StatusLine `
                -Status "WARN" `
                -Label "Audio Devices" `
                -Value "None detected"

            return
        }

        foreach ($device in $audioDevices) {

            $status = Get-PnpHealthStatus `
                -ErrorCode $device.ConfigManagerErrorCode

            Write-StatusLine `
                -Status $status `
                -Label "Audio Device" `
                -Value "$($device.Name)"

            Write-StatusLine `
                -Status $status `
                -Label "Device Status" `
                -Value (
                    Get-PnpStatusText `
                        -ConfigManagerErrorCode $device.ConfigManagerErrorCode
                )

            Write-Host ""
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Audio" `
            -Value "Unavailable"
    }
}


function Show-CameraCheck {

    Clear-Host

    Write-Host "CAMERA CHECK" -ForegroundColor Cyan
    Write-Host "============"
    Write-Host ""

    try {

        $cameraDevices = Get-PnpDevice `
            -PresentOnly `
            -ErrorAction Stop |
            Where-Object {
                $_.Class -eq "Camera" -or
                $_.Class -eq "Image"
            }

        if (-not $cameraDevices) {

            Write-StatusLine `
                -Status "WARN" `
                -Label "Camera" `
                -Value "No camera detected"

            return
        }

        foreach ($camera in $cameraDevices) {

            $status = if ($camera.Status -eq "OK") {
                "PASS"
            }
            else {
                "WARN"
            }

            Write-StatusLine `
                -Status $status `
                -Label "Camera" `
                -Value "$($camera.FriendlyName) - $($camera.Status)"
        }
    }
    catch {

        Write-StatusLine `
            -Status "INFO" `
            -Label "Camera" `
            -Value "Unable to query"
    }
}


function Show-BluetoothCheck {

    Clear-Host

    Write-Host "BLUETOOTH CHECK" -ForegroundColor Cyan
    Write-Host "==============="
    Write-Host ""

    try {

        $devices = Get-PnpDevice `
            -Class Bluetooth `
            -PresentOnly `
            -ErrorAction Stop

        if (-not $devices) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Bluetooth" `
                -Value "No Bluetooth devices detected"

            return
        }

        foreach ($device in $devices) {

            $status = if ($device.Status -eq "OK") {
                "PASS"
            }
            else {
                "WARN"
            }

            Write-StatusLine `
                -Status $status `
                -Label "Bluetooth" `
                -Value "$($device.FriendlyName) - $($device.Status)"
        }
    }
    catch {

        Write-StatusLine `
            -Status "INFO" `
            -Label "Bluetooth" `
            -Value "Unavailable"
    }
}


function Show-NetworkAdapterCheck {

    Clear-Host

    Write-Host "NETWORK ADAPTER CHECK" -ForegroundColor Cyan
    Write-Host "====================="
    Write-Host ""

    try {

        $adapters = Get-NetAdapter `
            -ErrorAction Stop

        foreach ($adapter in $adapters) {

            $status = if ($adapter.Status -eq "Up") {
                "PASS"
            }
            elseif ($adapter.Status -eq "Disabled") {
                "INFO"
            }
            else {
                "WARN"
            }

            Write-StatusLine `
                -Status $status `
                -Label "$($adapter.Name)" `
                -Value "$($adapter.Status) - $($adapter.InterfaceDescription)"
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Network Adapters" `
            -Value "Unavailable"
    }
}


function Show-InputDeviceCheck {

    Clear-Host

    Write-Host "KEYBOARD / MOUSE CHECK" -ForegroundColor Cyan
    Write-Host "======================"
    Write-Host ""

    try {

        $keyboards = Get-CimInstance `
            Win32_Keyboard `
            -ErrorAction SilentlyContinue

        $mice = Get-CimInstance `
            Win32_PointingDevice `
            -ErrorAction SilentlyContinue

        Write-StatusLine `
            -Status $(if ($keyboards) { "PASS" } else { "WARN" }) `
            -Label "Keyboard Devices" `
            -Value "$(@($keyboards).Count)"

        foreach ($keyboard in $keyboards) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Keyboard" `
                -Value "$($keyboard.Description)"
        }

        Write-StatusLine `
            -Status $(if ($mice) { "PASS" } else { "WARN" }) `
            -Label "Pointing Devices" `
            -Value "$(@($mice).Count)"

        foreach ($mouse in $mice) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Mouse / Touchpad" `
                -Value "$($mouse.Description)"
        }

        Write-Host ""
        Write-Host "Note:" -ForegroundColor Yellow
        Write-Host "Detection does not test every key, mouse button, or touchpad gesture."
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Input Devices" `
            -Value "Unable to query"
    }
}


function Show-StorageControllerCheck {

    Clear-Host

    Write-Host "STORAGE CONTROLLER CHECK" -ForegroundColor Cyan
    Write-Host "========================"
    Write-Host ""

    try {

        $controllers = Get-PnpDevice `
            -PresentOnly `
            -ErrorAction Stop |
            Where-Object {
                $_.Class -eq "SCSIAdapter" -or
                $_.Class -eq "HDC"
            }

        if (-not $controllers) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Storage Controllers" `
                -Value "None returned"
        }

        foreach ($controller in $controllers) {

            $status = if ($controller.Status -eq "OK") {
                "PASS"
            }
            else {
                "WARN"
            }

            Write-StatusLine `
                -Status $status `
                -Label "Storage Controller" `
                -Value "$($controller.FriendlyName) - $($controller.Status)"
        }

        if (Get-Command Get-StorageHealth -ErrorAction SilentlyContinue) {

            Write-Host ""
            Write-Host "Storage Health:" -ForegroundColor White
            Write-Host ""

            Get-StorageHealth |
                Format-Table `
                    FriendlyName,
                    MediaType,
                    HealthStatus,
                    OperationalStatus,
                    TemperatureC,
                    WearPercent `
                    -AutoSize
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Storage Controller" `
            -Value "Unable to query"
    }
}


function Show-BatteryPowerCheck {

    Clear-Host

    Write-Host "BATTERY / POWER CHECK" -ForegroundColor Cyan
    Write-Host "====================="
    Write-Host ""

    if (
        Get-Command `
            Get-BatteryHealthData `
            -ErrorAction SilentlyContinue
    ) {

        try {

            $battery = Get-BatteryHealthData

            if ($battery) {

                Write-StatusLine `
                    -Status "PASS" `
                    -Label "Battery Detected" `
                    -Value "$($battery.BatteryName)"

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "Charge" `
                    -Value "$($battery.CurrentCharge)%"

                Write-StatusLine `
                    -Status $(if ($battery.HealthPercent -ge 80) { "PASS" } elseif ($battery.HealthPercent -ge 60) { "WARN" } else { "FAIL" }) `
                    -Label "Battery Health" `
                    -Value "$($battery.HealthPercent)%"

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "Cycle Count" `
                    -Value "$($battery.CycleCount)"

                return
            }
        }
        catch {}
    }

    try {

        $battery = Get-CimInstance `
            Win32_Battery `
            -ErrorAction Stop

        if ($battery) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "Battery" `
                -Value "Detected"

            Write-StatusLine `
                -Status "INFO" `
                -Label "Estimated Charge" `
                -Value "$($battery.EstimatedChargeRemaining)%"
        }
        else {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Battery" `
                -Value "No battery detected"
        }
    }
    catch {

        Write-StatusLine `
            -Status "INFO" `
            -Label "Battery" `
            -Value "Unavailable"
    }
}


function Show-DeviceManagerErrors {

    Clear-Host

    Write-Host "DEVICE MANAGER ERROR SCAN" -ForegroundColor Cyan
    Write-Host "========================="
    Write-Host ""

    try {

        $badDevices = Get-CimInstance `
            Win32_PnPEntity `
            -ErrorAction Stop |
            Where-Object {
                $null -ne $_.ConfigManagerErrorCode -and
                $_.ConfigManagerErrorCode -ne 0
            }

        if (-not $badDevices) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "Device Manager" `
                -Value "No device errors detected"

            return
        }

        foreach ($device in $badDevices) {

            Write-StatusLine `
                -Status "WARN" `
                -Label "$($device.Name)" `
                -Value (
                    Get-PnpStatusText `
                        -ConfigManagerErrorCode $device.ConfigManagerErrorCode
                )
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Device Manager Scan" `
            -Value "Unavailable"
    }
}


function Invoke-FullPeripheralCheck {

    Clear-Host

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host " FULL HARDWARE & PERIPHERAL CHECK"

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    #
    # GPU
    #
    try {

        $gpus = Get-CimInstance `
            Win32_VideoController `
            -ErrorAction SilentlyContinue

        $gpuProblems = @(
            $gpus |
            Where-Object {
                $_.ConfigManagerErrorCode -ne 0
            }
        ).Count

        Write-StatusLine `
            -Status $(if ($gpus -and $gpuProblems -eq 0) { "PASS" } else { "WARN" }) `
            -Label "Display / GPU" `
            -Value "$(@($gpus).Count) adapter(s) detected"
    }
    catch {}


    #
    # Monitor
    #
    try {

        $monitors = Get-CimInstance `
            -Namespace root\wmi `
            -ClassName WmiMonitorID `
            -ErrorAction SilentlyContinue

        Write-StatusLine `
            -Status $(if ($monitors) { "PASS" } else { "WARN" }) `
            -Label "Monitor" `
            -Value "$(@($monitors).Count) detected"
    }
    catch {}


    #
    # USB
    #
    try {

        $usb = Get-CimInstance `
            Win32_USBController `
            -ErrorAction SilentlyContinue

        $usbErrors = @(
            $usb |
            Where-Object {
                $_.ConfigManagerErrorCode -ne 0
            }
        ).Count

        Write-StatusLine `
            -Status $(if ($usb -and $usbErrors -eq 0) { "PASS" } else { "WARN" }) `
            -Label "USB Controllers" `
            -Value "$(@($usb).Count) detected"
    }
    catch {}


    #
    # Audio
    #
    try {

        $audio = Get-CimInstance `
            Win32_SoundDevice `
            -ErrorAction SilentlyContinue

        $audioErrors = @(
            $audio |
            Where-Object {
                $_.ConfigManagerErrorCode -ne 0
            }
        ).Count

        Write-StatusLine `
            -Status $(if ($audio -and $audioErrors -eq 0) { "PASS" } else { "WARN" }) `
            -Label "Audio Devices" `
            -Value "$(@($audio).Count) detected"
    }
    catch {}


    #
    # Camera
    #
    try {

        $camera = Get-PnpDevice `
            -PresentOnly `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Class -eq "Camera" -or
                $_.Class -eq "Image"
            }

        Write-StatusLine `
            -Status $(if ($camera) { "PASS" } else { "INFO" }) `
            -Label "Camera" `
            -Value "$(@($camera).Count) detected"
    }
    catch {}


    #
    # Network
    #
    try {

        $network = Get-NetAdapter `
            -ErrorAction SilentlyContinue

        $up = @(
            $network |
            Where-Object {
                $_.Status -eq "Up"
            }
        ).Count

        Write-StatusLine `
            -Status $(if ($up -gt 0) { "PASS" } else { "WARN" }) `
            -Label "Network Adapters Up" `
            -Value "$up"
    }
    catch {}


    #
    # Device errors
    #
    try {

        $badDevices = Get-CimInstance `
            Win32_PnPEntity `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $null -ne $_.ConfigManagerErrorCode -and
                $_.ConfigManagerErrorCode -ne 0
            }

        $badCount = @($badDevices).Count

        Write-StatusLine `
            -Status $(if ($badCount -eq 0) { "PASS" } else { "WARN" }) `
            -Label "Device Manager Errors" `
            -Value "$badCount"
    }
    catch {}

    Write-Host ""
    Write-Host "Important:" -ForegroundColor Yellow
    Write-Host "This verifies Windows device detection and driver status."
    Write-Host "Physical functions such as USB socket contact, HDMI output,"
    Write-Host "speaker sound, microphone input, webcam image quality, and"
    Write-Host "individual keyboard keys still require an interactive test."
}


function Show-PeripheralDiagnosticsMenu {

    do {

        Clear-Host

        Write-Host "HARDWARE & PERIPHERAL TESTS" `
            -ForegroundColor Cyan

        Write-Host "==========================="
        Write-Host ""

        Write-Host "1.  Display / GPU Check"
        Write-Host "2.  Monitor Detection"
        Write-Host "3.  USB Controller / Port Check"
        Write-Host "4.  Audio Device Check"
        Write-Host "5.  Camera Check"
        Write-Host "6.  Bluetooth Check"
        Write-Host "7.  Network Adapter Check"
        Write-Host "8.  Keyboard / Mouse Check"
        Write-Host "9.  Storage Controller Check"
        Write-Host "10. Battery / Power Check"
        Write-Host "11. Device Manager Error Scan"
        Write-Host "12. Run Full Hardware Peripheral Check"
        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Show-DisplayCheck
            }

            "2" {
                Show-MonitorCheck
            }

            "3" {
                Show-USBCheck
            }

            "4" {
                Show-AudioCheck
            }

            "5" {
                Show-CameraCheck
            }

            "6" {
                Show-BluetoothCheck
            }

            "7" {
                Show-NetworkAdapterCheck
            }

            "8" {
                Show-InputDeviceCheck
            }

            "9" {
                Show-StorageControllerCheck
            }

            "10" {
                Show-BatteryPowerCheck
            }

            "11" {
                Show-DeviceManagerErrors
            }

            "12" {
                Invoke-FullPeripheralCheck
            }

            "0" {}

            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 1
            }
        }

        if ($choice -ne "0") {

            Write-Host ""
            Read-Host "Press ENTER"
        }

    } while ($choice -ne "0")
}


Export-ModuleMember -Function `
    Get-PnpStatusText, `
    Get-PnpHealthStatus, `
    Show-DisplayCheck, `
    Show-MonitorCheck, `
    Show-USBCheck, `
    Show-AudioCheck, `
    Show-CameraCheck, `
    Show-BluetoothCheck, `
    Show-NetworkAdapterCheck, `
    Show-InputDeviceCheck, `
    Show-StorageControllerCheck, `
    Show-BatteryPowerCheck, `
    Show-DeviceManagerErrors, `
    Invoke-FullPeripheralCheck, `
    Show-PeripheralDiagnosticsMenu