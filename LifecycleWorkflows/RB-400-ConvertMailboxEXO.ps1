param (
    [Parameter (Mandatory = $true)] 
    [object]$UserPrincipalname,
    [Parameter (Mandatory = $true)] 
    [object]$ManagerMail
)

#Import Modules
Import-Module ExchangeOnlineManagement

#Connect to Exchange Online with Managed Identity
Connect-ExchangeOnline -ManagedIdentity -Organization jacobsaa.onmicrosoft.com

#Convert mailbox in Exchange Online to shared
Set-Mailbox -identity $UserPrincipalname -type shared
Write-output "Mailbox converted to shared"

#Add manager to user mailbox in Exchange Online with 'Full Access'
Add-MailboxPermission -Identity $UserPrincipalname -User $ManagerMail -AccessRights FullAccess -InheritanceType All
Write-output "Manager added to mailbox"
