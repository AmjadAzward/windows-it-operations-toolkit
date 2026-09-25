function Get-ProcessHealth {
    param([int]$Top=10)
    Write-Host "TOP RESOURCE-CONSUMING PROCESSES" -ForegroundColor Cyan

    $cpuData = Get-Process -ErrorAction SilentlyContinue |
        Sort-Object CPU -Descending |
        Select-Object -First $Top Name,Id,
        @{N="CPU_Seconds";E={if($_.CPU){[math]::Round($_.CPU,1)}else{0}}},
        @{N="RAM_MB";E={[math]::Round($_.WorkingSet64/1MB,1)}}

    $ramData = Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First $Top Name,Id,
        @{N="RAM_MB";E={[math]::Round($_.WorkingSet64/1MB,1)}},
        @{N="CPU_Seconds";E={if($_.CPU){[math]::Round($_.CPU,1)}else{0}}}

    Write-Host "`nTop by RAM:" -ForegroundColor White
    $ramData | Format-Table -AutoSize
    Write-Host "Top by accumulated CPU time:" -ForegroundColor White
    $cpuData | Format-Table -AutoSize
}
Export-ModuleMember -Function *
