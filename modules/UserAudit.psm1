function Get-LocalUserAudit {

    Write-Host "LOCAL USER AUDIT" -ForegroundColor Cyan
    Write-Host "================"

    if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {

        Get-LocalUser |
            Select-Object `
                Name,
                Enabled,
                PasswordRequired,
                PasswordExpires,
                LastLogon |
            Format-Table -AutoSize

    }
    else {

        Get-CimInstance `
            Win32_UserAccount `
            -Filter "LocalAccount=True" |
            Select-Object `
                Name,
                Disabled,
                Lockout,
                PasswordRequired |
            Format-Table -AutoSize
    }
}


function Get-LocalAdministratorAudit {

    Write-Host "LOCAL ADMINISTRATORS" -ForegroundColor Cyan
    Write-Host "===================="

    if (
        Get-Command `
            Get-LocalGroupMember `
            -ErrorAction SilentlyContinue
    ) {

        Get-LocalGroupMember `
            -Group "Administrators" `
            -ErrorAction SilentlyContinue |
            Select-Object `
                Name,
                ObjectClass,
                PrincipalSource |
            Format-Table -AutoSize

    }
    else {

        net localgroup Administrators
    }
}


function Get-LoggedOnSessions {

    Write-Host "LOGGED-ON SESSIONS" -ForegroundColor Cyan
    Write-Host "=================="

    try {

        quser

    }
    catch {

        Write-Host `
            "Unable to query interactive sessions." `
            -ForegroundColor Yellow
    }
}


function Get-FailedLogons {

    [CmdletBinding()]
    param(
        [int]$Hours = 24
    )

    Write-Host "FAILED LOGON ATTEMPTS - LAST $Hours HOURS" `
        -ForegroundColor Cyan

    try {

        $events = Get-WinEvent `
            -FilterHashtable @{
                LogName   = "Security"
                Id        = 4625
                StartTime = (Get-Date).AddHours(-$Hours)
            } `
            -ErrorAction Stop |
            Select-Object -First 30

        if (-not $events) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "Failed Logons" `
                -Value "None detected"

            return
        }

        $events |
            Select-Object `
                TimeCreated,
                Id,
                @{
                    N = "Message"
                    E = {

                        $m = $_.Message -replace "`r|`n", " "

                        if ($m.Length -gt 180) {
                            $m.Substring(0, 180) + "..."
                        }
                        else {
                            $m
                        }
                    }
                } |
            Format-Table `
                -Wrap `
                -AutoSize
    }
    catch {

        Write-Host `
            "Security log access may require Administrator privileges." `
            -ForegroundColor Yellow
    }
}


function Test-UserAuditAdministrator {

    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = New-Object `
        Security.Principal.WindowsPrincipal(
            $currentIdentity
        )

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}


function Get-ProtectedLocalAccountNames {

    return @(
        "Administrator",
        "Guest",
        "DefaultAccount",
        "WDAGUtilityAccount",
        "defaultuser0"
    )
}


function Disable-LocalUserSafe {

    Clear-Host

    Write-Host "==============================================" `
        -ForegroundColor Cyan

    Write-Host " DISABLE LOCAL USER"

    Write-Host "==============================================" `
        -ForegroundColor Cyan

    Write-Host ""

    if (-not (Test-UserAuditAdministrator)) {

        Write-Host `
            "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }

    if (
        -not (
            Get-Command `
                Disable-LocalUser `
                -ErrorAction SilentlyContinue
        )
    ) {

        Write-Host `
            "Local user management cmdlets are unavailable." `
            -ForegroundColor Red

        return
    }

    Get-LocalUser |
        Select-Object `
            Name,
            Enabled,
            SID |
        Format-Table -AutoSize

    Write-Host ""

    $username = Read-Host "Enter the local username to disable"

    if ([string]::IsNullOrWhiteSpace($username)) {
        return
    }

    if ($username -eq $env:USERNAME) {

        Write-Host ""
        Write-Host `
            "You cannot disable the currently logged-in account." `
            -ForegroundColor Red

        return
    }

    $protected = Get-ProtectedLocalAccountNames

    if ($protected -contains $username) {

        Write-Host ""
        Write-Host `
            "Protected Windows account. Operation blocked." `
            -ForegroundColor Red

        return
    }

    try {

        $user = Get-LocalUser `
            -Name $username `
            -ErrorAction Stop

    }
    catch {

        Write-Host ""
        Write-Host `
            "User account not found." `
            -ForegroundColor Red

        return
    }

    if (-not $user.Enabled) {

        Write-Host ""
        Write-Host `
            "This user account is already disabled." `
            -ForegroundColor Yellow

        return
    }

    Write-Host ""
    Write-Host "Account selected:" -ForegroundColor Yellow
    Write-Host "Username : $($user.Name)"
    Write-Host "SID      : $($user.SID)"
    Write-Host ""

    $confirm = Read-Host "Disable this account? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {

        Write-Host ""
        Write-Host `
            "Operation cancelled." `
            -ForegroundColor Yellow

        return
    }

    try {

        Disable-LocalUser `
            -Name $username `
            -ErrorAction Stop

        Write-Host ""
        Write-Host `
            "User account disabled successfully." `
            -ForegroundColor Green

        try {

            Write-ToolkitLog `
                "Local user '$username' disabled." `
                "WARN"

        }
        catch {}

    }
    catch {

        Write-Host ""
        Write-Host `
            "Unable to disable user account." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Enable-LocalUserSafe {

    Clear-Host

    Write-Host "==============================================" `
        -ForegroundColor Cyan

    Write-Host " ENABLE LOCAL USER"

    Write-Host "==============================================" `
        -ForegroundColor Cyan

    Write-Host ""

    if (-not (Test-UserAuditAdministrator)) {

        Write-Host `
            "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }

    if (
        -not (
            Get-Command `
                Enable-LocalUser `
                -ErrorAction SilentlyContinue
        )
    ) {

        Write-Host `
            "Local user management cmdlets are unavailable." `
            -ForegroundColor Red

        return
    }

    Get-LocalUser |
        Select-Object `
            Name,
            Enabled,
            SID |
        Format-Table -AutoSize

    Write-Host ""

    $username = Read-Host "Enter the local username to enable"

    if ([string]::IsNullOrWhiteSpace($username)) {
        return
    }

    $protected = Get-ProtectedLocalAccountNames

    if ($protected -contains $username) {

        Write-Host ""
        Write-Host `
            "Protected Windows account. Operation blocked." `
            -ForegroundColor Red

        return
    }

    try {

        $user = Get-LocalUser `
            -Name $username `
            -ErrorAction Stop

    }
    catch {

        Write-Host ""
        Write-Host `
            "User account not found." `
            -ForegroundColor Red

        return
    }

    if ($user.Enabled) {

        Write-Host ""
        Write-Host `
            "This user account is already enabled." `
            -ForegroundColor Yellow

        return
    }

    Write-Host ""
    Write-Host "Account selected:" -ForegroundColor Yellow
    Write-Host "Username : $($user.Name)"
    Write-Host "SID      : $($user.SID)"
    Write-Host ""

    $confirm = Read-Host "Enable this account? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {

        Write-Host ""
        Write-Host `
            "Operation cancelled." `
            -ForegroundColor Yellow

        return
    }

    try {

        Enable-LocalUser `
            -Name $username `
            -ErrorAction Stop

        Write-Host ""
        Write-Host `
            "User account enabled successfully." `
            -ForegroundColor Green

        try {

            Write-ToolkitLog `
                "Local user '$username' enabled." `
                "INFO"

        }
        catch {}

    }
    catch {

        Write-Host ""
        Write-Host `
            "Unable to enable user account." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Remove-LocalUserSafe {

    Clear-Host

    Write-Host "==============================================" `
        -ForegroundColor Cyan

    Write-Host " DELETE LOCAL USER ACCOUNT"

    Write-Host "==============================================" `
        -ForegroundColor Cyan

    Write-Host ""

    if (-not (Test-UserAuditAdministrator)) {

        Write-Host `
            "Administrator privileges are required." `
            -ForegroundColor Red

        return
    }

    if (
        -not (
            Get-Command `
                Remove-LocalUser `
                -ErrorAction SilentlyContinue
        )
    ) {

        Write-Host `
            "Local user management cmdlets are unavailable." `
            -ForegroundColor Red

        return
    }

    Get-LocalUser |
        Select-Object `
            Name,
            Enabled,
            SID |
        Format-Table -AutoSize

    Write-Host ""

    $username = Read-Host "Enter the local username to delete"

    if ([string]::IsNullOrWhiteSpace($username)) {
        return
    }

    if ($username -eq $env:USERNAME) {

        Write-Host ""
        Write-Host `
            "You cannot delete the currently logged-in account." `
            -ForegroundColor Red

        return
    }

    $protected = Get-ProtectedLocalAccountNames

    if ($protected -contains $username) {

        Write-Host ""
        Write-Host `
            "Protected Windows account. Deletion blocked." `
            -ForegroundColor Red

        return
    }

    try {

        $user = Get-LocalUser `
            -Name $username `
            -ErrorAction Stop

    }
    catch {

        Write-Host ""
        Write-Host `
            "User account not found." `
            -ForegroundColor Red

        return
    }

    Write-Host ""
    Write-Host "Account selected:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Username : $($user.Name)"
    Write-Host "Enabled  : $($user.Enabled)"
    Write-Host "SID      : $($user.SID)"
    Write-Host ""

    Write-Host "WARNING" -ForegroundColor Red
    Write-Host "-------" -ForegroundColor Red
    Write-Host ""
    Write-Host "This will permanently remove the LOCAL WINDOWS ACCOUNT."
    Write-Host ""
    Write-Host "The user's profile folder will NOT be automatically deleted."
    Write-Host ""
    Write-Host "Example profile data may remain under:"
    Write-Host "C:\Users\$username"
    Write-Host ""

    $confirm = Read-Host "Type DELETE to permanently remove this account"

    if ($confirm -cne "DELETE") {

        Write-Host ""
        Write-Host `
            "Deletion cancelled." `
            -ForegroundColor Yellow

        return
    }

    try {

        Remove-LocalUser `
            -Name $username `
            -ErrorAction Stop

        Write-Host ""
        Write-Host `
            "User account deleted successfully." `
            -ForegroundColor Green

        Write-Host ""
        Write-Host `
            "User profile files were not deleted." `
            -ForegroundColor Yellow

        try {

            Write-ToolkitLog `
                "Local user account '$username' deleted." `
                "WARN"

        }
        catch {}

    }
    catch {

        Write-Host ""
        Write-Host `
            "Unable to delete user account." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Show-UserAuditMenu {

    do {

        Clear-Host

        Write-Host "USER / ADMIN AUDIT" `
            -ForegroundColor Cyan

        Write-Host "=================="
        Write-Host ""
        Write-Host "1. Local Users"
        Write-Host "2. Local Administrators"
        Write-Host "3. Logged-On Sessions"
        Write-Host "4. Failed Logons (24h)"
        Write-Host ""
        Write-Host "USER MANAGEMENT" `
            -ForegroundColor Yellow

        Write-Host "5. Disable Local User"
        Write-Host "6. Enable Local User"
        Write-Host "7. Delete Local User Account"
        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $c = Read-Host "Select"

        switch ($c) {

            "1" {
                Get-LocalUserAudit
            }

            "2" {
                Get-LocalAdministratorAudit
            }

            "3" {
                Get-LoggedOnSessions
            }

            "4" {
                Get-FailedLogons `
                    -Hours 24
            }

            "5" {
                Disable-LocalUserSafe
            }

            "6" {
                Enable-LocalUserSafe
            }

            "7" {
                Remove-LocalUserSafe
            }

            "0" {
                # Back
            }

            default {

                Write-Host ""
                Write-Host `
                    "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 1
            }
        }

        if ($c -ne "0") {

            Write-Host ""
            Read-Host "Press ENTER"
        }

    } while ($c -ne "0")
}


Export-ModuleMember -Function `
    Get-LocalUserAudit, `
    Get-LocalAdministratorAudit, `
    Get-LoggedOnSessions, `
    Get-FailedLogons, `
    Test-UserAuditAdministrator, `
    Get-ProtectedLocalAccountNames, `
    Disable-LocalUserSafe, `
    Enable-LocalUserSafe, `
    Remove-LocalUserSafe, `
    Show-UserAuditMenu