# Windows IT Operations Toolkit v5.0

A modular PowerShell-based **Advanced Technician Console** designed for Windows IT support, helpdesk troubleshooting, endpoint diagnostics, Active Directory support, Microsoft 365 administration, security checks, reporting, and technician case documentation.

The project remains fully **CMD / PowerShell based**. No web server, database, Windows service, or standalone software installation is required for the core toolkit.

---

## Project Evolution

This project has evolved through multiple versions, with each release adding a new layer of practical IT support capability.

### v1.0 - Core Windows IT Support Toolkit

The initial release focused on common Level 1 / Level 2 support activities.

Key features:

- System health checks
- Network diagnostics
- Hardware inventory
- Software inventory
- Printer troubleshooting
- Windows service monitoring
- Event Log analysis
- Windows repair tools
- HTML support reporting
- Activity logging

### v1.1 - Optimized Endpoint Diagnostics

Improved the original toolkit based on real diagnostic testing and PowerShell 5.1 compatibility requirements.

Key improvements:

- Cleaner full diagnostic output
- Top RAM-consuming processes
- Top CPU-consuming processes
- Better health indicators
- Improved Event Log summaries
- Microsoft Defender checks
- Windows Firewall checks
- BitLocker status
- Pending reboot detection
- Improved Windows PowerShell 5.1 compatibility

### v2.0 - Active Directory Support

Expanded the toolkit into enterprise user and computer administration.

Key features:

- Search Active Directory users
- Search Active Directory computers
- View group membership
- Check account status
- Check password expiry
- Check account expiry
- Unlock user accounts
- Enable or disable accounts
- Reset user passwords
- Require password change at next logon

### v3.0 - Microsoft 365 / Microsoft Graph Support

Added Microsoft 365 support through Microsoft Graph PowerShell.

Key features:

- Microsoft Graph authentication
- Microsoft 365 user lookup
- License details
- Group membership
- Tenant organization information
- Read-only Graph permissions by default

### v4.0 - IT Operations Dashboard

Introduced local visual reporting while keeping the toolkit fully PowerShell based.

Key features:

- Local HTML dashboard
- Memory health
- Disk health
- Uptime
- Critical/error event count
- Core Windows service status
- Process monitoring
- HTML support reports

### v4.1 - Enhanced IT Dashboard

Improved endpoint visibility and dashboard presentation.

Key improvements:

- Device overview
- Network health
- Security status
- Microsoft Defender information
- Windows Firewall information
- BitLocker status
- Top memory processes
- Top CPU processes
- Error-source analysis
- Responsive layout

### v4.2 - Dashboard & Report Improvements

Focused on dashboard usability and professional reporting.

Key improvements:

- Fixed table overflow
- Improved handling of long Event Log messages
- Responsive Event Log tables
- Executive health summary
- Device summary
- Network summary
- Security summary
- Better process tables
- Print-friendly support reports

### v5.0 - Advanced Technician Console

The current release expands the toolkit into a broader technician workflow while keeping the entire project CMD / PowerShell based.

Major additions:

- Smart Health Diagnosis
- Automated troubleshooting recommendations
- Windows Update diagnostics
- Wi-Fi diagnostics
- TCP port testing
- Listening-port inventory
- Local user audit
- Local administrator audit
- Logged-on session checks
- Failed logon analysis
- Startup program audit
- Crash / BSOD analysis
- Crash dump detection
- Secure Boot checks
- TPM status
- RDP status
- Domain / workgroup information
- Proxy information
- Time synchronization checks
- Technician support case logging

---

## v5.0 Highlights

### Smart Diagnosis

The toolkit can now evaluate several endpoint conditions and provide an overall device health state:

- Healthy
- Warning
- Critical

Checks include:

- Memory pressure
- Low disk space
- Pending reboot
- Windows Update service
- Internet connectivity
- DNS resolution
- Microsoft Defender
- Event Log activity

The toolkit also provides recommended technician actions based on detected conditions.
