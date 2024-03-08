<#
    .SYNOPSIS
        Veeam PostgreSQL Configuration Database object_id and host_id Update Script creator
    .EXAMPLE
        PS> .\C:\Program Files\PostgreSQL\15\bin> .\get_moref.ps1 <vcenter> <vcenter-user>
    .DESCRIPTION
        NOT SUPPORTED IN ANY WAY BY ME OR BY VEEAM! USE AT YOUR OWN RISK! 
    .NOTES  
        File Name  : get_moref.ps1
        Author     : Marc M
        Requires   : PowerShell, VMware-PowerCLI, VMware vCenter, PostgreSQL15, Veeam Backup and Replication V12.x
        Version    : 0.1
#>

$vmfilter = "_replica|vCLS-|.old"


if($args[0] -eq "build") {
$FilePath = Test-Path -Path '.\vm_list.txt' -PathType Leaf
    If (Get-ChildItem -Path '.\' -Filter vm_list.txt) {
    $hostid = $(cat .\vcenter-host_id-new.txt)
    $File1 = Get-Content ".\moref_only_old.txt"
    $File2 = Get-Content ".\moref_only_new.txt"
    $File3 = "'vm-"
    $File4 = "'"
    $File5 = '.\psql -U postgres -c "\c VeeamBackup;" -c "UPDATE public.BObjects SET host_id ='
    $File6 = ', object_id ='
    $File7 = ' WHERE object_id ='
    $File8 = $('"')

    # Go to PostgreSQL directory
    cd 'C:\Program Files\PostgreSQL\15\bin'
    Remove-Item .\temp_moref*.txt -ErrorAction SilentlyContinue
    Remove-Item .\update_moref.ps1 -ErrorAction SilentlyContinue

    for($i = 0; $i -lt $File2.Count; $i++) { ('{0}{1}{2}{3}{4}{5}{6}{7}' -f $File5,$File4,$hostid,$File4,$File6,$File3,$File2[$i],$File4) |Add-Content .\temp_moref1.txt }
    for($i = 0; $i -lt $File1.Count; $i++) { ('{0}{1}{2}{3}{4}' -f $File7,$File3,$File1[$i],$File4,$File8) |Add-Content .\temp_moref2.txt }

    $File1 = Get-Content ".\temp_moref1.txt"
    $File2 = Get-Content ".\temp_moref2.txt"

    for($i = 0; $i -lt $File1.Count; $i++)
    {
        ('{0}{1}' -f $File1[$i],$File2[$i]) |Add-Content .\update_moref.tmp
    }

    "# Start Configuration Database Backup and check result" | Out-File -FilePath .\update_moref.ps1 -Append
    "Write-host 'Starting Configuration Database Backup...'" | Out-File -FilePath .\update_moref.ps1 -Append
    "Start-VBRConfigurationBackupJob -RunAsync" | Out-File -FilePath .\update_moref.ps1 -Append
    "Write-host 'Waiting for Configuration Database Backup to complete...'" | Out-File -FilePath .\update_moref.ps1 -Append
    "sleep 120" | Out-File -FilePath .\update_moref.ps1 -Append
    "Write-host 'Configuration Database Backup completed...'" | Out-File -FilePath .\update_moref.ps1 -Append
    "Write-host 'Status of last Configuration Database Backup'" | Out-File -FilePath .\update_moref.ps1 -Append
    "Get-VBRConfigurationBackupJob" | Out-File -FilePath .\update_moref.ps1 -Append
    "Write-host 'The following VMs will be updated with the new MoRef ID:'" | Out-File -FilePath .\update_moref.ps1 -Append
    "cat .\vm_list.txt | Format-Wide -Property {`$_} -Column 3 -Force | Out-String -Width 100" | Out-File -FilePath .\update_moref.ps1 -Append
    "Write-host 'You are about to live update the Veeam Configuration Database!' -ForegroundColor Green" | Out-File -FilePath .\update_moref.ps1 -Append
    "Write-host '`n'" | Out-File -FilePath .\update_moref.ps1 -Append
    "`$confirmation = Read-Host 'Are you sure you want to continue? [yes|no]'" | Out-File -FilePath .\update_moref.ps1 -Append
    "if (`$confirmation -eq 'yes') {" | Out-File -FilePath .\update_moref.ps1 -Append
    cat .\update_moref.tmp | Out-File -FilePath .\update_moref.ps1 -Append
    "}" | Out-File -FilePath .\update_moref.ps1 -Append

    Remove-Item .\temp_moref*.txt -ErrorAction SilentlyContinue
    Remove-Item .\update_moref.tmp -ErrorAction SilentlyContinue
    Write-host "`n"; Write-host "Building Veeam Configuration Datbase object_id & host_id updater script completed!"; Write-host "`n";
    Write-host "The following VMs have been processed:"
    cat .\vm_list.txt | Format-Wide -Property {$_} -Column 3 -Force | Out-String -Width 100

}} else {

write-host "`n";
Write-Host "Are you connecting to the:"
Write-Host "[old] " -ForegroundColor Green -NoNewline; Write-Host "vCenter, to grab MoRef IDs before the migration"
Write-Host "[new] " -ForegroundColor Green -NoNewline; Write-Host "vCenter, to grab the MoRef IDs after the migration"
$type = $(Write-Host "Answer [old|new]: " -ForegroundColor yellow -NoNewLine; Read-Host)
write-host "`n"


$vcenter = $args[0]
$Username = $args[1]

# Check if PS module is installed and imported
if(-not (Get-Module VMware.PowerCLI -ListAvailable)){ Install-Module VMware.PowerCLI -Scope CurrentUser }


if ($type -eq "old") {
$FilePath = Test-Path -Path '.\vm_list.txt' -PathType Leaf
If (Get-ChildItem -Path '.\' -Filter vm_list.txt) {
    # Check if credentials file exists
    $FilePath = Test-Path -Path '.\vcenter_old_creds.txt' -PathType Leaf
    If (Get-ChildItem -Path '.\' -Filter vcenter_old_creds.txt) {
        Write-Host "Credentials file exists, continuing..."
    } else {
        Write-Host "Credentials file does not exist, enter credentials..."
        $credential = Get-Credential -credential "$Username"
        $credential.Password | ConvertFrom-SecureString | Set-Content ".\vcenter_old_creds.txt"
    }

    $passwordText = Get-Content ".\vcenter_old_creds.txt"
 
    # Convert to secure string
    $securePwd = $passwordText | ConvertTo-SecureString 
    # Create credential object
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd

    Write-Host "Logging into $vcenter"
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
    Connect-VIServer -Server $vcenter -Protocol https -Credential $Credentials | Out-Null

    echo " ";
    $vmlist = Get-VM | Select Name

    Write-Host "VM List file exists, so using this file..."
    $MyList = Get-Content .\vm_list.txt
    $MyList | %{Get-VM $_ | Select name,id} > .\vm_name_moref_$type.txt
    (gc .\vm_name_moref_$type.txt | select -Skip 3) | sc .\vm_name_moref_$type.txt # trim first 3 lines
    (gc .\vm_name_moref_$type.txt) | ? {$_.trim() -ne "" } | set-content .\vm_name_moref_$type.txt # trim blank end lines
    $content = Get-Content .\vm_name_moref_$type.txt # trim blank spaces at end of each line
    $content | Foreach {$_.TrimEnd()} | Set-Content .\vm_name_moref_$type.txt

    $MyList = Get-Content .\vm_list.txt
    $MyList | %{Get-VM $_ | Select id} > .\moref_only_$type.txt
    (gc .\moref_only_$type.txt | select -Skip 3) | sc .\moref_only_$type.txt # trim first 3 lines
    (gc .\moref_only_$type.txt) | ? {$_.trim() -ne "" } | set-content .\moref_only_$type.txt # trim blank end lines
    $content = Get-Content .\moref_only_$type.txt # trim blank spaces at end of each line
    $content | Foreach {$_.TrimEnd()} | Set-Content .\moref_only_$type.txt
    Get-Content -Path ".\moref_only_$type.txt" | ForEach{ $_.Remove(0,18) } 2>&1 | Out-File ".\moref_only_$type.tmp"
    mv ".\moref_only_$type.tmp" ".\moref_only_$type.txt" -Force

    $vcenterid_old = $(.\psql -U postgres -c "\c VeeamBackup;" -c "SELECT id FROM public.hosts where name = '$vcenter'" | Select-String "(\d{6})([a-z])")
    Write-host "The host_id of this (new) vCenter Server is: $vcenterid_old"
    Remove-Item .\vcenter-host_id-$type.txt -ErrorAction SilentlyContinue
    echo $vcenterid_old | Out-File -FilePath .\vcenter-host_id-$type.txt -Append
    (gc .\vcenter-host_id-$type.txt | select -Skip 1) | sc .\vcenter-host_id-$type.txt # trim first line
    (gc .\vcenter-host_id-$type.txt) | ? {$_.trim() -ne "" } | set-content .\vcenter-host_id-$type.txt
    $content = Get-Content .\vcenter-host_id-$type.txt # trim blank spaces at begin of each line
    $content | Foreach {$_.Trim()} | Set-Content .\vcenter-host_id-$type.txt

} else {
    # Check if credentials file exists
    $FilePath = Test-Path -Path '.\vcenter_old_creds.txt' -PathType Leaf
    If (Get-ChildItem -Path '.\' -Filter vcenter_old_creds.txt) {
        Write-Host "Credentials file exists, continuing..."
    } else {
        Write-Host "Credentials file does not exist, enter credentials..."
        $credential = Get-Credential -credential "$Username"
        $credential.Password | ConvertFrom-SecureString | Set-Content ".\vcenter_old_creds.txt"
    }

    $passwordText = Get-Content ".\vcenter_old_creds.txt"
 
    # Convert to secure string
    $securePwd = $passwordText | ConvertTo-SecureString 
    # Create credential object
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd

    Write-Host "Logging into $vcenter"
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
    Connect-VIServer -Server $vcenter -Protocol https -Credential $Credentials | Out-Null

    echo " ";
    $vmlist = Get-VM | Select Name

    Write-Host "VM List file does not exist, creating..."
    echo $vmlist | Sort-Object -Property Name > .\vm_list.txt
    (gc .\vm_list.txt | select -Skip 3) | sc .\vm_list.txt # trim first 3 lines
    (gc .\vm_list.txt) | ? {$_.trim() -ne "" } | set-content .\vm_list.txt # trim blank end lines
    $content = Get-Content .\vm_list.txt # trim blank spaces at end of each line
    $content | Foreach {$_.TrimEnd()} | Set-Content .\vm_list.txt

    # A little filtering hack
    Get-Content .\vm_list.txt | Where-Object {$_ -notmatch "$vmfilter"} | Set-Content .\vm_list.tmp;
    mv .\vm_list.txt .\vm_list_$($vcenter)_unfiltered.txt; mv .\vm_list.tmp .\vm_list.txt;

    $MyList = Get-Content .\vm_list.txt
    $MyList | %{Get-VM $_ | Select name,id} > .\vm_name_moref_$type.txt
    (gc .\vm_name_moref_$type.txt | select -Skip 3) | sc .\vm_name_moref_$type.txt # trim first 3 lines
    (gc .\vm_name_moref_$type.txt) | ? {$_.trim() -ne "" } | set-content .\vm_name_moref_$type.txt # trim blank end lines
    $content = Get-Content .\vm_name_moref_$type.txt # trim blank spaces at end of each line
    $content | Foreach {$_.TrimEnd()} | Set-Content .\vm_name_moref_$type.txt

    $MyList = Get-Content .\vm_list.txt
    $MyList | %{Get-VM $_ | Select id} > .\moref_only_$type.txt
    (gc .\moref_only_$type.txt | select -Skip 3) | sc .\moref_only_$type.txt # trim first 3 lines
    (gc .\moref_only_$type.txt) | ? {$_.trim() -ne "" } | set-content .\moref_only_$type.txt # trim blank end lines
    $content = Get-Content .\moref_only_$type.txt # trim blank spaces at end of each line
    $content | Foreach {$_.TrimEnd()} | Set-Content .\moref_only_$type.txt
    Get-Content -Path ".\moref_only_$type.txt" | ForEach{ $_.Remove(0,18) } 2>&1 | Out-File ".\moref_only_$type.tmp"
    mv ".\moref_only_$type.tmp" ".\moref_only_$type.txt" -Force

    $vcenterid_old = $(.\psql -U postgres -c "\c VeeamBackup;" -c "SELECT id FROM public.hosts where name = '$vcenter'" | Select-String "(\d{6})([a-z])")
    Write-host "The host_id of this (new) vCenter Server is: $vcenterid_old"
    Remove-Item .\vcenter-host_id-$type.txt -ErrorAction SilentlyContinue
    echo $vcenterid_old | Out-File -FilePath .\vcenter-host_id-$type.txt -Append
    (gc .\vcenter-host_id-$type.txt | select -Skip 1) | sc .\vcenter-host_id-$type.txt # trim first line
    (gc .\vcenter-host_id-$type.txt) | ? {$_.trim() -ne "" } | set-content .\vcenter-host_id-$type.txt
    $content = Get-Content .\vcenter-host_id-$type.txt # trim blank spaces at begin of each line
    $content | Foreach {$_.Trim()} | Set-Content .\vcenter-host_id-$type.txt

}} elseif($type -eq "new") {
$FilePath = Test-Path -Path '.\vm_list.txt' -PathType Leaf
If (Get-ChildItem -Path '.\' -Filter vm_list.txt) {
    # Check if credentials file exists
    $FilePath = Test-Path -Path '.\vcenter_new_creds.txt' -PathType Leaf
    If (Get-ChildItem -Path '.\' -Filter vcenter_new_creds.txt) {
        Write-Host "Credentials file exists, continuing..."
    } else {
        Write-Host "Credentials file does not exist, enter credentials..."
        $credential = Get-Credential -credential "$Username"
        $credential.Password | ConvertFrom-SecureString | Set-Content ".\vcenter_new_creds.txt"
    }

    $passwordText = Get-Content ".\vcenter_old_creds.txt"
 
    # Convert to secure string
    $securePwd = $passwordText | ConvertTo-SecureString 
    # Create credential object
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $securePwd

    Write-Host "Logging into $vcenter"
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
    Connect-VIServer -Server $vcenter -Protocol https -Credential $Credentials | Out-Null

    echo " ";
    $vmlist = Get-VM | Select Name
    Write-Host "VM List file exists, so using this file..."
    $MyList = Get-Content .\vm_list.txt
    $MyList | %{Get-VM $_ | Select name,id} > .\vm_name_moref_$type.txt
    (gc .\vm_name_moref_$type.txt | select -Skip 3) | sc .\vm_name_moref_$type.txt # trim first 3 lines
    (gc .\vm_name_moref_$type.txt) | ? {$_.trim() -ne "" } | set-content .\vm_name_moref_$type.txt # trim blank end lines
    $content = Get-Content .\vm_name_moref_$type.txt # trim blank spaces at end of each line
    $content | Foreach {$_.TrimEnd()} | Set-Content .\vm_name_moref_$type.txt

    $MyList = Get-Content .\vm_list.txt
    $MyList | %{Get-VM $_ | Select id} > .\moref_only_$type.txt
    (gc .\moref_only_$type.txt | select -Skip 3) | sc .\moref_only_$type.txt # trim first 3 lines
    (gc .\moref_only_$type.txt) | ? {$_.trim() -ne "" } | set-content .\moref_only_$type.txt # trim blank end lines
    $content = Get-Content .\moref_only_$type.txt # trim blank spaces at end of each line
    $content | Foreach {$_.TrimEnd()} | Set-Content .\moref_only_$type.txt
    Get-Content -Path ".\moref_only_$type.txt" | ForEach{ $_.Remove(0,18) } 2>&1 | Out-File ".\moref_only_$type.tmp"
    mv ".\moref_only_$type.tmp" ".\moref_only_$type.txt" -Force

    $vcenterid_new = $(.\psql -U postgres -c "\c VeeamBackup;" -c "SELECT id FROM public.hosts where name = '$vcenter'" | Select-String "(\d{6})([a-z])")
    Write-host "The host_id of this (new) vCenter Server is: $vcenterid_new"
    Remove-Item .\vcenter-host_id-$type.txt -ErrorAction SilentlyContinue
    echo $vcenterid_new | Out-File -FilePath .\vcenter-host_id-$type.txt -Append
    (gc .\vcenter-host_id-$type.txt | select -Skip 1) | sc .\vcenter-host_id-$type.txt # trim first line
    (gc .\vcenter-host_id-$type.txt) | ? {$_.trim() -ne "" } | set-content .\vcenter-host_id-$type.txt
    $content = Get-Content .\vcenter-host_id-$type.txt # trim blank spaces at begin of each line
    $content | Foreach {$_.Trim()} | Set-Content .\vcenter-host_id-$type.txt

} else {
    Write-Host "VM List file does not exist, create on using the OLD vCenter first! Exiting..."
    Disconnect-VIServer -Confirm:$false
}} 
else {
    Write-Host "VM List file does not exist, exiting..."
    Disconnect-VIServer -Confirm:$false
    exit
    }
}

