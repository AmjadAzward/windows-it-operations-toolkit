$script:Root = $null
$script:LogFile = $null

function Initialize-Toolkit {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    $script:Root = $ProjectRoot
    $logs = Join-Path $ProjectRoot "logs"
    if (-not (Test-Path $logs)) { New-Item -ItemType Directory $logs | Out-Null }
    $script:LogFile = Join-Path $logs ("Toolkit_{0}.log" -f (Get-Date -Format "yyyyMMdd"))
    Write-ToolkitLog "Toolkit v4.0 initialized." "INFO"
}

function Test-IsAdministrator {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { $false }
}

function Assert-Administrator {
    if (-not (Test-IsAdministrator)) {
        throw "Administrator privileges are required for this action."
    }
}

function Write-ToolkitLog {
    param([string]$Message,[ValidateSet("INFO","WARN","ERROR")][string]$Level="INFO")
    if ($script:LogFile) {
        Add-Content $script:LogFile ("{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Level,$Message)
    }
}

function Write-StatusLine {
    param([ValidateSet("PASS","WARN","FAIL","INFO")][string]$Status,[string]$Label,[string]$Value)
    $c = switch($Status){"PASS"{"Green"}"WARN"{"Yellow"}"FAIL"{"Red"}default{"Cyan"}}
    Write-Host ("[{0}] " -f $Status) -ForegroundColor $c -NoNewline
    Write-Host ("{0,-32} {1}" -f $Label,$Value)
}

function Confirm-Action {
    param([string]$Message)
    (Read-Host "$Message [Y/N]") -match '^[Yy]$'
}

Export-ModuleMember -Function *
