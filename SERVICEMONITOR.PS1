# Define the remote server details
$serverName = "dcname"
$services = @(
    "PMService",
    "PasswordManagerSTS",
    "W3SVC"
)

# Email configuration
$sender = "a@b.com"
$recipient = "a@b.com", "a@b.com"
$smtpServer = "malrelayservername"

# Loop through the services and check their status
$failedServices = @()
foreach ($service in $services) {
    $serviceStatus = Get-Service -ComputerName $serverName -Name $service

    # Check if the service is running
    if ($serviceStatus.Status -eq "Running") {
        Write-Host "Service '$service' is running on '$serverName'."
    }
    else {
        Write-Host "Service '$service' is not running on '$serverName'."
        $failedServices += $service

        # Start the service
        Write-Host "Starting service '$service'..."
        try {
            Get-Service -ComputerName $serverName $service | Restart-Service 
            # Start-Service -ComputerName $serverName -Name $service
            Write-Host "Service '$service' started successfully."
        }
        catch {
            Write-Host "Failed to start service '$service'. Error: $($_.Exception.Message)"
        }
    }
}

# Send email notification if any services are not running
if ($failedServices.Count -gt 0) {
    $subject = "Service Monitoring Alert on $serverName"
    $body = "The following services were not running on $serverName and have been started:`r`n`r`n"
    foreach ($failedService in $failedServices) {
        $body += "- $failedService`r`n"
    }

    $smtpParams = @{
        From       = $sender
        To         = $recipient
        Subject    = $subject
        Body       = $body
        SmtpServer = $smtpServer
    }

    try {
        Send-MailMessage @smtpParams
        Write-Host "Email notification sent successfully."
    }
    catch {
        Write-Host "Failed to send email notification. Error: $($_.Exception.Message)"
    }
}
else {
    Write-Host "All services are running on $serverName."
}