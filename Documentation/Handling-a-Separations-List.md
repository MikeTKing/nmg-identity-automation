# Handling a separations list

If an offboarding list has arrived from HR and you have never done this before. Start
here. The reasoning behind every step is in the runbook.

## 1. Save the file. Do not edit it.

Save it to `Evidence/` exactly as it arrived, even if you can see
something wrong with it. That file is the authorisation and it
has to stay as it was sent.

## 2. Validate it. This changes nothing.

    .\Scripts\Invoke-BulkValidation.ps1 `
        -InputFile ".\Evidence\<the file>.csv"

Produces three files: a cleaned copy, a report for a human, and
an approved list. No account is touched.

## 3. Send the report to the Privacy Officer.

Send `Validation-Report.txt`. Ask them to reply in writing with a
yes or no to anything under NEEDS YOUR DECISION.

## 4. Wait.

This usually takes a day and sometimes longer. Nothing runs until
the reply arrives. If you are waiting, you are not stuck.

Save the reply to `Evidence/` when it comes.

## 5. Dry run, then run it.

    .\Scripts\Invoke-BulkOffboarding.ps1 `
        -ApprovedList ".\Evidence\Approved.csv" `
        -Ticket "NMG-0000" -WhatIf

Read all of it. Check the count matches the approved list. Then
run the same command without `-WhatIf`.

Do not close the console when it finishes.

## 6. Verify three ways, then report.

Check the summary against the approved list, query the directory
directly, and count the evidence files. Then send three numbers
and a path to whoever asked for this.

### If something goes wrong

The script names the account, the step and the state. Rolled back
means untouched and safe to re-run. Stranded means it needs a
person, and there will only ever be a few.
