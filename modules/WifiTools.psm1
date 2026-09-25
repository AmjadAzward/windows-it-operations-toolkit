function Get-WifiDiagnostics {
    Write-Host "WI-FI DIAGNOSTICS" -ForegroundColor Cyan
    Write-Host "================="

    try {
        $output = netsh wlan show interfaces
        $output
    } catch {
        Write-Host "Unable to query Wi-Fi interfaces." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Saved Wi-Fi Profiles:" -ForegroundColor White
    try {
        netsh wlan show profiles
    } catch {}

    $wifi = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match "Wireless|Wi-Fi|802\.11" -or $_.Name -match "Wi-Fi|Wireless" } |
        Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress

    if ($wifi) {
        Write-Host ""
        $wifi | Format-Table -AutoSize
    }
}

Export-ModuleMember -Function Get-WifiDiagnostics
