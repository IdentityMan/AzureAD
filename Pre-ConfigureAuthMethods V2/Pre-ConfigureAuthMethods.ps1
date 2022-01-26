#install and import required modules
Install-Module Microsoft.Graph.Authentication -AllowClobber -Force
Import-Module Microsoft.Graph.Authentication

#Connect based on a service principal
Connect-MgGraph -ClientId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -CertificateThumbprint 0000000000000000000000000000000000000000
Select-MgProfile -Name "beta"

#if you want to connect interactive, comment the above two lines and use the ones mentioned below
#Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All"
#Select-MgProfile -Name "beta"

#import-csv file
$users = Import-Csv -Path "C:\Temp\AuthMethodsImport.csv"  -Delimiter ","

Foreach ($User in $Users) {
    Write-Host "Starting to set authentication methods for user" $user.upn -ForegroundColor Green
    $results = Get-MgUserAuthenticationPhoneMethod -UserId $User.UPN

    #Retrieve mobileresults from Results
    $mobileresult = $results | Where-Object {$_.phonetype -eq "Mobile"}

    #Reconfigure mobile field if a new value is presented.
    if ($User.Mobile) {
        if ($mobileresult.PhoneType -eq "Mobile") {
            if ($User.ForcedUpdate -eq $true) {
                Try {
                    Remove-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneAuthenticationMethodId $mobileresult.Id -Erroraction Stop
                    New-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneType Mobile -PhoneNumber $User.Mobile | Out-Null
                }
                Catch {
                    Write-Host "Failed to update mobile method as it's the default method for" $user.upn -ForegroundColor Yellow
                }
            }
        }
        Else {
            #NOTE: If the user is enabled for SMS Sign-in this number is automatically enabled for SMS Sign-in.
            New-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneType Mobile -PhoneNumber $User.Mobile | Out-Null
        }
    }
    
    Else {
        if (($User.ForcedRemoval -eq $true) -and ($mobileresult)) {
            Try {
                Remove-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneAuthenticationMethodId $mobileresult.Id -Erroraction Stop
            }
            Catch {
                Write-Host "Failed to delete mobile method as it's the default method for" $user.upn -ForegroundColor Yellow
            }

        }
    }

    #Retrieve Alternatemobileresults from Results
    $Alternatemobileresult = $results | Where-Object {$_.phonetype -eq "AlternateMobile"}
    
    #Reconfigure Alternatemobile field if a new value is presented.
    if ($User.AlternateMobile) {
        if ($Alternatemobileresult.PhoneType -eq "AlternateMobile") {
            if ($User.ForcedUpdate -eq $true) {
                Try {
                    Remove-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneAuthenticationMethodId $Alternatemobileresult.Id -Erroraction Stop
                    New-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneType AlternateMobile -PhoneNumber $User.AlternateMobile | out-null
                }
                Catch {
                    Write-Host "Failed to update Alternate Mobile method as it's the default method for" $user.upn -ForegroundColor Yellow
                }
            }
        }
        Else {
            New-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneType AlternateMobile -PhoneNumber $User.AlternateMobile | Out-Null
        }
    }
    
    Else {
        if (($User.ForcedRemoval -eq $true) -and ($Alternatemobileresult)) {
            Try {
                Remove-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneAuthenticationMethodId $Alternatemobileresult.Id -Erroraction Stop
            }
            Catch {
                Write-Host "Failed to delete Alternate Mobile method as it's the default method for" $user.upn -ForegroundColor Yellow
            }
        }
    }

    #Retrieve OfficePhoneResults from Results
    $OfficePhoneResults = $results | Where-Object {$_.phonetype -eq "Office"}
    
    #Reconfigure Office field if a new value is presented.
    if ($User.OfficePhone) {
        if ($OfficePhoneResults.PhoneType -eq "Office") {
            if ($User.ForcedUpdate -eq $true) {
                Try {
                    Remove-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneAuthenticationMethodId $OfficePhoneResults.Id -Erroraction Stop
                    New-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneType Office -PhoneNumber $User.OfficePhone | Out-Null
                }
                Catch {
                    Write-Host "Failed to update Office Phone method as it's the default method for" $user.upn -ForegroundColor Yellow
                }
            }
        }
        Else {
            New-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneType Office -PhoneNumber $User.OfficePhone | Out-Null
        }
    }
    
    Else {
         if (($User.ForcedRemoval -eq $true) -and ($OfficePhoneResults)) {
             Try {
                Remove-MgUserAuthenticationPhoneMethod -UserId $User.UPN -PhoneAuthenticationMethodId $OfficePhoneResults.Id -Erroraction Stop
            }
            Catch {
                Write-Host "Failed to delete Office Phone method as it's the default method for" $user.upn -ForegroundColor Yellow
            }
        }
    }
}
