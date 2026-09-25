#Requires -Version 5.1


function Get-StartupRegistryLocations {

    return @(
        @{
            Scope = "Current User"
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        },
        @{
            Scope = "Current User"
            Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        },
        @{
            Scope = "Local Machine"
            Path  = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
        },
        @{
            Scope = "Local Machine"
            Path  = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        },
        @{
            Scope = "Local Machine 32-bit"
            Path  = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
        }
    )
}


function Get-StartupBackupPath {

    $path = "HKCU:\Software\WindowsITOperationsToolkit\DisabledStartup"

    if (-not (Test-Path $path)) {

        New-Item `
            -Path $path `
            -Force |
            Out-Null
    }

    return $path
}


function Get-StartupAudit {

    Write-Host "STARTUP PROGRAM AUDIT" -ForegroundColor Cyan
    Write-Host "====================="
    Write-Host ""

    $items = @()

    #
    # Registry startup entries
    #
    foreach ($location in Get-StartupRegistryLocations) {

        if (-not (Test-Path $location.Path)) {
            continue
        }

        try {

            $properties = Get-ItemProperty `
                -Path $location.Path `
                -ErrorAction Stop

            foreach ($property in $properties.PSObject.Properties) {

                if (
                    $property.Name -like "PS*" -or
                    $property.Name -eq "(default)"
                ) {
                    continue
                }

                $items += [PSCustomObject]@{
                    Name     = $property.Name
                    Command  = [string]$property.Value
                    Scope    = $location.Scope
                    Source   = "Registry"
                    Location = $location.Path
                    Status   = "Enabled"
                }
            }
        }
        catch {}
    }


    #
    # Startup folders
    #
    $startupFolders = @(
        @{
            Scope = "Current User"
            Path  = [Environment]::GetFolderPath("Startup")
        },
        @{
            Scope = "All Users"
            Path  = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
        }
    )

    foreach ($folder in $startupFolders) {

        if (-not (Test-Path $folder.Path)) {
            continue
        }

        try {

            Get-ChildItem `
                -Path $folder.Path `
                -File `
                -ErrorAction SilentlyContinue |
            ForEach-Object {

                $items += [PSCustomObject]@{
                    Name     = $_.BaseName
                    Command  = $_.FullName
                    Scope    = $folder.Scope
                    Source   = "Startup Folder"
                    Location = $folder.Path
                    Status   = "Enabled"
                }
            }
        }
        catch {}
    }


    #
    # WMI fallback / visibility
    #
    try {

        $wmiItems = Get-CimInstance `
            Win32_StartupCommand `
            -ErrorAction SilentlyContinue

        foreach ($item in $wmiItems) {

            $alreadyExists = $items |
                Where-Object {
                    $_.Name -eq $item.Name -and
                    $_.Command -eq $item.Command
                }

            if (-not $alreadyExists) {

                $items += [PSCustomObject]@{
                    Name     = $item.Name
                    Command  = $item.Command
                    Scope    = $item.User
                    Source   = "WMI"
                    Location = $item.Location
                    Status   = "Enabled"
                }
            }
        }
    }
    catch {}


    if (-not $items) {

        Write-Host "No startup items found." `
            -ForegroundColor Yellow

        return
    }


    $items |
        Sort-Object Name, Command -Unique |
        Select-Object `
            Name,
            Command,
            Scope,
            Source,
            Status |
        Format-Table `
            -Wrap `
            -AutoSize

    Write-Host ""
    Write-Host `
        "Tip: Review unfamiliar or unnecessary startup items before disabling anything." `
        -ForegroundColor Yellow
}


function Get-ManageableStartupItems {

    $items = @()

    foreach ($location in Get-StartupRegistryLocations) {

        if (-not (Test-Path $location.Path)) {
            continue
        }

        try {

            $properties = Get-ItemProperty `
                -Path $location.Path `
                -ErrorAction Stop

            foreach ($property in $properties.PSObject.Properties) {

                if (
                    $property.Name -like "PS*" -or
                    $property.Name -eq "(default)"
                ) {
                    continue
                }

                $items += [PSCustomObject]@{
                    Name     = $property.Name
                    Command  = [string]$property.Value
                    Scope    = $location.Scope
                    Source   = "Registry"
                    Location = $location.Path
                }
            }
        }
        catch {}
    }


    $startupFolders = @(
        @{
            Scope = "Current User"
            Path  = [Environment]::GetFolderPath("Startup")
        },
        @{
            Scope = "All Users"
            Path  = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
        }
    )

    foreach ($folder in $startupFolders) {

        if (-not (Test-Path $folder.Path)) {
            continue
        }

        try {

            Get-ChildItem `
                -Path $folder.Path `
                -File `
                -ErrorAction SilentlyContinue |
            ForEach-Object {

                $items += [PSCustomObject]@{
                    Name     = $_.BaseName
                    Command  = $_.FullName
                    Scope    = $folder.Scope
                    Source   = "Startup Folder"
                    Location = $folder.Path
                }
            }
        }
        catch {}
    }

    return @(
        $items |
        Sort-Object Name, Command -Unique
    )
}


function Disable-StartupProgram {

    Clear-Host

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host " DISABLE STARTUP PROGRAM"

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    $items = @(Get-ManageableStartupItems)

    if ($items.Count -eq 0) {

        Write-Host "No manageable startup programs found." `
            -ForegroundColor Yellow

        return
    }


    for ($i = 0; $i -lt $items.Count; $i++) {

        Write-Host (
            "{0}. {1} [{2}]" `
            -f ($i + 1),
            $items[$i].Name,
            $items[$i].Source
        )
    }

    Write-Host ""
    Write-Host "0. Cancel"
    Write-Host ""

    $selection = Read-Host "Select startup item to disable"

    $number = 0

    if (
        -not [int]::TryParse(
            $selection,
            [ref]$number
        )
    ) {
        return
    }

    if ($number -eq 0) {
        return
    }

    if (
        $number -lt 1 -or
        $number -gt $items.Count
    ) {

        Write-Host ""
        Write-Host "Invalid selection." `
            -ForegroundColor Red

        return
    }

    $item = $items[$number - 1]

    Write-Host ""
    Write-Host "Selected:" -ForegroundColor Yellow
    Write-Host "Name    : $($item.Name)"
    Write-Host "Source  : $($item.Source)"
    Write-Host "Scope   : $($item.Scope)"
    Write-Host "Command : $($item.Command)"
    Write-Host ""

    $confirm = Read-Host "Disable this startup item? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }


    try {

        $backupRoot = Get-StartupBackupPath

        $id = [Guid]::NewGuid().ToString("N")

        $backupPath = Join-Path `
            $backupRoot `
            $id

        New-Item `
            -Path $backupPath `
            -Force |
            Out-Null


        New-ItemProperty `
            -Path $backupPath `
            -Name "Name" `
            -Value $item.Name `
            -PropertyType String `
            -Force |
            Out-Null

        New-ItemProperty `
            -Path $backupPath `
            -Name "Command" `
            -Value $item.Command `
            -PropertyType String `
            -Force |
            Out-Null

        New-ItemProperty `
            -Path $backupPath `
            -Name "Scope" `
            -Value $item.Scope `
            -PropertyType String `
            -Force |
            Out-Null

        New-ItemProperty `
            -Path $backupPath `
            -Name "Source" `
            -Value $item.Source `
            -PropertyType String `
            -Force |
            Out-Null

        New-ItemProperty `
            -Path $backupPath `
            -Name "Location" `
            -Value $item.Location `
            -PropertyType String `
            -Force |
            Out-Null


        if ($item.Source -eq "Registry") {

            Remove-ItemProperty `
                -Path $item.Location `
                -Name $item.Name `
                -ErrorAction Stop
        }
        elseif ($item.Source -eq "Startup Folder") {

            $disabledFolder = Join-Path `
                $env:LOCALAPPDATA `
                "WindowsITOperationsToolkit\DisabledStartupFiles"

            if (-not (Test-Path $disabledFolder)) {

                New-Item `
                    -Path $disabledFolder `
                    -ItemType Directory `
                    -Force |
                    Out-Null
            }

            $sourcePath = $item.Command
            $destination = Join-Path `
                $disabledFolder `
                ([IO.Path]::GetFileName($sourcePath))

            Move-Item `
                -LiteralPath $sourcePath `
                -Destination $destination `
                -Force `
                -ErrorAction Stop

            New-ItemProperty `
                -Path $backupPath `
                -Name "DisabledFilePath" `
                -Value $destination `
                -PropertyType String `
                -Force |
                Out-Null
        }


        Write-Host ""
        Write-Host "Startup item disabled successfully." `
            -ForegroundColor Green

        try {

            Write-ToolkitLog `
                "Startup item '$($item.Name)' disabled." `
                "INFO"
        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Unable to disable startup item." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-DisabledStartupPrograms {

    Write-Host "DISABLED STARTUP PROGRAMS" `
        -ForegroundColor Cyan

    Write-Host "========================="
    Write-Host ""

    $backupRoot = Get-StartupBackupPath

    $entries = Get-ChildItem `
        -Path $backupRoot `
        -ErrorAction SilentlyContinue

    if (-not $entries) {

        Write-Host "No startup items have been disabled by this toolkit." `
            -ForegroundColor Yellow

        return
    }


    $results = foreach ($entry in $entries) {

        $data = Get-ItemProperty `
            -Path $entry.PSPath `
            -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            ID       = $entry.PSChildName
            Name     = $data.Name
            Scope    = $data.Scope
            Source   = $data.Source
            Command  = $data.Command
        }
    }

    $results |
        Format-Table `
            Name,
            Scope,
            Source,
            Command `
            -Wrap `
            -AutoSize
}


function Enable-StartupProgram {

    Clear-Host

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host " ENABLE STARTUP PROGRAM"

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    $backupRoot = Get-StartupBackupPath

    $entries = @(
        Get-ChildItem `
            -Path $backupRoot `
            -ErrorAction SilentlyContinue
    )

    if ($entries.Count -eq 0) {

        Write-Host "No startup items have been disabled by this toolkit." `
            -ForegroundColor Yellow

        return
    }


    $items = @()

    foreach ($entry in $entries) {

        $data = Get-ItemProperty `
            -Path $entry.PSPath `
            -ErrorAction SilentlyContinue

        $items += [PSCustomObject]@{
            BackupPath       = $entry.PSPath
            Name             = $data.Name
            Command          = $data.Command
            Scope            = $data.Scope
            Source           = $data.Source
            Location         = $data.Location
            DisabledFilePath = $data.DisabledFilePath
        }
    }


    for ($i = 0; $i -lt $items.Count; $i++) {

        Write-Host (
            "{0}. {1} [{2}]" `
            -f ($i + 1),
            $items[$i].Name,
            $items[$i].Source
        )
    }

    Write-Host ""
    Write-Host "0. Cancel"
    Write-Host ""

    $selection = Read-Host "Select startup item to enable"

    $number = 0

    if (
        -not [int]::TryParse(
            $selection,
            [ref]$number
        )
    ) {
        return
    }

    if ($number -eq 0) {
        return
    }

    if (
        $number -lt 1 -or
        $number -gt $items.Count
    ) {

        Write-Host ""
        Write-Host "Invalid selection." `
            -ForegroundColor Red

        return
    }

    $item = $items[$number - 1]

    Write-Host ""
    Write-Host "Selected:" -ForegroundColor Yellow
    Write-Host "Name    : $($item.Name)"
    Write-Host "Source  : $($item.Source)"
    Write-Host "Command : $($item.Command)"
    Write-Host ""

    $confirm = Read-Host "Enable this startup item? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }


    try {

        if ($item.Source -eq "Registry") {

            if (-not (Test-Path $item.Location)) {

                New-Item `
                    -Path $item.Location `
                    -Force |
                    Out-Null
            }

            New-ItemProperty `
                -Path $item.Location `
                -Name $item.Name `
                -Value $item.Command `
                -PropertyType String `
                -Force `
                -ErrorAction Stop |
                Out-Null
        }
        elseif ($item.Source -eq "Startup Folder") {

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $item.DisabledFilePath
                ) -and
                (Test-Path $item.DisabledFilePath)
            ) {

                if (-not (Test-Path $item.Location)) {

                    New-Item `
                        -Path $item.Location `
                        -ItemType Directory `
                        -Force |
                        Out-Null
                }

                $destination = Join-Path `
                    $item.Location `
                    ([IO.Path]::GetFileName(
                        $item.DisabledFilePath
                    ))

                Move-Item `
                    -LiteralPath $item.DisabledFilePath `
                    -Destination $destination `
                    -Force `
                    -ErrorAction Stop
            }
        }


        Remove-Item `
            -Path $item.BackupPath `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue


        Write-Host ""
        Write-Host "Startup item enabled successfully." `
            -ForegroundColor Green

        try {

            Write-ToolkitLog `
                "Startup item '$($item.Name)' enabled." `
                "INFO"
        }
        catch {}
    }
    catch {

        Write-Host ""
        Write-Host "Unable to enable startup item." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Show-StartupAuditMenu {

    do {

        Clear-Host

        Write-Host "STARTUP PROGRAMS" `
            -ForegroundColor Cyan

        Write-Host "================"
        Write-Host ""

        Write-Host "1. View Startup Programs"
        Write-Host "2. Disable Startup Program"
        Write-Host "3. Enable Startup Program"
        Write-Host "4. View Disabled Startup Items"
        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Get-StartupAudit
            }

            "2" {
                Disable-StartupProgram
            }

            "3" {
                Enable-StartupProgram
            }

            "4" {
                Get-DisabledStartupPrograms
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


Export-ModuleMember -Function `
    Get-StartupRegistryLocations, `
    Get-StartupBackupPath, `
    Get-StartupAudit, `
    Get-ManageableStartupItems, `
    Disable-StartupProgram, `
    Get-DisabledStartupPrograms, `
    Enable-StartupProgram, `
    Show-StartupAuditMenu