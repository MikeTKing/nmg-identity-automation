# NMG Identity Automation

PowerShell scripts that automate parts of the identity lifecycle, written for Northstar Medical Group, a simulated healthcare organization.

## The Problem

Northstar did not have an automated way to find the user accounts that belonged to people who no longer worked there. The offboarding process was run by a single employee who notified the IT Department by email when someone was leaving. When she left, the notifications stopped, and nobody was aware for 102 days.

A manual reconciliation identified 23 stale accounts and took 11 hours across 4 days. It could not identify accounts belonging to people whose separation was never recorded, contractors who were never on payroll, or service accounts that were never people at all.

## The Approach

Instead of matching Active Directory against HR or payroll records, these scripts ask the domain controller when each account last signed in. That answer comes from sign-in activity itself, so it holds up even when a departure goes unreported, a name is spelled differently between systems, or the account never belonged to a person.

## Before you start

- Windows Server with the ActiveDirectory PowerShell module

      Import-Module ActiveDirectory

- Rights to modify user objects in the domain
- An authorising ticket number, in the form NMG-0000
- A Disabled Users OU at the root of the domain
- A writable reports folder. Create it if it does not exist:

      New-Item -Path "C:\Reports\Offboarding" -ItemType Directory -Force

## Tools

### Find-StaleAccounts.ps1

Lists enabled accounts that haven't signed in for a set number of days, including accounts that have never signed in. Each run saves a timestamped CSV and a summary file that records the exact criteria used.

```powershell
.\Find-StaleAccounts.ps1
.\Find-StaleAccounts.ps1 -Days 30
.\Find-StaleAccounts.ps1 -Days 180 -IncludeDisabled
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Days` | int | 90 | Number of days without a sign-in before an account is flagged |
| `-ReportPath` | string | C:\Reports | Folder where the reports are saved |
| `-IncludeDisabled` | switch | off | Also report disabled accounts |

**Output:** Every run creates two files: a CSV listing each flagged account, and a summary recording the question behind it, so anyone can rerun the same check and compare results.

### Offboard-NMGUser.ps1

Performs all five steps of SOP-IAM-001 against a single account.
Documents the account and its group memberships, verifies that
record on disk, disables the account, stamps the authorising
ticket, removes all group memberships, and moves the account to
the Disabled Users OU.

    .\Offboard-NMGUser.ps1 -Username "jdoe" -Ticket "NMG-0214" -WhatIf
    .\Offboard-NMGUser.ps1 -Username "jdoe" -Ticket "NMG-0214"

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Username` | string | required | SamAccountName of the account to offboard |
| `-Ticket` | string | required | Authorising ticket, in the form NMG-0000 |
| `-ReportPath` | string | C:\Reports\Offboarding | Where evidence files are written |
| `-LogPath` | string | Logs\ | Where the run transcript is written |
| `-WhatIf` | switch | off | Runs every check and changes nothing |

**Output:** two timestamped CSV files per account recording what
it was and what it could reach, plus a transcript of the run.

### Get-NMGOffboardingStatus.ps1

Reports how many accounts have been offboarded and quarantined,
how many are offboarded but not yet moved, and how many are still
waiting. Takes no parameters and makes no changes of any kind.

    .\Get-NMGOffboardingStatus.ps1

**Output:** three counts and two named lists, printed to the
console. Nothing is written to disk.

## When the script refuses

A refusal is the tool working correctly. It stops before making
any change at all, and tells you why.

| Message | What it means | What to do |
|---|---|---|
| no account named X | The username is wrong, or the account is already gone | Check the spelling in Active Directory |
| already disabled | Somebody has handled this one before you | Read the description field for the ticket number |
| looks like a service account | This is not a person | Find the owner. It needs a different procedure |
| ticket should look like NMG-0000 | The ticket format is wrong | Use the full four digit form |
| export file is empty | The record could not be written | Check the reports folder exists and is writable |
| Disabled Users OU not found | The destination is missing | Steps 1 to 4 completed. Move the account by hand |

## Known limitations

- Three accounts were offboarded before step 5 was implemented
  and were moved into the Disabled Users OU manually afterwards.
  Their logs do not record the move.
- Handles one account per run. Bulk processing is not built yet.
- The service account check matches on a name prefix and a
  department. An unusually named service account could get past it.

## Repository Structure

    Scripts/        PowerShell tools
    Documentation/  Runbooks and procedures
    Evidence/       Sample reports and screenshots that verify results
    Logs/           Output from script runs

## Environment

Runs on Windows Server with Active Directory Domain Services. Requires the ActiveDirectory PowerShell module.

## About

Created during the TotalThreat 30-Day Challenge. Northstar Medical Group and every account in this project are fictional, and all work was done in a simulated healthcare lab environment.

Author: Michael King
