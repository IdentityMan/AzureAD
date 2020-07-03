<#
.DESCRIPTION
    This script is able to change / provision the phone number of the end user used by MFA / SMS Signin

.PARAMETER Token Required <String>
    The token only string for a Bearer token.

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
    [String]$Token,
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

$ErrorActionPreference = 'Stop';

$graphApiVersion = "beta";
$resource = "authentication/phoneMethods";
$headers = @{
    "Authorization" = "Bearer $($Token)";
    "Content-Type" = "application/json";
}

#Try to see if the user is currently enrolled and if so retrieve current value
$currentusersetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)" -Method get -Headers $headers;
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
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)" -Method Post -Headers $headers -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
    }
    
    if (($ActionType -eq "Update" -or $ActionType -eq "Delete") -and $PhoneType -like "Mobile") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/3179e48a-750b-4051-897c-87b9720928f7" -Method $Method -Headers $headers -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
    }

    if (($ActionType -eq "Update" -or $ActionType -eq "Delete") -and $PhoneType -like "AlternateMobile") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/b6332ec1-7057-4abe-9331-3d72feddfe41" -Method $Method -Headers $headers -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
    }

    if (($ActionType -eq "Update" -or $ActionType -eq "Delete") -and $PhoneType -like "Office") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/e37fc753-ff3b-4958-9484-eaa9425c82bc" -Method $Method -Headers $headers -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing        
    }
    $newusersettings = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)" -Method get -Headers $headers;
    $newusersettings = $newusersettings | ConvertTo-Json
    write-host "New Authentication method settings for user $UPN." -ForegroundColor Green
    write-host $newusersettings -ForegroundColor Green
}

if (!$ActionType){
    write-host "No settings changed for $UPN!" -ForegroundColor Yellow
}

if ($SMSSignIn){
    if ($SMSSignIn -eq "Enable") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/3179e48a-750b-4051-897c-87b9720928f7/enableSmsSignIn" -Method Post -Headers $headers -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
       }
    if ($SMSSignIn -eq "Disable") {
        $ExecuteUpdateUserSetting = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)/3179e48a-750b-4051-897c-87b9720928f7/disableSmsSignIn" -Method Post -Headers $headers -Body $UpdateUserSetting -ErrorAction Stop -UseBasicParsing
        }
    $newusersettings = Invoke-RestMethod -Uri "https://graph.microsoft.com/$($graphApiVersion)/users/$($UPN)/$($resource)" -Method get -Headers $headers;
    $newusersettings = $newusersettings | ConvertTo-Json
    write-host "New Authentication method settings for user $UPN." -ForegroundColor Green
    write-host $newusersettings -ForegroundColor Green
}

if (!$SMSSignIn){
    write-host "No SMSSignIn settings changed for $UPN!" -ForegroundColor Yellow
}