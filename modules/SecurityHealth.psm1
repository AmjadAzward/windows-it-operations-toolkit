function Get-SecurityHealth {

    param(
        [switch]$Detailed
    )

    Write-Host "SECURITY HEALTH" -ForegroundColor Cyan
    Write-Host ""

    #
    # MICROSOFT DEFENDER
    #
    try {

        $mp = Get-MpComputerStatus -ErrorAction Stop

        Write-StatusLine `
            ($(if ($mp.AntivirusEnabled) { "PASS" } else { "FAIL" })) `
            "Microsoft Defender AV" `
            "$($mp.AntivirusEnabled)"

        Write-StatusLine `
            ($(if ($mp.RealTimeProtectionEnabled) { "PASS" } else { "FAIL" })) `
            "Real-Time Protection" `
            "$($mp.RealTimeProtectionEnabled)"

        Write-StatusLine `
            ($(if ($mp.BehaviorMonitorEnabled) { "PASS" } else { "WARN" })) `
            "Behavior Monitoring" `
            "$($mp.BehaviorMonitorEnabled)"

        Write-StatusLine `
            ($(if ($mp.IoavProtectionEnabled) { "PASS" } else { "WARN" })) `
            "Downloaded File Scanning" `
            "$($mp.IoavProtectionEnabled)"

        Write-StatusLine `
            ($(if ($mp.AntispywareEnabled) { "PASS" } else { "WARN" })) `
            "Antispyware Protection" `
            "$($mp.AntispywareEnabled)"

        if ($Detailed) {

            Write-StatusLine `
                INFO `
                "Signature Version" `
                "$($mp.AntivirusSignatureVersion)"

            Write-StatusLine `
                INFO `
                "Signature Updated" `
                "$($mp.AntivirusSignatureLastUpdated)"

            Write-StatusLine `
                INFO `
                "Last Quick Scan" `
                "$($mp.QuickScanEndTime)"

            Write-StatusLine `
                INFO `
                "Last Full Scan" `
                "$($mp.FullScanEndTime)"
        }
    }
    catch {

        Write-StatusLine `
            WARN `
            "Defender Status" `
            "Unavailable"
    }


    #
    # DEFENDER PREFERENCES
    #
    try {

        $pref = Get-MpPreference -ErrorAction Stop

        $cloudProtection = $false

        if (
            $null -ne $pref.MAPSReporting -and
            $pref.MAPSReporting -ne 0
        ) {
            $cloudProtection = $true
        }

        Write-StatusLine `
            ($(if ($cloudProtection) { "PASS" } else { "WARN" })) `
            "Cloud Protection" `
            "$cloudProtection"

        $puaEnabled = $false

        if (
            $null -ne $pref.PUAProtection -and
            $pref.PUAProtection -ne 0
        ) {
            $puaEnabled = $true
        }

        Write-StatusLine `
            ($(if ($puaEnabled) { "PASS" } else { "WARN" })) `
            "PUA Protection" `
            "$puaEnabled"

        if ($Detailed) {

            $exclusionCount = 0

            if ($pref.ExclusionPath) {
                $exclusionCount += @($pref.ExclusionPath).Count
            }

            if ($pref.ExclusionProcess) {
                $exclusionCount += @($pref.ExclusionProcess).Count
            }

            if ($pref.ExclusionExtension) {
                $exclusionCount += @($pref.ExclusionExtension).Count
            }

            Write-StatusLine `
                INFO `
                "Defender Exclusions" `
                "$exclusionCount"
        }
    }
    catch {

        if ($Detailed) {
            Write-StatusLine `
                WARN `
                "Defender Preferences" `
                "Unavailable"
        }
    }


    #
    # WINDOWS FIREWALL
    #
    try {

        $profiles = Get-NetFirewallProfile -ErrorAction Stop

        foreach ($p in $profiles) {

            Write-StatusLine `
                ($(if ($p.Enabled) { "PASS" } else { "WARN" })) `
                "Firewall $($p.Name)" `
                "$($p.Enabled)"
        }
    }
    catch {

        Write-StatusLine `
            WARN `
            "Firewall Status" `
            "Unavailable"
    }


    #
    # BITLOCKER
    #
    try {

        $bl = Get-BitLockerVolume `
            -MountPoint $env:SystemDrive `
            -ErrorAction Stop

        Write-StatusLine `
            ($(if ($bl.ProtectionStatus -eq "On") { "PASS" } else { "WARN" })) `
            "BitLocker $env:SystemDrive" `
            "$($bl.ProtectionStatus)"

        if ($Detailed) {

            Write-StatusLine `
                INFO `
                "Encryption Method" `
                "$($bl.EncryptionMethod)"

            Write-StatusLine `
                INFO `
                "Encryption %" `
                "$($bl.EncryptionPercentage)"
        }
    }
    catch {

        Write-StatusLine `
            WARN `
            "BitLocker" `
            "Unavailable / not supported"
    }


    #
    # SECURE BOOT
    #
    try {

        $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop

        Write-StatusLine `
            ($(if ($secureBoot) { "PASS" } else { "WARN" })) `
            "Secure Boot" `
            "$secureBoot"
    }
    catch {

        Write-StatusLine `
            INFO `
            "Secure Boot" `
            "Unavailable / unsupported"
    }


    #
    # TPM
    #
    try {

        $tpm = Get-Tpm -ErrorAction Stop

        Write-StatusLine `
            ($(if ($tpm.TpmPresent) { "PASS" } else { "WARN" })) `
            "TPM Present" `
            "$($tpm.TpmPresent)"

        Write-StatusLine `
            ($(if ($tpm.TpmReady) { "PASS" } else { "WARN" })) `
            "TPM Ready" `
            "$($tpm.TpmReady)"

        if ($Detailed) {

            Write-StatusLine `
                INFO `
                "TPM Enabled" `
                "$($tpm.TpmEnabled)"

            Write-StatusLine `
                INFO `
                "TPM Activated" `
                "$($tpm.TpmActivated)"
        }
    }
    catch {

        Write-StatusLine `
            INFO `
            "TPM" `
            "Unavailable"
    }


    #
    # UAC
    #
    try {

        $uac = Get-ItemProperty `
            -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
            -Name EnableLUA `
            -ErrorAction Stop

        $enabled = ($uac.EnableLUA -eq 1)

        Write-StatusLine `
            ($(if ($enabled) { "PASS" } else { "FAIL" })) `
            "User Account Control" `
            "$enabled"
    }
    catch {

        Write-StatusLine `
            WARN `
            "User Account Control" `
            "Unavailable"
    }


    #
    # SMBv1
    #
    try {

        $smb1 = Get-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol `
            -ErrorAction Stop

        $disabled = ($smb1.State -ne "Enabled")

        Write-StatusLine `
            ($(if ($disabled) { "PASS" } else { "WARN" })) `
            "SMBv1" `
            "$(if ($disabled) { 'Disabled' } else { 'Enabled' })"
    }
    catch {

        Write-StatusLine `
            INFO `
            "SMBv1" `
            "Unable to verify"
    }


    #
    # RDP
    #
    try {

        $rdp = Get-ItemProperty `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
            -Name fDenyTSConnections `
            -ErrorAction Stop

        $rdpEnabled = ($rdp.fDenyTSConnections -eq 0)

        Write-StatusLine `
            ($(if (-not $rdpEnabled) { "PASS" } else { "INFO" })) `
            "Remote Desktop" `
            "$(if ($rdpEnabled) { 'Enabled' } else { 'Disabled' })"
    }
    catch {

        Write-StatusLine `
            WARN `
            "Remote Desktop" `
            "Unavailable"
    }


    #
    # WINRM
    #
    try {

        $winrm = Get-Service `
            -Name WinRM `
            -ErrorAction Stop

        Write-StatusLine `
            INFO `
            "WinRM Service" `
            "$($winrm.Status)"
    }
    catch {

        Write-StatusLine `
            INFO `
            "WinRM Service" `
            "Unavailable"
    }


    #
    # SECURITY CENTER SERVICE
    #
    try {

        $securityCenter = Get-Service `
            -Name wscsvc `
            -ErrorAction Stop

        Write-StatusLine `
            ($(if ($securityCenter.Status -eq "Running") { "PASS" } else { "WARN" })) `
            "Security Center" `
            "$($securityCenter.Status)"
    }
    catch {

        Write-StatusLine `
            WARN `
            "Security Center" `
            "Unavailable"
    }


    #
    # WINDOWS UPDATE SERVICE
    #
    try {

        $wu = Get-Service `
            -Name wuauserv `
            -ErrorAction Stop

        Write-StatusLine `
            ($(if ($wu.Status -eq "Running") { "PASS" } else { "INFO" })) `
            "Windows Update Service" `
            "$($wu.Status)"
    }
    catch {

        Write-StatusLine `
            WARN `
            "Windows Update Service" `
            "Unavailable"
    }


    #
    # PENDING REBOOT
    #
    try {

        $pendingReboot = $false

        $rebootKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        )

        foreach ($key in $rebootKeys) {

            if (Test-Path $key) {
                $pendingReboot = $true
            }
        }

        $pendingFileRename = Get-ItemProperty `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
            -Name PendingFileRenameOperations `
            -ErrorAction SilentlyContinue

        if ($pendingFileRename.PendingFileRenameOperations) {
            $pendingReboot = $true
        }

        Write-StatusLine `
            ($(if ($pendingReboot) { "WARN" } else { "PASS" })) `
            "Pending Reboot" `
            "$pendingReboot"
    }
    catch {

        Write-StatusLine `
            INFO `
            "Pending Reboot" `
            "Unable to verify"
    }


    #
    # GUEST ACCOUNT
    #
    try {

        $guest = Get-LocalUser `
            -Name "Guest" `
            -ErrorAction Stop

        Write-StatusLine `
            ($(if (-not $guest.Enabled) { "PASS" } else { "WARN" })) `
            "Guest Account" `
            "$(if ($guest.Enabled) { 'Enabled' } else { 'Disabled' })"
    }
    catch {

        Write-StatusLine `
            INFO `
            "Guest Account" `
            "Unavailable / renamed"
    }


    #
    # LOCAL ADMINISTRATORS
    #
    if ($Detailed) {

        try {

            $admins = Get-LocalGroupMember `
                -Group "Administrators" `
                -ErrorAction Stop

            Write-StatusLine `
                INFO `
                "Local Administrators" `
                "$(@($admins).Count)"
        }
        catch {

            Write-StatusLine `
                INFO `
                "Local Administrators" `
                "Unavailable"
        }
    }


    #
    # FAILED LOGONS
    #
    if ($Detailed) {

        try {

            $since = (Get-Date).AddHours(-24)

            $failedLogons = Get-WinEvent `
                -FilterHashtable @{
                    LogName   = "Security"
                    Id        = 4625
                    StartTime = $since
                } `
                -ErrorAction SilentlyContinue

            $failedCount = @($failedLogons).Count

            Write-StatusLine `
                ($(if ($failedCount -eq 0) { "PASS" } else { "INFO" })) `
                "Failed Logons - 24h" `
                "$failedCount"
        }
        catch {

            Write-StatusLine `
                INFO `
                "Failed Logons - 24h" `
                "Unavailable"
        }
    }


    #
    # PASSWORD POLICY
    #
    if ($Detailed) {

        try {

            $netAccounts = net accounts 2>$null

            $minLength = $netAccounts |
                Select-String "Minimum password length"

            $lockoutThreshold = $netAccounts |
                Select-String "Lockout threshold"

            if ($minLength) {

                Write-StatusLine `
                    INFO `
                    "Password Policy" `
                    "$($minLength.ToString().Trim())"
            }

            if ($lockoutThreshold) {

                Write-StatusLine `
                    INFO `
                    "Account Lockout" `
                    "$($lockoutThreshold.ToString().Trim())"
            }
        }
        catch {}
    }


    #
    # MEMORY INTEGRITY / HVCI
    #
    try {

        $dg = Get-CimInstance `
            -Namespace "root\Microsoft\Windows\DeviceGuard" `
            -ClassName Win32_DeviceGuard `
            -ErrorAction Stop

        $hvci = $false

        if (
            $dg.SecurityServicesRunning -contains 2
        ) {
            $hvci = $true
        }

        Write-StatusLine `
            ($(if ($hvci) { "PASS" } else { "INFO" })) `
            "Memory Integrity / HVCI" `
            "$hvci"
    }
    catch {

        Write-StatusLine `
            INFO `
            "Memory Integrity / HVCI" `
            "Unavailable"
    }


    #
    # CREDENTIAL GUARD
    #
    try {

        $dg = Get-CimInstance `
            -Namespace "root\Microsoft\Windows\DeviceGuard" `
            -ClassName Win32_DeviceGuard `
            -ErrorAction Stop

        $credentialGuard = $false

        if (
            $dg.SecurityServicesRunning -contains 1
        ) {
            $credentialGuard = $true
        }

        Write-StatusLine `
            ($(if ($credentialGuard) { "PASS" } else { "INFO" })) `
            "Credential Guard" `
            "$credentialGuard"
    }
    catch {

        Write-StatusLine `
            INFO `
            "Credential Guard" `
            "Unavailable"
    }


    #
    # POWERSHELL EXECUTION POLICY
    #
    if ($Detailed) {

        try {

            $policy = Get-ExecutionPolicy `
                -Scope LocalMachine

            Write-StatusLine `
                INFO `
                "PowerShell Policy" `
                "$policy"
        }
        catch {}
    }


    #
    # WINDOWS LICENSE
    #
    try {

        $lic = Get-CimInstance `
            SoftwareLicensingProduct `
            -Filter "Name like 'Windows%'" |
            Where-Object {
                $_.PartialProductKey
            } |
            Select-Object -First 1

        $licenseText = switch ($lic.LicenseStatus) {

            1 { "Licensed" }
            2 { "Initial Grace Period" }
            3 { "Additional Grace Period" }
            4 { "Non-Genuine Grace Period" }
            5 { "Notification" }
            6 { "Extended Grace Period" }

            default {
                "Unknown ($($lic.LicenseStatus))"
            }
        }

        Write-StatusLine `
            ($(if ($lic.LicenseStatus -eq 1) { "PASS" } else { "WARN" })) `
            "Windows License" `
            "$licenseText"
    }
    catch {

        Write-StatusLine `
            INFO `
            "Windows License" `
            "Unavailable"
    }


    #
    # HOSTS FILE
    #
    if ($Detailed) {

        try {

            $hostsPath = Join-Path `
                $env:WINDIR `
                "System32\drivers\etc\hosts"

            if (Test-Path $hostsPath) {

                $hosts = Get-Item `
                    $hostsPath `
                    -ErrorAction Stop

                Write-StatusLine `
                    INFO `
                    "Hosts File Modified" `
                    "$($hosts.LastWriteTime)"
            }
        }
        catch {}
    }
}


Export-ModuleMember -Function Get-SecurityHealth