function Get-RecentCriticalEvents {
 param([int]$Hours=24,[int]$MaxEvents=30,[switch]$Compact)
 Write-Host "RECENT CRITICAL / ERROR EVENTS" -ForegroundColor Cyan
 try{
  $ev=@(Get-WinEvent -FilterHashtable @{LogName=@("System","Application");Level=1,2;StartTime=(Get-Date).AddHours(-$Hours)} -ErrorAction Stop | Select -First $MaxEvents)
  if(-not $ev){Write-StatusLine PASS "Recent Critical/Error Events" "None";return}
  if($Compact){
    Write-StatusLine WARN "Events Found" "$($ev.Count)"
    $ev|Group-Object ProviderName|Sort Count -Descending|Select -First 8 Count,Name|Format-Table -AutoSize
  }else{
    $ev|Select TimeCreated,LogName,Id,LevelDisplayName,ProviderName,@{N="Message";E={$m=$_.Message-replace"`r|`n"," ";if($m.Length-gt120){$m.Substring(0,120)+"..."}else{$m}}}|Format-Table -Wrap -AutoSize
  }
 }catch{Write-Host "Unable to read event logs: $($_.Exception.Message)" -ForegroundColor Red}
}
Export-ModuleMember -Function *
