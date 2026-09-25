function Get-WindowsUpdateDiagnostics {
    [CmdletBinding()]
    param()

    Write-Host "WINDOWS UPDATE DIAGNOSTICS" -ForegroundColor Cyan
    Write-Host "=========================="

    $svc = Get-Service wuauserv -ErrorAction SilentlyContinue
    $bits = Get-Service BITS -ErrorAction SilentlyContinue

    if ($svc) {
        Write-StatusLine -Status $(if($svc.Status -eq "Running"){"PASS"}else{"WARN"}) -Label "Windows Update Service" -Value "$($svc.Status)"
    }
    if ($bits) {
        Write-StatusLine -Status $(if($bits.Status -eq "Running"){"PASS"}else{"WARN"}) -Label "BITS" -Value "$($bits.Status)"
    }

    $pending =
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")

    Write-StatusLine -Status $(if($pending){"WARN"}else{"PASS"}) -Label "Pending Reboot" -Value $(if($pending){"YES"}else{"NO"})

    $hotfixes = @(Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 10)
    if ($hotfixes.Count -gt 0) {
        Write-Host ""
        Write-Host "Recent Installed Updates:" -ForegroundColor White
        $hotfixes | Select-Object HotFixID, Description, InstalledOn | Format-Table -AutoSize
    }

    try {
        $autoUpdate = (New-Object -ComObject Microsoft.Update.AutoUpdate)
        $last = $autoUpdate.Results.LastSearchSuccessDate
        Write-StatusLine -Status "INFO" -Label "Last Update Search" -Value "$last"
    } catch {
        Write-StatusLine -Status "INFO" -Label "Last Update Search" -Value "Unavailable"
    }
}

function Start-WindowsUpdateServiceSafe {
    Assert-Administrator
    if (Confirm-Action "Start the Windows Update service?") {
        Start-Service wuauserv
        Write-ToolkitLog "Windows Update service started." "INFO"
    }
}

function Show-WindowsUpdateMenu {
    do {
        Clear-Host
        Write-Host "WINDOWS UPDATE TOOLS" -ForegroundColor Cyan
        Write-Host "===================="
        Write-Host "1. Update Diagnostics"
        Write-Host "2. Start Windows Update Service"
        Write-Host "0. Back"
        $c = Read-Host "Select"

        try {
            switch ($c) {
                "1" { Get-WindowsUpdateDiagnostics }
                "2" { Start-WindowsUpdateServiceSafe }
            }
        } catch {
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        }

        if ($c -ne "0") { Read-Host "Press ENTER" }
    } while ($c -ne "0")
}

Export-ModuleMember -Function *
