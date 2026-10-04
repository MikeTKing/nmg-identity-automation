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

All five steps of this procedure are implemented in
`Scripts/Offboard-NMGUser.ps1`.

    .\Scripts\Offboard-NMGUser.ps1 -Username "jdoe" -Ticket "NMG-0214"

Both parameters are mandatory. The script will not run without
an authorising ticket number.

Operating instructions, including every refusal the script can
produce and what to do about each one, are in the repository
README rather than here. This document describes what should
happen. The README describes how to make it happen.

### Why step 4 has a gate in front of it

Removing group memberships is the only step in this procedure
that cannot be reversed. The CSV written moments earlier is the
only record that will ever exist of what the account could
reach, so the script reads that file back from disk and counts
the rows before the removal is reachable.

### Why step 5 goes last

Moving an object changes its distinguished name. Every earlier
step refers to the account at its original location, so a move
performed first would cause the remaining steps to fail against
a path that no longer exists.

## Reporting

`Scripts/Get-NMGOffboardingStatus.ps1` reports how many accounts
have been offboarded, how many are offboarded but not yet moved,
and how many remain. It takes no parameters and makes no changes
of any kind. It is safe for anybody to run at any time.

## Known exceptions

Two accounts, hgrady and rpace, were offboarded before step 5
was implemented and were moved into the Disabled Users OU
manually afterwards. Their evidence files and logs therefore do
not record the move.

## History

This procedure was tooled between Day 7 and Day 10. Earlier
commits refer to the script as Disable-NMGUser.ps1, which was
accurate when it performed two steps. It was renamed once it
performed all five.


### What it leaves behind

- Two timestamped CSV files in `Evidence/`, capturing the
  account and its group memberships before the change.
- A transcript in `Logs/`, recording which account was
  actioned, under which ticket, by whom, and at what time.

## Reporting

`Scripts/Get-NMGOffboardingStatus.ps1` reports how many accounts
have been offboarded, how many are offboarded but not yet moved,
and how many remain. It takes no parameters and makes no changes
of any kind. It is safe for anybody to run at any time.


## Known exceptions

Two accounts, hgrady and rpace, were offboarded before step 5
was implemented and were moved into the Disabled Users OU
manually afterwards. Their evidence files and logs therefore do
not record the move.

## Why step 4 depends on step 1

Removing group memberships is the only step in this procedure that
cannot be reversed. The CSV written in step 1 is the only record that
will ever exist of what the account could reach. The removal loop uses
the group list captured in step 1, so if the session was closed
between steps, step 1 must be run again first. If step 1 reports zero
memberships, stop and find out why before running step 4.

## Bulk requests

This procedure describes offboarding a single account against a
single authorising ticket. Requests sometimes arrive as a list
instead, usually as a spreadsheet from Human Resources.

A list is a request, not an authorisation. It must be validated
before any account on it is actioned.

### The file you were sent is evidence

Store the original unmodified, alongside the offboarding evidence
it produced. Cleaning is performed on a copy. The original proves
what was asked for. The cleaned copy proves what was decided.

### Every row is checked before any row is actioned

For each row, confirm:

- The username exists in the directory.
- The account is not already disabled.
- The account belongs to a person, not a service.
- The person is not a current employee.

That last check is the one a spreadsheet cannot help with, and it
is the one that matters most. A row naming a current employee is
indistinguishable, on the page, from a correct row.

### A person reviews the result

Validation produces a report. The report is read by a person, and
that person decides whether to proceed. Validation that feeds
straight into action is not validation, it is a delay.

### How bulk requests are processed

Bulk offboarding runs in three separate phases. The separation
is the control. Collapsing any two of them removes it.

**Phase 1, read and clean.** Import the file, trim every field,
skip rows with no username, reject anything not shaped like a
username, and remove duplicates on the trimmed username. This
phase uses the file alone and changes nothing.

**Phase 2, check and report.** Look up every remaining row in
the directory and record, for each one, whether the account
exists, whether it is already disabled, whether it is a service
account, and whether the person appears to be a current
employee. This phase produces a report and changes nothing.

**A person reviews the report and approves it.** This step is
not optional and it is not a formality. Deciding that a named
individual should not be offboarded is a judgement rather than
a rule, and judgements require a person.

**Phase 3, act.** Offboard the accounts on the approved list.
This phase reads the approved output of phase 2 and never the
original file.

### Why the phases stay separate

A validation check placed inside the action loop runs at the
same speed as the action, with nobody watching. It will catch
conditions that are rules, such as a service account or an
already disabled account. It cannot catch a row naming a current
employee, because that row is indistinguishable from a correct
one and only a person can decide.

Validation that feeds directly into action provides no
opportunity for review. It is a delay, not a control.

### Tested

An unvalidated bulk run against a real separations file was
simulated on 12 August 2026. It reported complete success while
disabling a current employee, two service accounts, and
overwriting four existing offboarding records, with no evidence
captured for any of the 32 accounts modified.

See `Documentation/Blast-Radius-Findings.md`.

### The validation report

Phase 2 produces a report for human review and a separate
approved list for phase 3. The two files have different
audiences and are not interchangeable.

`Validation-Report.txt` is written to be read by a person.
`Approved.csv` is written to be parsed by phase 3.

### Report format

The report presents findings in three tiers, ordered by what a
wrong decision costs. The format is part of the control. A
future version that flattens it into a single table has removed
the control without changing a single check.

**Tier 1, at the top, alone.** Any row where a wrong decision
would cause a person to lose access they need, or a system to
stop working. Stated as a question, with enough context to
answer it. Nothing appears above it on the page.

**Tier 2.** Rows requiring a decision where nothing is urgent.
Service accounts and previously offboarded records. Grouped and
listed once.

**Tier 3.** Rows dropped mechanically, where the tool is certain
and human review adds nothing. Counted and summarised, never
itemised. Full detail is available in the dropped file.

The report ends with the number of accounts that will be
offboarded if it is approved. That number is what the approver
is signing.

### Who approves

The Privacy Officer, or a delegate named in writing. Approval is
recorded by replying to the report, and the reply is stored with
the evidence for that run.

### Why the tiering matters

A reviewer reads the first few rows of a list carefully and the
remainder progressively less so. This is a description of
everybody rather than a criticism of anybody. A report that
presents forty rows of equal weight therefore spends most of the
reviewer's attention on rows that required none, and a row that
needed a decision can be approved without being read.

A review that is performed but not really done is worse than no
review, because it converts an unchecked action into an approved
one and attaches a name to it.

### When a bulk run fails partway

Each account is processed independently and atomically. An
account either completes all five steps or is restored to its
original state. No account is left partially offboarded.

### The three outcomes

Every account in a bulk run ends in exactly one of three states,
and each is recorded by name in the results file.

**COMPLETE.** All five steps ran. The account is offboarded and
the evidence exists.

**ROLLED BACK.** A step failed and the account was restored to
its original state. Group memberships are restored from the
export taken in step 1. The randomised password is not reversed,
because the value is unknown to everybody and a re-enabled
account with an unknown password cannot be signed into.

**STRANDED.** A step failed and the rollback also failed. The
account is in an undefined state and requires manual review. The
results file names the account, the step and the reason.

A stranded account is the only outcome requiring human action,
and it is always named.

### Stopping early

The run stops after three consecutive failures on the assumption
that the cause is systemic rather than per-account. Accounts not
yet attempted are untouched and remain on the approved list.

### Repeating a run

A bulk run may be repeated against the same approved list.
Accounts already offboarded fail at step 2 and are rolled back
without change, so a repeat run resumes rather than duplicating.

### The summary

Every run produces a summary naming, for each failure, the
account, the step that failed, the reason, and the resulting
state. A count alone is not sufficient.


## History

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-09-26 | Michael King | Initial release under NMG-0203. First use: kferreira, offboarded by hand. |
| 1.1 | 2026-09-28 | Michael King | Step 4 added to the script under NMG-0212, behind an evidence read-back gate, with partial-failure reporting. First use: rpace. |
| 1.2 | 2026-09-29 | Michael King | Step 5 added to the script under NMG-0213. Reporting script and known exceptions added. First use: oradcliffe. |

---

## Why each safeguard exists

Every safeguard below looks like unnecessary caution to somebody
who was not here when it was added. Each one is recorded with the
consequence of removing it, so that a future change is a decision
rather than an assumption.

**Documentation happens before removal.** Active Directory keeps
no history of a removed group membership. The CSV written in step
1 is the only record of what an account could reach, and it is
also the only thing a rollback can restore from. Remove this step
and a failed bulk run has nothing to roll back to.

**Validation is separate from action.** A check placed inside the
action loop runs at the same speed as the action, with nobody
watching. Separating them creates a point at which a person reads
a report and decides. Collapse the phases and that point
disappears, along with the only control that catches a row naming
a current employee.

**The report has three tiers.** A reviewer reads the first few
rows of a list carefully and the remainder progressively less so.
Presenting forty rows of equal weight spends the reviewer's
attention on rows that needed none, and a row requiring a decision
can be approved without being read. Flattening the report removes
the control without changing a single check.

**A person approves before anything runs.** Deciding that a named
individual should not be offboarded is a judgement rather than a
rule. On 13 August a row naming a current employee was correctly
formatted, correctly spelled and pointed at a valid account. No
automated check would have refused it. It was declined by a person
reading one line.

### Before removing any of the above

Read this section and the findings documents that produced it.
Each safeguard was added in response to a specific failure that
was observed rather than imagined.


Built during the TotalThreat 30-Day Challenge in a simulated
healthcare environment. Northstar Medical Group is fictional.