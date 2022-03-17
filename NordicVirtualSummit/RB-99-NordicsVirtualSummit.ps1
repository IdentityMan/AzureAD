#Define variables
$tenantId = Get-AutomationVariable -Name 'TenantName'
$AppID = Get-AutomationVariable -Name 'NVSApplicationID'
$AuthCertificate = Get-AutomationCertificate -Name 'NVS Service Principal'
$StorageAccountName = Get-AutomationVariable -Name 'NVSStorageAccountName'
$StorageAccountKey = Get-AutomationVariable -Name 'NVSStorageAccountKey'
$datetimerun = Get-Date -Format "yyyyMMddHHmm"
$CurrentDateTime = get-date
$DateIn30Days = (get-date).AddDays(+30)

#define arrays
$objOut = @()

#Connect to Graph
Connect-MgGraph -CertificateThumbprint $AuthCertificate.thumbprint -TenantId $tenantId -ClientId $AppID
#Select-MgProfile -Name "beta"

#Retrieve all applications
$Applications = Get-MgApplication -All

Foreach ($Application in $Applications) {
    $AppDisplayName = $Application.displayname
    $AppId = $Application.AppId
    $PasswordCredentials = $Application.passwordcredentials
    $KeyCredentials = $Application.KeyCredentials

    if ($PasswordCredentials) {
        Foreach ($PasswordCredential in $PasswordCredentials) {
            $AppSecretDateTime = $PasswordCredential.EndDateTime
            $AppSecretDateTime = [DateTime]$AppSecretDateTime
            $AppSecretId = $PasswordCredential.KeyId
            if ($AppSecretDateTime -lt $DateIn30Days) {
                
				if ($AppSecretDateTime -lt $CurrentDateTime) {
                    $AlreadyExpired = $True
                    # Create a JSON object for output to next step in Logic App workflow
                    $objOut += [pscustomobject]@{
                        AppDisplayName = $AppDisplayName
                        AppId = $AppId
                        AlreadyExpired = $AlreadyExpired
                        SecretId = $AppSecretId
						Expires = $AppSecretDateTime
                        CertificateID = "NA"
                        }
                    #write-host "$AppDisplayName has expired client secret with ID $AppSecretId!"
                }
                else {
                    $AlreadyExpired = $False
                    # Create a JSON object for output to next step in Logic App workflow
                    $objOut += [pscustomobject]@{
                        AppDisplayName = $AppDisplayName
                        AppId = $AppId
                        AlreadyExpired = $AlreadyExpired
                        SecretId = $AppSecretId
						Expires = $AppSecretDateTime
                        CertificateID = "NA"
                        }
                    #write-host "$AppDisplayName client secret with ID $AppSecretId will expire in 30 days!"
                }
            }
        }
    }

    if ($KeyCredentials) {
        Foreach ($KeyCredential in $KeyCredentials) {
            $AppCertificateDateTime = $KeyCredential.EndDateTime
            $AppCertificateDateTime = [DateTime]$AppCertificateDateTime
            $AppCertificateId = $KeyCredential.KeyId
            if ($AppCertificateDateTime -lt $DateIn30Days) {
                
				if ($AppCertificateDateTime -lt $CurrentDateTime) {
                    $AlreadyExpired = $True
                    # Create a JSON object for output to next step in Logic App workflow
                    $objOut += [pscustomobject]@{
                        AppDisplayName = $AppDisplayName
                        AppId = $AppId
                        AlreadyExpired = $AlreadyExpired
                        SecretId = "NA"
                        CertificateID = $AppCertificateId
						Expires = $AppCertificateDateTime
                        }
                    #write-host "$AppDisplayName has expired authentication certificate with ID $AppCertificateId!"
                }
                else {
                    $AlreadyExpired = $False
                    # Create a JSON object for output to next step in Logic App workflow
                    $objOut += [pscustomobject]@{
                        AppDisplayName = $AppDisplayName
                        AppId = $AppId
                        AlreadyExpired = $AlreadyExpired
                        SecretId = "NA"
                        CertificateID = $AppCertificateId
						Expires = $AppCertificateDateTime
                        }
                    #write-host "$AppDisplayName authentication certificate with ID $AppCertificateId will expire in 30 days!"
                }
            }
        }
    }

}

$objOutTotal = [pscustomobject]@{
       results = $objOut
    }

$objOutTotalFile = New-TemporaryFile

$Context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
$MyRawString = $objOutTotal | ConvertTo-Json -Depth 99
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($objOutTotalFile.FullName, $MyRawString, $Utf8NoBomEncoding)

$filenameblob = "rb-99-NordicsVirtualSummit"+$datetimerun+".json"
$storeblob = Set-AzureStorageBlobContent -Context $Context -Container nvsjson -File $objOutTotalFile.FullName -Blob $filenameblob -Properties @{"ContentEncoding" = "UTF-8"} 

$params = @{
 "blobfile"=$filenameblob;
}

Write-Output ( $params | ConvertTo-Json -Depth 99)
