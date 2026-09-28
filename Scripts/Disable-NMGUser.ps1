<#
.SYNOPSIS
    Documents, disables and strips group memberships from a single
    Active Directory account.

.DESCRIPTION
    Steps 1, 2 and 4 of SOP-IAM-001. Captures the account and its group
    memberships to timestamped CSV files, reads the membership file back
    from disk to verify the record exists, disables the account and
    stamps it with the authorising ticket number, then removes every
    group membership except Domain Users.

    Refuses to act on an account that does not exist, is already
    disabled, or appears to be a service account. Refuses to remove
    memberships if the export file was not written or is empty.

    Individual removal failures are recorded and reported; the loop
    continues so the result is never an unknown partial state.

.PARAMETER Username
    The SamAccountName of the account to offboard. Mandatory.

.PARAMETER Ticket
    The authorising ticket, in the form NMG-0000. Mandatory.

.PARAMETER ReportPath
    Folder for the evidence CSV files. Default C:\Reports\Offboarding.

.PARAMETER LogPath
    Folder for the transcript. Default C:\nmg-identity-automation\Logs.

.EXAMPLE
    .\Disable-NMGUser.ps1 -Username "rpace" -Ticket "NMG-0212" -WhatIf
    Runs every check and reports what it would do, changing nothing.

.NOTES
    Author  : Michael King
    Created : 2026-09-27
    Updated : 2026-09-28 - step 4 added behind an export verification gate
    Implements steps 1, 2 and 4 of SOP-IAM-001.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Username,
    [Parameter(Mandatory)]
    [string]$Ticket,

    [string]$ReportPath = "C:\Reports\Offboarding",
    [string]$LogPath    = "C:\nmg-identity-automation\Logs"
)
Import-Module ActiveDirectory

$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"

foreach ($p in @($ReportPath, $LogPath)) {
    if (-not (Test-Path $p)) {
        New-Item -Path $p -ItemType Directory -Force | Out-Null
    }
}

# Everything printed from here on ends up in a dated file.
# Never print a credential after this line.
Start-Transcript -Path "$LogPath\Disable-NMGUser_$stamp.log" | Out-Null

Write-Host ""
Write-Host "  DISABLE-NMGUSER" -ForegroundColor Cyan
Write-Host "  Target : $Username"
Write-Host "  Ticket : $Ticket"
Write-Host "  Run by : $env:USERNAME"
Write-Host ""

#--- THE FOUR CHECKS ----------------------------------------
# Every one of these stops the script. A warning that scrolls
# past at 4:50 on a Friday is a decoration, not a guardrail.

# CHECK 1: does the account exist at all?
$user = Get-ADUser -Identity $Username -Properties * -ErrorAction SilentlyContinue

if (-not $user) {
    Write-Host "  STOP: no account named $Username" -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch { }
    return
}

# CHECK 2: has somebody already handled this one?
if ($user.Enabled -eq $false) {
    Write-Host "  STOP: $Username is already disabled." -ForegroundColor Yellow
    Write-Host "        Existing note: $($user.Description)" -ForegroundColor Gray
    Write-Host "        Re-running would overwrite that record." -ForegroundColor Gray
    try { Stop-Transcript | Out-Null } catch { }
    return
}

# CHECK 3: is this a person, or is it machinery?
if ($user.SamAccountName -like "svc_*" -or $user.Department -eq "Service Accounts") {
    Write-Host "  STOP: $Username looks like a service account." -ForegroundColor Red
    Write-Host "        Find its owner first. Different procedure." -ForegroundColor Gray
    try { Stop-Transcript | Out-Null } catch { }
    return
}

# CHECK 4: is the ticket a real shape?
if ($Ticket -notmatch "^NMG-\d{4}$") {
    Write-Host "  STOP: ticket should look like NMG-0211" -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch { }
    return
}

Write-Host "  All checks passed for $($user.Name)" -ForegroundColor Green

#--- STEP 1: DOCUMENT ---------------------------------------
# Runs on a WhatIf too. Reading changes nothing, and the record
# is worth having either way.

$groups = Get-ADPrincipalGroupMembership -Identity $Username

$user |
  Select-Object Name, SamAccountName, Department, Title,
                LastLogonDate, Enabled, DistinguishedName |
  Export-Csv "$ReportPath\$($Username)_account_$stamp.csv" `
    -NoTypeInformation -Encoding UTF8

$groups |
  Select-Object Name, GroupCategory, DistinguishedName |
  Export-Csv "$ReportPath\$($Username)_groups_$stamp.csv" `
    -NoTypeInformation -Encoding UTF8

Write-Host "  Captured $($groups.Count) memberships" -ForegroundColor Green

#--- EDIT 2: THE VERIFICATION GATE --------------------------
# Read the file back from disk. $groups tells you the query
# worked. The file tells you the record actually exists.
# Sits BEFORE the disable, so a failed record leaves the
# account completely untouched.
#
# Export-Csv does not write on a dry run, so this only checks
# when the run is real. Otherwise every dry run would refuse.

if (-not $WhatIfPreference) {

    $groupFile = "$ReportPath\$($Username)_groups_$stamp.csv"

    if (-not (Test-Path $groupFile)) {
        Write-Host "  STOP: no export file was written." -ForegroundColor Red
        try { Stop-Transcript | Out-Null } catch { }
        return
    }

    $written = @(Import-Csv $groupFile)

    if ($written.Count -eq 0) {
        Write-Host "  STOP: export file is empty." -ForegroundColor Red
        Write-Host "        Refusing to remove unrecorded access." -ForegroundColor Gray
        try { Stop-Transcript | Out-Null } catch { }
        return
    }

    Write-Host "  Verified $($written.Count) memberships on disk" -ForegroundColor Green
}

#--- STEP 2: DISABLE ----------------------------------------
# ShouldProcess is what makes -WhatIf work. Everything inside
# this block is skipped on a WhatIf run, and you write nothing
# extra to make that happen.

if ($PSCmdlet.ShouldProcess($Username, "Disable account and stamp $Ticket")) {

    Disable-ADAccount -Identity $Username

    Set-ADUser -Identity $Username `
    -Description "Offboarded $(Get-Date -Format yyyy-MM-dd) | Ticket $Ticket"

    Write-Host "  Disabled and stamped." -ForegroundColor Green
}

#--- STEP 4: REMOVE GROUP MEMBERSHIPS -----------------------
# A SECOND ShouldProcess block. WhatIf skips what is inside it,
# including the loop AND the report of what the loop did.

$toRemove = @($groups | Where-Object { $_.Name -ne "Domain Users" })

if ($PSCmdlet.ShouldProcess($Username, "Remove $($toRemove.Count) memberships")) {

    $removed = @()
    $failed  = @()

    # The catch does NOT stop the loop. Stopping on one bad
    # membership would leave the rest attached, and you would
    # have no idea which half came off.
    foreach ($g in $toRemove) {

        try {
            Remove-ADGroupMember -Identity $g -Members $Username `
                -Confirm:$false -ErrorAction Stop
            $removed += $g.Name
            Write-Host "  Removed: $($g.Name)" -ForegroundColor Yellow
        }
        catch {
            $failed += "$($g.Name)  ($($_.Exception.Message))"
        }
    }

    # EDIT 5: report what actually happened. Partial success is
    # a real outcome and has to be visible.
    Write-Host ""
    Write-Host "  Removed : $($removed.Count)" -ForegroundColor Green

    if ($failed.Count -gt 0) {
        Write-Host "  FAILED  : $($failed.Count)" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        Write-Host "  Account is PARTIALLY stripped. Follow up." -ForegroundColor Yellow
    } else {
        Write-Host "  FAILED  : 0" -ForegroundColor Green
    }
}

#--- SUMMARY ------------------------------------------------

Write-Host ""
Write-Host "  Account  : $($user.Name) ($Username)"
Write-Host "  Ticket   : $Ticket"
Write-Host "  Evidence : $ReportPath"
Write-Host "  Log      : $LogPath"
Write-Host ""

# EDIT 1: last line. On a WhatIf run the transcript never
# started, so there is nothing to stop.
try { Stop-Transcript | Out-Null } catch { }