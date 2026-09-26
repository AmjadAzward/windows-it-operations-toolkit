#Requires -Version 5.1


# ============================================================
# ADMINISTRATOR CHECK
# ============================================================

function Test-NetworkAdministrator {

    try {

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        $principal = New-Object `
            Security.Principal.WindowsPrincipal($identity)

        return $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )
    }
    catch {

        return $false
    }
}


# ============================================================
# ACTIVE NETWORK ADAPTER
# ============================================================

function Get-PrimaryNetworkConfiguration {

    try {

        $configs = Get-NetIPConfiguration `
            -ErrorAction Stop |
            Where-Object {
                $_.NetAdapter.Status -eq "Up" -and
                $_.IPv4Address -and
                $_.IPv4DefaultGateway
            }

        if ($configs) {

            return $configs |
                Select-Object -First 1
        }


        $configs = Get-NetIPConfiguration `
            -ErrorAction Stop |
            Where-Object {
                $_.NetAdapter.Status -eq "Up" -and
                $_.IPv4Address
            }

        return $configs |
            Select-Object -First 1
    }
    catch {

        return $null
    }
}


# ============================================================
# NETWORK DIAGNOSTICS
# ============================================================

function Get-NetworkDiagnostics {

    [CmdletBinding()]
    param(
        [switch]$Detailed
    )

    Write-Host "NETWORK DIAGNOSTICS" `
        -ForegroundColor Cyan

    Write-Host "==================="
    Write-Host ""

    $primary = Get-PrimaryNetworkConfiguration


    # --------------------------------------------------------
    # Adapter
    # --------------------------------------------------------

    if ($primary) {

        Write-StatusLine `
            -Status "PASS" `
            -Label "Adapter" `
            -Value "$($primary.InterfaceAlias)"
    }
    else {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Adapter" `
            -Value "No active adapter with IPv4 detected"
    }


    # --------------------------------------------------------
    # IPv4
    # --------------------------------------------------------

    if ($primary -and $primary.IPv4Address) {

        $ipv4 = (
            $primary.IPv4Address |
            Select-Object -First 1
        ).IPAddress

        Write-StatusLine `
            -Status "INFO" `
            -Label "IPv4" `
            -Value "$ipv4"
    }
    else {

        Write-StatusLine `
            -Status "WARN" `
            -Label "IPv4" `
            -Value "Not assigned"
    }


    # --------------------------------------------------------
    # Gateway
    # --------------------------------------------------------

    $gateway = $null

    if (
        $primary -and
        $primary.IPv4DefaultGateway
    ) {

        $gateway = (
            $primary.IPv4DefaultGateway |
            Select-Object -First 1
        ).NextHop

        Write-StatusLine `
            -Status "INFO" `
            -Label "Gateway" `
            -Value "$gateway"
    }
    else {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Gateway" `
            -Value "Not configured"
    }


    # --------------------------------------------------------
    # DNS
    # --------------------------------------------------------

    if (
        $primary -and
        $primary.DNSServer.ServerAddresses
    ) {

        $dnsAddresses = @(
            $primary.DNSServer.ServerAddresses |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        )

        Write-StatusLine `
            -Status "INFO" `
            -Label "DNS" `
            -Value "$($dnsAddresses -join ', ')"
    }
    else {

        Write-StatusLine `
            -Status "WARN" `
            -Label "DNS" `
            -Value "No DNS servers detected"
    }


    # --------------------------------------------------------
    # Gateway Test
    # --------------------------------------------------------

    if ($gateway) {

        try {

            $gatewayResult = Test-Connection `
                -ComputerName $gateway `
                -Count 1 `
                -Quiet `
                -ErrorAction SilentlyContinue

            if ($gatewayResult) {

                Write-StatusLine `
                    -Status "PASS" `
                    -Label "Gateway Connectivity" `
                    -Value "$gateway"
            }
            else {

                Write-StatusLine `
                    -Status "WARN" `
                    -Label "Gateway Connectivity" `
                    -Value "No response from $gateway"
            }
        }
        catch {

            Write-StatusLine `
                -Status "WARN" `
                -Label "Gateway Connectivity" `
                -Value "Test failed"
        }
    }


    # --------------------------------------------------------
    # Internet Connectivity
    # --------------------------------------------------------

    try {

        $internet = Test-Connection `
            -ComputerName "1.1.1.1" `
            -Count 1 `
            -Quiet `
            -ErrorAction SilentlyContinue

        if ($internet) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "Internet Connectivity" `
                -Value "1.1.1.1"
        }
        else {

            Write-StatusLine `
                -Status "WARN" `
                -Label "Internet Connectivity" `
                -Value "Unable to reach 1.1.1.1"
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Internet Connectivity" `
            -Value "Test failed"
    }


    # --------------------------------------------------------
    # DNS Resolution
    # --------------------------------------------------------

    try {

        $dnsTest = Resolve-DnsName `
            -Name "www.microsoft.com" `
            -ErrorAction Stop |
            Select-Object -First 1

        if ($dnsTest) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "DNS Resolution" `
                -Value "www.microsoft.com"
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "DNS Resolution" `
            -Value "Failed"
    }


    # --------------------------------------------------------
    # Adapter Table
    # --------------------------------------------------------

    Write-Host ""

    try {

        $adapterTable = foreach (
            $config in Get-NetIPConfiguration `
                -ErrorAction SilentlyContinue
        ) {

            $address = ""

            if ($config.IPv4Address) {

                $address = (
                    $config.IPv4Address |
                    Select-Object -First 1
                ).IPAddress
            }


            $adapterGateway = ""

            if ($config.IPv4DefaultGateway) {

                $adapterGateway = (
                    $config.IPv4DefaultGateway |
                    Select-Object -First 1
                ).NextHop
            }


            if (
                $address -or
                $adapterGateway
            ) {

                [PSCustomObject]@{
                    InterfaceAlias = $config.InterfaceAlias
                    IPv4           = $address
                    Gateway        = $adapterGateway
                }
            }
        }


        if ($adapterTable) {

            $adapterTable |
                Format-Table `
                    InterfaceAlias,
                    IPv4,
                    Gateway `
                    -AutoSize
        }
    }
    catch {}


    # --------------------------------------------------------
    # Detailed Information
    # --------------------------------------------------------

    if ($Detailed) {

        Write-Host ""
        Write-Host "DETAILED NETWORK INFORMATION" `
            -ForegroundColor Cyan

        Write-Host "============================"
        Write-Host ""


        try {

            Get-NetAdapter `
                -ErrorAction Stop |
                Select-Object `
                    Name,
                    InterfaceDescription,
                    Status,
                    LinkSpeed,
                    MacAddress |
                Format-Table `
                    -AutoSize `
                    -Wrap

        }
        catch {}


        Write-Host ""


        try {

            Write-Host "NETWORK PROFILES" `
                -ForegroundColor White

            Write-Host ""

            Get-NetConnectionProfile `
                -ErrorAction Stop |
                Select-Object `
                    Name,
                    InterfaceAlias,
                    NetworkCategory,
                    IPv4Connectivity,
                    IPv6Connectivity |
                Format-Table `
                    -AutoSize

        }
        catch {}


        Write-Host ""


        try {

            Write-Host "IP CONFIGURATION" `
                -ForegroundColor White

            Write-Host ""

            Get-NetIPConfiguration `
                -ErrorAction Stop |
                ForEach-Object {

                    $ipv4Address = ""

                    if ($_.IPv4Address) {

                        $ipv4Address = (
                            $_.IPv4Address |
                            Select-Object -First 1
                        ).IPAddress
                    }


                    $gw = ""

                    if ($_.IPv4DefaultGateway) {

                        $gw = (
                            $_.IPv4DefaultGateway |
                            Select-Object -First 1
                        ).NextHop
                    }


                    [PSCustomObject]@{
                        Interface = $_.InterfaceAlias
                        IPv4      = $ipv4Address
                        Gateway   = $gw
                        DNS       = (
                            $_.DNSServer.ServerAddresses -join ", "
                        )
                    }
                } |
                Format-Table `
                    -AutoSize `
                    -Wrap

        }
        catch {}
    }
}


# ============================================================
# DNS CACHE
# ============================================================

function Clear-NetworkDNSCache {

    Clear-Host

    Write-Host "FLUSH DNS CACHE" `
        -ForegroundColor Cyan

    Write-Host "==============="
    Write-Host ""

    try {

        ipconfig /flushdns |
            Out-Host

        Write-Host ""
        Write-Host "DNS cache flushed successfully." `
            -ForegroundColor Green

        try {

            Write-ToolkitLog `
                "DNS cache flushed." `
                "INFO"

        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Unable to flush DNS cache." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


# ============================================================
# DHCP RELEASE / RENEW
# ============================================================

function Renew-NetworkDHCP {

    Clear-Host

    Write-Host "RENEW DHCP ADDRESS" `
        -ForegroundColor Cyan

    Write-Host "=================="
    Write-Host ""

    Write-Host "This releases and renews DHCP addresses."
    Write-Host ""
    Write-Host "Network connectivity will temporarily disconnect." `
        -ForegroundColor Yellow

    Write-Host ""

    $confirm = Read-Host "Continue? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {

        Write-Host ""
        Write-Host "Operation cancelled." `
            -ForegroundColor Yellow

        return
    }


    try {

        Write-Host ""
        Write-Host "Releasing DHCP address..."

        ipconfig /release |
            Out-Host


        Write-Host ""
        Write-Host "Renewing DHCP address..."

        ipconfig /renew |
            Out-Host


        Write-Host ""
        Write-Host "DHCP renewal completed." `
            -ForegroundColor Green


        try {

            Write-ToolkitLog `
                "DHCP release and renew completed." `
                "INFO"

        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "DHCP renewal failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


# ============================================================
# WINSOCK RESET
# ============================================================

function Reset-NetworkWinsock {

    Clear-Host

    Write-Host "RESET WINSOCK" `
        -ForegroundColor Cyan

    Write-Host "============="
    Write-Host ""

    if (-not (Test-NetworkAdministrator)) {

        Write-Host "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }


    Write-Host "This resets the Windows Winsock catalog."
    Write-Host ""
    Write-Host "A Windows restart may be required." `
        -ForegroundColor Yellow

    Write-Host ""

    $confirm = Read-Host "Reset Winsock? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }


    try {

        netsh winsock reset |
            Out-Host

        Write-Host ""
        Write-Host "Winsock reset completed." `
            -ForegroundColor Green

        Write-Host ""
        Write-Host "Restart Windows to complete the reset if required." `
            -ForegroundColor Yellow


        try {

            Write-ToolkitLog `
                "Winsock reset completed." `
                "INFO"

        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Winsock reset failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


# ============================================================
# TCP/IP RESET
# ============================================================

function Reset-NetworkTCPIP {

    Clear-Host

    Write-Host "RESET TCP/IP STACK" `
        -ForegroundColor Cyan

    Write-Host "=================="
    Write-Host ""

    if (-not (Test-NetworkAdministrator)) {

        Write-Host "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }


    Write-Host "This resets the Windows TCP/IP stack."
    Write-Host ""
    Write-Host "A Windows restart is recommended afterward." `
        -ForegroundColor Yellow

    Write-Host ""

    $confirm = Read-Host "Reset TCP/IP stack? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }


    try {

        netsh int ip reset |
            Out-Host

        Write-Host ""
        Write-Host "TCP/IP stack reset completed." `
            -ForegroundColor Green

        Write-Host ""
        Write-Host "Restart Windows to complete the reset." `
            -ForegroundColor Yellow


        try {

            Write-ToolkitLog `
                "TCP/IP stack reset completed." `
                "INFO"

        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "TCP/IP reset failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


# ============================================================
# ARP CACHE
# ============================================================

function Clear-NetworkARPCache {

    Clear-Host

    Write-Host "CLEAR ARP CACHE" `
        -ForegroundColor Cyan

    Write-Host "==============="
    Write-Host ""

    if (-not (Test-NetworkAdministrator)) {

        Write-Host "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }


    try {

        netsh interface ip delete arpcache |
            Out-Host

        Write-Host ""
        Write-Host "ARP cache cleared successfully." `
            -ForegroundColor Green


        try {

            Write-ToolkitLog `
                "ARP cache cleared." `
                "INFO"

        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Unable to clear ARP cache." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


# ============================================================
# NETWORK ADAPTER RESTART
# ============================================================

function Restart-NetworkAdapterSafe {

    Clear-Host

    Write-Host "RESTART NETWORK ADAPTER" `
        -ForegroundColor Cyan

    Write-Host "======================="
    Write-Host ""

    if (-not (Test-NetworkAdministrator)) {

        Write-Host "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }


    try {

        $adapters = @(
            Get-NetAdapter `
                -ErrorAction Stop |
                Where-Object {
                    $_.Status -ne "Disabled"
                } |
                Sort-Object Name
        )


        if ($adapters.Count -eq 0) {

            Write-Host "No available network adapters found." `
                -ForegroundColor Yellow

            return
        }


        for (
            $i = 0;
            $i -lt $adapters.Count;
            $i++
        ) {

            Write-Host (
                "{0}. {1} - {2} - {3}" -f `
                ($i + 1),
                $adapters[$i].Name,
                $adapters[$i].Status,
                $adapters[$i].InterfaceDescription
            )
        }


        Write-Host ""
        Write-Host "0. Cancel"
        Write-Host ""

        $selection = Read-Host "Select adapter"

        $number = 0

        if (
            -not [int]::TryParse(
                $selection,
                [ref]$number
            )
        ) {

            Write-Host ""
            Write-Host "Invalid selection." `
                -ForegroundColor Red

            return
        }


        if ($number -eq 0) {
            return
        }


        if (
            $number -lt 1 -or
            $number -gt $adapters.Count
        ) {

            Write-Host ""
            Write-Host "Invalid adapter selection." `
                -ForegroundColor Red

            return
        }


        $adapter = $adapters[$number - 1]


        Write-Host ""
        Write-Host "Selected Adapter : $($adapter.Name)"
        Write-Host "Status           : $($adapter.Status)"
        Write-Host ""

        Write-Host "WARNING: Restarting the active network adapter will" `
            -ForegroundColor Yellow

        Write-Host "temporarily disconnect this computer from the network." `
            -ForegroundColor Yellow

        Write-Host ""

        $confirm = Read-Host "Restart this adapter? [Y/N]"

        if ($confirm -notmatch "^[Yy]$") {
            return
        }


        Write-Host ""
        Write-Host "Disabling $($adapter.Name)..."

        Disable-NetAdapter `
            -Name $adapter.Name `
            -Confirm:$false `
            -ErrorAction Stop


        Start-Sleep `
            -Seconds 3


        Write-Host "Enabling $($adapter.Name)..."

        Enable-NetAdapter `
            -Name $adapter.Name `
            -Confirm:$false `
            -ErrorAction Stop


        Start-Sleep `
            -Seconds 3


        Write-Host ""
        Write-Host "Network adapter restarted successfully." `
            -ForegroundColor Green


        try {

            Write-ToolkitLog `
                "Network adapter '$($adapter.Name)' restarted." `
                "INFO"

        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Unable to restart network adapter." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


# ============================================================
# NETWORK SERVICES
# ============================================================

function Restart-NetworkServices {

    Clear-Host

    Write-Host "RESTART NETWORK SERVICES" `
        -ForegroundColor Cyan

    Write-Host "========================"
    Write-Host ""

    if (-not (Test-NetworkAdministrator)) {

        Write-Host "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }


    Write-Host "Windows may prevent some protected services from restarting."
    Write-Host ""

    $confirm = Read-Host "Restart supported network services? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }


    $services = @(
        "Dnscache",
        "Dhcp",
        "NlaSvc"
    )


    foreach ($serviceName in $services) {

        try {

            $service = Get-Service `
                -Name $serviceName `
                -ErrorAction Stop


            Write-Host ""
            Write-Host "Service : $($service.DisplayName)"
            Write-Host "Status  : $($service.Status)"


            Restart-Service `
                -Name $serviceName `
                -Force `
                -ErrorAction Stop


            Write-Host "Result  : Restarted" `
                -ForegroundColor Green
        }
        catch {

            Write-Host "Result  : Could not restart $serviceName" `
                -ForegroundColor Yellow
        }
    }


    try {

        Write-ToolkitLog `
            "Network service restart attempted." `
            "INFO"

    }
    catch {}
}


# ============================================================
# FULL NETWORK RESET
# ============================================================

function Invoke-FullNetworkReset {

    Clear-Host

    Write-Host "FULL NETWORK RESET" `
        -ForegroundColor Cyan

    Write-Host "=================="
    Write-Host ""

    if (-not (Test-NetworkAdministrator)) {

        Write-Host "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }


    Write-Host "This operation will perform:"
    Write-Host ""
    Write-Host " 1. Flush DNS cache"
    Write-Host " 2. Clear ARP cache"
    Write-Host " 3. Reset Winsock"
    Write-Host " 4. Reset TCP/IP stack"
    Write-Host ""

    Write-Host "IMPORTANT" `
        -ForegroundColor Yellow

    Write-Host "---------"
    Write-Host "Network settings will be modified."
    Write-Host "A Windows restart is recommended afterward."
    Write-Host ""

    Write-Host "This does NOT delete saved Wi-Fi profiles." `
        -ForegroundColor DarkGray

    Write-Host ""

    $confirm = Read-Host "Type RESET to continue"

    if ($confirm -cne "RESET") {

        Write-Host ""
        Write-Host "Full network reset cancelled." `
            -ForegroundColor Yellow

        return
    }


    try {

        Write-Host ""
        Write-Host "[1/4] Flushing DNS cache..." `
            -ForegroundColor Cyan

        ipconfig /flushdns |
            Out-Host


        Write-Host ""
        Write-Host "[2/4] Clearing ARP cache..." `
            -ForegroundColor Cyan

        netsh interface ip delete arpcache |
            Out-Host


        Write-Host ""
        Write-Host "[3/4] Resetting Winsock..." `
            -ForegroundColor Cyan

        netsh winsock reset |
            Out-Host


        Write-Host ""
        Write-Host "[4/4] Resetting TCP/IP stack..." `
            -ForegroundColor Cyan

        netsh int ip reset |
            Out-Host


        Write-Host ""
        Write-Host "========================================" `
            -ForegroundColor Green

        Write-Host "FULL NETWORK RESET COMPLETED" `
            -ForegroundColor Green

        Write-Host "========================================" `
            -ForegroundColor Green

        Write-Host ""
        Write-Host "Restart Windows to complete the repair." `
            -ForegroundColor Yellow


        try {

            Write-ToolkitLog `
                "Full network reset completed." `
                "INFO"

        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Full network reset encountered an error." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


# ============================================================
# OPEN WINDOWS NETWORK SETTINGS
# ============================================================

function Open-WindowsNetworkSettings {

    Clear-Host

    Write-Host "WINDOWS NETWORK SETTINGS" `
        -ForegroundColor Cyan

    Write-Host "========================"
    Write-Host ""

    try {

        Start-Process `
            "ms-settings:network"

        Write-Host "Windows Network settings opened." `
            -ForegroundColor Green
    }
    catch {

        Write-Host "Unable to open Windows Network settings." `
            -ForegroundColor Red
    }
}


# ============================================================
# SHOW IP CONFIG
# ============================================================

function Show-NetworkIPConfiguration {

    Clear-Host

    Write-Host "IP CONFIGURATION" `
        -ForegroundColor Cyan

    Write-Host "================"
    Write-Host ""

    ipconfig /all |
        Out-Host
}


# ============================================================
# SHOW ROUTING TABLE
# ============================================================

function Show-NetworkRoutingTable {

    Clear-Host

    Write-Host "NETWORK ROUTING TABLE" `
        -ForegroundColor Cyan

    Write-Host "====================="
    Write-Host ""

    try {

        Get-NetRoute `
            -AddressFamily IPv4 `
            -ErrorAction Stop |
            Sort-Object `
                RouteMetric,
                DestinationPrefix |
            Select-Object `
                DestinationPrefix,
                NextHop,
                InterfaceAlias,
                RouteMetric |
            Format-Table `
                -AutoSize

    }
    catch {

        route print |
            Out-Host
    }
}


# ============================================================
# DNS SERVER TEST
# ============================================================

function Test-NetworkDNS {

    Clear-Host

    Write-Host "DNS TEST" `
        -ForegroundColor Cyan

    Write-Host "========"
    Write-Host ""

    $domain = Read-Host "Domain to test [www.microsoft.com]"

    if ([string]::IsNullOrWhiteSpace($domain)) {

        $domain = "www.microsoft.com"
    }


    try {

        $result = Resolve-DnsName `
            -Name $domain `
            -ErrorAction Stop


        Write-Host ""
        Write-Host "DNS resolution successful." `
            -ForegroundColor Green

        Write-Host ""

        $result |
            Select-Object `
                Name,
                Type,
                IPAddress,
                NameHost |
            Format-Table `
                -AutoSize
    }
    catch {

        Write-Host ""
        Write-Host "DNS resolution failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


# ============================================================
# PING TEST
# ============================================================

function Test-NetworkPing {

    Clear-Host

    Write-Host "PING TEST" `
        -ForegroundColor Cyan

    Write-Host "========="
    Write-Host ""

    $target = Read-Host "Hostname or IP address"

    if ([string]::IsNullOrWhiteSpace($target)) {
        return
    }


    Write-Host ""

    try {

        Test-Connection `
            -ComputerName $target `
            -Count 4 `
            -ErrorAction Stop |
            Select-Object `
                Address,
                ResponseTime,
                StatusCode |
            Format-Table `
                -AutoSize

    }
    catch {

        Write-Host ""
        Write-Host "Ping test failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


# ============================================================
# NETWORK RESET MENU
# ============================================================

function Show-NetworkResetMenu {

    do {

        Clear-Host

        Write-Host "NETWORK RESET & REPAIR" `
            -ForegroundColor Cyan

        Write-Host "======================"
        Write-Host ""

        Write-Host "1. Flush DNS Cache"
        Write-Host "2. Renew DHCP Address"
        Write-Host "3. Reset Winsock"
        Write-Host "4. Reset TCP/IP Stack"
        Write-Host "5. Clear ARP Cache"
        Write-Host "6. Restart Network Adapter"
        Write-Host "7. Restart Network Services"
        Write-Host "8. Full Network Reset"
        Write-Host "9. Open Windows Network Settings"

        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"


        switch ($choice) {

            "1" {

                Clear-NetworkDNSCache
            }


            "2" {

                Renew-NetworkDHCP
            }


            "3" {

                Reset-NetworkWinsock
            }


            "4" {

                Reset-NetworkTCPIP
            }


            "5" {

                Clear-NetworkARPCache
            }


            "6" {

                Restart-NetworkAdapterSafe
            }


            "7" {

                Restart-NetworkServices
            }


            "8" {

                Invoke-FullNetworkReset
            }


            "9" {

                Open-WindowsNetworkSettings
            }


            "0" {}


            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep `
                    -Seconds 1
            }
        }


        if (
            $choice -ne "0" -and
            $choice -ne "9"
        ) {

            Write-Host ""
            Read-Host "Press ENTER"
        }

    } while ($choice -ne "0")
}


# ============================================================
# MAIN NETWORK TOOLS MENU
# ============================================================

function Show-NetworkToolsMenu {

    do {

        Clear-Host

        Write-Host "NETWORK DIAGNOSTICS & REPAIR" `
            -ForegroundColor Cyan

        Write-Host "============================"
        Write-Host ""

        Write-Host "DIAGNOSTICS" `
            -ForegroundColor Yellow

        Write-Host "1. Run Network Diagnostics"
        Write-Host "2. Detailed Network Diagnostics"
        Write-Host "3. Test Ping"
        Write-Host "4. Test DNS Resolution"
        Write-Host "5. Show IP Configuration"
        Write-Host "6. Show Routing Table"

        Write-Host ""

        Write-Host "REPAIR" `
            -ForegroundColor Yellow

        Write-Host "7. Network Reset & Repair"

        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"


        switch ($choice) {

            "1" {

                Clear-Host

                Get-NetworkDiagnostics
            }


            "2" {

                Clear-Host

                Get-NetworkDiagnostics `
                    -Detailed
            }


            "3" {

                Test-NetworkPing
            }


            "4" {

                Test-NetworkDNS
            }


            "5" {

                Show-NetworkIPConfiguration
            }


            "6" {

                Show-NetworkRoutingTable
            }


            "7" {

                Show-NetworkResetMenu
            }


            "0" {}


            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep `
                    -Seconds 1
            }
        }


        if (
            $choice -ne "0" -and
            $choice -ne "7"
        ) {

            Write-Host ""
            Read-Host "Press ENTER"
        }

    } while ($choice -ne "0")
}


# ============================================================
# EXPORT FUNCTIONS
# ============================================================

Export-ModuleMember -Function `
    Test-NetworkAdministrator, `
    Get-PrimaryNetworkConfiguration, `
    Get-NetworkDiagnostics, `
    Clear-NetworkDNSCache, `
    Renew-NetworkDHCP, `
    Reset-NetworkWinsock, `
    Reset-NetworkTCPIP, `
    Clear-NetworkARPCache, `
    Restart-NetworkAdapterSafe, `
    Restart-NetworkServices, `
    Invoke-FullNetworkReset, `
    Open-WindowsNetworkSettings, `
    Show-NetworkIPConfiguration, `
    Show-NetworkRoutingTable, `
    Test-NetworkDNS, `
    Test-NetworkPing, `
    Show-NetworkResetMenu, `
    Show-NetworkToolsMenu