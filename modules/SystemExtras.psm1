function Get-SystemExtras {
    Write-Host "ADVANCED SYSTEM CHECKS" -ForegroundColor Cyan
    Write-Host "======================"

    # Domain / Workgroup
    $cs = Get-CimInstance Win32_ComputerSystem
    Write-StatusLine -Status "INFO" -Label "Domain / Workgroup" -Value "$($cs.Domain)"
    Write-StatusLine -Status "INFO" -Label "Domain Joined" -Value "$($cs.PartOfDomain)"

    # Proxy
    try {
        $proxy = netsh winhttp show proxy | Out-String
        Write-Host ""
        Write-Host "WinHTTP Proxy:" -ForegroundColor White
        Write-Host $proxy.Trim()
    } catch {}

    # Time sync
    Write-Host ""
    Write-Host "Time Synchronization:" -ForegroundColor White
    try { w32tm /query /status } catch {}

    # Secure Boot
    try {
        $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
        Write-StatusLine -Status $(if($secureBoot){"PASS"}else{"WARN"}) -Label "Secure Boot" -Value "$secureBoot"
    } catch {
        Write-StatusLine -Status "INFO" -Label "Secure Boot" -Value "Unavailable / unsupported"
    }

    # TPM
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        Write-StatusLine -Status $(if($tpm.TpmReady){"PASS"}else{"WARN"}) -Label "TPM Ready" -Value "$($tpm.TpmReady)"
        Write-StatusLine -Status "INFO" -Label "TPM Present" -Value "$($tpm.TpmPresent)"
    } catch {
        Write-StatusLine -Status "INFO" -Label "TPM" -Value "Unavailable"
    }

    # RDP
    try {
        $denyRdp = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections).fDenyTSConnections
        Write-StatusLine -Status "INFO" -Label "Remote Desktop" -Value $(if($denyRdp -eq 0){"Enabled"}else{"Disabled"})
    } catch {}

    # Hosts file
    $hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
    Write-StatusLine -Status "INFO" -Label "Hosts File" -Value $hosts
}

Export-ModuleMember -Function Get-SystemExtras
