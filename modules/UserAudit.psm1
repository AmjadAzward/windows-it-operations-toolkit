function Get-LocalUserAudit {
    Write-Host "LOCAL USER AUDIT" -ForegroundColor Cyan
    Write-Host "================"

    if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
        Get-LocalUser |
            Select-Object Name, Enabled, PasswordRequired, PasswordExpires, LastLogon |
            Format-Table -AutoSize
    } else {
        Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True" |
            Select-Object Name, Disabled, Lockout, PasswordRequired |
            Format-Table -AutoSize
    }
}

function Get-LocalAdministratorAudit {
    Write-Host "LOCAL ADMINISTRATORS" -ForegroundColor Cyan
    Write-Host "===================="

    if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
        Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue |
            Select-Object Name, ObjectClass, PrincipalSource |
            Format-Table -AutoSize
    } else {
        net localgroup Administrators
    }
}

function Get-LoggedOnSessions {
    Write-Host "LOGGED-ON SESSIONS" -ForegroundColor Cyan
    try {
        quser
    } catch {
        Write-Host "Unable to query interactive sessions." -ForegroundColor Yellow
    }
}

function Get-FailedLogons {
    [CmdletBinding()]
    param([int]$Hours = 24)

    Write-Host "FAILED LOGON ATTEMPTS - LAST $Hours HOURS" -ForegroundColor Cyan

    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName = "Security"
            Id = 4625
            StartTime = (Get-Date).AddHours(-$Hours)
        } -ErrorAction Stop | Select-Object -First 30

        if (-not $events) {
            Write-StatusLine -Status "PASS" -Label "Failed Logons" -Value "None detected"
            return
        }

        $events |
            Select-Object TimeCreated, Id,
            @{N="Message";E={
                $m = $_.Message -replace "`r|`n"," "
                if($m.Length -gt 180){$m.Substring(0,180)+"..."}else{$m}
            }} |
            Format-Table -Wrap -AutoSize
    } catch {
        Write-Host "Security log access may require Administrator privileges." -ForegroundColor Yellow
    }
}

function Show-UserAuditMenu {
    do {
        Clear-Host
        Write-Host "USER / ADMIN AUDIT" -ForegroundColor Cyan
        Write-Host "=================="
        Write-Host "1. Local Users"
        Write-Host "2. Local Administrators"
        Write-Host "3. Logged-On Sessions"
        Write-Host "4. Failed Logons (24h)"
        Write-Host "0. Back"

        $c = Read-Host "Select"
        switch ($c) {
            "1" { Get-LocalUserAudit }
            "2" { Get-LocalAdministratorAudit }
            "3" { Get-LoggedOnSessions }
            "4" { Get-FailedLogons -Hours 24 }
        }
        if ($c -ne "0") { Read-Host "Press ENTER" }
    } while ($c -ne "0")
}

Export-ModuleMember -Function *
