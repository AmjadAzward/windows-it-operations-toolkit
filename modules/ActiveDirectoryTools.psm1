#Requires -Version 5.1


function Test-ADAdministrator {

    try {

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        $principal = New-Object `
            Security.Principal.WindowsPrincipal(
                $identity
            )

        return $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )
    }
    catch {

        return $false
    }
}


function Get-ADRSATStatus {

    Write-Host "RSAT / ACTIVE DIRECTORY STATUS" -ForegroundColor Cyan
    Write-Host "=============================="
    Write-Host ""

    try {

        $capability = Get-WindowsCapability `
            -Online `
            -ErrorAction Stop |
            Where-Object {
                $_.Name -like "Rsat.ActiveDirectory.DS-LDS.Tools*"
            } |
            Select-Object -First 1

        if (-not $capability) {

            Write-StatusLine `
                -Status "WARN" `
                -Label "RSAT AD Tools" `
                -Value "Capability not found"

            return
        }

        $status = switch ($capability.State) {

            "Installed" {
                "PASS"
            }

            "NotPresent" {
                "WARN"
            }

            default {
                "INFO"
            }
        }

        Write-StatusLine `
            -Status $status `
            -Label "RSAT AD Tools" `
            -Value "$($capability.State)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Capability Name" `
            -Value "$($capability.Name)"
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "RSAT Status" `
            -Value "Unable to query"

        Write-Host ""
        Write-Host $_.Exception.Message `
            -ForegroundColor DarkYellow
    }


    try {

        $module = Get-Module `
            -ListAvailable `
            -Name ActiveDirectory `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($module) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "ActiveDirectory Module" `
                -Value "$($module.Version)"
        }
        else {

            Write-StatusLine `
                -Status "WARN" `
                -Label "ActiveDirectory Module" `
                -Value "Not installed"
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "ActiveDirectory Module" `
            -Value "Unable to verify"
    }
}


function Install-ADRSATTools {

    Clear-Host

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host " INSTALL ACTIVE DIRECTORY RSAT TOOLS"

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    if (-not (Test-ADAdministrator)) {

        Write-Host `
            "Administrator privileges are required to install RSAT." `
            -ForegroundColor Red

        return
    }

    try {

        $capability = Get-WindowsCapability `
            -Online `
            -ErrorAction Stop |
            Where-Object {
                $_.Name -like "Rsat.ActiveDirectory.DS-LDS.Tools*"
            } |
            Select-Object -First 1

        if (-not $capability) {

            Write-Host `
                "The Active Directory RSAT capability was not found on this Windows installation." `
                -ForegroundColor Yellow

            return
        }

        if ($capability.State -eq "Installed") {

            Write-Host `
                "Active Directory RSAT tools are already installed." `
                -ForegroundColor Green

            return
        }

        Write-Host "Capability:"
        Write-Host $capability.Name
        Write-Host ""

        Write-Host "This will install Microsoft's Active Directory RSAT tools."
        Write-Host "Windows may need access to Windows Update or your organization's"
        Write-Host "configured feature source."
        Write-Host ""

        $confirm = Read-Host "Install RSAT Active Directory tools? [Y/N]"

        if ($confirm -notmatch "^[Yy]$") {

            Write-Host ""
            Write-Host "Installation cancelled." `
                -ForegroundColor Yellow

            return
        }

        Write-Host ""
        Write-Host "Installing RSAT Active Directory tools..."
        Write-Host ""

        $result = Add-WindowsCapability `
            -Online `
            -Name $capability.Name `
            -ErrorAction Stop

        Write-Host ""

        Write-Host "Installation State : $($result.State)" `
            -ForegroundColor Green

        if ($result.RestartNeeded) {

            Write-Host "Restart Required    : Yes" `
                -ForegroundColor Yellow
        }
        else {

            Write-Host "Restart Required    : No"
        }

        Write-Host ""

        try {

            Import-Module `
                ActiveDirectory `
                -Force `
                -ErrorAction Stop

            Write-Host `
                "ActiveDirectory PowerShell module loaded successfully." `
                -ForegroundColor Green
        }
        catch {

            Write-Host `
                "RSAT was installed, but the module could not be loaded yet." `
                -ForegroundColor Yellow

            Write-Host `
                "Close and reopen PowerShell or restart the toolkit."
        }

        try {

            Write-ToolkitLog `
                "Active Directory RSAT installation attempted. State: $($result.State)" `
                "INFO"
        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "RSAT installation failed." `
            -ForegroundColor Red

        Write-Host ""
        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Test-ADModule {

    Clear-Host

    Write-Host "ACTIVE DIRECTORY MODULE TEST" `
        -ForegroundColor Cyan

    Write-Host "============================"
    Write-Host ""

    $module = Get-Module `
        -ListAvailable `
        -Name ActiveDirectory `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $module) {

        Write-StatusLine `
            -Status "WARN" `
            -Label "ActiveDirectory Module" `
            -Value "Not installed"

        return $false
    }

    Write-StatusLine `
        -Status "PASS" `
        -Label "Module Installed" `
        -Value "$($module.Version)"

    try {

        Import-Module `
            ActiveDirectory `
            -Force `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "PASS" `
            -Label "Module Import" `
            -Value "Successful"

        $command = Get-Command `
            Get-ADUser `
            -ErrorAction SilentlyContinue

        Write-StatusLine `
            -Status $(if ($command) { "PASS" } else { "WARN" }) `
            -Label "Get-ADUser" `
            -Value $(if ($command) { "Available" } else { "Unavailable" })

        return $true
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Module Import" `
            -Value "Failed"

        Write-Host ""
        Write-Host $_.Exception.Message `
            -ForegroundColor DarkYellow

        return $false
    }
}


function Test-ADDomainConnectivity {

    Clear-Host

    Write-Host "ACTIVE DIRECTORY DOMAIN CONNECTIVITY" `
        -ForegroundColor Cyan

    Write-Host "===================================="
    Write-Host ""

    try {

        $computerSystem = Get-CimInstance `
            Win32_ComputerSystem `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "INFO" `
            -Label "Computer" `
            -Value "$env:COMPUTERNAME"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Domain / Workgroup" `
            -Value "$($computerSystem.Domain)"

        Write-StatusLine `
            -Status $(if ($computerSystem.PartOfDomain) { "PASS" } else { "INFO" }) `
            -Label "Domain Joined" `
            -Value "$($computerSystem.PartOfDomain)"

        if (-not $computerSystem.PartOfDomain) {

            Write-Host ""
            Write-Host `
                "This computer is not joined to an Active Directory domain." `
                -ForegroundColor Yellow

            Write-Host `
                "AD cmdlets can still be used if this workstation has network access" `
                -ForegroundColor DarkGray

            Write-Host `
                "to a domain and appropriate credentials are available." `
                -ForegroundColor DarkGray

            return
        }
    }
    catch {}


    if (
        -not (
            Get-Module `
                -ListAvailable `
                -Name ActiveDirectory `
                -ErrorAction SilentlyContinue
        )
    ) {

        Write-StatusLine `
            -Status "WARN" `
            -Label "AD Module" `
            -Value "Not installed"

        return
    }

    try {

        Import-Module `
            ActiveDirectory `
            -ErrorAction Stop

        $domain = Get-ADDomain `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "PASS" `
            -Label "Domain Reachable" `
            -Value "$($domain.DNSRoot)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "NetBIOS Name" `
            -Value "$($domain.NetBIOSName)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Domain Mode" `
            -Value "$($domain.DomainMode)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "PDC Emulator" `
            -Value "$($domain.PDCEmulator)"
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Domain Connectivity" `
            -Value "Unable to contact Active Directory"

        Write-Host ""
        Write-Host $_.Exception.Message `
            -ForegroundColor DarkYellow
    }


    try {

        $dc = Get-ADDomainController `
            -Discover `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "PASS" `
            -Label "Domain Controller" `
            -Value "$($dc.HostName)"

        if ($dc.IPv4Address) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "DC IPv4" `
                -Value "$($dc.IPv4Address)"
        }

        Write-StatusLine `
            -Status "INFO" `
            -Label "DC Site" `
            -Value "$($dc.Site)"
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Domain Controller" `
            -Value "Not discovered"
    }
}


function Search-ADUser {

    Clear-Host

    Write-Host "ACTIVE DIRECTORY USER LOOKUP" `
        -ForegroundColor Cyan

    Write-Host "============================"
    Write-Host ""

    $query = Read-Host "Enter username, name or email"

    if ([string]::IsNullOrWhiteSpace($query)) {
        return
    }

    try {

        $escaped = $query.Replace("'", "''")

        $users = Get-ADUser `
            -Filter "SamAccountName -like '*$escaped*' -or Name -like '*$escaped*' -or UserPrincipalName -like '*$escaped*'" `
            -Properties `
                DisplayName,
                UserPrincipalName,
                Enabled,
                LockedOut,
                PasswordLastSet,
                PasswordExpired,
                LastLogonDate `
            -ErrorAction Stop

        if (-not $users) {

            Write-Host ""
            Write-Host "No matching users found." `
                -ForegroundColor Yellow

            return
        }

        $users |
            Select-Object `
                SamAccountName,
                DisplayName,
                UserPrincipalName,
                Enabled,
                LockedOut,
                PasswordExpired,
                LastLogonDate |
            Format-Table `
                -AutoSize `
                -Wrap
    }
    catch {

        Write-Host ""
        Write-Host "AD user search failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Show-ADUserGroups {

    Clear-Host

    Write-Host "ACTIVE DIRECTORY USER GROUPS" `
        -ForegroundColor Cyan

    Write-Host "============================"
    Write-Host ""

    $username = Read-Host "Enter username"

    if ([string]::IsNullOrWhiteSpace($username)) {
        return
    }

    try {

        Get-ADPrincipalGroupMembership `
            -Identity $username `
            -ErrorAction Stop |
            Select-Object `
                Name,
                GroupCategory,
                GroupScope |
            Sort-Object Name |
            Format-Table `
                -AutoSize
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve user groups." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Search-ADComputer {

    Clear-Host

    Write-Host "ACTIVE DIRECTORY COMPUTER LOOKUP" `
        -ForegroundColor Cyan

    Write-Host "================================"
    Write-Host ""

    $query = Read-Host "Enter computer name"

    if ([string]::IsNullOrWhiteSpace($query)) {
        return
    }

    try {

        $escaped = $query.Replace("'", "''")

        Get-ADComputer `
            -Filter "Name -like '*$escaped*'" `
            -Properties `
                OperatingSystem,
                OperatingSystemVersion,
                IPv4Address,
                Enabled,
                LastLogonDate `
            -ErrorAction Stop |
            Select-Object `
                Name,
                Enabled,
                OperatingSystem,
                OperatingSystemVersion,
                IPv4Address,
                LastLogonDate |
            Format-Table `
                -AutoSize `
                -Wrap
    }
    catch {

        Write-Host ""
        Write-Host "AD computer search failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Unlock-ADUserSafe {

    Clear-Host

    Write-Host "UNLOCK ACTIVE DIRECTORY USER" `
        -ForegroundColor Cyan

    Write-Host "============================"
    Write-Host ""

    $username = Read-Host "Enter username"

    if ([string]::IsNullOrWhiteSpace($username)) {
        return
    }

    try {

        $user = Get-ADUser `
            -Identity $username `
            -Properties LockedOut `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "User      : $($user.SamAccountName)"
        Write-Host "Locked Out: $($user.LockedOut)"
        Write-Host ""

        if (-not $user.LockedOut) {

            Write-Host "Account is not currently locked." `
                -ForegroundColor Green

            return
        }

        $confirm = Read-Host "Unlock this account? [Y/N]"

        if ($confirm -notmatch "^[Yy]$") {
            return
        }

        Unlock-ADAccount `
            -Identity $user `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Account unlocked successfully." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "Unable to unlock account." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Set-ADUserEnabledState {

    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Enable", "Disable")]
        [string]$Action
    )

    Clear-Host

    Write-Host "$($Action.ToUpper()) ACTIVE DIRECTORY USER" `
        -ForegroundColor Cyan

    Write-Host "=============================="
    Write-Host ""

    $username = Read-Host "Enter username"

    if ([string]::IsNullOrWhiteSpace($username)) {
        return
    }

    try {

        $user = Get-ADUser `
            -Identity $username `
            -Properties Enabled `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "User    : $($user.SamAccountName)"
        Write-Host "Enabled : $($user.Enabled)"
        Write-Host ""

        $confirm = Read-Host "$Action this AD account? [Y/N]"

        if ($confirm -notmatch "^[Yy]$") {
            return
        }

        if ($Action -eq "Enable") {

            Enable-ADAccount `
                -Identity $user `
                -ErrorAction Stop
        }
        else {

            Disable-ADAccount `
                -Identity $user `
                -ErrorAction Stop
        }

        Write-Host ""
        Write-Host "Account $($Action.ToLower())d successfully." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "Operation failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Set-ADUserPasswordSafe {

    Clear-Host

    Write-Host "RESET ACTIVE DIRECTORY USER PASSWORD" `
        -ForegroundColor Cyan

    Write-Host "===================================="
    Write-Host ""

    $username = Read-Host "Enter username"

    if ([string]::IsNullOrWhiteSpace($username)) {
        return
    }

    try {

        $user = Get-ADUser `
            -Identity $username `
            -ErrorAction Stop
    }
    catch {

        Write-Host ""
        Write-Host "User not found." `
            -ForegroundColor Red

        return
    }

    Write-Host ""
    Write-Host "User: $($user.SamAccountName)"
    Write-Host ""

    $newPassword = Read-Host `
        "Enter new password" `
        -AsSecureString

    $confirm = Read-Host `
        "Reset password for this account? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    try {

        Set-ADAccountPassword `
            -Identity $user `
            -Reset `
            -NewPassword $newPassword `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Password reset successfully." `
            -ForegroundColor Green

        $changeNextLogon = Read-Host `
            "Require password change at next logon? [Y/N]"

        if ($changeNextLogon -match "^[Yy]$") {

            Set-ADUser `
                -Identity $user `
                -ChangePasswordAtLogon $true `
                -ErrorAction Stop

            Write-Host `
                "Password change at next logon enabled." `
                -ForegroundColor Green
        }
    }
    catch {

        Write-Host ""
        Write-Host "Password reset failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Show-ActiveDirectoryOperationsMenu {

    do {

        Clear-Host

        Write-Host "ACTIVE DIRECTORY OPERATIONS" `
            -ForegroundColor Cyan

        Write-Host "==========================="
        Write-Host ""

        Write-Host "1. Search AD User"
        Write-Host "2. View User Group Memberships"
        Write-Host "3. Search AD Computer"
        Write-Host "4. Unlock AD User"
        Write-Host "5. Enable AD User"
        Write-Host "6. Disable AD User"
        Write-Host "7. Reset AD User Password"
        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Search-ADUser
            }

            "2" {
                Show-ADUserGroups
            }

            "3" {
                Search-ADComputer
            }

            "4" {
                Unlock-ADUserSafe
            }

            "5" {
                Set-ADUserEnabledState `
                    -Action Enable
            }

            "6" {
                Set-ADUserEnabledState `
                    -Action Disable
            }

            "7" {
                Set-ADUserPasswordSafe
            }

            "0" {}

            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 1
            }
        }

        if ($choice -ne "0") {

            Write-Host ""
            Read-Host "Press ENTER"
        }

    } while ($choice -ne "0")
}


function Show-ActiveDirectoryMenu {

    do {

        Clear-Host

        Write-Host "ACTIVE DIRECTORY SUPPORT" `
            -ForegroundColor Cyan

        Write-Host "========================"
        Write-Host ""

        $moduleAvailable = $false

        if (
            Get-Module `
                -ListAvailable `
                -Name ActiveDirectory `
                -ErrorAction SilentlyContinue
        ) {

            $moduleAvailable = $true
        }

        if ($moduleAvailable) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "ActiveDirectory Module" `
                -Value "Installed"
        }
        else {

            Write-StatusLine `
                -Status "WARN" `
                -Label "ActiveDirectory Module" `
                -Value "Not installed"
        }

        Write-Host ""
        Write-Host "1. Check RSAT / AD Installation Status"
        Write-Host "2. Install Active Directory RSAT"
        Write-Host "3. Verify Active Directory Module"
        Write-Host "4. Test Domain Connectivity"

        if ($moduleAvailable) {

            Write-Host "5. Active Directory Operations"
        }

        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {

                Clear-Host

                Get-ADRSATStatus
            }

            "2" {

                Install-ADRSATTools
            }

            "3" {

                Test-ADModule |
                    Out-Null
            }

            "4" {

                Test-ADDomainConnectivity
            }

            "5" {

                if ($moduleAvailable) {

                    try {

                        Import-Module `
                            ActiveDirectory `
                            -ErrorAction Stop

                        Show-ActiveDirectoryOperationsMenu
                    }
                    catch {

                        Write-Host ""
                        Write-Host "Unable to load Active Directory module." `
                            -ForegroundColor Red

                        Write-Host $_.Exception.Message
                    }
                }
                else {

                    Write-Host ""
                    Write-Host `
                        "Install the Active Directory RSAT tools first." `
                        -ForegroundColor Yellow
                }
            }

            "0" {}

            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 1
            }
        }

        if (
            $choice -ne "0" -and
            $choice -ne "5"
        ) {

            Write-Host ""
            Read-Host "Press ENTER"
        }

    } while ($choice -ne "0")
}


Export-ModuleMember -Function `
    Test-ADAdministrator, `
    Get-ADRSATStatus, `
    Install-ADRSATTools, `
    Test-ADModule, `
    Test-ADDomainConnectivity, `
    Search-ADUser, `
    Show-ADUserGroups, `
    Search-ADComputer, `
    Unlock-ADUserSafe, `
    Set-ADUserEnabledState, `
    Set-ADUserPasswordSafe, `
    Show-ActiveDirectoryOperationsMenu, `
    Show-ActiveDirectoryMenu