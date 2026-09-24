# NMG Identity Automation

PowerShell scripts that automate parts of the identity lifecycle, written for Northstar Medical Group, a simulated healthcare organization.

## The Problem

Northstar did not have an automated way to find the user accounts that belonged to people who no longer worked there. The offboarding process was run by a single employee who notified the IT Department by email when someone was leaving. When she left, the notifications stopped, and nobody was aware for 102 days.

A manual reconciliation identified 23 stale accounts and took 11 hours across 4 days. It could not identify accounts belonging to people whose separation was never recorded, contractors who were never on payroll, or service accounts that were never people at all.

## The Approach

Instead of matching Active Directory against HR or payroll records, these scripts ask the domain controller when each account last signed in. That answer comes from sign-in activity itself, so it holds up even when a departure goes unreported, a name is spelled differently between systems, or the account never belonged to a person.

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
