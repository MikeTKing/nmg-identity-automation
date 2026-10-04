# Bulk offboarding run, 15 August 2026

**Ticket:** NMG-0231
**Source:** NMG_Separations_Q2Q3.csv, received 11 Aug, S. Torres
**Approved by:** R. Ito, Privacy Officer, in writing, 13 Aug
**Run by:** [your name]
**Duration:** approximately 1 minute

## Result

| Outcome | Count |
|---|---|
| Approved | 22 |
| Completed | 22 |
| Rolled back | 0 |
| Stranded | 0 |

### Not included

`ppatel` appeared on the source file at row 29 and was held at
validation as a current employee. R. Ito declined it in writing.
The account is untouched and was confirmed enabled after the run.

## Verification

Three independent checks were performed after the run:

1. The results file was reconciled against the approved list.
   22 outcomes, matching the approved count.
2. Active Directory was queried directly. 22 accounts appear in
   the Disabled Users OU with the ticket number in the description.
3. The evidence folder was counted. 44 per-account files, being
   two per completed account.

All three agree.

## Evidence

Held in `Evidence/`: the source file as received, the validation
report, the approved list, the written approval, 44 per-account
evidence files and the run results file. The transcript is in
`Logs/`.

## Notes

This is the first bulk offboarding performed at Northstar Medical
Group. Ticket NMG-0117, opened 3 April 2026 when termination
notifications ceased, was closed on the basis of this run.

---

Performed during the TotalThreat 30-Day Challenge in a simulated
healthcare environment. Northstar Medical Group is fictional.
