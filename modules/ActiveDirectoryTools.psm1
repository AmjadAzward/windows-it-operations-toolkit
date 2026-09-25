function Test-ADModule {
    if(-not (Get-Module -ListAvailable ActiveDirectory)){ return $false }
    Import-Module ActiveDirectory -ErrorAction Stop
    return $true
}

function Show-ActiveDirectoryMenu {
    Clear-Host
    Write-Host "ACTIVE DIRECTORY SUPPORT (v2.0)" -ForegroundColor Cyan
    if(-not (Test-ADModule)){
        Write-Host "ActiveDirectory PowerShell module was not found." -ForegroundColor Yellow
        Write-Host "Install RSAT / Active Directory PowerShell tools on an authorized admin workstation."
        Read-Host "Press ENTER"
        return
    }

    do{
      Clear-Host;Write-Host "ACTIVE DIRECTORY SUPPORT" -ForegroundColor Cyan
      Write-Host "1. Search User"
      Write-Host "2. User Group Membership"
      Write-Host "3. Account / Password Expiry"
      Write-Host "4. Search Computer"
      Write-Host "5. Unlock User Account"
      Write-Host "6. Enable / Disable User"
      Write-Host "7. Reset User Password"
      Write-Host "0. Back"
      $c=Read-Host "Select"

      try{
       switch($c){
        "1"{
          $q=Read-Host "Username / name"
          Get-ADUser -Filter "SamAccountName -like '*$q*' -or Name -like '*$q*'" -Properties Enabled,Mail,Department,LastLogonDate |
          Select Name,SamAccountName,Enabled,Mail,Department,LastLogonDate | Format-Table -AutoSize
        }
        "2"{
          $u=Read-Host "SamAccountName"
          Get-ADPrincipalGroupMembership $u|Select Name,GroupCategory,GroupScope|Format-Table -AutoSize
        }
        "3"{
          $u=Read-Host "SamAccountName"
          Get-ADUser $u -Properties Enabled,LockedOut,PasswordExpired,PasswordLastSet,AccountExpirationDate |
          Select Name,Enabled,LockedOut,PasswordExpired,PasswordLastSet,AccountExpirationDate|Format-List
        }
        "4"{
          $q=Read-Host "Computer name"
          Get-ADComputer -Filter "Name -like '*$q*'" -Properties OperatingSystem,LastLogonDate,Enabled |
          Select Name,Enabled,OperatingSystem,LastLogonDate|Format-Table -AutoSize
        }
        "5"{
          Assert-Administrator;$u=Read-Host "SamAccountName"
          if(Confirm-Action "Unlock AD account '$u'?"){Unlock-ADAccount -Identity $u;Write-ToolkitLog "AD account unlocked: $u" "INFO"}
        }
        "6"{
          Assert-Administrator;$u=Read-Host "SamAccountName";$a=Read-Host "Type ENABLE or DISABLE"
          if($a-eq"ENABLE" -and (Confirm-Action "Enable '$u'?")){Enable-ADAccount $u;Write-ToolkitLog "AD enabled: $u" "INFO"}
          elseif($a-eq"DISABLE" -and (Confirm-Action "Disable '$u'?")){Disable-ADAccount $u;Write-ToolkitLog "AD disabled: $u" "INFO"}
        }
        "7"{
          Assert-Administrator;$u=Read-Host "SamAccountName"
          $p=Read-Host "New temporary password" -AsSecureString
          if(Confirm-Action "Reset password for '$u' and require change at next logon?"){
            Set-ADAccountPassword $u -Reset -NewPassword $p
            Set-ADUser $u -ChangePasswordAtLogon $true
            Write-ToolkitLog "AD password reset: $u" "INFO"
          }
        }
       }
      }catch{Write-Host "AD ERROR: $($_.Exception.Message)" -ForegroundColor Red}
      if($c-ne"0"){Read-Host "Press ENTER"}
    }while($c-ne"0")
}
Export-ModuleMember -Function *
