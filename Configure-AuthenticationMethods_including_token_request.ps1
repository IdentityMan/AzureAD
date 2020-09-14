<#
.DESCRIPTION
    This script is able to change / provision the phone number of the end user used by MFA / SMS Signin
    Written by: Pim Jacobs (https://identity-man.eu)

.PARAMETER UPN Required <String>
    The UPN for which you want to add or change the phonenumber

.PARAMETER ActionType Optional <String>
    The actiontype for changes, which can either be Add, Update or Delete as action.

.PARAMETER PhoneNumber Optional<String>
    Enter the international phone number of the end user i.e. "+310612345678"

.PARAMETER PhoneType Optional <String>
    Choose between three values i.e. Mobile, AlternateMobile or Office

.PARAMETER SMSSignin Optional <String>
    The actiontype for the sms sign-in feature, which can either be Add, Update or Delete as action

.EXAMPLE
    To read current settings
    Configure-MFAMethods.ps1 -Token <Intune graph.microsoft.com token> -UPN 'username@identity-man.eu'

    To update, add or delete settings
    Configure-MFAMethods.ps1 -Token <Intune graph.microsoft.com token> -UPN 'username@identity-man.eu' -ActionType '<Add/Update/Delete>' -PhoneNumber '<+310612345678>' -PhoneType '<Mobile/AlternateMobile/Office>'

    To enable or disable the SMSSignIn feature (only when the user is allowed to use this feature).
    Configure-MFAMethods.ps1 -Token <Intune graph.microsoft.com token> -UPN 'username@identity-man.eu' -SMSSignIn '<Enable/Disable>'
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [String]$UPN,
    [Parameter(Mandatory=$false)]
    [ValidateSet("Add", "Update", "Delete")]
    [String]$ActionType,
    [Parameter(Mandatory=$false)]
    [String]$PhoneNumber,
    [Parameter(Mandatory=$false)]
    [ValidateSet("Mobile", "AlternateMobile", "Office")]
    [String]$PhoneType,
    [Parameter(Mandatory=$false)]
    [ValidateSet("Enable", "Disable")]
    [String]$SMSSignIn
)

# Update this info
$tenantDomain = 'tenantname.onmicrosoft.com' #Change to your tenant domain (tenantname.onmicrosoft.com)
$clientId = '00000000-0000-0000-0000-000000000000' #Change to your AppID / ClientId

# =====================================================================================================================================

function New-Auth {

	param($aR)

	#Try silently getting a new token
	    if ($aR) {
			$user = $aR.Account.Username
			$aR = $null
			$aR = Get-MsalToken -TenantId $tenantDomain -ClientId $clientId -RedirectUri 'urn:ietf:wg:oauth:2.0:oob' -LoginHint $user
		} else {
			# Interactive auth required
			$aR = Get-MsalToken -TenantId $tenantDomain -ClientId $clientId -RedirectUri 'urn:ietf:wg:oauth:2.0:oob' -Interactive
		}
	return $aR
}

function New-AuthHeaders{

	$aH = $null
	$aH = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
	$aH.Add('Authorization', 'Bearer ' + $authResult.AccessToken)
	$aH.Add('Content-Type','application/json')
	$aH.Add('Accept','application/json, text/plain')

	return $aH

}

function Test-TokenValidity {

	if ($authResult) {
		# We have an auth context
		if ($authResult.ExpiresOn.LocalDateTime -gt (Get-Date)) {

			# Token is still valid, nothing to do here.
			$remaining = $authResult.ExpiresOn.LocalDateTime - (Get-Date)
			Write-Host "Access Token valid for $remaining" -ForegroundColor Green

		} else {
			# Token expired, try to get a new one silently from the token cache			
			Write-Host 'Access Token expired, getting new token silently' -ForegroundColor Green
			$script:authResult = New-Auth $authResult
			$script:authHeaders = New-AuthHeaders

		}

	} else {
		# No auth context, go interactive
		Write-Host "We need to authenticate first, select a user with the appropriate permissions" -ForegroundColor Green
		$script:authResult = New-Auth
		$script:authHeaders = New-AuthHeaders
	}

}


$ErrorActionPreference = 'Stop';

#Verify Token and refresh Token if expired or not yet requested.
Test-TokenValidity

#MSGraphSettings
$graphApiVersion = "beta";
$resource = "authentication/phoneMethods";

#Try to see if the user is currently enrolled and if so retrieve current value
$currentusersetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)" -Method get -Headers $AuthHeaders;
$Currentsettings = $currentusersetting | ConvertTo-Json
write-host "Current Authentication method settings for user $UPN." -ForegroundColor Yellow
write-host $Currentsettings -ForegroundColor Yellow
#endregion

if ($ActionType -eq "Update"){
    $Method = "put"
}

if ($ActionType -eq "Delete"){
    $Method = "Delete"
}

if ($ActionType){
$UpdateUserSetting  = @{ phonetype=$phonetype;phonenumber=$phonenumber}
$UpdateUserSetting = ConvertTo-Json -InputObject $UpdateUserSetting

    if ($ActionType -eq "Add") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)" -Method Post -Headers $AuthHeaders -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
    }
    
    if (($ActionType -eq "Update" -or $ActionType -eq "Delete") -and $PhoneType -like "Mobile") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/3179e48a-750b-4051-897c-87b9720928f7" -Method $Method -Headers $AuthHeaders -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
    }

    if (($ActionType -eq "Update" -or $ActionType -eq "Delete") -and $PhoneType -like "AlternateMobile") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/b6332ec1-7057-4abe-9331-3d72feddfe41" -Method $Method -Headers $AuthHeaders -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
    }

    if (($ActionType -eq "Update" -or $ActionType -eq "Delete") -and $PhoneType -like "Office") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/e37fc753-ff3b-4958-9484-eaa9425c82bc" -Method $Method -Headers $AuthHeaders -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing        
    }
    $newusersettings = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)" -Method get -Headers $AuthHeaders;
    $newusersettings = $newusersettings | ConvertTo-Json
    write-host "New Authentication method settings for user $UPN." -ForegroundColor Green
    write-host $newusersettings -ForegroundColor Green
}

if (!$ActionType){
    write-host "No settings changed for $UPN!" -ForegroundColor Yellow
}

if ($SMSSignIn){
    if ($SMSSignIn -eq "Enable") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/3179e48a-750b-4051-897c-87b9720928f7/enableSmsSignIn" -Method Post -Headers $AuthHeaders -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
       }
    if ($SMSSignIn -eq "Disable") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/3179e48a-750b-4051-897c-87b9720928f7/disableSmsSignIn" -Method Post -Headers $AuthHeaders -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
        }
    $newusersettings = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)" -Method get -Headers $AuthHeaders;
    $newusersettings = $newusersettings | ConvertTo-Json
    write-host "New Authentication method settings for user $UPN." -ForegroundColor Green
    write-host $newusersettings -ForegroundColor Green
}

if (!$SMSSignIn){
    write-host "No SMSSignIn settings changed for $UPN!" -ForegroundColor Yellow
}
