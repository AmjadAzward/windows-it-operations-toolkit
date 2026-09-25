# Windows IT Operations Toolkit v4.2

A portfolio-ready, modular PowerShell project for Windows helpdesk, desktop support, system administration, Active Directory support, Microsoft 365 support, diagnostics, reporting, and local IT operations dashboards.

## Version Roadmap Included

### v1.1 - Optimized Endpoint Diagnostics
- Cleaner full diagnostic output
- Top RAM and CPU processes
- System health
- Network diagnostics
- Hardware and software inventory
- Security health
- BitLocker / firewall / Defender checks
- Printer troubleshooting
- Service monitoring
- SFC / DISM / DNS / Winsock tools
- Compact event log analysis
- HTML reporting
- Logging

### v2.0 - Active Directory Support
- Search users
- Group membership
- Password / account expiry
- Computer lookup
- Unlock accounts
- Enable / disable users
- Password reset with forced change at next logon
- Confirmation prompts for modifying actions

Requires the ActiveDirectory PowerShell module / RSAT and appropriate domain permissions.

### v3.0 - Microsoft 365 / Microsoft Graph
- Graph authentication
- User lookup
- License details
- Group membership
- Tenant organization summary
- Starts with read-only Graph scopes

Requires the Microsoft Graph PowerShell SDK and authorized Microsoft 365 access.

### v4.2 - IT Operations Dashboard
- Local HTML support report
- Local dashboard
- Memory and storage KPIs
- Uptime
- Top processes
- service status
- 24-hour critical/error event count

## Quick Start

```powershell
.\ITOpsToolkit.ps1
```

or run:

```text
Launch-Toolkit.bat
```

Use **Run as administrator** only when you need repair or account-management features.

## Security Design

- Read-only diagnostics are separated from modifying actions.
- Privileged actions require Administrator checks where applicable.
- Destructive/administrative operations require explicit confirmation.
- Microsoft 365 integration begins with read-only Graph scopes.
- No passwords, access tokens, tenant IDs, secrets, or credentials are stored in the repository.
- Do not commit generated reports or logs from production machines.

## Portfolio Skills Demonstrated

PowerShell, Windows 10/11 administration, helpdesk troubleshooting, system diagnostics, network troubleshooting, Windows security, Active Directory, Microsoft 365, Microsoft Graph, reporting, modular scripting, logging, Git, and GitHub documentation.

## Disclaimer

Use only on systems and directories you are authorized to administer. Test modifying actions in a lab or approved environment before production use.


## v4.2 Dashboard Upgrade

The dashboard now includes:

- Device overview
- Memory, disk, uptime and event health cards
- Pending reboot status
- Network health and DNS checks
- Active adapter, IP, gateway and DNS
- Microsoft Defender status
- Real-time protection status
- Defender signature version
- Windows Firewall profile status
- BitLocker status
- Top RAM processes
- Top CPU processes
- Core Windows service status
- Top event-error sources
- Recent critical/error event details
- Installed application count
- Laptop battery status where available
- Improved responsive layout and UTF-8 encoding
