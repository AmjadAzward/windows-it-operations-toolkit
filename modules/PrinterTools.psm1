function Show-PrinterSupportMenu {
 do{
   Clear-Host; Write-Host "PRINTER SUPPORT" -ForegroundColor Cyan
   Write-Host "1. List Printers`n2. Restart Print Spooler`n3. Clear Print Queue`n0. Back"
   $c=Read-Host "Select"
   try{
    switch($c){
      "1"{Get-Printer -ErrorAction SilentlyContinue|Select Name,DriverName,PortName,PrinterStatus,Shared|Format-Table -AutoSize; Get-Service Spooler|Format-Table Name,Status}
      "2"{Assert-Administrator; if(Confirm-Action "Restart Print Spooler?"){Restart-Service Spooler -Force; Write-ToolkitLog "Spooler restarted." "INFO"}}
      "3"{Assert-Administrator; if(Confirm-Action "Clear ALL queued print jobs?"){Stop-Service Spooler -Force; Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue; Start-Service Spooler; Write-ToolkitLog "Print queue cleared." "INFO"}}
    }
   }catch{Write-Host $_.Exception.Message -ForegroundColor Red}
   if($c-ne"0"){Read-Host "Press ENTER"}
 }while($c-ne"0")
}
Export-ModuleMember -Function *
