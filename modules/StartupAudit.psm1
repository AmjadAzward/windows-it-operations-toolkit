function Get-StartupAudit {
    Write-Host "STARTUP PROGRAM AUDIT" -ForegroundColor Cyan
    Write-Host "====================="

    $items = @()

    $items += Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
        Select-Object Name, Command, Location, User

    if (-not $items) {
        Write-StatusLine -Status "PASS" -Label "Startup Items" -Value "No startup entries detected"
        return
    }

    $items | Sort-Object Name | Format-Table -Wrap -AutoSize
    Write-Host ""
    Write-Host "Tip: Review unfamiliar or unnecessary startup items before disabling anything." -ForegroundColor DarkGray
}

Export-ModuleMember -Function Get-StartupAudit
