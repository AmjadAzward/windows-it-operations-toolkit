# v4.0.1 Fix

Fixed a Windows PowerShell 5.1 parser error in `SoftwareInventory.psm1`.

The invalid pattern:

```powershell
foreach (...) {
    ...
} | Sort-Object
```

was replaced with:

```powershell
$software = foreach (...) {
    ...
}

$software | Sort-Object DisplayName -Unique
```

This release also replaces a few shorthand aliases with explicit cmdlet names for clearer Windows PowerShell 5.1 compatibility.
