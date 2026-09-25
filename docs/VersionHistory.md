# Version History

## v1.0
Initial endpoint support toolkit.

## v1.1
Optimized diagnostic output, added top memory/CPU process analysis and security checks.

## v2.0
Added optional Active Directory support functions.

## v3.0
Added optional Microsoft 365 / Microsoft Graph read-only support.

## v4.0
Added local HTML IT operations dashboard and consolidated the project into one portfolio-ready release.

## v5.0
Advanced Technician Console with smart diagnosis, Windows Update diagnostics, user/admin auditing, Wi-Fi diagnostics, port testing, crash analysis, startup audit, advanced system checks, and technician case logging.

## v5.1
Added detailed battery health reporting, native Windows battery report generation, and battery health integration into the dashboard and HTML report.

## v5.1.1
Fixed Battery Health data not appearing in the HTML dashboard/report by ensuring BatteryHealth.psm1 is loaded before dependent reporting modules and explicitly importing the dependency inside those modules.


## v5.1.2
- Fixed Windows PowerShell 5.1 parser error caused by a trailing comma in the module list.
- Replaced the launcher execution-policy bypass with a safer RemoteSigned process policy.
- Added `Prepare-Toolkit.cmd` to explicitly remove downloaded-file zone markers only after user confirmation.
- The preparation utility does not disable Smart App Control, Defender, or Windows security features.
- Fixed TCP port parsing for Windows PowerShell 5.1 compatibility.
