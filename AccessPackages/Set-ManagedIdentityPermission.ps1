#Import Modules
Import-Module Microsoft.Graph.Applications

#Connect with the right permission scopes
Connect-MgGraph -Scopes Application.Read.All, AppRoleAssignment.ReadWrite.All, RoleManagement.ReadWrite.Directory

#Configure Variables
$managedIdentityId = "ObjectID of ServicePrincipal"
$roleName = "User.Read.All"

#Retrieve additional Details
$msgraph = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
$role = $Msgraph.AppRoles| Where-Object {$_.Value -eq $roleName}

#Assign application permissions to Managed Identity
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId -PrincipalId $managedIdentityId -ResourceId $msgraph.Id -AppRoleId $role.Id
