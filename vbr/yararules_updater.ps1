<#
.NAME
    Veeam Backup & Replication - Yara Rules
.DESCRIPTION
    This script downloads YARA Rules from https://github.com/Yara-Rules/rules, creates an index.yar to
    include all individual files/rules and and will upload them to the mount servers specified in the script.
    When setting the lab variable to yes, it downloads only 3 Yara rules (including eicar).
    When setting the lab variable to no, it will download all yara rules from the github repo.
 .NOTES  
    File Name  : yararules_updater.ps1
    Author     : Marc M
    Requires   : PowerShell, Veeam Backup & Replication v12.1
.VERSION
	1.1
#>


## Fill in Username, the Mount Servers you want to copy the rules to and select yes/no for a small/full set of Yara Rules ##
$Username = "BACKUP\Administrator"
$mountservers = "VBR.BACKUP.LAB", "REPO1-1.BACKUP.LAB", "VRO.BACKUP.LAB"
$lab = "no"



### DO NOT CHANGE ANYTHING BELOW HERE ###

# Check if credentials file exists
$FilePath = Test-Path -Path '.\creds.txt' -PathType Leaf
If (Get-ChildItem -Path '.\' -Filter creds.txt) {
    Write-Host "Credentials file exists, continuing..."
}
else {
    Write-Host "Credentials file does not exist, enter credentials..."
    $credential = Get-Credential
    $credential.Password | ConvertFrom-SecureString | Set-Content ".\creds.txt"
}

$passwordText = Get-Content ".\creds.txt"
 
# Convert to secure string
$securePwd = $passwordText | ConvertTo-SecureString 
# Create credential object
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd

# Converting User/Pass to Credentials
#$Passw = ConvertTo-SecureString -String "$Password" -AsPlainText -Force
#$Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $Passw

# Do we need to install a few Yara Rules or a Full set of Yara Rules
if ($lab -eq "yes") {
    ## PARTIAL - 3 YARA RULES - FOR LAB AND DEMO PURPOSES ##
    Write-Host ''; Write-Host 'Lab is set to Yes!' -ForegroundColor Green ; Write-Host '' ; Write-Host 'Downloading a few Yara Rules and extracting contents...';
    md '.\YaraRules' -Force | Out-Null
    Invoke-WebRequest 'https://github.com/Yara-Rules/rules/raw/master/exploit_kits/EK_ZeroAcces.yar' -OutFile .\YaraRules\EK_ZeroAcces.yar
    Invoke-WebRequest 'https://github.com/Yara-Rules/rules/raw/master/malware/MALW_Eicar.yar' -OutFile .\YaraRules\MALW_Eicar.yar
    Invoke-WebRequest 'https://github.com/Yara-Rules/rules/raw/master/malware/RANSOM_TeslaCrypt.yar' -OutFile .\YaraRules\RANSOM_TeslaCrypt.yar
}
else {
    ## FULL - ALL 450 YARA Rules - CPU INTENSIVE ##
    Write-Host ''; Write-Host 'Full is set to Yes!' -ForegroundColor Red ; Write-Host ''; Write-Host 'Downloading Full Set of Yara Rules and extracting contents...';
    Invoke-WebRequest 'https://codeload.github.com/Yara-Rules/rules/zip/refs/heads/master' -OutFile .\YaraRules.zip
    Expand-Archive -LiteralPath '.\YaraRules.zip' -DestinationPath .\ -ErrorAction SilentlyContinue
    Rename-Item -path '.\rules-master' -NewName '.\YaraRules'
}

# Removing .yar files from subdirs to top-level dir
cd '.\YaraRules'
Move-Item -Path '.\*\*.yar' -Destination . -ErrorAction SilentlyContinue
Get-ChildItem -Directory | Remove-Item -Recurse -ErrorAction SilentlyContinue

# Creating new index.yar file to include all individual files
Write-Host 'Creating index.yar to include all YARA Rules...'
Remove-Item -path '.\index.yar' -ErrorAction SilentlyContinue; Remove-Item -path '.\*index*.yar' -ErrorAction SilentlyContinue
Get-ChildItem -Recurse -Include *.yar | Select-Object -Property Name >> index.yar
(Get-Content '.\index.yar' | Select-Object -Skip 3) | Set-Content '.\index.yar'
(Get-Content '.\index.yar') -notmatch "index.yar" | Out-File '.\index.yar'
$index = Get-Content '.\index.yar'
$index[0..($index.count - 3)] | Out-File '.\index.yar'

# Adding full path to YARA Rules directory to beginning of each line 
$inputFile = Get-Content '.\index.yar'
$outputFile = '.\index.yar'
$collate = foreach ($Obj in $inputFile) {            
    $begin = 'include "C:\Program Files\Veeam\Backup and Replication\Backup\YaraRules\'
    $begin + $Obj
}
Set-Content -path $outputFile -value $collate
(Get-Content '.\index.yar').Replace('.yar', '.yar"') | Set-Content '.\index.yar'
cd '..\'

# Copying YaraRules folder to other Mount Servers
Write-Host 'Connecting to Mount Servers...'
Get-PSSession | Remove-PSSession
$Sessions = New-PSSession -Credential $Credentials -ComputerName $mountservers

$date = $(get-date -f dd-MM-yyyy_HHmm)
Write-Host 'Backup old YaraRules folders from the following Mount Servers:'$mountservers'...'
foreach ($Session in $Sessions) { Invoke-Command -Session $Session { (Compress-Archive -Path "C:\Program Files\Veeam\Backup and Replication\Backup\YaraRules" -DestinationPath "C:\Program Files\Veeam\Backup and Replication\Backup\YaraRules_Backup-$(get-date -f dd-MM-yyyy_HHmm).zip" -Force ) } -ErrorAction SilentlyContinue } 
#Write-Host "Backup Completed! Backup file YaraRules_Backup-$date.zip created in C:\Program Files\Veeam\Backup and Replication\Backup\"
Write-Host "Backup Completed!"; Write-Host "Backup file " -NoNewline ; Write-Host "YaraRules_Backup-$date.zip " -ForegroundColor Green -NoNewline ; Write-Host 'created in "C:\Program Files\Veeam\Backup and Replication\Backup\" on the Mount Servers...';
Write-Host 'Removing old YaraRules folders from the following Mount Servers:'$mountservers'...'
foreach ($Session in $Sessions) { Invoke-Command -Session $Session { (Remove-Item "C:\Program Files\Veeam\Backup and Replication\Backup\YaraRules" -Force -Recurse -ErrorAction SilentlyContinue) } } 

Write-Host 'Copying new YARA Rules to the following Mount Servers:'$mountservers'...'
foreach ($Session in $Sessions) { Copy-Item ".\YaraRules\" -Destination "C:\Program Files\Veeam\Backup and Replication\Backup\YaraRules" -ToSession $Session -Recurse -Force }
Get-PSSession | Remove-PSSession

# Removing temp files
Write-Host 'Removing temporary files...'
Remove-Item '.\YaraRules' -Recurse -ErrorAction SilentlyContinue
Remove-Item -path '.\YaraRules.zip' -ErrorAction SilentlyContinue
Write-Host 'Done!'

