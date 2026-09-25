function Get-CriticalServiceStatus {
  Write-Host "CRITICAL SERVICES" -ForegroundColor Cyan
  foreach($n in @("wuauserv","BITS","Spooler","WinDefend","EventLog","Dhcp","Dnscache")){
    $s=Get-Service $n -ErrorAction SilentlyContinue
    if($s){Write-StatusLine ($(if($s.Status-eq"Running"){"PASS"}else{"WARN"})) $s.DisplayName "$($s.Status)"}
  }
}
function Show-ServiceToolsMenu {
 do{
  Clear-Host;Write-Host "SERVICE MONITORING" -ForegroundColor Cyan
  Write-Host "1. Critical Services`n2. Restart a Service`n0. Back"
  $c=Read-Host "Select"
  if($c-eq"1"){Get-CriticalServiceStatus}
  elseif($c-eq"2"){
    try{
      Assert-Administrator;$n=Read-Host "Service name";$s=Get-Service $n -ErrorAction Stop
      if(Confirm-Action "Restart $($s.DisplayName)?"){Restart-Service $n -Force;Write-ToolkitLog "Service $n restarted." "INFO"}
    }catch{Write-Host $_.Exception.Message -ForegroundColor Red}
  }
  if($c-ne"0"){Read-Host "Press ENTER"}
 }while($c-ne"0")
}
Export-ModuleMember -Function *
