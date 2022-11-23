param (
    [Parameter (Mandatory = $true)] 
    [object]$UserPrincipalname
)

#Import Modules
Import-Module ActiveDirectory
Add-PSSnapin *RecipientManagement

#Set date time
$datetime = Get-Date

#Retrieve the user details
$User = Get-AdUser -Filter {UserPrincipalName -eq $UserPrincipalname}

#Enable account and set description
Set-AdUser -identity $User.SamAccountName -Enabled $true
Set-AdUser -identity $User.SamAccountName -Description "Enabled by LifeCycle Workflows onboarding Flow on: $datetime"

$pos = $UserPrincipalname.IndexOf("@")
$mailvalue = $UserPrincipalname.Substring(0, $pos)

#Provision mailbox details in on-prem AD
Enable-RemoteMailbox -identity $user.SamAccountName -RemoteRoutingAddress "$mailvalue@jacobsaa.mail.onmicrosoft.com" -alias $mailvalue -PrimarySMTPAddress $UserPrincipalname
