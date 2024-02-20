#############################################################################################
# DISCLAIMER:																				#
#																							#
# THE SAMPLE SCRIPTS ARE NOT SUPPORTED UNDER ANY MICROSOFT STANDARD SUPPORT					#
# PROGRAM OR SERVICE. THE SAMPLE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY				#
# OF ANY KIND. MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING, WITHOUT		#
# LIMITATION, ANY IMPLIED WARRANTIES OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR		#
# PURPOSE. THE ENTIRE RISK ARISING OUT OF THE USE OR PERFORMANCE OF THE SAMPLE SCRIPTS		#
# AND DOCUMENTATION REMAINS WITH YOU. IN NO EVENT SHALL MICROSOFT, ITS AUTHORS, OR			#
# ANYONE ELSE INVOLVED IN THE CREATION, PRODUCTION, OR DELIVERY OF THE SCRIPTS BE LIABLE	#
# FOR ANY DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS	#
# PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS)	#
# ARISING OUT OF THE USE OF OR INABILITY TO USE THE SAMPLE SCRIPTS OR DOCUMENTATION,		#
# EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES						#
#############################################################################################

<#PSScriptInfo

.VERSION 1.0

.GUID 71f257a8-c758-4eb6-8e23-8714a35f290c

.AUTHOR Timothy J. McMichael (aka timmcmic)

.COMPANYNAME Microsoft Corporation

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
 This script assists in automating the DAG recovery process. 

#> 

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
    out-logfile -string "************************************************************************"
    out-logfile -string "Entering test-ExchangeMangaementShell"

    out-logfile -string "************************************************************************"

    try {
        out-logfile -string "Testing for EX Commands."        
        get-EXCommand -errorAction STOP
        out-logfile -string "EX Commands located."
    }
    catch {
        out-logfile -string "This script requires execution in the Exchange Management Shell."
        out-logfile -string $_ -isError:$true
    }

    out-logfile -string "************************************************************************"
    out-logfile -string "Exiting test-ExchangeMangaementShell"
    out-logfile -string "************************************************************************"
}

#=============================================================================================================
#=============================================================================================================

function RecoverDAG
{
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

    #Start the log file based on DAG name.

    new-logfile -logFileName $dagName -logFolderPath $logFolderPath

    #Start logging...

    out-logfile -string "************************************************************************"
    out-logfile -string "Entering Recover DAG"
    out-logfile -string "************************************************************************"

    out-logfile -string "Determine if the Exchange Mangaement Shell is being utilized."


}
