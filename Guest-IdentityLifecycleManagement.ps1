#Configure tenant variables
$AppClientId = Get-AutomationVariable -Name 'ApplicationID'
$TenantId = Get-AutomationVariable -Name 'TenantID'
$ClientSecret= Get-AutomationVariable -Name 'ClientSecret'

#Configure connection to Graph API and make sure to retrieve access token
$RequestBody = @{client_id=$AppClientId;client_secret=$ClientSecret;grant_type="client_credentials";scope="https://graph.microsoft.com/.default";}
$OAuthResponse = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token -Body $RequestBody
$AccessToken = $OAuthResponse.access_token

#Form request headers with the acquired $AccessToken
$headers = @{'Content-Type'="application/json";'Authorization'="Bearer $AccessToken"}
 
#This defines the filter we are applying to the guest acccount Graph call.
$ApiUserUrl = "https://graph.microsoft.com/beta/users?`$filter=userType in ('Guest')&`$select=displayName,id,accountEnabled,userPrincipalName,signInActivity,userType,CreatedDateTime,ExternalUserState"

#Reset variables
$Today = Get-Date
$DeletedUserCount = 0
$DisabledUserCount = 0
$ActiveUserCount = 0
$DeletedUsers = @()
$DisabledUsers = @()
$ActiveUsers = @()

#Perform pagination if next page link (odata.nextlink) returned.
While ($ApiUserUrl -ne $Null) {
#Retrieve all guest users with their properties
$UserResponse = Invoke-WebRequest -Method GET -Uri $ApiUserUrl -ContentType "application/json" -Headers $headers –UseBasicParsing | ConvertFrom-Json
    #If the user response contains a value continue the script
    if($UserResponse.value) {
        $Users = $UserResponse.value
        #for each guest user found run the following loop
        ForEach($User in $Users) {
            #define variables or reset them
            $id = $user.id
            $count = 0

            #This defines the Graph call to retrieve if the user is a member of any groups.
            $ApiMemberOfUrl  = "https://graph.microsoft.com/beta/users/$id/memberOf/microsoft.graph.group?"
            
            #Perform pagination if next page link (odata.nextlink) returned.            
            While ($ApiMemberOfUrl -ne $Null) {
                #retrieve all group memberships
                $MemberOfResponse = Invoke-WebRequest -Method GET -Uri $ApiMemberOfUrl -ContentType "application/json" -Headers $headers –UseBasicParsing | ConvertFrom-Json
                $MemberOfGroups = $MemberOfResponse.value

                #if the user is a member of groups, exclude the dynamic groups from the count and fill count per user
                ForEach ($MemberOfGroup in $MemberOfGroups) {
                    $GroupType = ""
                    $GroupType = $MemberOfGroup.groupTypes

                    if ($GroupType -notcontains 'DynamicMembership') {
                        $count = $count + 1
                    }
                }
                
                #if the count is equal to 0 this means the user doesn't have group memberships so we can either disable or delete the account based on activity
                if ($count -eq 0) {
                    #First we check the activity of te account and check the state of the invite of the guest user.
                    $DaysInvited = (New-TimeSpan -Start $User.CreatedDateTime -End $Today).Days
                    $LastSignInDateTime = if($User.signInActivity.lastSignInDateTime) { [DateTime]$User.signInActivity.lastSignInDateTime } Else {$null}
                    $ExternalUserState = $user.ExternalUserState
                    $accountEnabled = $user.accountEnabled
                       
                    #if the lastsignindatetime is empty, the user hasn't accepted their invite and this is alrady the case for 30 days, cleanup the account.
                    If (($LastSignInDateTime -eq $null) -and ($ExternalUserState -eq "PendingAcceptance") -and ($DaysInvited -gt 30)) {
                        $userprincipalname = $User.userPrincipalName
                        $ApiDeleteUserUrl = "https://graph.microsoft.com/beta/users/$id"
                        $DeleteUserResponse = Invoke-WebRequest -Method DELETE -Uri $ApiDeleteUserUrl -ContentType "application/json" -Headers $headers –UseBasicParsing | ConvertFrom-Json
                        $DeletedUserCount = $DeletedUserCount + 1
                        $DeletedUsers = $DeletedUsers + "$userprincipalname is invited for more than 30 days ago and hasn't accepted yet, start deletion of guest account!`n"
                    }

                    #If the lastsignindatetime is empty (because this value was only there for 1,5 year) and the interactive sign-in happend before that time let's make sure to put a value in the system of -200 days.
                    if ($LastSignInDateTime) {
                        $DaysInactive = (New-TimeSpan -Start $LastSignInDateTime -End $Today).Days
                    }
                    else {
                        $LastSignInDateTime = (get-date).AddDays(-200)
                        $DaysInactive = (New-TimeSpan -Start $LastSignInDateTime -End $Today).Days
                    }

                    #If the lastsignindatetime is empty, the user did accept the invite and therefore can access the system but didn't use the account for more than 150 days but less than 179 let's disable the account.
                    if (($LastSignInDateTime -ne $null) -and ($accountEnabled -ne $False) -and ($ExternalUserState -ne "PendingAcceptance") -and ($DaysInactive -gt 150) -and ($DaysInactive -lt 179)) {
                        $userprincipalname = $User.userPrincipalName
                        $ApiBlockUserUrl = "https://graph.microsoft.com/beta/users/$id"
                        $Body = @{accountEnabled = "false"}
                        $BlockUserResponse = Invoke-WebRequest -Method PATCH -Uri $ApiBlockUserUrl -ContentType "application/json" -body ($body | convertto-json -depth 5) -Headers $headers –UseBasicParsing | ConvertFrom-Json
                        $DisabledUserCount = $DisabledUserCount + 1
                        $DisabledUsers = $DisabledUsers + "$userprincipalname is inactive for more than 150 days, start disablement of guest account!`n"
                
                    }

                    #If the lastsignindatetime is empty, the user did accept the invite and therefore can access the system but didn't use the account for more than 180 days let's disable the account.
                    if (($LastSignInDateTime -ne $null) -and ($ExternalUserState -ne "PendingAcceptance") -and ($DaysInactive -gt 180)) {
                        $userprincipalname = $User.userPrincipalName
                        $ApiDeleteUserUrl = "https://graph.microsoft.com/beta/users/$id"
                        $DeleteUserResponse = Invoke-WebRequest -Method DELETE -Uri $ApiDeleteUserUrl -ContentType "application/json" -Headers $headers –UseBasicParsing | ConvertFrom-Json
                        $DeletedUserCount = $DeletedUserCount + 1
                        $DeletedUsers = $DeletedUsers + "$userprincipalname is inactive for more than 180 days, start deletion of guest account!`n"
                    }
                }

                #If the user still has group memberships an access review should eventually trigger the removal of that membership whereby the user falls in scope for this deletion.
                Else {
                    $userprincipalname = $User.userPrincipalName
                    $ActiveUserCount = $ActiveUserCount + 1
                    $ActiveUsers = $ActiveUsers + "$userprincipalname still has $count group memberships, skipping guest user for deletion!`n"
                }

            $ApiMemberOfUrl=$MemberOfResponse.'@odata.nextlink'
            }            
        }
    }

$ApiUserUrl=$UserResponse.'@odata.nextlink'
}

#Report summarized blocked and deleted accounts within the Output
Write-output "The following $DisabledUserCount accounts are disabled:"
Write-output "$DisabledUsers"
Write-output "The following $DeletedUserCount accounts are deleted:"
Write-output "$DeletedUsers"
Write-output "The following $ActiveUserCount accounts are active and therefore not deleted or blocked:"
Write-output "$ActiveUsers"
