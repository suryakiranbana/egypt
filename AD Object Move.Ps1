# Import Active Directory module
Import-Module ActiveDirectory

# Path to the text file containing the list of computer objects
$ComputerListPath = ".\server.txt"

# OU path where you want to move the computer objects
$TargetOU = "OU=Workstation,DC=conteso,DC=com"

# Path to store the error log
$ErrorLogPath = ".\error.log"

# Array to store the results
$Results = @()

# Read the list of computer names from the text file
$Computers = Get-Content $ComputerListPath

# Iterate through each computer name
foreach ($Computer in $Computers) {
    try {
        # Attempt to move the computer object to the target OU
        Move-ADObject -Identity $Computer -TargetPath $TargetOU -ErrorAction Stop

        # If successful, add a success entry to the results
        $Results += [PSCustomObject]@{
            ComputerName = $Computer
            Status = "Success"
            Message = "Computer object moved to $TargetOU"
        }
    } catch {
        # If an error occurs, add an error entry to the results and log the error
        $ErrorMessage = $_.Exception.Message
        $Results += [PSCustomObject]@{
            ComputerName = $Computer
            Status = "Error"
            Message = $ErrorMessage
        }
        $ErrorMessage | Out-File -FilePath $ErrorLogPath -Append
    }
}

# Export the results to a CSV file
$Results | Export-Csv -Path ".\results.csv" -NoTypeInformation