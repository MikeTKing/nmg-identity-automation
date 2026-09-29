#--- STEP 1 OF 5: DOCUMENT ---------------------------------
# Nothing here changes anything. That is the point.
# Everything after this is difficult or impossible to reverse,
# so the record gets taken while the record still exists.

$stamp  = Get-Date -Format "yyyy-MM-dd_HHmm"
$out    = "C:\Reports\Offboarding"

$user   = Get-ADUser -Identity "kferreira" -Properties *
$groups = Get-ADPrincipalGroupMembership -Identity "kferreira"

# The account itself
$user |
  Select-Object Name, SamAccountName, Department, Title,
                LastLogonDate, Enabled, DistinguishedName |
  Export-Csv "$out\kferreira_account_$stamp.csv" `
    -NoTypeInformation -Encoding UTF8

# What it could reach. THIS is the part that cannot be rebuilt.
$groups |
  Select-Object Name, GroupCategory, DistinguishedName |
  Export-Csv "$out\kferreira_groups_$stamp.csv" `
    -NoTypeInformation -Encoding UTF8

Write-Host "Captured $($groups.Count) memberships" -ForegroundColor Green

#--- STEP 2 OF 5: DISABLE ----------------------------------
# The step that actually reduces risk. Everything after
# this one is cleanup.

Disable-ADAccount -Identity "kferreira"

# Stamp it, so nobody has to guess who did this or why
Set-ADUser -Identity "kferreira" `
  -Description "Offboarded $(Get-Date -Format yyyy-MM-dd) | Ticket NMG-0203"


  #--- STEP 3 OF 5: RESET THE PASSWORD -----------------------
# Belt and braces. If somebody re-enables this account by
# mistake, the old credential must not still work.

Add-Type -AssemblyName System.Web
$random = [System.Web.Security.Membership]::GeneratePassword(24,6)

Set-ADAccountPassword -Identity "kferreira" -Reset `
  -NewPassword (ConvertTo-SecureString $random -AsPlainText -Force)

# Deliberately not printing it. Nobody needs it, including you.
Write-Host "Password randomised" -ForegroundColor Green

#--- STEP 4 OF 5: REMOVE GROUP MEMBERSHIPS -----------------
# Safe now, and ONLY now, because $groups was captured and
# written to disk in step 1.

foreach ($g in $groups) {
# Domain Users is the primary group. Active Directory will
    # refuse to remove it. Unhandled, that error stops the loop
    # partway and leaves the account half stripped.
    if ($g.Name -eq "Domain Users") { continue }

    Remove-ADGroupMember -Identity $g `
        -Members "kferreira" -Confirm:$false

    Write-Host "  Removed: $($g.Name)" -ForegroundColor Yellow
}


#--- STEP 5 OF 5: MOVE -------------------------------------
# Last, because moving changes the object path. Anything
# still pointing at the old location will fail after this.

$root   = (Get-ADDomain).DistinguishedName
$target = "OU=Disabled Users,$root"

$dn = (Get-ADUser -Identity "kferreira").DistinguishedName
Move-ADObject -Identity $dn -TargetPath $target

Write-Host "Moved to Disabled Users" -ForegroundColor Green
