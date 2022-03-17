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

#Retrieve all Service Principals
$ServicePrincipals = Get-MgServicePrincipal -aLL

Foreach ($ServicePrincipal in $ServicePrincipals) {
    $ServicePrincpalDisplayName = $ServicePrincipal.displayname
    $ServicePrincpalId = $ServicePrincipal.AppId
	$AppObjectId = $ServicePrincipal.Id
    $PasswordCredentials = $ServicePrincipal.passwordcredentials

    if ($PasswordCredentials) {
        Foreach ($PasswordCredential in $PasswordCredentials) {
            $FederatedSSOCertDateTime = $PasswordCredential.EndDateTime
            $FederatedSSOCertDateTime = [DateTime]$FederatedSSOCertDateTime
            $FederatedSSOCertId = $PasswordCredential.KeyId
			if ($ServicePrincipal.AccountEnabled -eq $true) {
				if ($FederatedSSOCertDateTime -lt $DateIn30Days) {
					if ($FederatedSSOCertDateTime -lt $CurrentDateTime) {
						$AlreadyExpired = $True
						# Create a JSON object for output to next step in Logic App workflow
						$objOut += [pscustomobject]@{
							AppDisplayName = $ServicePrincpalDisplayName
							AppId = $ServicePrincpalId
							AlreadyExpired = $AlreadyExpired
							Expires = $FederatedSSOCertDateTime
							CertificateID = $FederatedSSOCertId
							AppObjectId = $AppObjectId
							}
						#write-output "$ServicePrincpalDisplayName has an expired Federated SSO Certificate with ID $FederatedSSOCertId!"
					}
					else {
						$AlreadyExpired = $False
						# Create a JSON object for output to next step in Logic App workflow
						$objOut += [pscustomobject]@{
							AppDisplayName = $ServicePrincpalDisplayName
							AppId = $ServicePrincpalId
							AlreadyExpired = $AlreadyExpired
							SecretId = $AppSecretId
							Expires = $FederatedSSOCertDateTime
							CertificateID = $FederatedSSOCertId
							AppObjectId = $AppObjectId
							}
						#write-output "$ServicePrincpalDisplayName has an Federated SSO Certificate active with ID $FederatedSSOCertId which will expire in 30 days!"
					}
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

$filenameblob = "rb-99-NordicsVirtualSummit-Saml"+$datetimerun+".json"
$storeblob = Set-AzureStorageBlobContent -Context $Context -Container nvsjson -File $objOutTotalFile.FullName -Blob $filenameblob -Properties @{"ContentEncoding" = "UTF-8"} 

$params = @{
 "blobfile"=$filenameblob;
}

Write-Output ( $params | ConvertTo-Json -Depth 99)
