# Path to the text file containing group names
$groupFilePath = "groupnames.txt"

# Path to the CSV file to export the group membership
$outputCsvPath = "GroupMembership.csv"

# Path to the log file for errors
$errorLogPath = "error.log"

# Email settings
$emailSmtpServer = "smtp.yourserver.com" # Replace with your SMTP server
$emailFrom = "your-email@example.com"    # Replace with your email address
$emailTo = "recipient@example.com"       # Replace with the recipient's email address
$emailSubject = "Group Membership Export"
$emailBody = "Please find attached the group membership details."

# Initialize an empty array to store group membership information
$groupMembership = @()

# Initialize an empty array to store error messages
$errors = @()

# Read group names from the text file
$groupNames = Get-Content -Path $groupFilePath

# Iterate through each group name
foreach ($groupName in $groupNames) {
    try {
        # Get members of the group
        $members = Get-ADGroupMember -Identity $groupName -ErrorAction Stop
        
        # Iterate through each member and collect their details
        foreach ($member in $members) {
            $groupMembership += [PSCustomObject]@{
                GroupName = $groupName
                MemberName = $member.Name
                MemberSamAccountName = $member.SamAccountName
                MemberObjectClass = $member.objectClass
            }
        }
    } catch {
        $errorMessage = "Failed to retrieve members for group: $groupName. Error: $_"
        Write-Warning $errorMessage
        $errors += $errorMessage
    }
}

# Try exporting the collected group membership information to a CSV file
try {
    $groupMembership | Export-Csv -Path $outputCsvPath -NoTypeInformation -ErrorAction Stop
    Write-Host "Group membership information exported to $outputCsvPath"
} catch {
    $exportErrorMessage = "Failed to export group membership information to CSV. Error: $_"
    Write-Warning $exportErrorMessage
    $errors += $exportErrorMessage
}

# Log errors to the error log file if there are any
if ($errors.Count -gt 0) {
    $errors | Out-File -FilePath $errorLogPath -Encoding utf8
    Write-Host "Errors have been logged to $errorLogPath"
}

# Send email with the CSV file as an attachment
try {
    Send-MailMessage -SmtpServer $emailSmtpServer -From $emailFrom -To $emailTo -Subject $emailSubject -Body $emailBody -Attachments $outputCsvPath -ErrorAction Stop
    Write-Host "Email sent successfully to $emailTo with the attachment $outputCsvPath"
} catch {
    $emailErrorMessage = "Failed to send email. Error: $_"
    Write-Warning $emailErrorMessage
    $errors += $emailErrorMessage
}

# Log email errors to the error log file if there are any
if ($errors.Count -gt 0) {
    $errors | Out-File -FilePath $errorLogPath -Encoding utf8
    Write-Host "Errors have been logged to $errorLogPath"
}

# Exit the script
exit
