
<#PSScriptInfo

.VERSION 1.0

.GUID fe16be3b-ae98-409e-900f-e2f4ec12860d

.AUTHOR timmcmic

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 This script backs up and recovers database copy information 

#> 
Param
    (
        [Parameter(Mandatory = $true)]
        [string]$dagName,
        [Parameter(Mandatory = $true)]
        [string]$domainController,
        [Parameter(Mandatory = $true)]
        [string]$logFolderPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Backup","Restore","Clear")]
        [string]$operation
    )

$functionBackupOperation = "Backup"
$functionRestoreOperation = "Restore"
$functionClearOperation = "Clear"
$functionADConfigurationContext = ""
$functionServicesContainer = "CN=Services"
$functionExchangeContainer = "CN=Microsoft Exchange"
$functionFullExchangeContainer = ""
$functionActiveDirectoryBackupKey = $DAGName + "-Backup"
$functionActiveDirectoryBackupKeyCN = ""
$functionBackupObject = ""
$functionDagInfo = $null

#=============================================================================================================
#=============================================================================================================
Function new-LogFile
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory = $true)]
        [string]$logFileName,
        [Parameter(Mandatory = $true)]
        [string]$logFolderPath
    )

    [string]$logFileSuffix=".log"
    [string]$fileName=$logFileName+$logFileSuffix

    # Get our log file path

    $logFolderPath = $logFolderPath+"\"+$logFileName+"\"
    
    #Since $logFile is defined in the calling function - this sets the log file name for the entire script
    
    $global:LogFile = Join-path $logFolderPath $fileName

    #Test the path to see if this exists if not create.

    [boolean]$pathExists = Test-Path -Path $logFolderPath

    if ($pathExists -eq $false)
    {
        try 
        {
            #Path did not exist - Creating

            New-Item -Path $logFolderPath -Type Directory
        }
        catch 
        {
            throw $_
        } 
    }
}

#=============================================================================================================
#=============================================================================================================

Function Out-LogFile
{
    [cmdletbinding()]

    Param
    (
        [Parameter(Mandatory = $true)]
        $String,
        [Parameter(Mandatory = $false)]
        [boolean]$isError=$FALSE
    )

    # Get the current date

    [string]$date = Get-Date -Format G

    # Build output string
    #In this case since I abuse the function to write data to screen and record it in log file
    #If the input is not a string type do not time it just throw it to the log.

    if ($string.gettype().name -eq "String")
    {
        [string]$logstring = ( "[" + $date + "] - " + $string)
    }
    else 
    {
        $logString = $String
    }

    # Write everything to our log file and the screen

    $logstring | Out-File -FilePath $global:LogFile -Append

    #Write to the screen the information passed to the log.

    if ($string.gettype().name -eq "String")
    {
        Write-Host $logString
    }
    else 
    {
        write-host $logString | select-object -expandProperty *
    }
}

#=============================================================================================================
#=============================================================================================================


Function test-ExchangeManagementShell
{
    #Code reuse attributed to: https://stackoverflow.com/questions/68441646/detect-in-script-whether-being-run-via-normal-powershell-window-or-exchange-man
 
    out-logfile -string "************************************************************************"
    out-logfile -string "Entering test-ExchangeMangaementShell"
    out-logfile -string "************************************************************************"

    $functionISEMS = [bool] (Get-Command -eq Ignore Get-ExCommand)

    out-logfile -string ("Exchange Management Shell: "+$functionISEMS)

    if ($functionISEMS -eq $TRUE)
    {
        out-logfile -string "Exchange Management Shell in use..."
    }
    Else
    {
        out-logfile -string "This script must be run from the Exchange Management Shell." -isError:$TRUE
    }

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting test-ExchangeMangaementShell"
    out-logfile -string "************************************************************************"
}

#=============================================================================================================
#=============================================================================================================

Function get-ADConfigurationNamingContext
{ 
    Param
    (
        [Parameter(Mandatory = $true)]
        $domainController
    )
    out-logfile -string "************************************************************************"
    out-logfile -string "Entering get-ADConfigurationNamingContext"
    out-logfile -string "************************************************************************"

    $functionADConfigurationContext = $null

    try {
        out-logfile -string "Obtain configuraiton namging context..."
        $functionADConfigurationContext = (Get-ADRootDSE -server $domainController -errorAction STOP).configurationNamingContext 
        out-logfile -string $functionADConfigurationContext
    }
    catch {
        out-logfile -string $_
        out-logfile -string "Unable to obtain configuration naming context." -isError:$TRUE
        exit
    }

    out-logfile -string "************************************************************************"
    out-logfile -string "get-ADConfigurationNamingContext"
    out-logfile -string "************************************************************************"

    return $functionADConfigurationContext
}

#=============================================================================================================
#=============================================================================================================

Function construct-FullExchangeContainer
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $servicesCN,
        [Parameter(Mandatory = $true)]
        $exchangeCN,
        [Parameter(Mandatory = $true)]
        $configurationCN
    )

    $functionReturnCN = ""

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering construct-FullExchangeContainer"
    out-logfile -string "************************************************************************"

    $functionReturnCN = $exchangeCN+","+$servicesCN
    out-logfile -string $functionReturnCN
    $functionReturnCN = $functionReturnCN + "," + $configurationCN
    out-logfile -string $functionReturnCN

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting construct-FullExchangeContainer"
    out-logfile -string "************************************************************************"

    return $functionReturnCN
}

#=============================================================================================================
#=============================================================================================================

Function test-ADObject
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $objectDN,
        [Parameter(Mandatory = $true)]
        $domainController
    )

    $functionTest = $false

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering test-ADObject"
    out-logfile -string "************************************************************************"

    if (get-adobject -identity $objectDN -server $domainController -ErrorAction SilentlyContinue)
    {
        out-logfile -string "Directory object present by DN."
        $functionTest = $TRUE
    }
    else 
    {
        out-logfile -string "Objec is not present by DN."
    }

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting test-ADObject"
    out-logfile -string "************************************************************************"

    return $functionTest
}

#=============================================================================================================
#=============================================================================================================

Function return-ADObject
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $objectDN,
        [Parameter(Mandatory = $true)]
        $domainController
    )

    $functionReturn = $null

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering return-ADObject"
    out-logfile -string "************************************************************************"

    try {
        $functionReturn = get-adobject -identity $objectDN -server $domainController -properties * -errorAction STOP
    }
    catch {
        out-logfile -string "AD Object not located by DN."
        exit
    }
    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting return-ADObject"
    out-logfile -string "************************************************************************"

    return $functionReturn
}

#=============================================================================================================
#=============================================================================================================

Function create-BackupObject
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $objectName,
        [Parameter(Mandatory = $true)]
        $objectDN,
        [Parameter(Mandatory = $true)]
        $domainController
    )

    $functionObjectType = "msDS-App-Configuration"


    out-logfile -string "************************************************************************"
    out-logfile -string "Entering create-BackupObject"
    out-logfile -string "************************************************************************"

    try {
        new-ADObject -Name $objectName -path $objectDN -type $functionObjectType -server $domainController -errorAction STOP
    }
    catch {
        out-logfile -string "Unable to create backup object in Active Directory."
        out-logfile -string $_ 
        exit
    }
    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting create-BackupObject"
    out-logfile -string "************************************************************************"
}

#=============================================================================================================
#=============================================================================================================

Function construct-BackupKey
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $backupCN,
        [Parameter(Mandatory = $true)]
        $exchangeCN
    )

    $functionReturnCN = ""

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering construct-BackupKey"
    out-logfile -string "************************************************************************"

    $functionReturnCN = "CN="+$backupCN
    out-logfile -string $FunctionReturnCN
    $functionReturnCN = $functionReturnCN+","+$exchangeCN
    out-logfile -string $functionReturnCN

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting construct-BackupKey"
    out-logfile -string "************************************************************************"

    return $functionReturnCN
}

#=============================================================================================================
#=============================================================================================================

Function get-DAGInfo
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $dagName,
        [Parameter(Mandatory = $true)]
        $domainController
    )

    $functionReturn =@()
    $functionDatabaseCopyStatus = @()
    $functionServers = ""
    $functionReplay = "Configured:"
    $functionMaxTime = "MaxDelay:"
    $functionMaxTimeValue = $null
    $functionReplayTimeValue = $null
    $functionReplayStatus = $null

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering get-DAGInfo"
    out-logfile -string "************************************************************************"

    out-logfile -string "Obtaining database copy status."

    try {
        $functionServers = (Get-databaseAvailabilityGroup -identity $DAGName -domainController $domainController -errorAction STOP).servers
    }
    catch {
        out-logfile -string "Uanble to obtain database availability group servers."
        out-logfile -string $_
        exit
    }

    out-logfile -string $functionServers

    foreach ($server in $functionServers)
    {
        out-logfile -string ("Processing server: "+$server)

        try {
            $functionDatabaseCopyStatus += @(get-mailboxDatabaseCopyStatus -server $server -domainController $domainController -errorAction STOP)
        }
        catch {
            out-logfile -string "Unable to obtain database copy status for server."
            out-logfile -string $_
            exit
        }

        out-logfile -string $functionDatabaseCopyStatus
    }

    out-logfile -string "Create objects to persist backup information to Active Directory."

    foreach ($database in $functionDatabaseCopyStatus)
    {
        $functionReplayStatus = $database.ReplayLagStatus.split(";")
        out-logfile -string $functionReplayStatus

        foreach ($status in $functionReplayStatus)
        {
            out-logfile -string $status

            if ($status.contains($functionReplay))
            {
                $functionReplayTimeValue = $status.tostring()
                $functionReplayTimeValue = $functionReplayTimeValue.replace($functionReplay,"")
                $functionReplayTimeValue = $functionReplayTimeValue.trim()
                out-logfile -string $functionReplayTimeValue
            }
            elseif ($status.contains($functionMaxTime))
            {
                $functionMaxTimeValue = $status.tostring()
                $functionMaxTimeValue = $functionMaxTimeValue.replace($functionMaxTime,"")
                $functionMaxTimeValue = $functionMaxTimeValue.trim()
                out-logfile -string $functionMaxTimeValue
            }
            else 
            {
                out-logfile -string "Nothing to see here - move on..."
            }
        }

        $functionObject = New-Object PSObject -Property @{
            Identity = $database.Identity
            MailboxServer = $database.MailboxServer
            ActivationPreference = $database.ActivationPreference
            ReplayLagTime = $functionReplayTimeValue
            MaxLagTime = $functionMaxTimeValue
        }
    
        out-logfile -string $functionObject

        $functionReturn += $functionObject
    }

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting get-DAGInfo"
    out-logfile -string "************************************************************************"

    return $functionReturn
}

#=============================================================================================================
#=============================================================================================================

Function set-BackupInfo
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $objectDN,
        [Parameter(Mandatory = $true)]
        $backupInfo,
        [Parameter(Mandatory = $true)]
        $domainController
    )

    $functionJSON = $NULL

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering set-BackupInfo"
    out-logfile -string "************************************************************************"

    try {
        Set-ADObject -identity $objectDN -clear 'msds-Settings' -server $domainController -errorAction STOP
    }
    catch {
        out-logfile -string "Error clearing previous backup properties."
        out-logfile -string $_
        exit
    }


    foreach ($database in $backupInfo)
    {
        $functionJson = ConvertTo-Json -InputObject $database
        out-logfile -string $functionJSON
        $functionJSON = $functionJSON.tostring()
        out-logfile -string $functionJSON

        try{
            set-adobject -identity $objectDN -add @{'msds-settings'=$functionJSON} -server $domainController -errorAction STOP
        }
        catch {
            out-logfile -string "Unable to update backup information."
            out-logfile -string $_
        }
    }

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting set-BackupInfo"
    out-logfile -string "************************************************************************"
}

#=============================================================================================================
#=============================================================================================================

Function restore-BackupInfo
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $backupInfo,
        [Parameter(Mandatory = $true)]
        $domainController
    )

    $functionDatabaseCopyMap = @()
    $functionDatabaseServers = @()
    $functionServerHealthStatus = $null
    $functionServerHealthStatusObjects = @()
    $functionServerHealthErrors = @()
    $functionDatabaseCopyErrors = @()
    $functionSortAttribute = "ActivationPreference"
    $functionServerAttribute = "MailboxServer"

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering restore-BackupInfo"
    out-logfile -string "************************************************************************"

    #Convert the JSON entries from Active Directory back to functional PS objects.

    foreach ($entry in $backupInfo.'msds-Settings')
    {
        out-logfile -string $entry

        $entry = ConvertFrom-Json -InputObject $entry

        out-logfile $entry

        $functionDatabaseCopyMap += $entry
    }

    #Sort the objects by activation preference.

    out-logfile -string "Sort all databases by activation preference."

    $functionDatabaseCopyMap = $functionDatabaseCopyMap | Sort-Object $functionSortAttribute

    foreach ($database in $functionDatabaseCopyMap)
    {
        out-logfile -string $database
    }

    out-logfile -string "Extract unique mailbox servers from backup."

    $functionDatabaseServers = $functionDatabaseCopyMap | Select-Object $functionServerAttribute -Unique

    out-logfile -string "Perform a test service health to validate server is online..."

    foreach ($server in $functionDatabaseServers)
    {
        out-logfile -string $server.MailboxServer

        out-logfile -string "Perform a test server health on all mailbox servers."

        try {
            $functionServerHealthStatus = test-ServiceHealth -server $server.MailboxServer -errorAction STOP

            $functionObject = New-Object PSObject -Property @{
                MailboxServer = $server.MailboxServer
                HealthStatus = $functionServerHealthStatus
            }

            out-logfile -string $functionObject

            $functionServerHealthStatusObjects += $functionObject
        }
        catch {
            $functionObject = New-Object PSObject -Property @{
                MailboxServer = $server.MailboxServer
                Error = $_
            }
            $functionServerHealthErrors += $functionObject
        }
    }

    out-logfile -string "Review server health failures."

    if ($functionServerHealthErrors.count -gt 0)
    {
        foreach ($server in $functionServerHealthErrors)
        {
            out-logfile -string ("Server health check failed on the following server: "+$server.mailboxServer)
            out-logfile -string $server.Error
            out-logfile -string "All members of the database availability group must be accessible."
        }
        exit
    }
    else {
        out-logfile -string "No server health issues detected this pass."
    }

    out-logfile -string "Review all service health status - fail if any services not ready."

    $functionServerHealthErrors = @()

    foreach ($object in $functionServerHealthStatusObjects)
    {
        out-logfile -string $object.mailboxServer

        foreach ($entry in $object.HealthStatus)
        {
            out-logfile -string $entry.role
            out-logfile -string $entry.RequiredServicesRunning
            out-logfile -string $entry.ServicesNotRunning

            if ($entry.RequiredServicesRunning -eq $false)
            {
                out-logfile -string "Required services for role not available."

                $functionObject = New-Object PSObject -Property @{
                    MailboxServer = $object.mailboxServer
                    Role = $entry.role
                    RequiredServicesRunning = $entry.RequiredServicesRunning
                    ServicesNotRunning = $entry.ServicesNotRunning
                }

                $functionServerHealthErrors += $functionObject
            }
            else 
            {
                out-logfile -string "Server is functional and ready."
            }
        }
    }

    out-logfile -string "Determine if service errors exist on servers."

    if ($functionServerHealthErrors.count -gt 0)
    {
        out-logfile -string "Service health issues on servers exist."

        foreach ($object in $functionServerHealthErrors)
        {
            out-logfile -string "The following issues are present:"
            out-logfile -string ("Mailbox Server: "+$object.MailboxServer)
            out-logfile -string ("Role: "+$object.role)
            out-logfile -string ("Required Services Running: "+$object.RequiredServicesRunning)
            out-logfile -string ("Services Not Running: "+$object.ServicesNotRunning)
        }
        exit
    }
    else 
    {
        out-logfile -string "No individual service health issues present."
    }

    out-logfile -string "Validate that each mailbox database copy exists."

    foreach ($database in $functionDatabaseCopyMap)
    {
        try {
            Get-mailboxDatabaseCopyStatus -identity $database.identity -errorAction STOP
        }
        catch {
            $functionObject = New-Object PSObject -Property @{
                DatabaseCopy = $database.identity
                Error = $_
            }

            $functionDatabaseCopyErrors += $functionObject
        }
    }

    if ($functionDatabaseCopyErrors.count -gt 0)
    {
        out-logfile -string "Database copy errors were detected."
        out-logfile -string "In order to proceed with restoration all database copies backed up must exist."

        foreach ($object in  $functionDatabaseCopyErrors)
        {
            out-logfile -string ("Database Copy: "+$object.DatabaseCopy)
            out-logfile -string ("Error: "+$object.Error)
        }
        exit
    }
    else 
    {
        out-logfile -string "All mailbox database copies accounted for."
    }

    $functionDatabaseCopyErrors = @()

    out-logfile -string "Restore the activation preferences."

    foreach ($database in $functionDatabaseCopyMap)
    {
        out-logfile -string ("Processing identity: "+$database.identity)

        try {
            set-mailboxDatabaseCopy -identity $database.identity -activationPreference $database.ActivationPreference -errorAction STOP -domainController $domainController
        }
        catch {
            $functionObject = New-Object PSObject -Property @{
                DatabaseCopy = $database.identity
                ActivationPreference = $database.ActivationPreference
                Error = $_
            }

            $functionDatabaseCopyErrors += $functionObject
        }
    }

    if ($functionDatabaseCopyErrors.count -gt 0)
    {
        out-logfile -string "Setting activation preference for copy failed - retry restoration of manual intervention required."

        foreach ($entry in $functionDatabaseCopyErrors)
        {
            out-logfile -string ("DatabaseCopy: "+$entry.DatabaseCopy)
            out-logfile -string ("ActivationPrefernce: "+$entry.ActivationPreference)
            out-logfile -string ("Error: "+$entry.Error)
        }
    }
    else 
    {
        out-logfile -string "No errors encountered adjusting activation preferences."
    }

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting restore-BackupInfo"
    out-logfile -string "************************************************************************"
}

#=============================================================================================================
#=============================================================================================================

Function clear-BackupInfo
{ 
    # Specifies a path to one or more locations. Wildcards are permitted.
    Param
    (
        [Parameter(Mandatory = $true)]
        $objectDN,
        [Parameter(Mandatory = $true)]
        $domainController
    )

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering clear-BackupInfo"
    out-logfile -string "************************************************************************"

    try {
        remove-adObject -identity $objectDN -server $domainController -Confirm:$FALSE -errorAction STOP
    }
    catch {
        out-logfile -string "Unable to remove the backup key from Active Directory for this DAG Backup."
        exit
    }

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting clear-BackupInfo"
    out-logfile -string "************************************************************************"
}

#=============================================================================================================
#=============================================================================================================

#Start the log file based on DAG name.

new-logfile -logFileName $dagName -logFolderPath $logFolderPath

#Start logging...

out-logfile -string "************************************************************************"
out-logfile -string "Entering Recover DAG"
out-logfile -string "************************************************************************"

test-ExchangeManagementShell

out-logfile -string "Obtaining the Active Directory Configuration Naming Context"

$functionADConfigurationContext = get-ADConfigurationNamingContext -domainController $domainController

out-logfile -string $functionADConfigurationContext 

out-logfile -string "Construct the full Exchange container."

$functionFullExchangeContainer = construct-FullExchangeContainer -servicesCN $functionServicesContainer -exchangeCN $functionExchangeContainer -configurationCN $functionADConfigurationContext 

out-logfile -string $functionFullExchangeContainer 

if (test-ADObject -objectDN $functionFullExchangeContainer -domainController $domainController)
{
    out-logfile -string "Exchange container located successfully in directory - proceed."
}
else 
{
    out-logfile -string "Exchange container required to be present in Active Directory and not found." -isError:$true
}

out-logfile -string "Contruct the backup key."

out-logfile -string $functionActiveDirectoryBackupKey
$functionActiveDirectoryBackupKeyCN = construct-BackupKey -backupCN $functionActiveDirectoryBackupKey -exchangeCN $functionFullExchangeContainer
out-logfile -string $functionActiveDirectoryBackupKeyCN 

out-logfile -string "Proceed based on action selected.."
out-logfile -string $operation

if ($operation -eq $functionBackupOperation)
{
    out-logfile -string "Entering backup procedure."
    out-logfile -string "Determine if backup Active Directory Key exists."

    if (test-ADObject -objectDN $functionActiveDirectoryBackupKeyCN -domainController $domainController)
    {
        out-logfile -string "The backup key exits for this DAG in Active Directory."
    }
    else {
        out-logfile -string "Backup key does not already exist - create."

        create-BackupObject -objectDN $functionFullExchangeContainer -objectName $functionActiveDirectoryBackupKey -domainController $domainController
    }

    out-logfile -string "Obtain the backup object."

    $functionBackupObject = return-ADObject -objectDN $functionActiveDirectoryBackupKeyCN -domainController $domainController

    out-logfile -string $functionBackupObject

    out-logfile -string "Obtain the database copy information for the DAG and persist required information."

    $functionDagINFO = get-DAGInfo -dagName $dagName -domainController $domainController

    set-backupInfo -objectDN $functionActiveDirectoryBackupKeyCN -backupInfo $functionDagInfo -domainController $domainController
}
elseif ($operation -eq $functionRestoreOperation) 
{
    out-logfile -string "Entering restore procedure"

    #Test for the presence of the backup key.  If this is not present this is a hard failure.

    if (test-ADObject -objectDN $functionActiveDirectoryBackupKeyCN -domainController $domainController)
    {
        out-logfile -string "The backup key exits for this DAG in Active Directory."
    }
    else 
    {
        out-logfile -string "Restoration is not possible - the backup key cannot be located in Active Directory."
        exit
    }

    #Obtain the backup information from the directory for parsing and processing.

    $functionBackupObject = return-ADObject -objectDN $functionActiveDirectoryBackupKeyCN -domainController $domainController

    out-logfile -string $functionBackupObject

    restore-BackupInfo -backupInfo $functionBackupObject -domainController $domainController
}
elseif ($operation -eq $functionClearOperation)
{
    out-logfile -string "Entering clear process."

    clear-BackupInfo -objectDN $functionActiveDirectoryBackupKeyCN -domainController $domainController
}
else 
{
    Out-logfile -string "You should have never gotten here since paramter operations are scoped and mandatory."
}