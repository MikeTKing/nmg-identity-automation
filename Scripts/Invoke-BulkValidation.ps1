<#
.SYNOPSIS
    Validates a bulk offboarding request. Changes nothing.

.DESCRIPTION
    Phase 1 reads the separations file and produces a cleaned
    copy. Phase 2 checks every remaining row against Active
    Directory and writes a report for human review.

    This script contains no command that modifies an account.
    It cannot disable, strip, move or reset anything. Acting on
    the result is a separate step, performed by a separate
    script, against the approved output of this one.

.PARAMETER InputFile
    The separations file, as received. Never modified.

.PARAMETER OutputPath
    Where the cleaned copy, the report and the approved list go.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$InputFile,
    [string]$OutputPath = "C:\Reports\Separations"
)

#--- THE SKELETON -------------------------------------------
# Two phases. No third one, on purpose.
#
#  PHASE 1   read and clean      uses the file only
#  PHASE 2   check and report    uses the directory
#
#  ( no phase 3 )
#
# Friday adds the action, in a separate script, reading the
# approved list rather than this file.
#
# A script that COULD act is a script somebody will run
# without reading the report.

# Today something runs, so today there is a log.

$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$log   = "C:\nmg-identity-automation\Logs"

Start-Transcript -Path "$log\Invoke-BulkValidation_$stamp.log" | Out-Null

# A script that reads a live directory leaves a record of
# having done so, even when it changes nothing.


#=============================================================
#  PHASE 1 - READ AND CLEAN. THE FILE ONLY.
#=============================================================

#--- EDIT 1: READ IT, KEEP THE ROW NUMBERS ------------------
# The row number is the cheapest thing on this page and it
# pays for itself the first time somebody queries a decision.

$raw   = Import-Csv $InputFile
$drops = @()

$stage1 = foreach ($i in 0..($raw.Count - 1)) {
    [PSCustomObject]@{
        Row      = $i + 2          # +2 because the header is line 1
        Username = $raw[$i].Username
        Name     = $raw[$i]."Employee Name"
    }
}

Write-Host "  Rows read : $($stage1.Count)"

#--- EDIT 2: TRIM, THEN DROP THE EMPTIES --------------------
# Trim FIRST. A username with a trailing space fails every
# test you apply to it, for the wrong reason.

$stage2 = foreach ($r in $stage1) {

    $u = "$($r.Username)".Trim()

    if (-not $u) {
        $drops += [PSCustomObject]@{ Row=$r.Row; Why="no username" }
        continue
    }

    [PSCustomObject]@{
        Row = $r.Row; Username = $u; Name = "$($r.Name)".Trim()
    }
}

#--- EDIT 3: REJECT WHAT IS NOT A USERNAME ------------------
# Lowercase letters, maybe a dot or an underscore.
# An employee ID is not a username. This catches row 19.

$stage3 = foreach ($r in $stage2) {

    if ($r.Username -notmatch "^[a-z][a-z0-9._]+$") {
        $drops += [PSCustomObject]@{ Row=$r.Row; Why="not a username" }
        continue
    }

    $r
}

#--- EDIT 4: DEDUPLICATE, AFTER TRIMMING --------------------
# Order matters. Deduplicate before trimming and row 14
# slips through, because it does not look identical until
# the trailing space is gone.

$seen  = @{}
$clean = foreach ($r in $stage3) {

    if ($seen.ContainsKey($r.Username)) {
        $drops += [PSCustomObject]@{
            Row = $r.Row
            Why = "duplicate of row $($seen[$r.Username])"
        }
        continue
    }

    $seen[$r.Username] = $r.Row
    $r
}

#--- EDIT 5: THE DROP LOG -----------------------------------
# Sandra sent 40 names and believes 40 things are handled.
# 5 of them are not. She has to be told which.

$drops | Export-Csv "$OutputPath\Separations_dropped.csv" `
    -NoTypeInformation

Write-Host ""
Write-Host "  Rows in   : $($raw.Count)"
Write-Host "  Cleaned   : $($clean.Count)"
Write-Host "  Dropped   : $($drops.Count)"

$drops | Group-Object Why | Sort-Object Count -Descending |
  ForEach-Object { "    {0,-24} {1}" -f $_.Name, $_.Count }

# A cleaning step that silently drops rows is not a cleaning
# step. It is a data loss step with a friendly name.


#=============================================================
#  PHASE 2 - CHECK AND REPORT. THE DIRECTORY.
#=============================================================

Import-Module ActiveDirectory

# Phase two reaches outside the file for the first time.
# It still changes nothing.

#--- CHECK 1: ONE LOOKUP PER ROW ----------------------------
#--- CHECK 2: THE FIVE VERDICTS -----------------------------

$checked = foreach ($r in $clean) {

    $u = Get-ADUser -Identity $r.Username `
            -Properties Department, info `
            -ErrorAction SilentlyContinue

    # SilentlyContinue so a missing account returns nothing
    # rather than throwing and stopping the loop.

    $verdict =
      if     (-not $u)                   { "NOT IN DIRECTORY" }
      elseif ($r.Username -like "svc_*") { "SERVICE ACCOUNT"  }
      elseif (-not $u.Enabled)           { "ALREADY DISABLED" }
      elseif ($u.LastLogonDate -gt (Get-Date).AddDays(-90)) {
                                           "STILL EMPLOYED"   }
      else                               { "READY"            }

    [PSCustomObject]@{
        Row      = $r.Row
        Username = $r.Username
        Name     = $r.Name
        LastSeen = $u.LastLogonDate
        Verdict  = $verdict
    }
}

# 4 of those are facts the directory states plainly.
# STILL EMPLOYED is inferred. Inference needs a person.

#--- BUILD THE REPORT ---------------------------------------
# Three tiers, ordered by what a wrong decision costs.
# Built as an array of lines, then written in one go.

$still   = $checked | Where-Object { $_.Verdict -eq "STILL EMPLOYED" }
$svc     = $checked | Where-Object { $_.Verdict -eq "SERVICE ACCOUNT" }
$already = $checked | Where-Object { $_.Verdict -eq "ALREADY DISABLED" }
$missing = $checked | Where-Object { $_.Verdict -eq "NOT IN DIRECTORY" }
$ready   = $checked | Where-Object { $_.Verdict -eq "READY" }

$report = @()
$report += "  BULK OFFBOARDING REVIEW"
$report += "  Source: $(Split-Path $InputFile -Leaf)"
$report += "  Validated: $(Get-Date -Format 'dddd d MMMM yyyy, HH:mm')"
$report += ""

#--- TIER 1: alone at the top, phrased as a question ---------
if ($still) {
    $report += "  NEEDS YOUR DECISION"
    $report += ""
    foreach ($r in $still) {
        $seen = if ($r.LastSeen) { $r.LastSeen.ToString("d MMMM, HH:mm") } else { "unknown" }
        $report += "    Row $($r.Row) asks you to offboard $($r.Name) ($($r.Username))."
        $report += "    This account was last used on $seen."
        $report += "    Should this account be offboarded?   [ ] yes   [ ] no"
        $report += ""
    }
}

#--- TIER 2: grouped, listed once ----------------------------
if ($svc -or $already) {
    $report += "  PLEASE CONFIRM"
    $report += ""

    if ($svc) {
        $report += "    $($svc.Count) service accounts. Not people, and neither has a"
        $report += "      named owner.          $(($svc.Username) -join ', ')"
        $report += ""
    }

    if ($already) {
        $report += "    $($already.Count) already offboarded. Re-running would overwrite"
        $report += "      the record of who did it and under which ticket."
        $report += ""
    }
}

#--- TIER 3: counted and summarised, never itemised ----------
$report += "  DROPPED AUTOMATICALLY, NO ACTION NEEDED"
$report += ""
$report += "    $($drops.Count) rows dropped during cleaning:"

$drops | Group-Object Why | Sort-Object Count -Descending | ForEach-Object {
    $report += "      $($_.Count)  $($_.Name)"
}

if ($missing) {
    $report += "      $($missing.Count)  not in the directory"
}

$report += ""
$report += "    Full detail in Separations_dropped.csv"
$report += ""

#--- THE NUMBER BEING SIGNED ---------------------------------
$report += "  ----------------------------------------------------"
$report += "  $($ready.Count) accounts will be offboarded if you approve this."
$report += "  ----------------------------------------------------"
$report += ""

#--- TWO FILES, TWO AUDIENCES -------------------------------

# For a human. Written to be READ.
$report | Out-File "$OutputPath\Validation-Report.txt" -Encoding UTF8

# For Friday. Written to be PARSED.
$approved = $checked | Where-Object { $_.Verdict -eq "READY" }
$approved | Export-Csv "$OutputPath\Approved.csv" -NoTypeInformation

# Do not try to make one file do both jobs.

#--- CLOSE THE TRANSCRIPT -----------------------------------
# The very last line of the script.
#
# try and catch, because Stop-Transcript throws a hard error
# when there is nothing running, and -ErrorAction does not
# suppress that one.

try { Stop-Transcript | Out-Null } catch { }


