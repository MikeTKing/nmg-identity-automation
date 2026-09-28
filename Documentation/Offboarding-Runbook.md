# User Account Offboarding

**Document:** SOP-IAM-001
**Author:** Michael King
**Raised under:** Ticket NMG-0203
**Approved by:** R. Ito, Privacy Office

## Purpose

Defines the complete sequence for offboarding a user account at
Northstar Medical Group. Before this document, no written
offboarding standard existed.

## Before you begin

- There is a ticket from a named requester.
- Username, display name and department all match.
- No legal hold prevents action on this account.
- The account belongs to a person, not a service.

## Procedure

### 1. Document the current state
Export every attribute and group membership to a timestamped file.
Removed memberships cannot be recovered, so the record is taken
before anything changes.

### 2. Disable the account
Blocks authentication. This is the step that reduces risk, so it
happens as early as the record allows. Stamp the description with
the ticket number.

### 3. Reset the password
A random value nobody holds. If the account is ever re-enabled by
mistake, the old credential must not still work.

### 4. Remove group memberships
Disabling removes no access. Stripping the groups means a
re-enabled account can reach nothing. Domain Users is the primary
group and is skipped.

### 5. Move to the Disabled Users OU
Quarantine, so the account is never mistaken for active staff.
Last, because moving changes the object path and invalidates
earlier references.

## Retention and disposal

Retained in the Disabled Users OU for the period the retention
policy defines, then deleted on a documented schedule. Where a
legal hold is in place the clock stops and nothing is deleted
until Counsel releases it in writing.

Disabled accounts are evidence. You disable a leaver.
You do not delete them.

## Tooling

Steps 1, 2 and 4 of this procedure are implemented in
`Scripts/Disable-NMGUser.ps1`.

    .\Disable-NMGUser.ps1 -Username "rpace" -Ticket "NMG-0212"

Both parameters are mandatory. The script will not run without
an authorising ticket number.

### What the tool refuses to do

The script stops, without making any change, if:

- The named account does not exist.
- The account is already disabled.
- The account appears to be a service account.
- The ticket number is not in the form NMG-0000.
- The group membership export did not write a file.
- The export file exists but contains no rows.

### Why step 4 has a gate in front of it

Removing group memberships is the only step in this procedure
that cannot be reversed. Active Directory keeps no history of a
removed membership, so the CSV written moments earlier is the
only record that will ever exist of what the account could reach.

The script therefore reads that file back from disk and counts
the rows before the removal is reachable. Checking the query
result instead would confirm only that the query ran, not that
the record survived to disk.

If the record cannot be verified, the script stops and the
account is left untouched.

### Partial failure

If an individual membership cannot be removed, the script
records it, continues with the rest, and reports removed and
failed counts separately. An account left partially stripped is
reported as such rather than passing silently.

### Checking before acting

The script supports `-WhatIf`. Both the disable and the group
removal are declared, so both are skipped on a dry run.

Run it with `-WhatIf` first, and verify the result rather than
trusting the output. Every time.

### What it leaves behind

- Two timestamped CSV files in `Evidence/`, capturing the
  account and its group memberships before the change.
- A transcript in `Logs/`, recording which account was
  actioned, under which ticket, by whom, and at what time.

Steps 3 and 5 are still performed by hand.

## Why step 4 depends on step 1

Removing group memberships is the only step in this procedure that
cannot be reversed. The CSV written in step 1 is the only record that
will ever exist of what the account could reach. The removal loop uses
the group list captured in step 1, so if the session was closed
between steps, step 1 must be run again first. If step 1 reports zero
memberships, stop and find out why before running step 4.

## Why step 5 goes last

Moving an object changes its distinguished name. Every earlier step
refers to the account at its original location, so a move performed
first would cause the remaining steps to fail against a path that no
longer exists.

## History

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-26 | Michael King | Initial release under NMG-0203. First use: kferreira, offboarded by hand. |
| 1.1 | 2026-09-28 | Michael King | Step 4 added to the script under NMG-0212, behind an evidence read-back gate, with partial-failure reporting. First use: rpace. |

---

Built during the TotalThreat 30-Day Challenge in a simulated
healthcare environment. Northstar Medical Group is fictional.