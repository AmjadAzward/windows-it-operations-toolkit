#Requires -Version 5.1


function Get-SystemExtras {

    Write-Host "ADVANCED SYSTEM CHECKS" -ForegroundColor Cyan
    Write-Host "======================"
    Write-Host ""

    #
    # SYSTEM / DOMAIN
    #
    try {

        $cs = Get-CimInstance `
            Win32_ComputerSystem `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "INFO" `
            -Label "Domain / Workgroup" `
            -Value "$($cs.Domain)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Domain Joined" `
            -Value "$($cs.PartOfDomain)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Manufacturer" `
            -Value "$($cs.Manufacturer)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Model" `
            -Value "$($cs.Model)"

    }
    catch {}


    #
    # BIOS / SERIAL
    #
    try {

        $bios = Get-CimInstance `
            Win32_BIOS `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "INFO" `
            -Label "System Serial" `
            -Value "$($bios.SerialNumber)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "BIOS Version" `
            -Value "$($bios.SMBIOSBIOSVersion)"

    }
    catch {}


    #
    # OPERATING SYSTEM / UPTIME
    #
    try {

        $os = Get-CimInstance `
            Win32_OperatingSystem `
            -ErrorAction Stop

        $lastBoot = $os.LastBootUpTime

        if ($lastBoot) {

            $uptime = (Get-Date) - $lastBoot

            $uptimeText = "{0} days {1} hours {2} minutes" -f `
                $uptime.Days,
                $uptime.Hours,
                $uptime.Minutes

            Write-StatusLine `
                -Status "INFO" `
                -Label "Last Boot" `
                -Value "$lastBoot"

            Write-StatusLine `
                -Status "INFO" `
                -Label "System Uptime" `
                -Value "$uptimeText"
        }

        Write-StatusLine `
            -Status "INFO" `
            -Label "OS Architecture" `
            -Value "$($os.OSArchitecture)"

    }
    catch {}


    #
    # FIRMWARE MODE
    #
    try {

        $firmwareType = Get-ItemPropertyValue `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control" `
            -Name "PEFirmwareType" `
            -ErrorAction Stop

        $firmwareText = switch ($firmwareType) {

            1 { "BIOS / Legacy" }
            2 { "UEFI" }

            default {
                "Unknown"
            }
        }

        Write-StatusLine `
            -Status "INFO" `
            -Label "Firmware Mode" `
            -Value "$firmwareText"

    }
    catch {

        Write-StatusLine `
            -Status "INFO" `
            -Label "Firmware Mode" `
            -Value "Unavailable"
    }


    #
    # SECURE BOOT
    #
    try {

        $secureBoot = Confirm-SecureBootUEFI `
            -ErrorAction Stop

        Write-StatusLine `
            -Status $(if ($secureBoot) { "PASS" } else { "WARN" }) `
            -Label "Secure Boot" `
            -Value $(if ($secureBoot) { "Enabled" } else { "Disabled" })

    }
    catch {

        Write-StatusLine `
            -Status "INFO" `
            -Label "Secure Boot" `
            -Value "Unavailable / unsupported"
    }


    #
    # TPM
    #
    try {

        $tpm = Get-Tpm `
            -ErrorAction Stop

        Write-StatusLine `
            -Status $(if ($tpm.TpmReady) { "PASS" } else { "WARN" }) `
            -Label "TPM Ready" `
            -Value "$($tpm.TpmReady)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "TPM Present" `
            -Value "$($tpm.TpmPresent)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "TPM Enabled" `
            -Value "$($tpm.TpmEnabled)"

    }
    catch {

        Write-StatusLine `
            -Status "INFO" `
            -Label "TPM" `
            -Value "Unavailable"
    }


    Write-Host ""
    Write-Host "NETWORK CONFIGURATION" -ForegroundColor White
    Write-Host "---------------------"


    #
    # WINHTTP PROXY
    #
    try {

        $proxy = netsh winhttp show proxy |
            Out-String

        $proxyText = $proxy.Trim()

        if (
            $proxyText -match "Direct access"
        ) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "WinHTTP Proxy" `
                -Value "Direct access"
        }
        else {

            Write-Host ""
            Write-Host "WinHTTP Proxy:"
            Write-Host $proxyText
        }

    }
    catch {

        Write-StatusLine `
            -Status "INFO" `
            -Label "WinHTTP Proxy" `
            -Value "Unavailable"
    }


    #
    # USER PROXY
    #
    try {

        $internetSettings = Get-ItemProperty `
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" `
            -ErrorAction Stop

        $proxyEnabled = (
            $internetSettings.ProxyEnable -eq 1
        )

        Write-StatusLine `
            -Status "INFO" `
            -Label "User Proxy" `
            -Value $(if ($proxyEnabled) { "Enabled" } else { "Disabled" })

        if (
            $proxyEnabled -and
            $internetSettings.ProxyServer
        ) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Proxy Server" `
                -Value "$($internetSettings.ProxyServer)"
        }

    }
    catch {}


    #
    # ACTIVE NETWORK CONFIGURATION
    #
    try {

        $configs = Get-NetIPConfiguration `
            -ErrorAction Stop |
            Where-Object {
                $_.NetAdapter.Status -eq "Up"
            }

        foreach ($config in $configs) {

            $alias = $config.InterfaceAlias

            Write-StatusLine `
                -Status "INFO" `
                -Label "Network Adapter" `
                -Value "$alias"

            if ($config.IPv4Address) {

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "IPv4 Address" `
                    -Value "$($config.IPv4Address.IPAddress)"
            }

            if ($config.IPv4DefaultGateway) {

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "Default Gateway" `
                    -Value "$($config.IPv4DefaultGateway.NextHop)"
            }

            if ($config.DNSServer.ServerAddresses) {

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "DNS Servers" `
                    -Value "$($config.DNSServer.ServerAddresses -join ', ')"
            }
        }

    }
    catch {}


    #
    # DHCP
    #
    try {

        $adapters = Get-CimInstance `
            Win32_NetworkAdapterConfiguration `
            -Filter "IPEnabled=True" `
            -ErrorAction Stop

        foreach ($adapter in $adapters) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "DHCP Enabled" `
                -Value "$($adapter.DHCPEnabled)"
        }

    }
    catch {}


    #
    # NETWORK PROFILE
    #
    try {

        $profiles = Get-NetConnectionProfile `
            -ErrorAction Stop

        foreach ($profile in $profiles) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Network Profile" `
                -Value "$($profile.NetworkCategory)"
        }

    }
    catch {}


    #
    # IPv6
    #
    try {

        $ipv6Bindings = Get-NetAdapterBinding `
            -ComponentID ms_tcpip6 `
            -ErrorAction Stop |
            Where-Object {
                $_.Enabled -eq $true
            }

        $ipv6Enabled = (
            @($ipv6Bindings).Count -gt 0
        )

        Write-StatusLine `
            -Status "INFO" `
            -Label "IPv6" `
            -Value $(if ($ipv6Enabled) { "Enabled" } else { "Disabled" })

    }
    catch {}


    Write-Host ""
    Write-Host "TIME & REGION" -ForegroundColor White
    Write-Host "-------------"


    #
    # WINDOWS TIME SERVICE
    #
    try {

        $timeService = Get-Service `
            -Name W32Time `
            -ErrorAction Stop

        Write-StatusLine `
            -Status $(if ($timeService.Status -eq "Running") { "PASS" } else { "WARN" }) `
            -Label "Windows Time Service" `
            -Value "$($timeService.Status)"

        if (
            $timeService.Status -eq "Running"
        ) {

            try {

                $timeSource = (
                    w32tm /query /source 2>$null |
                    Out-String
                ).Trim()

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "Time Source" `
                    -Value "$timeSource"

            }
            catch {}
        }
        else {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Time Source" `
                -Value "Unavailable - service stopped"
        }

    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Windows Time Service" `
            -Value "Unavailable"
    }


    #
    # TIME ZONE
    #
    try {

        $tz = Get-TimeZone `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "INFO" `
            -Label "Time Zone" `
            -Value "$($tz.DisplayName)"

    }
    catch {}


    #
    # LOCALE
    #
    try {

        $culture = Get-Culture

        Write-StatusLine `
            -Status "INFO" `
            -Label "System Locale" `
            -Value "$($culture.Name)"

    }
    catch {}


    Write-Host ""
    Write-Host "REMOTE ACCESS" -ForegroundColor White
    Write-Host "-------------"


    #
    # RDP
    #
    try {

        $terminalServer = Get-ItemProperty `
            "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
            -ErrorAction Stop

        $rdpEnabled = (
            $terminalServer.fDenyTSConnections -eq 0
        )

        Write-StatusLine `
            -Status "INFO" `
            -Label "Remote Desktop" `
            -Value $(if ($rdpEnabled) { "Enabled" } else { "Disabled" })

    }
    catch {}


    #
    # RDP NLA
    #
    try {

        $nla = Get-ItemProperty `
            "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
            -Name UserAuthentication `
            -ErrorAction Stop

        $nlaEnabled = (
            $nla.UserAuthentication -eq 1
        )

        Write-StatusLine `
            -Status $(if ($nlaEnabled) { "PASS" } else { "WARN" }) `
            -Label "RDP Network Level Auth" `
            -Value $(if ($nlaEnabled) { "Enabled" } else { "Disabled" })

    }
    catch {

        Write-StatusLine `
            -Status "INFO" `
            -Label "RDP Network Level Auth" `
            -Value "Unavailable"
    }


    #
    # REMOTE ASSISTANCE
    #
    try {

        $ra = Get-ItemProperty `
            "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" `
            -Name fAllowToGetHelp `
            -ErrorAction Stop

        $raEnabled = (
            $ra.fAllowToGetHelp -eq 1
        )

        Write-StatusLine `
            -Status "INFO" `
            -Label "Remote Assistance" `
            -Value $(if ($raEnabled) { "Enabled" } else { "Disabled" })

    }
    catch {}


    #
    # WINRM
    #
    try {

        $winrm = Get-Service `
            WinRM `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "INFO" `
            -Label "WinRM" `
            -Value "$($winrm.Status)"

    }
    catch {}


    Write-Host ""
    Write-Host "WINDOWS SERVICES & MAINTENANCE" -ForegroundColor White
    Write-Host "------------------------------"


    #
    # KEY SERVICES
    #
    $servicesToCheck = @(
        @{
            Name  = "wuauserv"
            Label = "Windows Update"
        },
        @{
            Name  = "BITS"
            Label = "BITS"
        },
        @{
            Name  = "Dnscache"
            Label = "DNS Client"
        },
        @{
            Name  = "W32Time"
            Label = "Windows Time"
        },
        @{
            Name  = "MpsSvc"
            Label = "Windows Firewall"
        }
    )

    foreach ($serviceItem in $servicesToCheck) {

        try {

            $service = Get-Service `
                -Name $serviceItem.Name `
                -ErrorAction Stop

            Write-StatusLine `
                -Status $(if ($service.Status -eq "Running") { "PASS" } else { "INFO" }) `
                -Label $serviceItem.Label `
                -Value "$($service.Status)"

        }
        catch {

            Write-StatusLine `
                -Status "INFO" `
                -Label $serviceItem.Label `
                -Value "Unavailable"
        }
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

        $pendingRename = Get-ItemProperty `
            "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
            -Name PendingFileRenameOperations `
            -ErrorAction SilentlyContinue

        if ($pendingRename.PendingFileRenameOperations) {
            $pendingReboot = $true
        }

        Write-StatusLine `
            -Status $(if ($pendingReboot) { "WARN" } else { "PASS" }) `
            -Label "Pending Reboot" `
            -Value "$pendingReboot"

    }
    catch {}


    #
    # POWER PLAN
    #
    try {

        $powerOutput = powercfg /getactivescheme |
            Out-String

        $powerOutput = $powerOutput.Trim()

        Write-StatusLine `
            -Status "INFO" `
            -Label "Active Power Plan" `
            -Value "$powerOutput"

    }
    catch {}


    #
    # HIBERNATION
    #
    try {

        $hibernateFile = Join-Path `
            $env:SystemDrive `
            "hiberfil.sys"

        $hibernateEnabled = Test-Path `
            $hibernateFile

        Write-StatusLine `
            -Status "INFO" `
            -Label "Hibernate" `
            -Value $(if ($hibernateEnabled) { "Enabled" } else { "Disabled" })

    }
    catch {}


    #
    # WINDOWS RE
    #
    try {

        $reagent = reagentc /info 2>$null |
            Out-String

        $winREEnabled = (
            $reagent -match "Windows RE status:\s+Enabled"
        )

        Write-StatusLine `
            -Status $(if ($winREEnabled) { "PASS" } else { "WARN" }) `
            -Label "Windows Recovery" `
            -Value $(if ($winREEnabled) { "Enabled" } else { "Disabled / unavailable" })

    }
    catch {}


    #
    # PAGEFILE
    #
    try {

        $pageFiles = Get-CimInstance `
            Win32_PageFileUsage `
            -ErrorAction Stop

        if ($pageFiles) {

            foreach ($page in $pageFiles) {

                Write-StatusLine `
                    -Status "INFO" `
                    -Label "Page File" `
                    -Value "$($page.Name)"
            }
        }
        else {

            Write-StatusLine `
                -Status "WARN" `
                -Label "Page File" `
                -Value "Not detected"
        }

    }
    catch {}


    Write-Host ""
    Write-Host "CRASH & RECOVERY" -ForegroundColor White
    Write-Host "----------------"


    #
    # CRASH DUMP CONFIGURATION
    #
    try {

        $crashControl = Get-ItemProperty `
            "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" `
            -ErrorAction Stop

        $dumpType = switch ($crashControl.CrashDumpEnabled) {

            0 { "Disabled" }
            1 { "Complete Memory Dump" }
            2 { "Kernel Memory Dump" }
            3 { "Small Memory Dump" }
            7 { "Automatic Memory Dump" }

            default {
                "Unknown"
            }
        }

        Write-StatusLine `
            -Status "INFO" `
            -Label "Crash Dump Type" `
            -Value "$dumpType"

    }
    catch {}


    #
    # MINIDUMP COUNT
    #
    try {

        $miniDumpPath = Join-Path `
            $env:SystemRoot `
            "Minidump"

        $dumpCount = 0

        if (Test-Path $miniDumpPath) {

            $dumpCount = @(
                Get-ChildItem `
                    $miniDumpPath `
                    -Filter "*.dmp" `
                    -ErrorAction SilentlyContinue
            ).Count
        }

        Write-StatusLine `
            -Status $(if ($dumpCount -eq 0) { "PASS" } else { "INFO" }) `
            -Label "Minidump Files" `
            -Value "$dumpCount"

    }
    catch {}


    #
    # UNEXPECTED SHUTDOWNS - 7 DAYS
    #
    try {

        $shutdownEvents = Get-WinEvent `
            -FilterHashtable @{
                LogName   = "System"
                Id        = 6008
                StartTime = (Get-Date).AddDays(-7)
            } `
            -ErrorAction SilentlyContinue

        $shutdownCount = @(
            $shutdownEvents
        ).Count

        Write-StatusLine `
            -Status $(if ($shutdownCount -eq 0) { "PASS" } else { "WARN" }) `
            -Label "Unexpected Shutdowns - 7d" `
            -Value "$shutdownCount"

    }
    catch {}


    #
    # LAST BUGCHECK
    #
    try {

        $bugcheck = Get-WinEvent `
            -FilterHashtable @{
                LogName = "System"
                Id      = 1001
            } `
            -MaxEvents 1 `
            -ErrorAction SilentlyContinue

        if ($bugcheck) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Last Bugcheck" `
                -Value "$($bugcheck.TimeCreated)"
        }
        else {

            Write-StatusLine `
                -Status "PASS" `
                -Label "Last Bugcheck" `
                -Value "None found"
        }

    }
    catch {}


    Write-Host ""
    Write-Host "WINDOWS UPDATE / PATCHING" -ForegroundColor White
    Write-Host "-------------------------"


    #
    # LATEST INSTALLED HOTFIX
    #
    try {

        $latestHotfix = Get-HotFix `
            -ErrorAction Stop |
            Where-Object {
                $_.InstalledOn
            } |
            Sort-Object InstalledOn -Descending |
            Select-Object -First 1

        if ($latestHotfix) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Latest Hotfix" `
                -Value "$($latestHotfix.HotFixID)"

            Write-StatusLine `
                -Status "INFO" `
                -Label "Hotfix Installed" `
                -Value "$($latestHotfix.InstalledOn)"
        }

    }
    catch {}


    #
    # INSTALLED HOTFIX COUNT
    #
    try {

        $hotfixCount = @(
            Get-HotFix `
                -ErrorAction SilentlyContinue
        ).Count

        Write-StatusLine `
            -Status "INFO" `
            -Label "Installed Hotfixes" `
            -Value "$hotfixCount"

    }
    catch {}


    Write-Host ""
    Write-Host "FILES & CONFIGURATION" -ForegroundColor White
    Write-Host "---------------------"


    #
    # HOSTS FILE
    #
    try {

        $hosts = Join-Path `
            $env:SystemRoot `
            "System32\drivers\etc\hosts"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Hosts File" `
            -Value "$hosts"

        if (Test-Path $hosts) {

            $hostsItem = Get-Item `
                $hosts `
                -ErrorAction Stop

            Write-StatusLine `
                -Status "INFO" `
                -Label "Hosts File Modified" `
                -Value "$($hostsItem.LastWriteTime)"
        }

    }
    catch {}


    Write-Host ""
}


Export-ModuleMember -Function Get-SystemExtras