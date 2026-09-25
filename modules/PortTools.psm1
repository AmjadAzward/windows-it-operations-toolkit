function Test-PortInteractive {
    Write-Host "PORT CONNECTIVITY TEST" -ForegroundColor Cyan
    Write-Host "======================"

    $hostName = Read-Host "Host or IP"
    $port = Read-Host "TCP Port"

    if (-not [int]::TryParse($port, [ref]$null)) {
        Write-Host "Invalid port number." -ForegroundColor Red
        return
    }

    try {
        $result = Test-NetConnection -ComputerName $hostName -Port ([int]$port) -WarningAction SilentlyContinue
        Write-StatusLine -Status $(if($result.TcpTestSucceeded){"PASS"}else{"FAIL"}) -Label "TCP $port" -Value "$hostName"
        Write-Host "Remote Address : $($result.RemoteAddress)"
        Write-Host "Source Address : $($result.SourceAddress)"
    } catch {
        Write-Host "Port test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-ListeningPorts {
    Write-Host "LOCAL LISTENING TCP PORTS" -ForegroundColor Cyan
    Write-Host "========================="

    try {
        Get-NetTCPConnection -State Listen -ErrorAction Stop |
            Sort-Object LocalPort |
            Select-Object LocalAddress, LocalPort, OwningProcess,
            @{N="Process";E={
                $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
                if($p){$p.ProcessName}else{"Unknown"}
            }} |
            Format-Table -AutoSize
    } catch {
        Write-Host "Unable to query listening ports." -ForegroundColor Yellow
    }
}

function Show-PortToolsMenu {
    do {
        Clear-Host
        Write-Host "PORT & CONNECTION TOOLS" -ForegroundColor Cyan
        Write-Host "======================="
        Write-Host "1. Test Remote TCP Port"
        Write-Host "2. List Local Listening Ports"
        Write-Host "0. Back"
        $c = Read-Host "Select"

        switch ($c) {
            "1" { Test-PortInteractive }
            "2" { Get-ListeningPorts }
        }

        if ($c -ne "0") { Read-Host "Press ENTER" }
    } while ($c -ne "0")
}

Export-ModuleMember -Function *
