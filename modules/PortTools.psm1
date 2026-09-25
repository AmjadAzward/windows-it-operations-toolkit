#Requires -Version 5.1


function Get-PortBindingType {
    param(
        [string]$LocalAddress
    )

    if (
        $LocalAddress -eq "127.0.0.1" -or
        $LocalAddress -eq "::1"
    ) {
        return "Local Only"
    }

    if (
        $LocalAddress -eq "0.0.0.0" -or
        $LocalAddress -eq "::"
    ) {
        return "All Interfaces"
    }

    return "Specific Interface"
}


function Get-PortCategory {
    param(
        [int]$Port,
        [string]$ProcessName
    )

    switch ($Port) {

        53 {
            return "DNS"
        }

        80 {
            return "HTTP Web Server"
        }

        135 {
            return "Windows RPC"
        }

        137 {
            return "NetBIOS"
        }

        138 {
            return "NetBIOS"
        }

        139 {
            return "NetBIOS Session"
        }

        443 {
            return "HTTPS"
        }

        445 {
            return "SMB File Sharing"
        }

        1433 {
            return "Microsoft SQL Server"
        }

        1521 {
            return "Oracle Database"
        }

        3000 {
            return "Development Web Server"
        }

        3306 {
            return "MySQL Database"
        }

        3389 {
            return "Remote Desktop"
        }

        5000 {
            return "Development / Web Service"
        }

        5432 {
            return "PostgreSQL Database"
        }

        5985 {
            return "WinRM HTTP"
        }

        5986 {
            return "WinRM HTTPS"
        }

        7070 {
            return "Remote Access / Application"
        }

        8080 {
            return "HTTP Alternate / Development"
        }

        8443 {
            return "HTTPS Alternate"
        }

        default {

            if ($ProcessName -match "AnyDesk") {
                return "Remote Access"
            }

            if ($ProcessName -match "postgres") {
                return "PostgreSQL Database"
            }

            if ($ProcessName -match "mysql") {
                return "MySQL Database"
            }

            if ($ProcessName -match "node") {
                return "Node.js / Development"
            }

            if ($ProcessName -match "Code") {
                return "Visual Studio Code"
            }

            if ($ProcessName -match "spoolsv") {
                return "Print Spooler"
            }

            if ($ProcessName -match "lsass") {
                return "Windows Security"
            }

            if ($ProcessName -match "svchost") {
                return "Windows Service"
            }

            if ($ProcessName -match "System") {
                return "Windows System"
            }

            return "Application / Service"
        }
    }
}


function Get-PortExposureNote {
    param(
        [string]$Binding,
        [int]$Port,
        [string]$ProcessName
    )

    if ($Binding -eq "Local Only") {
        return "Only accessible from this PC"
    }

    if ($Port -eq 445) {
        return "SMB may be reachable on local network"
    }

    if ($Port -eq 3389) {
        return "Remote Desktop service exposure"
    }

    if ($Port -eq 5432) {
        return "Database listening beyond localhost"
    }

    if ($ProcessName -match "AnyDesk") {
        return "Remote access software"
    }

    if ($ProcessName -match "node") {
        return "Development service listening externally"
    }

    if ($Binding -eq "All Interfaces") {
        return "Listening on all network interfaces"
    }

    return "Listening on a specific network interface"
}


function Get-LocalListeningPorts {

    Write-Host "LOCAL LISTENING TCP PORTS" -ForegroundColor Cyan
    Write-Host "========================="
    Write-Host ""

    try {

        $connections = Get-NetTCPConnection `
            -State Listen `
            -ErrorAction Stop |
            Sort-Object LocalPort, LocalAddress

        if (-not $connections) {

            Write-Host "No listening TCP ports found." `
                -ForegroundColor Yellow

            return
        }

        $results = foreach ($connection in $connections) {

            $processName = "Unknown"

            try {

                $process = Get-Process `
                    -Id $connection.OwningProcess `
                    -ErrorAction Stop

                $processName = $process.ProcessName

            }
            catch {

                if ($connection.OwningProcess -eq 4) {
                    $processName = "System"
                }
            }

            $binding = Get-PortBindingType `
                -LocalAddress $connection.LocalAddress

            $category = Get-PortCategory `
                -Port $connection.LocalPort `
                -ProcessName $processName

            $note = Get-PortExposureNote `
                -Binding $binding `
                -Port $connection.LocalPort `
                -ProcessName $processName

            [PSCustomObject]@{
                LocalAddress  = $connection.LocalAddress
                LocalPort     = $connection.LocalPort
                Process       = $processName
                PID           = $connection.OwningProcess
                Binding       = $binding
                Category      = $category
                Note          = $note
            }
        }

        $results |
            Format-Table `
                LocalPort,
                Process,
                PID,
                Binding,
                Category,
                Note `
                -Wrap `
                -AutoSize

        Write-Host ""
        Write-Host "BINDING LEGEND" -ForegroundColor Cyan
        Write-Host "=============="
        Write-Host ""
        Write-Host "Local Only         : Accessible only from this PC"
        Write-Host "Specific Interface : Bound to one network interface"
        Write-Host "All Interfaces     : Listening on all IPv4/IPv6 interfaces"
        Write-Host ""
        Write-Host "Note: A listening port does not automatically mean it is reachable"
        Write-Host "from the Internet. Windows Firewall and network routing still apply."
        Write-Host ""

    }
    catch {

        Write-Host "Unable to query local listening TCP ports." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Test-RemoteTCPPort {

    Clear-Host

    Write-Host "REMOTE TCP PORT TEST" -ForegroundColor Cyan
    Write-Host "===================="
    Write-Host ""

    $computer = Read-Host "Enter hostname or IP address"

    if ([string]::IsNullOrWhiteSpace($computer)) {
        return
    }

    $portText = Read-Host "Enter TCP port"

    $port = 0

    if (
        -not [int]::TryParse(
            $portText,
            [ref]$port
        )
    ) {

        Write-Host ""
        Write-Host "Invalid port number." `
            -ForegroundColor Red

        return
    }

    if (
        $port -lt 1 -or
        $port -gt 65535
    ) {

        Write-Host ""
        Write-Host "Port must be between 1 and 65535." `
            -ForegroundColor Red

        return
    }

    Write-Host ""
    Write-Host "Testing $computer on TCP port $port..."
    Write-Host ""

    try {

        $result = Test-NetConnection `
            -ComputerName $computer `
            -Port $port `
            -WarningAction SilentlyContinue `
            -ErrorAction Stop

        Write-Host "Remote Host : $computer"
        Write-Host "Remote Port : $port"

        if ($result.RemoteAddress) {
            Write-Host "Resolved IP : $($result.RemoteAddress)"
        }

        if ($result.TcpTestSucceeded) {

            Write-Host "TCP Result  : OPEN / REACHABLE" `
                -ForegroundColor Green
        }
        else {

            Write-Host "TCP Result  : CLOSED / UNREACHABLE" `
                -ForegroundColor Yellow
        }

        if ($result.SourceAddress) {
            Write-Host "Source IP   : $($result.SourceAddress)"
        }

        if ($result.InterfaceAlias) {
            Write-Host "Interface   : $($result.InterfaceAlias)"
        }

    }
    catch {

        Write-Host ""
        Write-Host "Port test failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Show-PortDetails {

    Clear-Host

    Write-Host "PORT DETAILS" -ForegroundColor Cyan
    Write-Host "============"
    Write-Host ""

    $portText = Read-Host "Enter local TCP port"

    $port = 0

    if (
        -not [int]::TryParse(
            $portText,
            [ref]$port
        )
    ) {

        Write-Host ""
        Write-Host "Invalid port number." `
            -ForegroundColor Red

        return
    }

    if (
        $port -lt 1 -or
        $port -gt 65535
    ) {

        Write-Host ""
        Write-Host "Port must be between 1 and 65535." `
            -ForegroundColor Red

        return
    }

    $connections = Get-NetTCPConnection `
        -LocalPort $port `
        -State Listen `
        -ErrorAction SilentlyContinue

    if (-not $connections) {

        Write-Host ""
        Write-Host "No process is currently listening on TCP port $port." `
            -ForegroundColor Yellow

        return
    }

    foreach ($connection in $connections) {

        $processName = "Unknown"
        $processPath = "Unavailable"

        try {

            $process = Get-Process `
                -Id $connection.OwningProcess `
                -ErrorAction Stop

            $processName = $process.ProcessName

            try {
                $processPath = $process.Path
            }
            catch {}

        }
        catch {

            if ($connection.OwningProcess -eq 4) {
                $processName = "System"
            }
        }

        $binding = Get-PortBindingType `
            -LocalAddress $connection.LocalAddress

        $category = Get-PortCategory `
            -Port $connection.LocalPort `
            -ProcessName $processName

        $note = Get-PortExposureNote `
            -Binding $binding `
            -Port $connection.LocalPort `
            -ProcessName $processName

        Write-Host "--------------------------------------------"
        Write-Host "Port          : $($connection.LocalPort)"
        Write-Host "Address       : $($connection.LocalAddress)"
        Write-Host "Process       : $processName"
        Write-Host "PID           : $($connection.OwningProcess)"
        Write-Host "Process Path  : $processPath"
        Write-Host "Binding       : $binding"
        Write-Host "Category      : $category"
        Write-Host "Note          : $note"
        Write-Host ""
    }
}


function Show-PortToolsMenu {

    do {

        Clear-Host

        Write-Host "PORT & CONNECTION TOOLS" `
            -ForegroundColor Cyan

        Write-Host "======================="
        Write-Host ""

        Write-Host "1. Test Remote TCP Port"
        Write-Host "2. List Local Listening Ports"
        Write-Host "3. Inspect Local Port"
        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {

                Test-RemoteTCPPort

                Write-Host ""
                Read-Host "Press ENTER"
            }


            "2" {

                Clear-Host

                Get-LocalListeningPorts

                Write-Host ""
                Read-Host "Press ENTER"
            }


            "3" {

                Show-PortDetails

                Write-Host ""
                Read-Host "Press ENTER"
            }


            "0" {
                # Back
            }


            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 1
            }
        }

    } while ($choice -ne "0")
}


Export-ModuleMember -Function `
    Get-PortBindingType, `
    Get-PortCategory, `
    Get-PortExposureNote, `
    Get-LocalListeningPorts, `
    Test-RemoteTCPPort, `
    Show-PortDetails, `
    Show-PortToolsMenu