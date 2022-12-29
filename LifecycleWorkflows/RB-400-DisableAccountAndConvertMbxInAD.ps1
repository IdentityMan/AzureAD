param (
    [Parameter (Mandatory = $true)] 
    [object]$UserPrincipalname
)

#Import Modules
Import-Module ActiveDirectory
Add-PSSnapin *RecipientManagement

#Define Variables
$datetime = Get-Date

#Disable user account and configure description
$User = Get-AdUser -Filter {UserPrincipalName -eq $UserPrincipalname}
Set-AdUser -identity $User.SamAccountName -Enabled $false
Set-AdUser -identity $User.SamAccountName -Description "Disabled by LifeCycle Workflows offboarding Flow on: $datetime"

#Convert mailbox in on-premises Active Directory to shared
Set-RemoteMailbox -identity $user.SamAccountName -Type Shared
