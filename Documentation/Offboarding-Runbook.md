markdown
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

---

Built during the TotalThreat 30-Day Challenge in a simulated
healthcare environment. Northstar Medical Group is fictional.
