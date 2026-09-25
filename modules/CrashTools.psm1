function Get-CrashDiagnostics {
    Write-Host "CRASH / BSOD ANALYZER" -ForegroundColor Cyan
    Write-Host "====================="

    Write-Host ""
    Write-Host "Recent Application Crashes:" -ForegroundColor White
    $appCrashes = Get-WinEvent -FilterHashtable @{
        LogName = "Application"
        Id = 1000,1001
        StartTime = (Get-Date).AddDays(-7)
    } -ErrorAction SilentlyContinue | Select-Object -First 20

    if ($appCrashes) {
        $appCrashes |
            Select-Object TimeCreated, Id, ProviderName,
            @{N="Message";E={
                $m = $_.Message -replace "`r|`n"," "
                if($m.Length -gt 150){$m.Substring(0,150)+"..."}else{$m}
            }} |
            Format-Table -Wrap -AutoSize
    } else {
        Write-StatusLine -Status "PASS" -Label "Application Crashes" -Value "No recent crash events detected"
    }

    Write-Host ""
    Write-Host "Unexpected Shutdown / BugCheck Events:" -ForegroundColor White
    $systemEvents = Get-WinEvent -FilterHashtable @{
        LogName = "System"
        Id = 41,6008,1001
        StartTime = (Get-Date).AddDays(-30)
    } -ErrorAction SilentlyContinue | Select-Object -First 20

    if ($systemEvents) {
        $systemEvents |
            Select-Object TimeCreated, Id, ProviderName,
            @{N="Message";E={
                $m = $_.Message -replace "`r|`n"," "
                if($m.Length -gt 150){$m.Substring(0,150)+"..."}else{$m}
            }} |
            Format-Table -Wrap -AutoSize
    } else {
        Write-StatusLine -Status "PASS" -Label "BSOD/Unexpected Shutdown" -Value "No matching events detected"
    }

    Write-Host ""
    Write-Host "Crash Dump Files:" -ForegroundColor White
    $dumps = @()
    if (Test-Path "$env:SystemRoot\MEMORY.DMP") {
        $dumps += Get-Item "$env:SystemRoot\MEMORY.DMP"
    }
    if (Test-Path "$env:SystemRoot\Minidump") {
        $dumps += Get-ChildItem "$env:SystemRoot\Minidump" -Filter "*.dmp" -ErrorAction SilentlyContinue
    }

    if ($dumps) {
        $dumps | Sort-Object LastWriteTime -Descending |
            Select-Object -First 15 FullName, Length, LastWriteTime |
            Format-Table -AutoSize
    } else {
        Write-Host "No dump files detected." -ForegroundColor DarkGray
    }
}

Export-ModuleMember -Function Get-CrashDiagnostics
