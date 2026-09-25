function Show-WindowsRepairMenu {
 do{
  Clear-Host;Write-Host "WINDOWS REPAIR TOOLS" -ForegroundColor Cyan
  Write-Host "1. SFC /scannow`n2. DISM ScanHealth`n3. DISM RestoreHealth`n4. Flush DNS`n5. Reset Winsock`n0. Back"
  $c=Read-Host "Select"
  try{
   switch($c){
    "1"{Assert-Administrator;if(Confirm-Action "Run SFC?"){& sfc.exe /scannow}}
    "2"{Assert-Administrator;if(Confirm-Action "Run DISM ScanHealth?"){& dism.exe /Online /Cleanup-Image /ScanHealth}}
    "3"{Assert-Administrator;if(Confirm-Action "Run DISM RestoreHealth?"){& dism.exe /Online /Cleanup-Image /RestoreHealth}}
    "4"{if(Confirm-Action "Flush DNS cache?"){& ipconfig.exe /flushdns}}
    "5"{Assert-Administrator;if(Confirm-Action "Reset Winsock?"){& netsh.exe winsock reset}}
   }
  }catch{Write-Host $_.Exception.Message -ForegroundColor Red}
  if($c-ne"0"){Read-Host "Press ENTER"}
 }while($c-ne"0")
}
Export-ModuleMember -Function *
