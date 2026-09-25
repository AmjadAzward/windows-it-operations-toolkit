# Windows IT Operations Toolkit v5.1.2

A modular PowerShell-based **Advanced Technician Console** for Windows IT support, helpdesk troubleshooting, endpoint diagnostics, Active Directory support, Microsoft 365 support, security checks, reporting, battery diagnostics, and technician case documentation.

The project remains fully **CMD / PowerShell based**. No web server, database, service, or standalone software installation is required for the core toolkit.

---

## Latest Release

### v5.1.2 - Windows Security & PowerShell Compatibility Fixes

**Current Version: v5.1.2**

Latest improvements include:

- Fixed Windows PowerShell 5.1 parser compatibility
- Removed the problematic trailing comma in the module list
- Improved launcher security behavior
- Replaced `ExecutionPolicy Bypass` with a safer `RemoteSigned` launch method
- Added `Prepare-Toolkit.cmd`
- Added trusted-file preparation for downloaded toolkit files
- Smart App Control is not disabled
- Microsoft Defender and Windows Firewall remain enabled
- Improved TCP port validation for PowerShell 5.1
- Retained all v5.1 battery-health functionality
- Retained battery integration in the dashboard and HTML report

---

## Version History

| Version | Release Focus | Key Additions |
|---|---|---|
| **v5.1.2** | **Latest - Security & Compatibility Fixes** | PowerShell 5.1 parser fix, safer launcher, `Prepare-Toolkit.cmd`, Smart App Control handling, TCP port validation |
| v5.1.1 | Battery Dashboard Fix | Fixed battery-health integration in Dashboard and HTML Report |
| v5.1 | Battery Health Integration | Design capacity, full charge capacity, charge %, health %, wear %, cycle count, native battery report |
| v5.0 | Advanced Technician Console | Smart Diagnosis, Wi-Fi tools, Windows Update diagnostics, user audit, BSOD analysis, case logging, system checks |
| v4.2 | Dashboard & Reporting Improvements | Responsive tables, Event Log overflow fixes, improved HTML reporting |
| v4.1 | Enhanced Dashboard | Device, network, security, process, and Event Log visibility improvements |
| v4.0 | IT Operations Dashboard | Local HTML dashboard and reporting |
| v3.0 | Microsoft 365 / Graph | Microsoft Graph user lookup, licensing, groups, tenant details |
| v2.0 | Active Directory Support | User/computer lookup, account management, password reset, group membership |
| v1.1 | Improved Endpoint Diagnostics | Better diagnostics, security checks, pending reboot detection, PowerShell 5.1 improvements |
| v1.0 | Core Windows IT Support Toolkit | System health, network, hardware/software inventory, printers, services, Event Logs, repair tools |

---

### Performance
- Top RAM processes
- Top accumulated CPU processes
- System uptime
- Disk usage
- Memory usage

### Network
- Active adapter information
- IPv4, gateway, and DNS
- Internet reachability
- DNS resolution
- Wi-Fi interface diagnostics
- Saved Wi-Fi profile listing
- Remote TCP port tester
- Local listening-port inventory

### Windows Update
- Windows Update service status
- BITS status
- Pending reboot detection
- Recent installed updates
- Last update-search time where available

### Security & Users
- Microsoft Defender status
- Real-time protection
- Firewall profile status
- BitLocker status
- Local users
- Local administrators
- Logged-on sessions
- Failed logon events
- Secure Boot
- TPM
- RDP status
- Domain/workgroup information
- WinHTTP proxy information
- Time synchronization

### Troubleshooting
- Printer support
- Service monitoring
- SFC
- DISM ScanHealth
- DISM RestoreHealth
- DNS cache flush
- Winsock reset
- Crash / BSOD event analysis
- Crash dump discovery
- Startup-program audit
- Event-log analyzer

### Enterprise Support
- Active Directory user/computer lookup
- Group membership
- Account/password expiry
- Unlock account
- Enable/disable account
- Password reset
- Microsoft Graph user lookup
- Microsoft 365 license details
- Group membership
- Tenant organization summary

### Reporting & Case Management
- Enhanced HTML support report
- Local HTML IT dashboard
- Technician support case notes
- Daily activity logging
- Generated reports/logs/case notes excluded from Git by default


## Windows Download / Smart App Control Note

If Windows reports that the downloaded toolkit is blocked, do **not** disable Smart App Control.

If the toolkit came from a source you trust, such as your own GitHub repository:

1. Run `Prepare-Toolkit.cmd`
2. Confirm that you trust the files
3. Run `Launch-Toolkit.bat`

`Prepare-Toolkit.cmd` only removes Windows downloaded-file zone markers from the toolkit files. It does not disable Smart App Control, Microsoft Defender, Windows Firewall, or other Windows security controls.

For managed enterprise deployment, digitally signing the PowerShell scripts with a trusted code-signing certificate is the preferred approach.

---

## Quick Start

Run:

```text
Launch-Toolkit.bat
```

Use **Run as administrator** when you need privileged troubleshooting, Security Event Log access, repair commands, or account-management functions.

## Main Menu

```text
SMART DIAGNOSTICS
 1. Smart Health Diagnosis
 2. Run Full Diagnostic
 3. Performance / Top Processes
 4. Network Diagnostics
 5. Wi-Fi Diagnostics
 6. Windows Update Diagnostics
 7. Crash / BSOD Analyzer

SYSTEM & SECURITY
 8. Hardware Inventory
 9. Software Inventory
10. Security Health
11. User / Local Admin Audit
12. Startup Programs Audit
13. Advanced System Checks
14. Event Log Analyzer
15. Port & Connection Tools
16. Battery Health & Report

SUPPORT & REMEDIATION
16. Printer Support
17. Service Monitoring
18. Windows Repair Tools

ENTERPRISE SUPPORT
19. Active Directory Tools
20. Microsoft 365 / Graph Tools

REPORTING & CASE MANAGEMENT
21. Generate HTML Support Report
22. Generate IT Dashboard
23. Technician Case Log
24. Open Reports Folder
25. Open Logs Folder
26. Open Cases Folder
```

## Safety

- Diagnostic functions are read-only wherever practical.
- System-changing actions require explicit confirmation.
- Administrative actions check for elevated privileges where appropriate.
- Microsoft 365 integration starts with read-only Graph permissions.
- Passwords, access tokens, recovery keys, and credentials are not written to reports or logs.
- Do not commit production diagnostic output because it can contain device names, usernames, IP addresses, software inventory, and event details.

## Requirements

- Windows 10 / Windows 11
- Windows PowerShell 5.1+
- Administrator privileges for selected functions
- RSAT / ActiveDirectory module for AD features
- Microsoft Graph PowerShell SDK for Microsoft 365 features

## Portfolio Skills Demonstrated

PowerShell, Windows administration, IT support, helpdesk troubleshooting, networking, endpoint security, Active Directory, Microsoft 365, Microsoft Graph, incident documentation, event-log analysis, Git, GitHub, modular scripting, logging, reporting, and safe administrative automation.

## Disclaimer

Use only on systems you are authorized to support or administer. Test modifying actions in a lab or approved environment before production use.
