# Function to perform port scanning
function Test-Port {
    param (
        [string]$SourceServer,
        [string]$DestinationServer,
        [int]$Port
    )
    
    try {
        $tcpconnection = Test-NetConnection -ComputerName $DestinationServer -Port $Port -ErrorAction Stop
        if ($tcpconnection.TcpTestSucceeded) {
            return "Open"
        } else {
            return "Closed"
        }
    } catch {
        return "Error: $_"
    }
}

# List of ports to scan
$Ports = 135, 445, 88, 636, 389, 53, 3268, 3269, 464

# List of servers from a text file
$Servers = Get-Content -Path ".\servers.txt"

# Array to hold results
$Results = @()

foreach ($Server in $Servers) {
    $SourceServer = $env:COMPUTERNAME
    $ServerResults = New-Object PSObject -Property @{
        "SourceServer" = $SourceServer
        "DestinationServer" = $Server
    }
    
    foreach ($Port in $Ports) {
        $PortResult = Test-Port -SourceServer $SourceServer -DestinationServer $Server -Port $Port
        $ServerResults | Add-Member -MemberType NoteProperty -Name "Port_$Port" -Value $PortResult
    }
    
    $Results += $ServerResults
}

# Export results to CSV
$Results | Export-Csv -Path "port_scan_results.csv" -NoTypeInformation