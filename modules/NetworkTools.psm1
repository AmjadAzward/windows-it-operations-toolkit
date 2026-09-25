function Get-NetworkDiagnostics {
    param([switch]$Detailed)
    Write-Host "NETWORK DIAGNOSTICS" -ForegroundColor Cyan
    $cfgs = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
      Where-Object {$_.IPv4Address -and $_.NetAdapter.Status -eq "Up"}

    if(-not $cfgs){ Write-StatusLine FAIL "Active Adapter" "None"; return }

    foreach($c in $cfgs){
        Write-StatusLine PASS "Adapter" $c.InterfaceAlias
        Write-StatusLine INFO "IPv4" (($c.IPv4Address|Select -First 1).IPAddress)
        Write-StatusLine INFO "Gateway" (($c.IPv4DefaultGateway|Select -First 1).NextHop)
        Write-StatusLine INFO "DNS" ($c.DnsServer.ServerAddresses -join ", ")
    }

    $gw = ($cfgs | ForEach-Object {$_.IPv4DefaultGateway.NextHop} | Select -First 1)
    if($gw){
      Write-StatusLine ($(if(Test-Connection $gw -Count 1 -Quiet -ErrorAction SilentlyContinue){"PASS"}else{"FAIL"})) "Gateway Connectivity" $gw
    }
    Write-StatusLine ($(if(Test-Connection "1.1.1.1" -Count 1 -Quiet -ErrorAction SilentlyContinue){"PASS"}else{"FAIL"})) "Internet Connectivity" "1.1.1.1"
    try { Resolve-DnsName "www.microsoft.com" -ErrorAction Stop | Out-Null; $dns=$true } catch {$dns=$false}
    Write-StatusLine ($(if($dns){"PASS"}else{"FAIL"})) "DNS Resolution" "www.microsoft.com"

    if($Detailed){
      Get-NetIPConfiguration | Where-Object {$_.IPv4Address} |
      Select InterfaceAlias,@{N="IPv4";E={$_.IPv4Address.IPAddress -join ", "}},
      @{N="Gateway";E={$_.IPv4DefaultGateway.NextHop -join ", "}} | Format-Table -AutoSize
    }
}
Export-ModuleMember -Function *
