
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
        [string]$logFolderPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Backup","Restore")]
        [string]$operation
    )

$functionBackupOperation = "Backup"
$functionRestoreOperation = "Restore"
$functionADConfigurationContext = ""
$functionServicesContainer = "CN=Services"
$functionExchangeContainer = "CN=Microsoft Exchange"
$functionFullExchangeContainer = ""
$functionActiveDirectoryBackupKey = "CN="+ $DAGName + "-Backup,"
$functionActiveDirectoryBackupKeyCN = ""

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
    out-logfile -string "************************************************************************"
    out-logfile -string "Entering get-ADConfigurationNamingContext"
    out-logfile -string "************************************************************************"

    $functionADConfigurationContext = $null

    try {
        out-logfile -string "Obtain configuraiton namging context..."
        $functionADConfigurationContext = (Get-ADRootDSE -errorAction STOP).configurationNamingContext 
        out-logfile -string $functionADConfigurationContext
    }
    catch {
        out-logfile -string $_
        out-logfile -string "Unable to obtain configuration naming context." -isError:$TRUE
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
        $objectDN
    )

    $functionTest = $false

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering test-ADObject"
    out-logfile -string "************************************************************************"

    if (get-adobject -identity $objectDN -ErrorAction SilentlyContinue)
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

#Start the log file based on DAG name.

new-logfile -logFileName $dagName -logFolderPath $logFolderPath

#Start logging...

out-logfile -string "************************************************************************"
out-logfile -string "Entering Recover DAG"
out-logfile -string "************************************************************************"

test-ExchangeManagementShell

out-logfile -string "Obtaining the Active Directory Configuration Naming Context"

$functionADConfigurationContext = get-ADConfigurationNamingContext

out-logfile -string $functionADConfigurationContext 

out-logfile -string "Construct the full Exchange container."

$functionFullExchangeContainer = construct-FullExchangeContainer -servicesCN $functionServicesContainer -exchangeCN $functionExchangeContainer -configurationCN $functionADConfigurationContext 

out-logfile -string $functionFullExchangeContainer 

if (test-ADObject -objectDN $functionFullExchangeContainer)
{
    out-logfile -string "Exchange container located successfully in directory - proceed."
}
else 
{
    out-logfile -string "Exchange container required to be present in Active Directory and not found." -isError:$true
}

out-logfile -string "Proceed based on action selected.."
out-logfile -string $operation

if ($operation -eq $functionBackupOperation)
{
    out-logfile -string "Entering backup procedure."
    out-logfile -string "Determine if backup Active Directory Key exists."
    out-logfile -string $functionActiveDirectoryBackupKey
    $functionActiveDirectoryBackupKeyCN = $functionActiveDirectoryBackupKey + $functionFullExchangeContainer
    out-logfile -string $functionActiveDirectoryBackupKeyCN 

    if (test-ADObject -objectDN $functionActiveDirectoryBackupKeyCN)
    {
        out-logfile -string "The backup key exits for this DAG in Active Directory."
    }
    else {
        out-logfile -string "The backup key does not exist for this DAG in Active Directory - operation abort" -isError:$true
    }
}
else 
{
    out-logfile -string "Entering restore procedure"
}