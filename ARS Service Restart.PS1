# Get the service name to check
$serviceName = "ARAdminSvc"

# Get the remote computer name
$remoteComputerName = "hostname"

# Active Roles Administration Service Port
$port = 15172

# Check if the port is open
$result = Test-NetConnection -ComputerName $remoteComputerName -Port $port

# Get the process ID for the ARS service
$processID = (Get-WmiObject -Class Win32_Service -ComputerName $remoteComputerName -Filter "Name = '$serviceName'").ProcessId


# Check if the service is hung on the remote computer
$isserviceHung = (Get-Service -ComputerName $remoteComputerName -Name $serviceName).Status -eq "Hanging"

# Check if the process is hung on the remote computer
$isprocessHung = (Get-Process -ComputerName $remoteComputerName -Id $processID).Responding -eq $false

# If the service is hung, restart the service and send an email notification
if ($result.TcpTestSucceeded -ne $true) {
    Get-Service -ComputerName $remoteComputerName -Name $serviceName | Restart-Service
    Send-MailMessage -smtpserver relayserver -To "a@b.com" -From a@b.com -Subject "ARS Port Not Responding" -Body "The $serviceName service on $remoteComputerName is not responding on port $port. ARS service has been restarted. Kindly validate that ARS is functional."
}
elseif ($isserviceHung) {
   Get-Service -ComputerName $remoteComputerName -Name $serviceName | Restart-Service
    Send-MailMessage -smtpserver relayserver -To "a@b.com" -From a@b.com -Subject "ARS Service Hung State" -Body "The $serviceName service on $remoteComputerName is not responding on port $port. ARS service has been restarted. Kindly validate ARS is functional."
}
elseif ($isprocessFalse) {
    Get-Service -ComputerName $remoteComputerName -Name $serviceName | Restart-Service    
    Send-MailMessage -smtpserver relayserver -To "a@b.com" -From a@b.com -Subject "ARS Process Not Responding" -Body "The $serviceName service on $remoteComputerName is not responding on port $port. ARS service has been restarted. Kindly validate ARS is functional."
}
elseif ($processID -eq 0) {
    Get-Service -ComputerName $remoteComputerName -Name $serviceName | Restart-Service    
    Send-MailMessage -smtpserver relayserver -To "a@b.com" -From a@b.com -Subject "ARS Service Stopped" -Body "The $serviceName service on $remoteComputerName is not responding on port $port. ARS service has been restarted. Kindly validate ARS is functional."
}