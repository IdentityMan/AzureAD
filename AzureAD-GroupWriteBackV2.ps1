import-module ADSync
$precedenceValue = Read-Host -Prompt "Enter a unique sync rule precedence value [0-99]"

 New-ADSyncRule  `
 -Name 'In from AAD - Group SOAinAAD Delete WriteBackOutOfScope and SoftDelete' `
 -Identifier 'cb871f2d-0f01-4c32-a333-ff809145b947' `
 -Description 'Delete AD groups that fall out of scope of Group Writeback or get Soft Deleted in Azure AD' `
 -Direction 'Inbound' `
 -Precedence $precedenceValue `
 -PrecedenceAfter '00000000-0000-0000-0000-000000000000' `
 -PrecedenceBefore '00000000-0000-0000-0000-000000000000' `
 -SourceObjectType 'group' `
 -TargetObjectType 'group' `
 -Connector 'b891884f-051e-4a83-95af-2544101c9083' `
 -LinkType 'Join' `
 -SoftDeleteExpiryInterval 0 `
 -ImmutableTag '' `
 -OutVariable syncRule

 Add-ADSyncAttributeFlowMapping  `
 -SynchronizationRule $syncRule[0] `
 -Destination 'reasonFiltered' `
 -FlowType 'Expression' `
 -ValueMergeType 'Update' `
 -Expression 'IIF((IsPresent([reasonFiltered]) = True) && (InStr([reasonFiltered], "WriteBackOutOfScope") > 0 || InStr([reasonFiltered], "SoftDelete") > 0), "DeleteThisGroupInAD", [reasonFiltered])' `
 -OutVariable syncRule

New-Object  `
-TypeName 'Microsoft.IdentityManagement.PowerShell.ObjectModel.ScopeCondition' `
-ArgumentList 'cloudMastered','true','EQUAL' `
-OutVariable condition0

Add-ADSyncScopeConditionGroup  `
-SynchronizationRule $syncRule[0] `
-ScopeConditions @($condition0[0]) `
-OutVariable syncRule

New-Object  `
-TypeName 'Microsoft.IdentityManagement.PowerShell.ObjectModel.JoinCondition' `
-ArgumentList 'cloudAnchor','cloudAnchor',$false `
-OutVariable condition0

Add-ADSyncJoinConditionGroup  `
-SynchronizationRule $syncRule[0] `
-JoinConditions @($condition0[0]) `
-OutVariable syncRule

Add-ADSyncRule  `
-SynchronizationRule $syncRule[0]

Get-ADSyncRule  `
-Identifier 'cb871f2d-0f01-4c32-a333-ff809145b947'
