# Function to check DNS port connectivity
function Test-DnsPort {
    param (
        [string]$Server,
        [int]$Port,
        [string]$Protocol
    )
    try {
        $tcpudp = if ($Protocol -eq 'tcp') { 'TCP' } else { 'UDP' }
        $endpoint = New-Object System.Net.IPEndPoint ([System.Net.Dns]::GetHostAddresses($Server)[0], $Port)
        $tcpudpClient = New-Object System.Net.Sockets.TcpClient
        $tcpudpClient.Connect($endpoint)
        $tcpudpClient.Close()
        Write-Output "SUCCESS: $tcpudp port $Port is open on $Server."
        return $true
    } catch {
        Write-Output "ERROR: $tcpudp port $Port is not open on $Server."
        return $false
    }
}

# Function to update DNS forwarders
function Update-DnsForwarders {
    param (
        [string]$Server,
        [string[]]$Forwarders
    )
    try {
        $dns = Get-WmiObject -Namespace "root\MicrosoftDNS" -Class MicrosoftDNS_Server -ComputerName $Server
        $dns.Forwarders = $Forwarders
        $dns.Put()
        Write-Host "DNS forwarders updated on $Server." -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to update DNS forwarders on $Server." -ForegroundColor Red
    }
}

# Read the list of DNS servers from the text file
$dnsServersFile = ".\DNSservers.txt"
$dnsServers = Get-Content $dnsServersFile

# Initialize a report array
$report = @()

# Check DNS port connectivity for each server and update forwarders if successful
foreach ($dnsServer in $dnsServers) {
Write-host "Checking DNS Server $dnsServer..." -ForegroundColor Yellow
    $check='30.45.20.2','30.45.20.1' | Test-NetConnection -Port 53
#	$check
	 if ($check.tcpTestSucceeded -eq $true) 
	 {
	 Write-Host "DNS connection to $dnsServer successful." -ForegroundColor Green
        # Update DNS forwarders if both TCP and UDP ports are successfully connected
        $forwarders = @("30.45.20.2", "30.45.20.1")  # Replace with your desired forwarders
        Update-DnsForwarders -Server $dnsServer -Forwarders $forwarders
    }
else 
{
		Write-Host "DNS connection to $dnsServer failed." -ForegroundColor Red
}

    # Add the server status to the report array
    $report += [PSCustomObject]@{
        DNS_Server = $dnsServer
        TCP_Port_Status = $check
         Forwarders_Updated = if ($check.tcpTestSucceeded -eq $true) { "Yes" } else { "No" }
    }
}

# Generate the report
$report | Export-Csv -Path ".\DNSForwarderUpdateReport.csv" -NoTypeInformation

Write-Host "DNS port check and forwarders update completed & Report generated." -ForegroundColor Yellow