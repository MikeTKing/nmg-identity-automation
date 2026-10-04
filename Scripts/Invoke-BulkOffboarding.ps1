[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string]$ApprovedList,
    [string]$Ticket     = "NMG-0215",
    [string]$OutputPath = "C:\Reports\Offboarding",
    [string]$BreakOn    = ""
)

Import-Module ActiveDirectory

$stamp    = Get-Date -Format "yyyy-MM-dd_HHmm"
$approved = Import-Csv $ApprovedList

if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$LogPath = "C:\nmg-identity-automation\Logs"
if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
Start-Transcript -Path "$LogPath\BulkRun_$stamp.log" | Out-Null

Write-Host ""
Write-Host "  BULK OFFBOARDING" -ForegroundColor Cyan
Write-Host "  Accounts : $($approved.Count)"
Write-Host "  Ticket   : $Ticket"
if ($WhatIfPreference) { Write-Host "  DRY RUN. Nothing will change." -ForegroundColor Yellow }
Write-Host ""

#--- THE FIVE STEPS, AS FUNCTIONS ---------------------------
# Real commands. You have written every one of these before,
# on Days 6 to 9. Putting them in functions is what lets the
# loop track which ones completed.

function Export-GroupMemberships {
    param($Username)
    $file = "$OutputPath\$($Username)_groups_$stamp.csv"
    Get-ADPrincipalGroupMembership -Identity $Username |
      Select-Object Name, DistinguishedName |
      Export-Csv $file -NoTypeInformation -ErrorAction Stop
    return $file
}

function Disable-Account {
    param($Username)
    Disable-ADAccount -Identity $Username -ErrorAction Stop
    Set-ADUser -Identity $Username -ErrorAction Stop `
      -Description "Offboarded $(Get-Date -Format yyyy-MM-dd) | Ticket $Ticket"
}

function Reset-Password {
    param($Username)
    $random = [guid]::NewGuid().ToString() + "!Aa1"
    Set-ADAccountPassword -Identity $Username -Reset -ErrorAction Stop `
      -NewPassword (ConvertTo-SecureString $random -AsPlainText -Force)
}

function Remove-AllGroups {
    param($Username)

    # THE TEST HOOK. Does nothing unless -BreakOn is passed.
    # Simulates one account whose group was renamed since the
    # check ran. Leave this line in. It is harmless without
    # the parameter, and it is how you test the rollback.
    if ($BreakOn -and $Username -like $BreakOn) {
        throw "Cannot find an object with identity: 'EHR-Clinical-RENAMED'"
    }

    Get-ADPrincipalGroupMembership -Identity $Username |
      Where-Object { $_.Name -ne "Domain Users" } |
      ForEach-Object {
          Remove-ADGroupMember -Identity $_ -Members $Username `
            -Confirm:$false -ErrorAction Stop
      }
}

function Move-ToQuarantine {
    param($Username)
    $dn = (Get-ADUser -Identity $Username).DistinguishedName
    Move-ADObject -Identity $dn -ErrorAction Stop `
      -TargetPath "OU=Disabled Users,$((Get-ADDomain).DistinguishedName)"
}

#--- THE ROLLBACK -------------------------------------------
# 4 of the 5 reverse cleanly. The fifth does not need to.

function Undo-Offboard {
    param($Username, $GroupCsv, $OriginalOU)

    Enable-ADAccount -Identity $Username -ErrorAction Stop
    Set-ADUser -Identity $Username -Description "" -ErrorAction Stop

    # The step 1 CSV IS the rollback. This is why it goes first.
    if ($GroupCsv -and (Test-Path $GroupCsv)) {
        Import-Csv $GroupCsv | ForEach-Object {
            Add-ADGroupMember -Identity $_.Name -Members $Username -ErrorAction Stop
        }
    }

    $dn = (Get-ADUser -Identity $Username).DistinguishedName
    Move-ADObject -Identity $dn -TargetPath $OriginalOU -ErrorAction Stop
}

# The password reset is NOT reversed. Nobody knows the value,
# so a re-enabled account with an unknown password is a state
# nobody can log into. Note it, then leave it.

#--- THE RESULT LINE ----------------------------------------
# 6 fields. Every one answers a question somebody will ask.
# Appended to disk the moment it is known. Never collected.

$ResultsFile = "$OutputPath\BulkRun_$stamp.csv"

function Write-Result {
    param($Account, $Outcome, $Step, $Detail)

    [PSCustomObject]@{
        Time     = (Get-Date -Format "HH:mm:ss")
        Row      = $Account.Row
        Username = $Account.Username
        Outcome  = $Outcome     # COMPLETE / ROLLED BACK / STRANDED
        Step     = $Step
        Detail   = $Detail
    } | Export-Csv $ResultsFile -NoTypeInformation -Append
}

#--- THE ATOMIC LOOP, WITH A CIRCUIT BREAKER ----------------
# One try PER ACCOUNT. And a counter that stops the run when
# failures stop looking like coincidence.

$consecutive = 0

foreach ($a in $approved) {

    $done   = @()
    $csv    = $null
    $origOU = ((Get-ADUser -Identity $a.Username).DistinguishedName -split ",", 2)[1]

    try {
        $csv = Export-GroupMemberships $a.Username ; $done += "document"
        Disable-Account   $a.Username              ; $done += "disable"
        Reset-Password    $a.Username              ; $done += "password"
        Remove-AllGroups  $a.Username              ; $done += "groups"
        Move-ToQuarantine $a.Username              ; $done += "move"

        Write-Result $a "COMPLETE" 5 ""
        if ($WhatIfPreference) { Write-Host "  would    $($a.Username)" }
        else                   { Write-Host "  ok       $($a.Username)" }
        $consecutive = 0
    }
    catch {
        $consecutive++
        $step   = [Math]::Min($done.Count + 1, 5)
        $reason = $_.Exception.Message

        try {
            Undo-Offboard $a.Username $csv $origOU
            Write-Result $a "ROLLED BACK" $step $reason
            Write-Host "  FAILED   $($a.Username)  step $step, rolled back" -ForegroundColor Yellow
        }
        catch {
            Write-Result $a "STRANDED" $step "rollback FAILED: $($_.Exception.Message)"
            Write-Host "  STRANDED $($a.Username)  MANUAL REVIEW NEEDED" -ForegroundColor Red
        }
    }

    if ($consecutive -ge 3) {
        Write-Host ""
        Write-Host "  STOPPING: 3 consecutive failures." -ForegroundColor Red
        Write-Host "  This looks systemic rather than per-account."
        Write-Host "  $($approved.Count - $approved.IndexOf($a) - 1) accounts not attempted."
        break
    }
}

#--- THE SUMMARY THAT NAMES NAMES ---------------------------

if (-not (Test-Path $ResultsFile)) {
    Write-Host ""
    Write-Host "  Dry run finished. Nothing changed, nothing recorded." -ForegroundColor Yellow
    Write-Host "  Remove -WhatIf to run it for real."
    Write-Host ""
    try { Stop-Transcript | Out-Null } catch { }
    return
}

$r = Import-Csv $ResultsFile
Write-Host ""
Write-Host "  Bulk offboarding finished.  Approved: $($approved.Count)"
Write-Host ""
Write-Host "    Completed ......... $(($r | Where-Object Outcome -eq 'COMPLETE').Count)"
Write-Host "    Rolled back ....... $(($r | Where-Object Outcome -eq 'ROLLED BACK').Count)"
Write-Host "    Stranded .......... $(($r | Where-Object Outcome -eq 'STRANDED').Count)"
Write-Host ""

$r | Where-Object { $_.Outcome -ne "COMPLETE" } | ForEach-Object {
    Write-Host "    $($_.Username.PadRight(12)) row $($_.Row.PadRight(4)) $($_.Outcome) at step $($_.Step)"
    Write-Host "    $(' ' * 12)      $($_.Detail)"
}
Write-Host ""

try { Stop-Transcript | Out-Null } catch { }
