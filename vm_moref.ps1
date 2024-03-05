<#
.NAME
    vCenter - VM Checker
.DESCRIPTION
    This script outputs all the VM names, MoRef IDs and IPs from vCenter
 .NOTES  
    File Name  : vm.ps1
    Author     : Marc M
    Requires   : PowerShell, VMware vCenter
.VERSION
	1.0
#>

$vcenter = "<VCENTER IP/FQDN>"
$Username = "<VSPHERE USERNAME>"


# Check if PS module is installed and imported
if(-not (Get-Module VMware.PowerCLI -ListAvailable)){ Install-Module VMware.PowerCLI -Scope CurrentUser }

# Check if credentials file exists
$FilePath = Test-Path -Path '.\vcenter_creds.txt' -PathType Leaf
If (Get-ChildItem -Path '.\' -Filter vcenter_creds.txt) {
    Write-Host "Credentials file exists, continuing..."
} else {
    Write-Host "Credentials file does not exist, enter credentials..."
    $credential = Get-Credential
    $credential.Password | ConvertFrom-SecureString | Set-Content ".\vcenter_creds.txt"
}

$passwordText = Get-Content ".\vcenter_creds.txt"
 
# Convert to secure string
$securePwd = $passwordText | ConvertTo-SecureString 
# Create credential object
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd

Write-Host "Logging into $vcenter"
Connect-VIServer -Server $vcenter -Protocol https -Credential $Credentials | Out-Null

$IPaddresses = Get-VM | Select Name,id, @{N="IPAddress";E={$_.guest.ipaddress[0]}}
echo $IPaddresses | Sort-Object -Property Name