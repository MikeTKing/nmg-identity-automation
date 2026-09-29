#--- GET-NMGOFFBOARDINGSTATUS.PS1 ---------------------------
# Save as C:\Scripts\Get-NMGOffboardingStatus.ps1
#
# Answers a question. Changes nothing. No parameters, so
# Rachel types the name and presses enter.
#
# There is not a single Set, Remove or Move in this file,
# and there never will be.

Import-Module ActiveDirectory

$cutoff = (Get-Date).AddDays(-90)
$root   = (Get-ADDomain).DistinguishedName
$quar   = "OU=Disabled Users,$root"

$all = Get-ADUser -Filter * -Properties LastLogonDate, Department

# Done properly: disabled AND in quarantine
$done = $all | Where-Object {
    $_.Enabled -eq $false -and $_.DistinguishedName -like "*$quar"
}

# Disabled, but still sitting in a department OU
$partial = $all | Where-Object {
    $_.Enabled -eq $false -and $_.DistinguishedName -notlike "*$quar"
}

# Dormant and still live. Nobody has reached these yet.
$waiting = $all | Where-Object {
    $_.Enabled -eq $true -and $_.Department -ne $null -and
    ($_.LastLogonDate -lt $cutoff -or $_.LastLogonDate -eq $null)
}

# The labels matter more than the queries.
# Rachel reads these. She will never read the code.

Write-Host ""
Write-Host "  NORTHSTAR OFFBOARDING STATUS" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'dddd d MMMM yyyy, HH:mm')"
Write-Host ""
Write-Host "  Offboarded and quarantined ....... $($done.Count)"
Write-Host "  Offboarded, not yet moved ........ $($partial.Count)"
Write-Host "  Still waiting .................... $($waiting.Count)"
Write-Host ""

if ($partial.Count -gt 0) {
    Write-Host "  NOT YET MOVED" -ForegroundColor Yellow
    $partial | ForEach-Object {
        Write-Host "    $($_.SamAccountName.PadRight(12)) $($_.Name)"
    }
    Write-Host ""
}

if ($waiting.Count -gt 0) {
    Write-Host "  STILL WAITING" -ForegroundColor Red
    $waiting | Sort-Object LastLogonDate | ForEach-Object {
        Write-Host "    $($_.SamAccountName.PadRight(12)) $($_.Name.PadRight(20)) $($_.Department)"
    }
    Write-Host ""
}
