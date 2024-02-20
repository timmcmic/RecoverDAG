
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

#Start the log file based on DAG name.

new-logfile -logFileName $dagName -logFolderPath $logFolderPath

#Start logging...

out-logfile -string "************************************************************************"
out-logfile -string "Entering Recover DAG"
out-logfile -string "************************************************************************"

test-ExchangeManagementShell

out-logfile -string "Proceed based on action selected.."
out-logfile -string $operation

if ($operation -eq $functionBackupOperation)
{
    out-logfile -string "Entering backup procedure."
}
else 
{
    out-logfile -string "Entering restore procedure"
}