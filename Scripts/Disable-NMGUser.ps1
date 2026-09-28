<#
.SYNOPSIS
    Documents and disables a single Active Directory account.

.DESCRIPTION
    Steps 1 and 2 of SOP-IAM-001. Captures the account and its group
    memberships to timestamped CSV files, then disables the account and
    stamps it with the authorising ticket number.

    Refuses to act on an account that does not exist, is already
    disabled, or appears to be a service account.

.PARAMETER Username
    The SamAccountName of the account to offboard. Mandatory.

.PARAMETER Ticket
    The authorising ticket, in the form NMG-0000. Mandatory.

.EXAMPLE
    .\Disable-NMGUser.ps1 -Username "hgrady" -Ticket "NMG-0211" -WhatIf
    Runs every check and reports what it would do, changing nothing.

.NOTES
    Author  : YOUR NAME HERE
    Created : TODAY'S DATE HERE
    Implements steps 1 and 2 of SOP-IAM-001.
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
    Stop-Transcript | Out-Null
    return
}

# CHECK 2: has somebody already handled this one?
if ($user.Enabled -eq $false) {
    Write-Host "  STOP: $Username is already disabled." -ForegroundColor Yellow
    Write-Host "        Existing note: $($user.Description)" -ForegroundColor Gray
    Write-Host "        Re-running would overwrite that record." -ForegroundColor Gray
    Stop-Transcript | Out-Null
    return
}

# CHECK 3: is this a person, or is it machinery?
if ($user.SamAccountName -like "svc_*" -or $user.Department -eq "Service Accounts") {
    Write-Host "  STOP: $Username looks like a service account." -ForegroundColor Red
    Write-Host "        Find its owner first. Different procedure." -ForegroundColor Gray
    Stop-Transcript | Out-Null
    return
}

# CHECK 4: is the ticket a real shape?
if ($Ticket -notmatch "^NMG-\d{4}$") {
    Write-Host "  STOP: ticket should look like NMG-0211" -ForegroundColor Red
Stop-Transcript | Out-Null
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

#--- SUMMARY ------------------------------------------------

Write-Host ""
Write-Host "  Account  : $($user.Name) ($Username)"
Write-Host "  Ticket   : $Ticket"
Write-Host "  Evidence : $ReportPath"
Write-Host "  Log      : $LogPath"
Write-Host ""

Stop-Transcript | Out-Null

foreach ($g in $groups) {

    if ($g.Name -eq "Domain Users") { continue }

    Remove-ADGroupMember -Identity $g `
        -Members $Username -Confirm:$false

    Write-Host "  Removed: $($g.Name)" -ForegroundColor Yellow
}
