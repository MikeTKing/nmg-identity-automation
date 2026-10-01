markdown
# Findings: NMG_Separations_Q2Q3.csv

**Received:** 11 August 2026, from S. Torres, HR
**Reviewed by:** [your name]
**Rows:** 40
**Accounts actioned:** 0

## Summary

The file contains 13 defects. Nine are visible on inspection.
Four are only detectable by comparing each row against the
directory. No account was actioned during this review.

## Visible on inspection

| # | Problem | Rows | What it would break | Rule that catches it |
|---|---|---|---|---|
| 1 | Blank row | 23 | Lookup with no identity | Skip rows with no username |
| 2 | Employee ID in username column | 19 | Account not found | Reject anything not shaped like a username |
| 3 | Exact duplicate | 4, 20 | Second run overwrites the first record | Deduplicate on trimmed username |
| 4 | Duplicate, name reversed | 6, 14 | Same, and harder to see | Deduplicate on trimmed username |
| 5 | Trailing whitespace | 14, 21, 32 | Account reported as not found | Trim every field on import |
| 6 | Five date formats | many | Nothing, this column is unused | Ignore the column, and say so |
| 7 | Row with no name | 17 | No way to verify the person | Require both name and username |
| 8 | Row with no username | 18 | Nothing to act on | Skip and report |
| 9 | Email pasted into a cell | 21 | Contradicts the date column | Flag unusually long notes |

## Only detectable against the directory

| # | Problem | Rows | Consequence |
|---|---|---|---|
| 10 | Account of a current employee | 29 | A working colleague would be disabled and stripped |
| 11 | Service accounts | 30, 41 | Overnight processes would fail |
| 12 | Already disabled | 9 rows | Original offboarding record overwritten |
| 13 | Usernames not in the directory | 17 | Script refuses. No harm, but no action either |

## Row 29

The row naming P. Patel is correctly spelled, carries a valid
username, the correct department and no formatting defect of any
kind. It is indistinguishable from the 39 rows around it.

She is a current employee. The row was added in July from a
service desk export titled "accounts to review".

No amount of reading this file would have found it.

## Recommendation

No bulk offboarding should be run from this file, or any file
like it, until every row has been checked against the directory
and the result reviewed by a person before any change is made.

---

Written during the TotalThreat 30-Day Challenge in a simulated
healthcare environment. Northstar Medical Group is fictional.
