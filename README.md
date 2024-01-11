In the script you will need to fill in a couple of things:

- Username (this user will create PS Sessions to the specified mount server(s))
- The Mount Server(s) you want to upload the YARA Rules to
- Specify if it's for Lab usage (only 3 YARA Rules, including one for Eicar) or not (download all ~450 YARA Rules)


When you execute the script for the first time it will ask for User/Pass credentials and save the password encrypted in a creds.txt file in the working directory. After that, it will continue to: 

1) Download all or just three YARA Rules from https://github.com/Yara-Rules/rules
2) Generate an index.yar file to include all the downloaded files/rules
3) Start PowerShell sessions to all the specified Mount Server(s)
4) Backup any existing YARA Rules on the specified Mount Server(s) to a 'YaraRules_Backup-DD-MM-YYYY_HHMM.zip' file in the "C:\Program Files\Veeam\Backup and Replication\Backup\YaraRules" directory
5) Copy the new YARA Rules to the "C:\Program Files\Veeam\Backup and Replication\Backup\YaraRules" directory on the Mount Server(s) (and create the directory structure if necessary)
6) Close the PowerShell sessions
7) Clean up any temporary files from the working directory

Then use the index.yar for scanning and you're all set.

If the YaraRules directory is not present on one of the Mount Servers you have specified it can throw some errors since it cannot compress and delete the folder, don't worry...the script will work fine ;)
