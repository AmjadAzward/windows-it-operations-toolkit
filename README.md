# Windows IT Operations Toolkit v5.1

A modular PowerShell-based **Advanced Technician Console** for Windows IT support, endpoint diagnostics, troubleshooting, Active Directory, Microsoft 365, security checks, reporting, and technician case documentation.

The toolkit is fully **CMD / PowerShell based** and does not require a web server, database, or standalone application.

---

## Key Features

### Smart Diagnostics
- Automated health status: Healthy / Warning / Critical
- Memory and disk checks
- Pending reboot detection
- Windows Update service checks
- Internet and DNS diagnostics
- Defender checks
- Event Log error checks
- Suggested technician actions

### Battery Health
- Design capacity
- Full charge capacity
- Current remaining capacity
- Current charge percentage
- Battery health percentage
- Battery wear percentage
- Cycle count where supported
- Native Windows `powercfg /batteryreport`
- Battery information included in dashboard and HTML report

Battery health formula:

```text
Battery Health % = Full Charge Capacity / Design Capacity x 100
```

### Performance
- Memory usage
- Disk usage
- System uptime
- Top RAM processes
- Top CPU processes

### Network
- Active adapter details
- IPv4 address
- Gateway
- DNS servers
- Internet connectivity
- DNS resolution
- Wi-Fi diagnostics
- Saved Wi-Fi profiles
- TCP port testing
- Local listening ports

### Security
- Microsoft Defender
- Real-time protection
- Windows Firewall
- BitLocker
- Secure Boot
- TPM
- RDP status
- Local users
- Local administrators
- Logged-on sessions
- Failed logon events

### Troubleshooting
- Printer support
- Service monitoring
- Startup program audit
- Event Log analysis
- Crash / BSOD analysis
- Crash dump detection
- SFC
- DISM
- DNS flush
- Winsock reset

### Enterprise Support
- Active Directory user and computer lookup
- Group membership
- Account and password expiry
- Unlock accounts
- Enable / disable accounts
- Password reset
- Microsoft Graph user lookup
- Microsoft 365 license details
- Tenant information

### Reporting
- HTML support report
- Local HTML dashboard
- Battery health reporting
- Technician case logging
- Daily activity logging

---

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
17. Printer Support
18. Service Monitoring
19. Windows Repair Tools

ENTERPRISE SUPPORT
20. Active Directory Tools
21. Microsoft 365 / Graph Tools

REPORTING & CASE MANAGEMENT
22. Generate HTML Support Report
23. Generate IT Dashboard
24. Technician Case Log
25. Open Reports Folder
26. Open Logs Folder
27. Open Cases Folder

0. Exit
```

---

## Quick Start

Run:

```text
Launch-Toolkit.bat
```

or:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ITOpsToolkit.ps1
```

Use **Run as administrator** for privileged troubleshooting, Security Event Log access, repair commands, and account-management functions.

---

## Requirements

- Windows 10 / Windows 11
- Windows PowerShell 5.1+
- Administrator privileges for selected functions
- RSAT / ActiveDirectory module for Active Directory features
- Microsoft Graph PowerShell SDK for Microsoft 365 features

---

## Version History

| Version | Main Focus |
|---|---|
| v1.0 | Core Windows IT support and diagnostics |
| v1.1 | Improved endpoint diagnostics |
| v2.0 | Active Directory support |
| v3.0 | Microsoft 365 / Microsoft Graph |
| v4.0 | Local IT Operations Dashboard |
| v4.1 | Enhanced dashboard |
| v4.2 | Dashboard and reporting improvements |
| v5.0 | Advanced Technician Console |
| v5.1 | Battery Health Integration |

---

## Safety

- Diagnostic functions are read-only wherever practical.
- System-changing actions require confirmation.
- Administrative actions require appropriate privileges.
- Microsoft 365 integration starts with read-only Graph permissions.
- Passwords, access tokens, and recovery keys are not written to reports or logs.
- Generated reports, logs, and case files should not be committed to public repositories.

---

## Portfolio Skills Demonstrated

PowerShell, Windows administration, IT support, helpdesk troubleshooting, networking, endpoint security, Active Directory, Microsoft 365, Microsoft Graph, Windows Event Logs, battery diagnostics, Git, GitHub, modular scripting, logging, reporting, and safe administrative automation.

---

## Disclaimer

Use only on systems you are authorized to inspect, support, or administer.

Test system-changing actions in a lab or approved environment before production use.
