function Get-SecurityHealth {
    param([switch]$Detailed)
    Write-Host "SECURITY HEALTH" -ForegroundColor Cyan

    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        Write-StatusLine ($(if($mp.AntivirusEnabled){"PASS"}else{"FAIL"})) "Microsoft Defender AV" "$($mp.AntivirusEnabled)"
        Write-StatusLine ($(if($mp.RealTimeProtectionEnabled){"PASS"}else{"FAIL"})) "Real-Time Protection" "$($mp.RealTimeProtectionEnabled)"
        if($Detailed){
            Write-StatusLine INFO "Signature Version" $mp.AntivirusSignatureVersion
            Write-StatusLine INFO "Last Quick Scan" "$($mp.QuickScanEndTime)"
        }
    } catch {
        Write-StatusLine WARN "Defender Status" "Unavailable"
    }

    try {
        $profiles = Get-NetFirewallProfile -ErrorAction Stop
        foreach($p in $profiles){
            Write-StatusLine ($(if($p.Enabled){"PASS"}else{"WARN"})) "Firewall $($p.Name)" "$($p.Enabled)"
        }
    } catch { Write-StatusLine WARN "Firewall Status" "Unavailable" }

    try {
        $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        Write-StatusLine ($(if($bl.ProtectionStatus -eq "On"){"PASS"}else{"WARN"})) "BitLocker $env:SystemDrive" "$($bl.ProtectionStatus)"
    } catch { Write-StatusLine WARN "BitLocker" "Unavailable / not supported" }

    try {
        $lic = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%'" |
          Where-Object {$_.PartialProductKey} | Select -First 1
        Write-StatusLine INFO "Windows License Status" "$($lic.LicenseStatus)"
    } catch {}
}
Export-ModuleMember -Function *
