param (
    [Parameter (Mandatory = $true)] 
    [object]$UserPrincipalname
)

#Import Modules
Import-Module ActiveDirectory

#Retrieve & Delete user account
$User = Get-AdUser -Filter {UserPrincipalName -eq $UserPrincipalname}
Remove-ADUser -Identity $User.SamAccountName -Confirm:$False
