#Configure tenant variables
$AppClientId = Get-AutomationVariable -Name 'ApplicationID'
$TenantId = Get-AutomationVariable -Name 'TenantID'
$ClientSecret= Get-AutomationVariable -Name 'ClientSecret'

#Configure connection to Graph API and make sure to retrieve access token
$RequestBody = @{client_id=$AppClientId;client_secret=$ClientSecret;grant_type="client_credentials";scope="https://graph.microsoft.com/.default";}
$OAuthResponse = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token -Body $RequestBody
$AccessToken = $OAuthResponse.access_token

#Form request headers with the acquired $AccessToken
$headers = @{'Content-Type'="application\json";'Authorization'="Bearer $AccessToken"}

###################################################

Function Build-AccessReviewRequestBody($id,$displayname,$LabelResponse){

## Configure the Access Review Settings here per group Sensitivity Label.
## These settings will be used later on to build the requestbody on group input like ID, DisplayName and Label.

    if ($LabelResponse -eq "Confidential") {
        $accessReviewBody = @"
{
    "displayName": "the group membership and access to the group $displayname ",
    "descriptionForAdmins": "the group membership and access to the group $displayname ",
    "descriptionForReviewers": "the group membership and access to the group $displayname ",
    "scope": {
        "query": "/groups/$id/transitiveMembers",
        "queryType": "MicrosoftGraph"
    },
    "instanceEnumerationScope": {
        "query": "/groups/$id",
        "queryType": "MicrosoftGraph"
    },
    "reviewers": [
        {
        "query": "/v1.0/groups/$id/owners",
        "queryType": "MicrosoftGraph"
        }
    ],
    "settings": {
        "mailNotificationsEnabled": true,
        "reminderNotificationsEnabled": true,
        "justificationRequiredOnApproval": true,
        "defaultDecisionEnabled": true,
        "defaultDecision": "Deny",
        "instanceDurationInDays": 30,
        "autoApplyDecisionsEnabled": true,
        "recommendationsEnabled": true,
        "recommendationLookBackDuration": "P30D",
        "recurrence": {
            "pattern": {
                "type": "absoluteMonthly",
                "interval": 3,
                },
            "range": {
                "type": "noEnd",
                "numberOfOccurrences": 0,
                "recurrenceTimeZone": null,
                "startDate": "2022-01-02",
                "endDate": "9999-12-31"
                }
        },
        "applyActions": [
            {
                "@odata.type": "#microsoft.graph.removeAccessApplyAction"
            }
        ],
        "recommendationInsightSettings": [
            {
                "@odata.type": "#microsoft.graph.userLastSignInRecommendationInsightSetting",
                "recommendationLookBackDuration": "P30D",
                "signInScope": "tenant"
            }
        ]
    }
}
"@
    }
    if ($LabelResponse -eq "General") {
        $accessReviewBody = @"
{
    "displayName": "the group membership and access to the group $displayname ",
    "descriptionForAdmins": "the group membership and access to the group $displayname ",
    "descriptionForReviewers": "the group membership and access to the group $displayname ",
    "scope": {
        "query": "/groups/$id/transitiveMembers",
        "queryType": "MicrosoftGraph"
    },
    "instanceEnumerationScope": {
        "query": "/groups/$id",
        "queryType": "MicrosoftGraph"
    },
    "reviewers": [],
    "settings": {
        "mailNotificationsEnabled": true,
        "reminderNotificationsEnabled": true,
        "justificationRequiredOnApproval": true,
        "defaultDecisionEnabled": true,
        "defaultDecision": "Recommendation",
        "instanceDurationInDays": 30,
        "autoApplyDecisionsEnabled": true,
        "recommendationsEnabled": true,
        "recommendationLookBackDuration": "P30D",
        "recurrence": {
            "pattern": {
                "type": "absoluteMonthly",
                "interval": 3,
                },
            "range": {
                "type": "noEnd",
                "numberOfOccurrences": 0,
                "recurrenceTimeZone": null,
                "startDate": "2022-01-02",
                "endDate": "9999-12-31"
                }
        },
        "applyActions": [
            {
                "@odata.type": "#microsoft.graph.removeAccessApplyAction"
            }
        ],
        "recommendationInsightSettings": [
            {
                "@odata.type": "#microsoft.graph.userLastSignInRecommendationInsightSetting",
                "recommendationLookBackDuration": "P30D",
                "signInScope": "tenant"
            }
        ]
    }
}
"@
    }

    return $accessReviewBody
}

####################################################
 
#Define Graph API Call for all Microsoft 365 Groups (as only M365 Groups can have a sensitivity label applied).
#$ApiGroupUrl = "https://graph.microsoft.com/v1.0/groups?$filter=groupTypes/any(c:c+eq+'Unified')"
$ApiGroupUrl = "https://graph.microsoft.com/v1.0/groups"


#Perform pagination if next page link (odata.nextlink) returned.
While ($ApiGroupUrl -ne $Null) {
    #Retrieve all groups.
    $GroupResponse = Invoke-WebRequest -Method GET -Uri $ApiGroupUrl -ContentType "application\json" -Headers $headers | ConvertFrom-Json

    #If the variable $groupresponse contains a value continue.
    if($GroupResponse.value) {
        #Retrieve the value details
        $Groups = $GroupResponse.value
        
        #Define Graph API Call to retrieve all current access reviews.      
        $ApiReviewsUrl = "https://graph.microsoft.com/beta/identityGovernance/accessReviews/definitions/" 

        #Perform pagination if next page link (odata.nextlink) returned.
        While ($ApiReviewsUrl -ne $Null){
            #retrieve all Access Reviews
            $AccessReviewsResponse = Invoke-WebRequest -Method GET -Uri $ApiReviewsUrl -ContentType "application\json" -Headers $headers | ConvertFrom-Json

            #List all groups in Azure AD which do contain an Access Review and grab their ID.
            $GroupsWithAccessReviews = $AccessReviewsResponse.value.instanceEnumerationScope.query | where {$_ -like "*/groups/*"} | ForEach-Object { ($_ -split "/groups/")[1] }

            #for each group in $groups do the following
            ForEach($Group in $Groups) {
                #Grab ID and DisplayName and check if group already has an Access Review Applied.
                $id = $group.id
                $displayname = $group.displayName
                $AccessReviewApplied = $GroupsWithAccessReviews.Contains($id)

                #Grab the label from the group from the description (for assigned groups as an example).
                $Groupdescription = $group.description
                $pattern = '(?<=\[).+?(?=\])'
                $Groupdescription = [regex]::Matches($Groupdescription, $pattern).Value
                

                #If the group doesn't have an access review yet the next section will be ran.
                if ($AccessReviewApplied -eq $false) {
                    #Now let's retreive the label from the group (if any).
                    $ApiLabelUrl  = "https://graph.microsoft.com/beta/groups/{$id}?`$select=assignedLabels"
                    $LabelResponse = Invoke-WebRequest -Method GET -Uri $ApiLabelUrl -ContentType "application\json" -Headers $headers | ConvertFrom-Json
                    $LabelResponse = $LabelResponse.assignedLabels.displayname

                    #If the group does have a label applied the following section will be ran.
                    if ($LabelResponse) {
                        #write output to the screen, build the access review based on the function and post it to the Graph API.
                        write-host "Microsoft 365 Group '$displayname' current has Sensitivity Label '$labelresponse' assigned, creating Access Review type $labelresponse!" -ForegroundColor Green
                        $accessReviewBody = Build-AccessReviewRequestBody -id $id -displayname $displayname -LabelResponse $labelresponse
                        $accessReviewCreateUrl = "https://graph.microsoft.com/beta/identityGovernance/accessReviews/definitions/"
                        $accessReviewResponse = Invoke-RestMethod -Method Post -Uri $accessReviewCreateUrl -Body $accessReviewBody -ContentType 'application/json' -Headers $headers
                        write-host "AR Applied for Microsoft 365 group: $displayname" -ForegroundColor Green
                    }
                    else {
                        #If the group does have a label applied the following section will be ran.
                        if ($Groupdescription) {
                            #write output to the screen, build the access review based on the function and post it to the Graph API.
                            write-host "Security Group '$displayname' current has Description Label '$Groupdescription' assigned, creating Access Review type $Groupdescription!" -ForegroundColor Green
                            $accessReviewBody = Build-AccessReviewRequestBody -id $id -displayname $displayname -LabelResponse $Groupdescription
                            $accessReviewCreateUrl = "https://graph.microsoft.com/beta/identityGovernance/accessReviews/definitions/"
                            $accessReviewResponse = Invoke-RestMethod -Method Post -Uri $accessReviewCreateUrl -Body $accessReviewBody -ContentType 'application/json' -Headers $headers
                            write-host "AR Applied for Security Group: $displayname" -ForegroundColor Green
                        }
                        #If the group does not have a label applied the following section will be ran.
                        Else {
                            #write-output
                            Write-host "Group $displayname has no Sensitivity Label applied, skipping Access Review Assignment." -ForegroundColor Cyan
                        }
                    }

                }
                #If the group already has an access review the next section will be ran.
                else {
                    #write-output
                    Write-host "Group $displayname already has an Access Review Applied, skipping Access Review Assignment." -ForegroundColor Yellow
                }

            }
        $ApiReviewsUrl=$AccessReviewsResponse.'@odata.nextlink'
        }
    }
$ApiGroupUrl=$GroupResponse.'@odata.nextlink'
}
