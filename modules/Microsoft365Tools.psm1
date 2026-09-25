function Test-GraphModule {
    [bool](Get-Module -ListAvailable Microsoft.Graph.Authentication)
}

function Connect-M365ReadOnly {
    if(-not (Test-GraphModule)){
      Write-Host "Microsoft Graph PowerShell SDK is not installed." -ForegroundColor Yellow
      Write-Host "Install from an elevated PowerShell session if approved:"
      Write-Host "Install-Module Microsoft.Graph -Scope CurrentUser"
      return $false
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","Directory.Read.All" -NoWelcome
    return $true
}

function Show-Microsoft365Menu {
    Clear-Host
    Write-Host "MICROSOFT 365 / GRAPH SUPPORT (v3.0)" -ForegroundColor Cyan
    if(-not (Test-GraphModule)){
      Write-Host "Microsoft Graph SDK not detected." -ForegroundColor Yellow
      Write-Host "This module intentionally starts with read-only Graph scopes."
      Write-Host "Install-Module Microsoft.Graph -Scope CurrentUser"
      Read-Host "Press ENTER"
      return
    }

    try{
      if(-not (Get-MgContext)){ if(-not (Connect-M365ReadOnly)){return} }
    }catch{
      if(-not (Connect-M365ReadOnly)){return}
    }

    do{
      Clear-Host;Write-Host "MICROSOFT 365 / GRAPH SUPPORT" -ForegroundColor Cyan
      Write-Host "1. Lookup User"
      Write-Host "2. List User Licenses"
      Write-Host "3. List User Group Membership"
      Write-Host "4. Tenant Organization Summary"
      Write-Host "5. Disconnect Graph"
      Write-Host "0. Back"
      $c=Read-Host "Select"
      try{
       switch($c){
        "1"{
          $u=Read-Host "User principal name / email"
          Get-MgUser -UserId $u -Property Id,DisplayName,UserPrincipalName,AccountEnabled,Department,JobTitle |
          Select DisplayName,UserPrincipalName,AccountEnabled,Department,JobTitle | Format-List
        }
        "2"{
          $u=Read-Host "User principal name / email"
          Get-MgUserLicenseDetail -UserId $u | Select SkuPartNumber,SkuId | Format-Table -AutoSize
        }
        "3"{
          $u=Read-Host "User principal name / email"
          $usr=Get-MgUser -UserId $u
          Get-MgUserMemberOf -UserId $usr.Id | ForEach-Object {
            [pscustomobject]@{Id=$_.Id;Type=$_.AdditionalProperties.'@odata.type';Name=$_.AdditionalProperties.displayName}
          } | Format-Table -AutoSize
        }
        "4"{
          Get-MgOrganization | Select DisplayName,Id,VerifiedDomains | Format-List
        }
        "5"{Disconnect-MgGraph;Write-Host "Disconnected." -ForegroundColor Green}
       }
      }catch{Write-Host "GRAPH ERROR: $($_.Exception.Message)" -ForegroundColor Red}
      if($c-ne"0"){Read-Host "Press ENTER"}
    }while($c-ne"0")
}
Export-ModuleMember -Function *
