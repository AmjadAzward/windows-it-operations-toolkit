#Requires -Version 5.1


function Test-M365Administrator {

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


function Get-GraphRequiredModules {

    return @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Users",
        "Microsoft.Graph.Groups",
        "Microsoft.Graph.Identity.DirectoryManagement"
    )
}


function Get-GraphReadOnlyScopes {

    return @(
        "User.Read.All",
        "Group.Read.All",
        "Directory.Read.All",
        "Organization.Read.All"
    )
}


function Get-MicrosoftGraphStatus {

    Clear-Host

    Write-Host "MICROSOFT GRAPH SDK STATUS" `
        -ForegroundColor Cyan

    Write-Host "=========================="
    Write-Host ""

    $modules = Get-GraphRequiredModules

    foreach ($moduleName in $modules) {

        $module = Get-Module `
            -ListAvailable `
            -Name $moduleName `
            -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if ($module) {

            Write-StatusLine `
                -Status "PASS" `
                -Label $moduleName `
                -Value "$($module.Version)"
        }
        else {

            Write-StatusLine `
                -Status "WARN" `
                -Label $moduleName `
                -Value "Not installed"
        }
    }

    Write-Host ""

    try {

        $graphModule = Get-Module `
            -ListAvailable `
            -Name Microsoft.Graph `
            -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if ($graphModule) {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Microsoft.Graph Meta Module" `
                -Value "$($graphModule.Version)"
        }
        else {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Microsoft.Graph Meta Module" `
                -Value "Not installed"
        }
    }
    catch {}
}


function Install-MicrosoftGraphToolkitModules {

    Clear-Host

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host " INSTALL MICROSOFT GRAPH MODULES"

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "The toolkit will install these Microsoft Graph modules:"
    Write-Host ""

    $modules = Get-GraphRequiredModules

    foreach ($moduleName in $modules) {

        Write-Host " - $moduleName"
    }

    Write-Host ""
    Write-Host "These modules are used for read-only Microsoft 365 administration."
    Write-Host ""

    $confirm = Read-Host "Install required Microsoft Graph modules? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {

        Write-Host ""
        Write-Host "Installation cancelled." `
            -ForegroundColor Yellow

        return
    }

    try {

        #
        # Ensure NuGet provider exists
        #
        $nuget = Get-PackageProvider `
            -Name NuGet `
            -ErrorAction SilentlyContinue

        if (-not $nuget) {

            Write-Host ""
            Write-Host "Installing NuGet package provider..."

            Install-PackageProvider `
                -Name NuGet `
                -MinimumVersion 2.8.5.201 `
                -Force `
                -Scope CurrentUser `
                -ErrorAction Stop |
                Out-Null
        }


        #
        # Ensure PSGallery exists
        #
        $gallery = Get-PSRepository `
            -Name PSGallery `
            -ErrorAction SilentlyContinue

        if (-not $gallery) {

            Register-PSRepository `
                -Default `
                -ErrorAction Stop
        }


        foreach ($moduleName in $modules) {

            Write-Host ""
            Write-Host "Checking $moduleName..."

            $existing = Get-Module `
                -ListAvailable `
                -Name $moduleName `
                -ErrorAction SilentlyContinue |
                Sort-Object Version -Descending |
                Select-Object -First 1

            if ($existing) {

                Write-Host "$moduleName is already installed." `
                    -ForegroundColor Green

                continue
            }

            Write-Host "Installing $moduleName..."

            Install-Module `
                -Name $moduleName `
                -Scope CurrentUser `
                -Repository PSGallery `
                -Force `
                -AllowClobber `
                -ErrorAction Stop

            Write-Host "$moduleName installed successfully." `
                -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "Microsoft Graph module installation completed." `
            -ForegroundColor Green

        try {

            Write-ToolkitLog `
                "Microsoft Graph toolkit modules installed or verified." `
                "INFO"
        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Microsoft Graph installation failed." `
            -ForegroundColor Red

        Write-Host ""
        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Test-MicrosoftGraphModules {

    Clear-Host

    Write-Host "MICROSOFT GRAPH MODULE VERIFICATION" `
        -ForegroundColor Cyan

    Write-Host "==================================="
    Write-Host ""

    $modules = Get-GraphRequiredModules

    $allAvailable = $true

    foreach ($moduleName in $modules) {

        $module = Get-Module `
            -ListAvailable `
            -Name $moduleName `
            -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if ($module) {

            Write-StatusLine `
                -Status "PASS" `
                -Label $moduleName `
                -Value "$($module.Version)"

            try {

                Import-Module `
                    $moduleName `
                    -Force `
                    -ErrorAction Stop

                Write-StatusLine `
                    -Status "PASS" `
                    -Label "$moduleName Import" `
                    -Value "Successful"
            }
            catch {

                Write-StatusLine `
                    -Status "WARN" `
                    -Label "$moduleName Import" `
                    -Value "Failed"

                $allAvailable = $false
            }
        }
        else {

            Write-StatusLine `
                -Status "WARN" `
                -Label $moduleName `
                -Value "Not installed"

            $allAvailable = $false
        }
    }

    return $allAvailable
}


function Connect-Microsoft365Graph {

    Clear-Host

    Write-Host "CONNECT TO MICROSOFT 365" `
        -ForegroundColor Cyan

    Write-Host "========================"
    Write-Host ""

    $authenticationModule = Get-Module `
        -ListAvailable `
        -Name Microsoft.Graph.Authentication `
        -ErrorAction SilentlyContinue

    if (-not $authenticationModule) {

        Write-Host `
            "Microsoft Graph Authentication module is not installed." `
            -ForegroundColor Yellow

        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Authentication `
            -Force `
            -ErrorAction Stop

        $existingContext = Get-MgContext `
            -ErrorAction SilentlyContinue

        if ($existingContext) {

            Write-Host "An existing Graph session was detected."
            Write-Host ""

            Write-Host "Account : $($existingContext.Account)"
            Write-Host "Tenant  : $($existingContext.TenantId)"
            Write-Host ""

            $reuse = Read-Host "Use existing connection? [Y/N]"

            if ($reuse -match "^[Yy]$") {

                Write-Host ""
                Write-Host "Using existing Microsoft Graph connection." `
                    -ForegroundColor Green

                return
            }

            Disconnect-MgGraph `
                -ErrorAction SilentlyContinue |
                Out-Null
        }

        $scopes = Get-GraphReadOnlyScopes

        Write-Host "The toolkit requests these read-only Graph scopes:"
        Write-Host ""

        foreach ($scope in $scopes) {

            Write-Host " - $scope"
        }

        Write-Host ""

        $confirm = Read-Host "Connect to Microsoft Graph? [Y/N]"

        if ($confirm -notmatch "^[Yy]$") {

            Write-Host ""
            Write-Host "Connection cancelled." `
                -ForegroundColor Yellow

            return
        }

        Connect-MgGraph `
            -Scopes $scopes `
            -NoWelcome `
            -ErrorAction Stop

        $context = Get-MgContext `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Connected successfully." `
            -ForegroundColor Green

        Write-Host ""
        Write-Host "Account : $($context.Account)"
        Write-Host "Tenant  : $($context.TenantId)"

        if ($context.Scopes) {

            Write-Host ""
            Write-Host "Granted Scopes:"

            foreach ($scope in $context.Scopes) {

                Write-Host " - $scope"
            }
        }

        try {

            Write-ToolkitLog `
                "Connected to Microsoft Graph as $($context.Account)." `
                "INFO"
        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Microsoft Graph connection failed." `
            -ForegroundColor Red

        Write-Host ""
        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-MicrosoftGraphConnection {

    Clear-Host

    Write-Host "MICROSOFT GRAPH CONNECTION" `
        -ForegroundColor Cyan

    Write-Host "=========================="
    Write-Host ""

    try {

        Import-Module `
            Microsoft.Graph.Authentication `
            -ErrorAction Stop

        $context = Get-MgContext `
            -ErrorAction SilentlyContinue

        if (-not $context) {

            Write-StatusLine `
                -Status "WARN" `
                -Label "Graph Connection" `
                -Value "Not connected"

            return
        }

        Write-StatusLine `
            -Status "PASS" `
            -Label "Graph Connection" `
            -Value "Connected"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Account" `
            -Value "$($context.Account)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Tenant ID" `
            -Value "$($context.TenantId)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Auth Type" `
            -Value "$($context.AuthType)"

        Write-Host ""

        Write-Host "Granted Scopes:" `
            -ForegroundColor White

        foreach ($scope in $context.Scopes) {

            Write-Host " - $scope"
        }
    }
    catch {

        Write-StatusLine `
            -Status "WARN" `
            -Label "Graph Connection" `
            -Value "Unavailable"
    }
}


function Disconnect-Microsoft365Graph {

    Clear-Host

    Write-Host "DISCONNECT MICROSOFT GRAPH" `
        -ForegroundColor Cyan

    Write-Host "=========================="
    Write-Host ""

    try {

        Import-Module `
            Microsoft.Graph.Authentication `
            -ErrorAction Stop

        $context = Get-MgContext `
            -ErrorAction SilentlyContinue

        if (-not $context) {

            Write-Host "No active Microsoft Graph session." `
                -ForegroundColor Yellow

            return
        }

        Write-Host "Connected account:"
        Write-Host $context.Account
        Write-Host ""

        $confirm = Read-Host "Disconnect Microsoft Graph? [Y/N]"

        if ($confirm -notmatch "^[Yy]$") {
            return
        }

        Disconnect-MgGraph `
            -ErrorAction Stop |
            Out-Null

        Write-Host ""
        Write-Host "Microsoft Graph disconnected." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "Unable to disconnect Microsoft Graph." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Test-Microsoft365Connection {

    $context = Get-MgContext `
        -ErrorAction SilentlyContinue

    if (-not $context) {

        Write-Host ""
        Write-Host "Microsoft Graph is not connected." `
            -ForegroundColor Yellow

        Write-Host "Use the Connect option first."

        return $false
    }

    return $true
}


function Get-M365TenantInformation {

    Clear-Host

    Write-Host "MICROSOFT 365 TENANT INFORMATION" `
        -ForegroundColor Cyan

    Write-Host "================================"
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Identity.DirectoryManagement `
            -ErrorAction Stop

        $organization = Get-MgOrganization `
            -ErrorAction Stop |
            Select-Object -First 1

        if (-not $organization) {

            Write-Host "Tenant information unavailable." `
                -ForegroundColor Yellow

            return
        }

        Write-StatusLine `
            -Status "INFO" `
            -Label "Display Name" `
            -Value "$($organization.DisplayName)"

        Write-StatusLine `
            -Status "INFO" `
            -Label "Tenant ID" `
            -Value "$($organization.Id)"

        if ($organization.VerifiedDomains) {

            $domains = $organization.VerifiedDomains |
                ForEach-Object {
                    $_.Name
                }

            Write-StatusLine `
                -Status "INFO" `
                -Label "Verified Domains" `
                -Value "$($domains -join ', ')"
        }
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve tenant information." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Search-M365User {

    Clear-Host

    Write-Host "MICROSOFT 365 USER SEARCH" `
        -ForegroundColor Cyan

    Write-Host "========================="
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    $query = Read-Host "Enter user name, UPN or email"

    if ([string]::IsNullOrWhiteSpace($query)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Users `
            -ErrorAction Stop

        $escaped = $query.Replace("'", "''")

        $users = Get-MgUser `
            -Filter "startswith(displayName,'$escaped') or startswith(userPrincipalName,'$escaped') or startswith(mail,'$escaped')" `
            -Property `
                Id,
                DisplayName,
                UserPrincipalName,
                Mail,
                AccountEnabled `
            -ConsistencyLevel eventual `
            -ErrorAction Stop

        if (-not $users) {

            Write-Host ""
            Write-Host "No matching users found." `
                -ForegroundColor Yellow

            return
        }

        $users |
            Select-Object `
                DisplayName,
                UserPrincipalName,
                Mail,
                AccountEnabled,
                Id |
            Format-Table `
                -AutoSize `
                -Wrap
    }
    catch {

        Write-Host ""
        Write-Host "User search failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-M365UserDetails {

    Clear-Host

    Write-Host "MICROSOFT 365 USER DETAILS" `
        -ForegroundColor Cyan

    Write-Host "=========================="
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    $identity = Read-Host "Enter user principal name or user ID"

    if ([string]::IsNullOrWhiteSpace($identity)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Users `
            -ErrorAction Stop

        $user = Get-MgUser `
            -UserId $identity `
            -Property `
                Id,
                DisplayName,
                UserPrincipalName,
                Mail,
                AccountEnabled,
                JobTitle,
                Department,
                OfficeLocation,
                BusinessPhones,
                MobilePhone,
                CreatedDateTime,
                AssignedLicenses `
            -ErrorAction Stop

        [PSCustomObject]@{
            DisplayName       = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            Mail              = $user.Mail
            AccountEnabled    = $user.AccountEnabled
            JobTitle          = $user.JobTitle
            Department        = $user.Department
            OfficeLocation    = $user.OfficeLocation
            MobilePhone       = $user.MobilePhone
            BusinessPhones    = ($user.BusinessPhones -join ", ")
            CreatedDateTime   = $user.CreatedDateTime
            LicenseCount      = @($user.AssignedLicenses).Count
            UserId            = $user.Id
        } |
            Format-List
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve user details." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-M365UserLicenseInformation {

    Clear-Host

    Write-Host "MICROSOFT 365 USER LICENSES" `
        -ForegroundColor Cyan

    Write-Host "=========================="
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    $identity = Read-Host "Enter user principal name or user ID"

    if ([string]::IsNullOrWhiteSpace($identity)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Users `
            -ErrorAction Stop

        $details = Get-MgUserLicenseDetail `
            -UserId $identity `
            -ErrorAction Stop

        if (-not $details) {

            Write-Host ""
            Write-Host "No licenses assigned." `
                -ForegroundColor Yellow

            return
        }

        $details |
            Select-Object `
                SkuPartNumber,
                SkuId |
            Format-Table `
                -AutoSize
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve license information." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-M365UserGroupMemberships {

    Clear-Host

    Write-Host "MICROSOFT 365 USER GROUP MEMBERSHIPS" `
        -ForegroundColor Cyan

    Write-Host "===================================="
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    $identity = Read-Host "Enter user principal name or user ID"

    if ([string]::IsNullOrWhiteSpace($identity)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Users `
            -ErrorAction Stop

        Import-Module `
            Microsoft.Graph.Groups `
            -ErrorAction Stop

        $memberships = Get-MgUserMemberOf `
            -UserId $identity `
            -All `
            -ErrorAction Stop

        if (-not $memberships) {

            Write-Host ""
            Write-Host "No group memberships returned." `
                -ForegroundColor Yellow

            return
        }

        $results = foreach ($membership in $memberships) {

            $name = $null

            try {

                if (
                    $membership.AdditionalProperties.ContainsKey(
                        "displayName"
                    )
                ) {

                    $name = $membership.AdditionalProperties["displayName"]
                }
            }
            catch {}

            [PSCustomObject]@{
                DisplayName = $name
                Type        = $membership.AdditionalProperties["@odata.type"]
                ObjectId    = $membership.Id
            }
        }

        $results |
            Format-Table `
                -AutoSize `
                -Wrap
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve group memberships." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-M365LicensedUsers {

    Clear-Host

    Write-Host "LICENSED MICROSOFT 365 USERS" `
        -ForegroundColor Cyan

    Write-Host "============================"
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Users `
            -ErrorAction Stop

        $users = Get-MgUser `
            -All `
            -Property `
                DisplayName,
                UserPrincipalName,
                AccountEnabled,
                AssignedLicenses `
            -ErrorAction Stop

        $licensed = $users |
            Where-Object {
                @($_.AssignedLicenses).Count -gt 0
            }

        Write-StatusLine `
            -Status "INFO" `
            -Label "Licensed Users" `
            -Value "$(@($licensed).Count)"

        Write-Host ""

        $licensed |
            Select-Object `
                DisplayName,
                UserPrincipalName,
                AccountEnabled,
                @{
                    Name = "LicenseCount"
                    Expression = {
                        @($_.AssignedLicenses).Count
                    }
                } |
            Format-Table `
                -AutoSize `
                -Wrap
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve licensed users." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-M365UnlicensedUsers {

    Clear-Host

    Write-Host "UNLICENSED MICROSOFT 365 USERS" `
        -ForegroundColor Cyan

    Write-Host "=============================="
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Users `
            -ErrorAction Stop

        $users = Get-MgUser `
            -All `
            -Property `
                DisplayName,
                UserPrincipalName,
                AccountEnabled,
                AssignedLicenses `
            -ErrorAction Stop

        $unlicensed = $users |
            Where-Object {
                @($_.AssignedLicenses).Count -eq 0
            }

        Write-StatusLine `
            -Status "INFO" `
            -Label "Unlicensed Users" `
            -Value "$(@($unlicensed).Count)"

        Write-Host ""

        $unlicensed |
            Select-Object `
                DisplayName,
                UserPrincipalName,
                AccountEnabled |
            Format-Table `
                -AutoSize `
                -Wrap
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve unlicensed users." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-M365LicenseSummary {

    Clear-Host

    Write-Host "MICROSOFT 365 LICENSE SUMMARY" `
        -ForegroundColor Cyan

    Write-Host "============================="
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Identity.DirectoryManagement `
            -ErrorAction Stop

        $skus = Get-MgSubscribedSku `
            -All `
            -ErrorAction Stop

        if (-not $skus) {

            Write-Host "No subscription SKUs returned." `
                -ForegroundColor Yellow

            return
        }

        $skus |
            Select-Object `
                SkuPartNumber,
                @{
                    Name = "Enabled"
                    Expression = {
                        $_.PrepaidUnits.Enabled
                    }
                },
                ConsumedUnits,
                @{
                    Name = "Available"
                    Expression = {

                        [int]$_.PrepaidUnits.Enabled -
                        [int]$_.ConsumedUnits
                    }
                } |
            Format-Table `
                -AutoSize
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve license summary." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Search-M365Group {

    Clear-Host

    Write-Host "MICROSOFT 365 GROUP SEARCH" `
        -ForegroundColor Cyan

    Write-Host "=========================="
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    $query = Read-Host "Enter group name"

    if ([string]::IsNullOrWhiteSpace($query)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Groups `
            -ErrorAction Stop

        $escaped = $query.Replace("'", "''")

        $groups = Get-MgGroup `
            -Filter "startswith(displayName,'$escaped')" `
            -Property `
                Id,
                DisplayName,
                Mail,
                MailEnabled,
                SecurityEnabled,
                GroupTypes `
            -ConsistencyLevel eventual `
            -ErrorAction Stop

        if (-not $groups) {

            Write-Host ""
            Write-Host "No matching groups found." `
                -ForegroundColor Yellow

            return
        }

        $groups |
            Select-Object `
                DisplayName,
                Mail,
                MailEnabled,
                SecurityEnabled,
                @{
                    Name = "GroupTypes"
                    Expression = {
                        $_.GroupTypes -join ", "
                    }
                },
                Id |
            Format-Table `
                -AutoSize `
                -Wrap
    }
    catch {

        Write-Host ""
        Write-Host "Group search failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-M365Groups {

    Clear-Host

    Write-Host "MICROSOFT 365 GROUPS" `
        -ForegroundColor Cyan

    Write-Host "===================="
    Write-Host ""

    if (-not (Test-Microsoft365Connection)) {
        return
    }

    try {

        Import-Module `
            Microsoft.Graph.Groups `
            -ErrorAction Stop

        $groups = Get-MgGroup `
            -All `
            -Property `
                DisplayName,
                Mail,
                MailEnabled,
                SecurityEnabled,
                GroupTypes `
            -ErrorAction Stop

        Write-StatusLine `
            -Status "INFO" `
            -Label "Group Count" `
            -Value "$(@($groups).Count)"

        Write-Host ""

        $groups |
            Select-Object `
                DisplayName,
                Mail,
                MailEnabled,
                SecurityEnabled,
                @{
                    Name = "GroupTypes"
                    Expression = {
                        $_.GroupTypes -join ", "
                    }
                } |
            Format-Table `
                -AutoSize `
                -Wrap
    }
    catch {

        Write-Host ""
        Write-Host "Unable to retrieve Microsoft 365 groups." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Show-Microsoft365ReadOnlyMenu {

    do {

        Clear-Host

        Write-Host "MICROSOFT 365 READ-ONLY TOOLS" `
            -ForegroundColor Cyan

        Write-Host "============================="
        Write-Host ""

        Write-Host "1.  Tenant Information"
        Write-Host "2.  Search User"
        Write-Host "3.  User Details"
        Write-Host "4.  User License Information"
        Write-Host "5.  User Group Memberships"
        Write-Host "6.  List Licensed Users"
        Write-Host "7.  List Unlicensed Users"
        Write-Host "8.  License Summary"
        Write-Host "9.  Search Group"
        Write-Host "10. List Groups"
        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Get-M365TenantInformation
            }

            "2" {
                Search-M365User
            }

            "3" {
                Get-M365UserDetails
            }

            "4" {
                Get-M365UserLicenseInformation
            }

            "5" {
                Get-M365UserGroupMemberships
            }

            "6" {
                Get-M365LicensedUsers
            }

            "7" {
                Get-M365UnlicensedUsers
            }

            "8" {
                Get-M365LicenseSummary
            }

            "9" {
                Search-M365Group
            }

            "10" {
                Get-M365Groups
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


function Show-Microsoft365Menu {

    do {

        Clear-Host

        Write-Host "MICROSOFT 365 / GRAPH SUPPORT" `
            -ForegroundColor Cyan

        Write-Host "============================="
        Write-Host ""

        $authenticationAvailable = $false

        if (
            Get-Module `
                -ListAvailable `
                -Name Microsoft.Graph.Authentication `
                -ErrorAction SilentlyContinue
        ) {

            $authenticationAvailable = $true
        }

        if ($authenticationAvailable) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "Graph SDK" `
                -Value "Installed"
        }
        else {

            Write-StatusLine `
                -Status "WARN" `
                -Label "Graph SDK" `
                -Value "Not installed"
        }

        $context = $null

        if ($authenticationAvailable) {

            try {

                Import-Module `
                    Microsoft.Graph.Authentication `
                    -ErrorAction SilentlyContinue

                $context = Get-MgContext `
                    -ErrorAction SilentlyContinue
            }
            catch {}
        }

        if ($context) {

            Write-StatusLine `
                -Status "PASS" `
                -Label "Graph Session" `
                -Value "$($context.Account)"
        }
        else {

            Write-StatusLine `
                -Status "INFO" `
                -Label "Graph Session" `
                -Value "Not connected"
        }

        Write-Host ""

        Write-Host "1. Check Microsoft Graph SDK Status"
        Write-Host "2. Install Required Graph Modules"
        Write-Host "3. Verify Graph Modules"
        Write-Host "4. Connect to Microsoft 365"
        Write-Host "5. Show Current Graph Connection"
        Write-Host "6. Disconnect Microsoft Graph"

        if ($context) {

            Write-Host "7. Microsoft 365 Read-Only Tools"
        }

        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {

                Get-MicrosoftGraphStatus
            }

            "2" {

                Install-MicrosoftGraphToolkitModules
            }

            "3" {

                Test-MicrosoftGraphModules |
                    Out-Null
            }

            "4" {

                Connect-Microsoft365Graph
            }

            "5" {

                Get-MicrosoftGraphConnection
            }

            "6" {

                Disconnect-Microsoft365Graph
            }

            "7" {

                if ($context) {

                    Show-Microsoft365ReadOnlyMenu
                }
                else {

                    Write-Host ""
                    Write-Host `
                        "Connect to Microsoft Graph first." `
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
            $choice -ne "7"
        ) {

            Write-Host ""
            Read-Host "Press ENTER"
        }

    } while ($choice -ne "0")
}


Export-ModuleMember -Function `
    Test-M365Administrator, `
    Get-GraphRequiredModules, `
    Get-GraphReadOnlyScopes, `
    Get-MicrosoftGraphStatus, `
    Install-MicrosoftGraphToolkitModules, `
    Test-MicrosoftGraphModules, `
    Connect-Microsoft365Graph, `
    Get-MicrosoftGraphConnection, `
    Disconnect-Microsoft365Graph, `
    Test-Microsoft365Connection, `
    Get-M365TenantInformation, `
    Search-M365User, `
    Get-M365UserDetails, `
    Get-M365UserLicenseInformation, `
    Get-M365UserGroupMemberships, `
    Get-M365LicensedUsers, `
    Get-M365UnlicensedUsers, `
    Get-M365LicenseSummary, `
    Search-M365Group, `
    Get-M365Groups, `
    Show-Microsoft365ReadOnlyMenu, `
    Show-Microsoft365Menu