# Blast Radius Test: unvalidated bulk offboarding

**Date:** 12 August 2026
**Run by:** Michael King
**Environment:** simulator. No live system was involved.
**Source file:** NMG_Separations_Q2Q3.csv, 40 rows, as received

## What was tested

A four line loop that imports the separations file, disables
each account and removes its group memberships. No validation
of any kind. The loop calls Active Directory directly and does
not use `Offboard-NMGUser.ps1`.

## Result

The loop completed in 4.12 seconds and reported 40 processed,
0 failures. That report is accurate and it is also the only
kind of statement the script is capable of making.

| Measure | Result |
|---|---|
| Accounts modified | 32 |
| Current employees disabled | 1 |
| Service accounts disabled | 2 |
| Existing offboarding records overwritten | 4 |
| Errors, loop continued past all | 8 |
| Evidence files written | 0 |
| Log entries written | 0 |
| Ticket numbers recorded | 0 |

## The finding that matters most

No evidence was captured for any account. Active Directory
keeps no history of a removed group membership, and nothing was
written to disk before the removals. There is no record, in any
system, of what any of the 32 accounts could reach.

Every other outcome on this page can be reversed by somebody.
This one cannot be reversed by anybody.

## Why existing controls did not prevent it

`Offboard-NMGUser.ps1` performs four refusal checks, verifies
the group export on disk, and confirms the destination OU before
moving an account. None of those controls were reached, because
the loop does not call the script.

The controls were not defeated. They were not on the path taken.

## Same file, with validation

| Measure | Unvalidated | Validated |
|---|---|---|
| Accounts changed | 32 | 26 |
| Current employees hit | 1 | 0 |
| Service accounts hit | 2 | 0 |
| Records overwritten | 4 | 0 |
| Evidence files | 0 | 52 |
| Held for human review | 0 | 14 |

Time difference: 0.19 seconds.

## Recommendation

Bulk offboarding is implemented in three separate phases:

1. Read and clean. Uses the file only. Changes nothing.
2. Check and report. Uses the directory. Changes nothing.
3. Act on an approved list, reviewed by a person.

Phase 3 must read the approved output of phase 2, never the
original file. Validation that feeds directly into action
provides no opportunity for review and is not validation.

---

Written during the TotalThreat 30-Day Challenge in a simulated
healthcare environment. Northstar Medical Group is fictional.
