﻿#Configure tenant variables
$AppClientId = "4ec1aa79-15c7-4365-a40e-c9f70cf858f9"
$TenantId = "ad7aaf9d-e478-4d3f-99aa-ce450535d9cc"
$ClientSecret = "3So8Q~jeh~_d7.j~yRhLK9zZFks9dhtSgFSQOcgs"

#Configure connection to Graph API and make sure to retrieve access token
$RequestBody = @{client_id=$AppClientId;client_secret=$ClientSecret;grant_type="client_credentials";scope="https://graph.microsoft.com/.default";}
$OAuthResponse = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token -Body $RequestBody
$AccessToken = $OAuthResponse.access_token

#Form request headers with the acquired $AccessToken
$headers = @{'Content-Type'="application\json";'Authorization'="Bearer $AccessToken"}
#$ConsistencyLevelHeaders = @{'Content-Type'="application\json";'ConsistencyLevel'="eventual";'Authorization'="Bearer $AccessToken"}

###################################################

Function Build-AccessReviewRequestBody($id,$displayname,$LabelResponse) {
    ## Configure the Access Review Settings here per Sensitivity Label.
    ## These settings will be used later on to build the requestbody on group input like ID, DisplayName and Label.
    if ($LabelResponse -eq "Default") {
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
            "queryType": "MicrosoftGraph",
            "queryRoot": null
        }
    ],
    "settings": {
        "mailNotificationsEnabled": true,
        "reminderNotificationsEnabled": true,
        "justificationRequiredOnApproval": true,
        "defaultDecisionEnabled": true,
        "defaultDecision": "Recommendation",
        "instanceDurationInDays": 21,
        "autoApplyDecisionsEnabled": false,
        "recommendationsEnabled": true,
        "recommendationLookBackDuration": "P30D",
        "decisionHistoriesForReviewersEnabled": false,
        "recurrence": {
            "pattern": {
                "type": "absoluteMonthly",
                "interval": 12,
                },
            "range": {
                "type": "noEnd",
                "numberOfOccurrences": 0,
                "recurrenceTimeZone": null,
                "startDate": "2024-03-01",
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

    ## For Confidential only review guest users each quarter and give the review (owner) 14 days time to respond.
    ## If owner doesn't respond don't take action.
    if ($LabelResponse -eq "Confidential") {
        $accessReviewBody = @"
{
    "displayName": "Confidential Guest Access to the group $displayname ",
    "descriptionForAdmins": "Access Review for guest access to the group $displayname ",
    "descriptionForReviewers": "Please review guest membership and access to the group $displayname as it's labeled as confidential.",
    "scope": {
        "query": "/v1.0/groups/$id/transitiveMembers/microsoft.graph.user/?`$count=true&`$filter=(userType eq 'Guest')",
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
        "defaultDecisionEnabled": false,
        "defaultDecision": "None",
        "instanceDurationInDays": 21,
        "autoApplyDecisionsEnabled": true,
        "recommendationsEnabled": true,
        "recommendationLookBackDuration": "P30D",
        "decisionHistoriesForReviewersEnabled": false,
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

    ## For Highly Confidential review all users in the M365 Group each quarter and give the review (owner) 14 days time to respond.
    ## If owner doesn't respond take recommended actions.
    if ($LabelResponse -eq "Highly Confidential") {
        $accessReviewBody = @"
{
    "displayName": "Highly Confidential user Access to the group $displayname ",
    "descriptionForAdmins": "Access Review for user access to the group $displayname ",
    "descriptionForReviewers": "Please review user membership and access to the group $displayname as it's labeled as Highly Confidential.",
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
        "defaultDecision": "Recommendation",
        "instanceDurationInDays": 21,
        "autoApplyDecisionsEnabled": true,
        "recommendationsEnabled": true,
        "recommendationLookBackDuration": "P30D",
        "decisionHistoriesForReviewersEnabled": false,
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

###################################################
 
#Define Graph API Call for all Microsoft 365 Groups / Microsoft Teams Groups.
$ApiGroupUrl = "https://graph.microsoft.com/v1.0/groups?`$filter=groupTypes/any(c:c+eq+'Unified')"

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
                    
                    #If the group does not have a label applied the following section will be ran.
                    Else {
                        #write-output
                        Write-host "Group $displayname has no Sensitivity Label applied, skipping Access Review Creation." -ForegroundColor Yellow
                    }
                }

                #If the group already has an access review the next section will be ran.
                else {
                    #write-output
                    Write-host "Group $displayname already has an Access Review Applied, skipping Access Review Creation." -ForegroundColor Cyan
                }

            }
        $ApiReviewsUrl=$AccessReviewsResponse.'@odata.nextlink'
        }
    }
$ApiGroupUrl=$GroupResponse.'@odata.nextlink'
}