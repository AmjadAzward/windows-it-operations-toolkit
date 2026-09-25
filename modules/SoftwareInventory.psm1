function Get-InstalledSoftware {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $software = foreach ($p in $paths) {
        Get-ItemProperty $p -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
    }

    $software | Sort-Object DisplayName -Unique
}

function Get-SoftwareInventory {
    [CmdletBinding()]
    param(
        [switch]$Display,
        [switch]$Summary
    )

    $sw = @(Get-InstalledSoftware)

    Write-Host "SOFTWARE INVENTORY" -ForegroundColor Cyan

    if ($Summary) {
        Write-StatusLine -Status "INFO" -Label "Installed Applications" -Value "$($sw.Count)"
    }

    if ($Display) {
        $sw |
            Format-Table DisplayName, DisplayVersion, Publisher -AutoSize
    }
}

Export-ModuleMember -Function Get-InstalledSoftware, Get-SoftwareInventory
