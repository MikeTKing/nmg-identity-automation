
# NMG Identity Automation

PowerShell tooling for identity lifecycle management, built for
Northstar Medical Group.

## The Problem

Northstar did not have an automated way to find the user accounts that belonged to people 
who no longer worked there. 
The offboarding process was run by a single employee who notified the IT Department 
by email when someone was leaving. 
When she left, the notifications stopped, and nobody was aware for 102 days.

A manual reconciliation identified 23 stale accounts and took 11 hours
across 4 days. It could not identify accounts belonging to people whose
separation was never recorded, contractors who were never on payroll,
or service accounts that were never people at all.

## The Approach

Rather than comparing directory records against payroll records, these
tools query the domain controller directly for the last authentication
date of every account. That value does not depend on paperwork being
filed correctly or names matching between systems.

## Tools

### Find-StaleAccounts.ps1

Identifies enabled accounts that have not authenticated within a given
number of days, including accounts that have never authenticated.
Exports a timestamped CSV plus a summary recording the exact query used

.\Find-StaleAccounts.ps1
    .\Find-StaleAccounts.ps1 -Days 30
    .\Find-StaleAccounts.ps1 -Days 180 -IncludeDisabled

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Days` | int | 90 | Days without authentication before an account is considered stale |
| `-ReportPath` | string | C:\Reports | Where reports are written |
| `-IncludeDisabled` | switch | off | Include disabled accounts in results |

**Output:** a timestamped CSV of findings, and a summary file recording
the question that produced them so the report can be reproduced.

## Repository Structure

    Scripts/        PowerShell tools
    Documentation/  Runbooks and process documentation
    Evidence/       Sample output and verification screenshots
    Logs/           Execution logs

## Environment

Windows Server with Active Directory Domain Services.
Requires the ActiveDirectory PowerShell module.

## About

Built during the TotalThreat 30-Day Challenge in a simulated
healthcare environment. Northstar Medical Group is fictional.

Author: Michael King