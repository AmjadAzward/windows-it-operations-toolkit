function Get-HardwareInventory {
    param([switch]$Display,[switch]$SummaryOnly)
    $cs=Get-CimInstance Win32_ComputerSystem
    $bios=Get-CimInstance Win32_BIOS
    $cpu=Get-CimInstance Win32_Processor|Select -First 1
    $ram=Get-CimInstance Win32_PhysicalMemory
    $disk=Get-CimInstance Win32_DiskDrive
    $obj=[pscustomobject]@{
      Computer=$env:COMPUTERNAME; Manufacturer=$cs.Manufacturer; Model=$cs.Model;
      Serial=$bios.SerialNumber; CPU=$cpu.Name;
      RAM_GB=[math]::Round(($ram | Measure-Object -Property Capacity -Sum).Sum/1GB,2);
      DiskCount=@($disk).Count
    }

    Write-Host "HARDWARE INVENTORY" -ForegroundColor Cyan
    if($SummaryOnly){
      Write-StatusLine INFO "Manufacturer / Model" "$($obj.Manufacturer) $($obj.Model)"
      Write-StatusLine INFO "Serial Number" $obj.Serial
      Write-StatusLine INFO "RAM" "$($obj.RAM_GB) GB"
      Write-StatusLine INFO "Physical Disks" "$($obj.DiskCount)"
    } elseif($Display){
      $obj|Format-List
      $ram|Select Manufacturer,PartNumber,@{N="CapacityGB";E={[math]::Round($_.Capacity/1GB,2)}},Speed|Format-Table -AutoSize
      $disk|Select Model,InterfaceType,@{N="SizeGB";E={[math]::Round($_.Size/1GB,2)}},SerialNumber|Format-Table -AutoSize
      Get-NetAdapter -Physical -ErrorAction SilentlyContinue|Select Name,InterfaceDescription,Status,MacAddress,LinkSpeed|Format-Table -AutoSize
    }
}
Export-ModuleMember -Function *
