#Requires -Version 5.1


function Get-CaseFolder {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $caseFolder = Join-Path `
        $ProjectRoot `
        "cases"

    if (-not (Test-Path $caseFolder)) {

        New-Item `
            -Path $caseFolder `
            -ItemType Directory `
            -Force |
        Out-Null
    }

    return $caseFolder
}


function Convert-ToSafeFileName {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $invalidChars = [IO.Path]::GetInvalidFileNameChars()

    $safe = $Name

    foreach ($char in $invalidChars) {
        $safe = $safe.Replace(
            [string]$char,
            "_"
        )
    }

    $safe = $safe.Trim()

    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = "CASE"
    }

    return $safe
}


function Get-CaseSystemInformation {

    $os = $null
    $ipAddress = "Unavailable"

    try {

        $os = Get-CimInstance `
            Win32_OperatingSystem `
            -ErrorAction SilentlyContinue

    }
    catch {}


    try {

        $ip = Get-NetIPAddress `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.IPAddress -notmatch "^127\." -and
                $_.IPAddress -notmatch "^169\.254\." -and
                $_.AddressState -eq "Preferred"
            } |
            Select-Object -First 1

        if ($ip) {
            $ipAddress = $ip.IPAddress
        }

    }
    catch {}


    return [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        LoggedInUser = $env:USERNAME
        Windows      = if ($os) { $os.Caption } else { "Unavailable" }
        OSVersion    = if ($os) { $os.Version } else { "Unavailable" }
        IPAddress    = $ipAddress
        DateTime     = Get-Date
    }
}


function Get-CasePriority {

    Write-Host ""
    Write-Host "PRIORITY" -ForegroundColor Cyan
    Write-Host "1. Low"
    Write-Host "2. Medium"
    Write-Host "3. High"
    Write-Host "4. Critical"
    Write-Host ""

    $choice = Read-Host "Select priority"

    switch ($choice) {

        "1" { return "Low" }
        "2" { return "Medium" }
        "3" { return "High" }
        "4" { return "Critical" }

        default {
            return "Medium"
        }
    }
}


function Get-CaseCategory {

    Write-Host ""
    Write-Host "ISSUE CATEGORY" -ForegroundColor Cyan
    Write-Host "1. Hardware"
    Write-Host "2. Software"
    Write-Host "3. Network"
    Write-Host "4. Printer"
    Write-Host "5. User Account"
    Write-Host "6. Security"
    Write-Host "7. Microsoft 365"
    Write-Host "8. Active Directory"
    Write-Host "9. Performance"
    Write-Host "10. Other"
    Write-Host ""

    $choice = Read-Host "Select category"

    switch ($choice) {

        "1"  { return "Hardware" }
        "2"  { return "Software" }
        "3"  { return "Network" }
        "4"  { return "Printer" }
        "5"  { return "User Account" }
        "6"  { return "Security" }
        "7"  { return "Microsoft 365" }
        "8"  { return "Active Directory" }
        "9"  { return "Performance" }
        "10" { return "Other" }

        default {
            return "Other"
        }
    }
}


function New-SupportCaseLog {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    Clear-Host

    Write-Host "TECHNICIAN SUPPORT CASE LOG" `
        -ForegroundColor Cyan

    Write-Host "==========================="
    Write-Host ""

    $caseFolder = Get-CaseFolder `
        -ProjectRoot $ProjectRoot

    $systemInfo = Get-CaseSystemInformation


    $caseNumber = Read-Host "Ticket / Case Number"

    if ([string]::IsNullOrWhiteSpace($caseNumber)) {

        $caseNumber = "CASE-{0}" -f (
            Get-Date -Format "yyyyMMdd-HHmmss"
        )

        Write-Host ""
        Write-Host "Generated Case Number: $caseNumber" `
            -ForegroundColor Yellow
    }


    $affectedUser = Read-Host "Affected User"
    $department = Read-Host "Department"
    $contact = Read-Host "Contact Number / Email"

    $category = Get-CaseCategory
    $priority = Get-CasePriority

    Write-Host ""

    $reportedIssue = Read-Host "Reported Issue"
    $initialDiagnosis = Read-Host "Initial Diagnosis"
    $findings = Read-Host "Findings"
    $actionTaken = Read-Host "Action Taken"
    $partsSoftware = Read-Host "Parts / Software Used"
    $resolution = Read-Host "Result / Resolution"

    Write-Host ""
    $resolved = Read-Host "Is the case resolved? [Y/N]"

    if ($resolved -match "^[Yy]$") {
        $status = "Resolved"
    }
    else {
        $status = "Open"
    }

    $followUp = Read-Host "Follow-Up Required? [Y/N]"

    if ($followUp -match "^[Yy]$") {
        $followUpRequired = "Yes"
    }
    else {
        $followUpRequired = "No"
    }

    $technician = Read-Host "Technician Name"

    if ([string]::IsNullOrWhiteSpace($technician)) {
        $technician = $env:USERNAME
    }


    $safeName = Convert-ToSafeFileName `
        -Name $caseNumber

    $filePath = Join-Path `
        $caseFolder `
        "$safeName.txt"


    if (Test-Path $filePath) {

        Write-Host ""
        Write-Host "A case with this number already exists." `
            -ForegroundColor Yellow

        $overwrite = Read-Host "Overwrite existing case? [Y/N]"

        if ($overwrite -notmatch "^[Yy]$") {

            Write-Host ""
            Write-Host "Case creation cancelled." `
                -ForegroundColor Yellow

            return
        }
    }


    $caseContent = @"
============================================================
TECHNICIAN SUPPORT CASE
============================================================

CASE INFORMATION
----------------
Case Number       : $caseNumber
Created           : $($systemInfo.DateTime.ToString("yyyy-MM-dd HH:mm:ss"))
Status            : $status
Priority          : $priority
Category          : $category

USER INFORMATION
----------------
Affected User     : $affectedUser
Department        : $department
Contact           : $contact

DEVICE INFORMATION
------------------
Computer Name     : $($systemInfo.ComputerName)
Logged-In User    : $($systemInfo.LoggedInUser)
Windows           : $($systemInfo.Windows)
OS Version        : $($systemInfo.OSVersion)
IP Address        : $($systemInfo.IPAddress)

REPORTED ISSUE
--------------
$reportedIssue

INITIAL DIAGNOSIS
-----------------
$initialDiagnosis

FINDINGS
--------
$findings

ACTION TAKEN
------------
$actionTaken

PARTS / SOFTWARE USED
---------------------
$partsSoftware

RESOLUTION
----------
$resolution

FOLLOW-UP
---------
Follow-Up Required: $followUpRequired

TECHNICIAN
----------
$technician

============================================================
END OF CASE
============================================================
"@


    try {

        $caseContent |
            Set-Content `
                -Path $filePath `
                -Encoding UTF8 `
                -Force

        Write-Host ""
        Write-Host "Case saved successfully." `
            -ForegroundColor Green

        Write-Host ""
        Write-Host $filePath

        try {

            Write-ToolkitLog `
                "Support case '$caseNumber' saved. Status: $status." `
                "INFO"

        }
        catch {}

        return $filePath

    }
    catch {

        Write-Host ""
        Write-Host "Unable to save case." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red
    }
}


function Get-SupportCases {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $caseFolder = Get-CaseFolder `
        -ProjectRoot $ProjectRoot

    return Get-ChildItem `
        -Path $caseFolder `
        -Filter "*.txt" `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
}


function Show-SupportCases {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    Clear-Host

    Write-Host "EXISTING SUPPORT CASES" `
        -ForegroundColor Cyan

    Write-Host "======================"
    Write-Host ""

    $cases = @(
        Get-SupportCases `
            -ProjectRoot $ProjectRoot
    )

    if ($cases.Count -eq 0) {

        Write-Host "No support cases found." `
            -ForegroundColor Yellow

        return
    }


    $results = foreach ($case in $cases) {

        $content = Get-Content `
            -Path $case.FullName `
            -ErrorAction SilentlyContinue

        $caseNumber = (
            $content |
            Select-String "^Case Number\s+:" |
            Select-Object -First 1
        )

        $status = (
            $content |
            Select-String "^Status\s+:" |
            Select-Object -First 1
        )

        $priority = (
            $content |
            Select-String "^Priority\s+:" |
            Select-Object -First 1
        )

        $user = (
            $content |
            Select-String "^Affected User\s+:" |
            Select-Object -First 1
        )


        [PSCustomObject]@{
            CaseNumber = if ($caseNumber) {
                ($caseNumber.ToString() -split ":", 2)[1].Trim()
            }
            else {
                $case.BaseName
            }

            User = if ($user) {
                ($user.ToString() -split ":", 2)[1].Trim()
            }
            else {
                ""
            }

            Priority = if ($priority) {
                ($priority.ToString() -split ":", 2)[1].Trim()
            }
            else {
                ""
            }

            Status = if ($status) {
                ($status.ToString() -split ":", 2)[1].Trim()
            }
            else {
                ""
            }

            Modified = $case.LastWriteTime
        }
    }


    $results |
        Format-Table `
            CaseNumber,
            User,
            Priority,
            Status,
            Modified `
            -AutoSize
}


function Find-SupportCase {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "Case",
            "User",
            "Computer"
        )]
        [string]$SearchType
    )

    Clear-Host

    Write-Host "SEARCH SUPPORT CASES" `
        -ForegroundColor Cyan

    Write-Host "===================="
    Write-Host ""

    $query = Read-Host "Enter search value"

    if ([string]::IsNullOrWhiteSpace($query)) {
        return
    }

    $cases = Get-SupportCases `
        -ProjectRoot $ProjectRoot

    $results = @()


    foreach ($case in $cases) {

        $content = Get-Content `
            -Path $case.FullName `
            -Raw `
            -ErrorAction SilentlyContinue

        if (-not $content) {
            continue
        }


        $matched = $false

        switch ($SearchType) {

            "Case" {

                if (
                    $case.BaseName -like "*$query*" -or
                    $content -match "(?im)^Case Number\s*:.*$([regex]::Escape($query))"
                ) {
                    $matched = $true
                }
            }


            "User" {

                if (
                    $content -match "(?im)^Affected User\s*:.*$([regex]::Escape($query))"
                ) {
                    $matched = $true
                }
            }


            "Computer" {

                if (
                    $content -match "(?im)^Computer Name\s*:.*$([regex]::Escape($query))"
                ) {
                    $matched = $true
                }
            }
        }


        if ($matched) {
            $results += $case
        }
    }


    if ($results.Count -eq 0) {

        Write-Host ""
        Write-Host "No matching cases found." `
            -ForegroundColor Yellow

        return
    }


    Write-Host ""
    Write-Host "Matching cases:" `
        -ForegroundColor Green

    Write-Host ""

    for ($i = 0; $i -lt $results.Count; $i++) {

        Write-Host (
            "{0}. {1}" -f `
            ($i + 1),
            $results[$i].BaseName
        )
    }

    Write-Host ""
    Write-Host "0. Cancel"
    Write-Host ""

    $selection = Read-Host "Select case to view"

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
        $number -gt $results.Count
    ) {
        return
    }

    Clear-Host

    Get-Content `
        -Path $results[$number - 1].FullName
}


function Select-SupportCaseFile {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $cases = @(
        Get-SupportCases `
            -ProjectRoot $ProjectRoot
    )

    if ($cases.Count -eq 0) {

        Write-Host ""
        Write-Host "No support cases found." `
            -ForegroundColor Yellow

        return $null
    }


    for ($i = 0; $i -lt $cases.Count; $i++) {

        Write-Host (
            "{0}. {1}" -f `
            ($i + 1),
            $cases[$i].BaseName
        )
    }

    Write-Host ""
    Write-Host "0. Cancel"
    Write-Host ""

    $selection = Read-Host "Select case"

    $number = 0

    if (
        -not [int]::TryParse(
            $selection,
            [ref]$number
        )
    ) {
        return $null
    }

    if ($number -eq 0) {
        return $null
    }

    if (
        $number -lt 1 -or
        $number -gt $cases.Count
    ) {
        return $null
    }

    return $cases[$number - 1]
}


function Update-SupportCase {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    Clear-Host

    Write-Host "UPDATE SUPPORT CASE" `
        -ForegroundColor Cyan

    Write-Host "==================="
    Write-Host ""

    $case = Select-SupportCaseFile `
        -ProjectRoot $ProjectRoot

    if (-not $case) {
        return
    }


    Write-Host ""
    Write-Host "Selected Case: $($case.BaseName)" `
        -ForegroundColor Yellow

    Write-Host ""

    $updateText = Read-Host "Enter update / additional notes"

    if ([string]::IsNullOrWhiteSpace($updateText)) {
        return
    }

    $technician = Read-Host "Technician Name"

    if ([string]::IsNullOrWhiteSpace($technician)) {
        $technician = $env:USERNAME
    }


    $update = @"

============================================================
CASE UPDATE
============================================================
Date       : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Technician : $technician

$updateText
============================================================
"@


    try {

        Add-Content `
            -Path $case.FullName `
            -Value $update `
            -Encoding UTF8

        Write-Host ""
        Write-Host "Case updated successfully." `
            -ForegroundColor Green

        try {

            Write-ToolkitLog `
                "Support case '$($case.BaseName)' updated." `
                "INFO"

        }
        catch {}

    }
    catch {

        Write-Host ""
        Write-Host "Unable to update case." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


function Close-SupportCase {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    Clear-Host

    Write-Host "CLOSE SUPPORT CASE" `
        -ForegroundColor Cyan

    Write-Host "=================="
    Write-Host ""

    $case = Select-SupportCaseFile `
        -ProjectRoot $ProjectRoot

    if (-not $case) {
        return
    }


    Write-Host ""
    Write-Host "Selected: $($case.BaseName)"
    Write-Host ""

    $resolution = Read-Host "Final resolution / closure note"

    $confirm = Read-Host "Close this case? [Y/N]"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }


    try {

        $content = Get-Content `
            -Path $case.FullName `
            -Raw `
            -ErrorAction Stop

        $content = $content -replace `
            "(?im)^Status\s*:.*$", `
            "Status            : Closed"


        Set-Content `
            -Path $case.FullName `
            -Value $content `
            -Encoding UTF8


        $closure = @"

============================================================
CASE CLOSED
============================================================
Closed Date : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Closed By   : $env:USERNAME

FINAL CLOSURE NOTE
------------------
$resolution

============================================================
"@


        Add-Content `
            -Path $case.FullName `
            -Value $closure `
            -Encoding UTF8


        Write-Host ""
        Write-Host "Case closed successfully." `
            -ForegroundColor Green

        try {

            Write-ToolkitLog `
                "Support case '$($case.BaseName)' closed." `
                "INFO"

        }
        catch {}

    }
    catch {

        Write-Host ""
        Write-Host "Unable to close case." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }
}


function Open-SupportCasesFolder {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $caseFolder = Get-CaseFolder `
        -ProjectRoot $ProjectRoot

    Start-Process `
        explorer.exe `
        $caseFolder
}


function Show-SupportCaseMenu {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    do {

        Clear-Host

        Write-Host "TECHNICIAN CASE MANAGEMENT" `
            -ForegroundColor Cyan

        Write-Host "=========================="
        Write-Host ""

        Write-Host "1. Create New Case"
        Write-Host "2. View Existing Cases"
        Write-Host "3. Search Case by Number"
        Write-Host "4. Search Cases by User"
        Write-Host "5. Search Cases by Computer"
        Write-Host "6. Update Existing Case"
        Write-Host "7. Close Case"
        Write-Host "8. Open Cases Folder"
        Write-Host ""
        Write-Host "0. Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {

                New-SupportCaseLog `
                    -ProjectRoot $ProjectRoot |
                Out-Null
            }


            "2" {

                Show-SupportCases `
                    -ProjectRoot $ProjectRoot
            }


            "3" {

                Find-SupportCase `
                    -ProjectRoot $ProjectRoot `
                    -SearchType Case
            }


            "4" {

                Find-SupportCase `
                    -ProjectRoot $ProjectRoot `
                    -SearchType User
            }


            "5" {

                Find-SupportCase `
                    -ProjectRoot $ProjectRoot `
                    -SearchType Computer
            }


            "6" {

                Update-SupportCase `
                    -ProjectRoot $ProjectRoot
            }


            "7" {

                Close-SupportCase `
                    -ProjectRoot $ProjectRoot
            }


            "8" {

                Open-SupportCasesFolder `
                    -ProjectRoot $ProjectRoot
            }


            "0" {}


            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep `
                    -Seconds 1
            }
        }


        if (
            $choice -ne "0" -and
            $choice -ne "8"
        ) {

            Write-Host ""
            Read-Host "Press ENTER"
        }

    } while ($choice -ne "0")
}


Export-ModuleMember -Function `
    Get-CaseFolder, `
    Convert-ToSafeFileName, `
    Get-CaseSystemInformation, `
    Get-CasePriority, `
    Get-CaseCategory, `
    New-SupportCaseLog, `
    Get-SupportCases, `
    Show-SupportCases, `
    Find-SupportCase, `
    Select-SupportCaseFile, `
    Update-SupportCase, `
    Close-SupportCase, `
    Open-SupportCasesFolder, `
    Show-SupportCaseMenu