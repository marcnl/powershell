<#
.SYNOPSIS
	This Powershell script  will:
		- Automatically create a S3 bucket in Wasabi/AWS/AzureBlob/MinIO and a folder in that bucket
		- Add your Wasabi/AWS/AzureBlob/MinIO credentials to VB365
		- Add the bucket as Object Storage Repository in VB365
		- And create a VB365 Backup repository using a Cache Repo and Object Storage Repository
		- By default, the Backup Repo is created with an 1 Year Retention period, Snapshot Based
		- After the repository has been created, you can change the name, description, etc.

	The script will fail if:
		- The S3 credentials already exists
		- The bucket already exists
	
		- If you want more repositories using the same credentials or the same bucket, create those manually
		- MinIO support is experimental, on some installations it works, on others it doesn't....no idea why

.DESCRIPTION
	MAKE SURE THIS MODULE IS INSTALLED AND IMPORTED
		- Install-Module -Name AWSPowerShell -Force
		- Import-Module -Name AWSPowershell

.EXAMPLE
	.\create_vb365_repo.ps1 s3-provider s3-access-key s3-secret-key bucketname foldername-in-bucket vbo-server-ip-hostname-or-fqdn proxy-name

	.\create_vb365_repo.ps1 wasabi WPDPN8DODU04KSZ3SJ2V uOmftyucFGvXc3yYg5fWaQosmeBSJtbApOXwNJ2h vbotest veeam vbo.veeam.lab vbo
	.\create_vb365_repo.ps1 aws WPDPN8DODU04KSZ3SJ2V uOmftyucFGvXc3yYg5fWaQosmeBSJtbApOXwNJ2h vbotest veeam vbo.veeam.lab vbo
	.\create_vb365_repo.ps1 blob storageaccountname uOmftyucFGvXc3yYg5fWaQosmeBSJtbApOXwNJ2h vbotest veeam vbo.veeam.lab vbo
	.\create_vb365_repo.ps1 minio WPDPN8DODU04KSZ3SJ2V uOmftyucFGvXc3yYg5fWaQosmeBSJtbApOXwNJ2h vbotest veeam vbo.veeam.lab vbo

.NOTES
	DO NOT forget to edit the required "USER INPUT" part in the script!! 

.VERSION
    1.2
#>


### USER INPUT STARTS HERE ###

$Username = "BACKUP\Administrator"

## Wasabi Endpoint and region settings
$EndpointUrl = "https://s3.eu-central-1.wasabisys.com"	## set the correct endpoint
$Region = "eu-central-1"								## set the correct region

## AWS Region Settings
$RegionType = "Global"									## set the correct regiontype: Global | USGovernment | China
$Region2 = "eu-west-2"									## set the correct region

## Azure Blob Region Settings
$RegionType2 = "Global"									## set the correct regiontype: Global | Germany | China | Government

## Minio Endpoint and region settings
$EndpointUrl3 = "https://s3.veeam.lab:9000"		        ## set the correct endpoint
$Region3 = "nl-home-lab-1"								## set the correct region

## Repository names and cache path
$objectstoragename = "Automated Object Storage Repo"	## name of the object storage repository
$vbobackupreponame = "Automated Backup Repo"			## name of the backup repository
$cachepath = "C:\RepoCache" 							## the folder is automatically created on the proxy, adjust drive letter where needed

## Repository Retention Settings
$RetentionPeriod = "Year1"			## Year1 | Years2 | Years3 | Years5 | Years7 | Years10 | Years25 | KeepForever
$RetentionType = "SnapshotBased"	## ItemLevel | SnapshotBased
$RetentionFrequencyType = "Daily"	## Daily | Monthly
$DailyType = "Everyday"				## Everyday | Workdays | Weekends | Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday
$DailyTime = "02:00:00"				## Default: 00:00:00

### USER INPUT ENDS HERE ###




### DO NOT CHANGE ANYTHING BELOW HERE ###


## The arguments that are passed on via command line
$S3type = $args[0]
$AccessKey = $args[1]
$SecretKey = $args[2]
$bucketname = $args[3]
$foldername = $args[4]
$vb365server = $args[5]
$proxyname = $args[6]

# Check if PS modules are installed and imported
if(-not (Get-Module AWSPowerShell -ListAvailable)){ Install-Module AWSPowerShell }


# Import PS Modules
Import-Module -Name AWSPowershell
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"
Import-Module "C:\Program Files\Veeam\Backup and Replication\Explorers\Exchange\Veeam.Exchange.PowerShell\Veeam.Exchange.PowerShell.psd1"
Import-Module "C:\Program Files\Veeam\Backup and Replication\Explorers\SharePoint\Veeam.SharePoint.PowerShell\Veeam.SharePoint.PowerShell.psd1"
Import-Module "C:\Program Files\Veeam\Backup and Replication\Explorers\Teams\Veeam.Teams.PowerShell\Veeam.Teams.PowerShell.psd1"

# Check if credentials file exists
$FilePath = Test-Path -Path '.\vb365creds.txt' -PathType Leaf
If (Get-ChildItem -Path '.\' -Filter 'vb365creds.txt') {
    Write-Host "Credentials file exists, continuing..."
}
else {
    Write-Host "Credentials file does not exist, enter credentials..."
    $credential = Get-Credential
    $credential.Password | ConvertFrom-SecureString | Set-Content ".\vb365creds.txt"
}

$passwordText = Get-Content ".\vb365creds.txt"
 
# Convert to secure string
$securePwd = $passwordText | ConvertTo-SecureString 
# Create credential object
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd


## Disconnect from a VBO Server if needed and connect to the specified Veeam Backup for Microsoft 365 Server
echo " "
echo "Connecting to VB365 Server: $vb365server"
Disconnect-VBOServer
Connect-VBOServer -Server $vb365server -Credential $Credentials

## Save the S3 Credentials
echo "Saving S3 Access Key and Secret Key"
$SecretKey2 = ConvertTo-SecureString $args[2] -AsPlainText -Force
Set-AWSCredential -AccessKey $AccessKey -SecretKey $SecretKey -StoreAs default

if ( $args[0] -eq "wasabi" ) {
    Add-VBOAmazonS3CompatibleAccount -AccessKey $AccessKey -SecurityKey $SecretKey2 -Description "Created by Powershell for $S3type bucket $bucketname" > tmp.txt
    [string]$Id = Get-Content ".\tmp.txt" | Select-String "Id"
    $length = $Id.length
    $Id2 = $Id.substring($length - 36)
    rm .\tmp.txt
}
elseif ( $args[0] -eq "minio" ) {
    Add-VBOAmazonS3CompatibleAccount -AccessKey $AccessKey -SecurityKey $SecretKey2 -Description "Created by Powershell for $S3type bucket $bucketname" > tmp.txt
    [string]$Id = Get-Content ".\tmp.txt" | Select-String "Id"
    $length = $Id.length
    $Id2 = $Id.substring($length - 36)
    rm .\tmp.txt
}
elseif ( $args[0] -eq "aws" ) {
    Add-VBOAmazonS3Account -AccessKey $AccessKey -SecurityKey $SecretKey2 -Description "Created by Powershell for $S3type bucket $bucketname" > tmp.txt
    [string]$Id = Get-Content ".\tmp.txt" | Select-String "Id"
    $length = $Id.length
    $Id2 = $Id.substring($length - 36)
    rm .\tmp.txt
}
elseif ( $args[0] -eq "blob" ) {
    Add-VBOAzureBlobAccount -Name $AccessKey -SharedKey $SecretKey2 -Description "Created by Powershell for $S3type bucket $bucketname" > tmp.txt
    sleep 3
    Get-VBOAzureBlobAccount > tmp.txt	 
    #		[string]$Id = Get-Content ".\tmp.txt" |Select-String $AccessKey
    #		$length = $Id.length
    #		$Id3 = $Id -replace ".{86}$"
    [string]$Id = Get-Content ".\tmp.txt" | Select-String $AccessKey
    $Id3 = $Id.Substring(0, $Id.IndexOf(' '))
    rm .\tmp.txt
}
else {
    Write-Warning "The S3 Storage Provider (AWS, Wasabi, Blob was not provided), exiting script"
}



## Create the S3 bucket
if ( $args[0] -eq "wasabi" ) {
    echo "Creating S3 bucket $bucketname in Wasabi region $Region"
    New-S3Bucket -BucketName "$bucketname" -EndpointUrl "$EndpointUrl" -Region "$Region"
}
elseif ( $args[0] -eq "minio" ) {
    echo "Creating S3 bucket $bucketname in MinIO region $Region3"
    New-S3Bucket -BucketName "$bucketname" -EndpointUrl "$EndpointUrl3" -Region "$Region3"
}
elseif ( $args[0] -eq "aws" ) {
    echo "Creating S3 bucket $bucketname in AWS region $Region2"
    New-S3Bucket -BucketName "$bucketname" -Region "$Region2"
}
elseif ( $args[0] -eq "blob" ) {
    echo ""
    echo "In about 5 seconds you will see a pop-up to login to your Microsoft Azure Account"
    echo ""
    sleep 5
    Connect-AzureRmAccount
    $StorageContext = New-AzureStorageContext -StorageAccountKey $SecretKey -StorageAccountName $AccessKey
    New-AzureStorageContainer -Name $bucketname -Context $StorageContext
    echo "Creating S3 bucket $bucketname in Azure region $RegionType2"
}
else {
    Write-Warning "The S3 Storage Provider (AWS, Wasabi, Blob was not provided), exiting script"
}



## Get Connection data
if ( $args[0] -eq "wasabi" ) {
    $account = Get-VBOAmazonS3CompatibleAccount -Id $Id2
    $connection = New-VBOAmazonS3CompatibleConnectionSettings -Account $account -ServicePoint $EndpointUrl
}
elseif ( $args[0] -eq "minio" ) {
    $account = Get-VBOAmazonS3CompatibleAccount -Id $Id2
    $connection = New-VBOAmazonS3CompatibleConnectionSettings -Account $account -ServicePoint $EndpointUrl3
}
elseif ( $args[0] -eq "aws" ) {
    $account = Get-VBOAmazonS3Account -Id $Id2
    $connection = New-VBOAmazonS3ServiceConnectionSettings -Account $account -RegionType $RegionType
}
elseif ( $args[0] -eq "blob" ) {
    $account = Get-VBOAzureBlobAccount -Id $Id3
    $connection = New-VBOAzureBlobConnectionSettings -Account $account -RegionType $RegionType2
}
else {
    Write-Warning "The S3 Storage Provider (AWS, Wasabi, Blob was not provided), exiting script"
}


## Connect to the Bucket and create the folder in the bucket
echo " "
echo "Creating folder $foldername in bucket $bucketname"
if ( $args[0] -eq "wasabi" ) {
    $bucket = Get-VBOAmazonS3Bucket -AmazonS3CompatibleConnectionSettings $Connection -Name $bucketname
    $folder = Add-VBOAmazonS3Folder -Bucket $bucket -Name $foldername
}
elseif ( $args[0] -eq "minio" ) {
    $bucket = Get-VBOAmazonS3Bucket -AmazonS3CompatibleConnectionSettings $Connection -Name $bucketname
    $folder = Add-VBOAmazonS3Folder -Bucket $bucket -Name $foldername
}
elseif ( $args[0] -eq "aws" ) {
    $bucket = Get-VBOAmazonS3Bucket -AmazonS3ConnectionSettings $Connection -Name $bucketname
    $folder = Add-VBOAmazonS3Folder -Bucket $bucket -Name $foldername
}
elseif ( $args[0] -eq "blob" ) {
    $bucket = Get-VBOAzureBlobContainer -ConnectionSetting $Connection
    $folder = Add-VBOAzureBlobFolder -Container $bucket -Name $foldername
}
else {
    Write-Warning "The S3 Storage Provider (AWS, Wasabi, Blob was not provided), exiting script"
}


## Connect the created folder as an object storage backup repository to VB365
echo "Creating Object Storage Repository: $objectstoragename"
if ( $args[0] -eq "wasabi" ) {
    $objectstorage = Add-VBOAmazonS3CompatibleObjectStorageRepository -Folder $folder -Name "$objectstoragename - $S3type - $bucketname"
}
elseif ( $args[0] -eq "minio" ) {
    $objectstorage = Add-VBOAmazonS3CompatibleObjectStorageRepository -Folder $folder -Name "$objectstoragename - $S3type - $bucketname"
}
elseif ( $args[0] -eq "aws" ) {
    $objectstorage = Add-VBOAmazonS3ObjectStorageRepository -Folder $folder -Name "$objectstoragename - $S3type - $bucketname"
}
elseif ( $args[0] -eq "blob" ) {
    $objectstorage = Add-VBOAzureBlobObjectStorageRepository -Folder $folder -Name "$objectstoragename - $S3type - $bucketname"
}
else {
    Write-Warning "The S3 Storage Provider (AWS, Wasabi, Blob was not provided), exiting script"
}
	
	
## Create the VBO Backup repository with Cache disk and object storage, 1 Year Retention, Snapshot Based
echo "Creating Backup Repository: $vbobackupreponame ($RetentionPeriod, $RetentionType, $RetentionFrequencyType, $DailyType at $DailyTime)"
$VboProxy = Get-VBOProxy -hostname $proxyname
Add-VBORepository -Proxy $VboProxy -Path "$cachepath $S3type $bucketname" -Name "$vbobackupreponame - $S3type - $bucketname" -ObjectStorageRepository $objectstorage -RetentionPeriod $RetentionPeriod -RetentionType $RetentionType -RetentionFrequencyType $RetentionFrequencyType -DailyTime $DailyTime -DailyType $DailyType

echo "Done!"
