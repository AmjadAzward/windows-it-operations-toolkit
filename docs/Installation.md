# Installation

## Basic endpoint diagnostics
Requires Windows PowerShell 5.1+ on Windows 10/11.

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ITOpsToolkit.ps1
```

## Active Directory features
Install RSAT / Active Directory PowerShell tools using your organization's approved method.

Check:

```powershell
Get-Module -ListAvailable ActiveDirectory
```

## Microsoft 365 features
Install Microsoft Graph PowerShell SDK:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

Then use menu option 13 and authenticate with an account that has the required permissions.
