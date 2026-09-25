function New-SupportCaseLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    Clear-Host
    Write-Host "TECHNICIAN SUPPORT CASE LOG" -ForegroundColor Cyan
    Write-Host "==========================="

    $ticket = Read-Host "Ticket / Case Number"
    if ([string]::IsNullOrWhiteSpace($ticket)) {
        $ticket = "CASE-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    }

    $user = Read-Host "Affected User"
    $issue = Read-Host "Reported Issue"
    $findings = Read-Host "Findings"
    $action = Read-Host "Action Taken"
    $result = Read-Host "Result / Resolution"
    $technician = Read-Host "Technician Name"

    $safeTicket = $ticket -replace '[^a-zA-Z0-9_-]','_'
    $caseDir = Join-Path $ProjectRoot "cases"
    if (-not (Test-Path $caseDir)) {
        New-Item -ItemType Directory -Path $caseDir | Out-Null
    }

    $path = Join-Path $caseDir "$safeTicket.txt"

    $content = @"
WINDOWS IT OPERATIONS TOOLKIT - SUPPORT CASE
============================================

Ticket / Case : $ticket
Date / Time   : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer      : $env:COMPUTERNAME
Current User  : $env:USERNAME
Affected User : $user
Technician    : $technician

REPORTED ISSUE
--------------
$issue

FINDINGS
--------
$findings

ACTION TAKEN
------------
$action

RESULT / RESOLUTION
-------------------
$result
"@

    $content | Set-Content -Path $path -Encoding UTF8
    Write-ToolkitLog "Support case created: $ticket" "INFO"

    Write-Host ""
    Write-Host "Case saved:" -ForegroundColor Green
    Write-Host $path

    return $path
}

Export-ModuleMember -Function New-SupportCaseLog
