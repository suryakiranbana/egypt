function Check-Latency {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Target,
        [Parameter(Position = 1)]
        [string]$Source = $env:COMPUTERNAME,
        [Parameter(Position = 2)]
        [int]$PacketCount = 4
    )

    if ($PacketCount -le 0) {
        Write-Warning "PacketCount must be a positive integer. Defaulting to 4."
        $PacketCount = 4
    }

    Write-Host ("Verifying network latency for DC: $Target") -ForegroundColor Green

    try {
        $pingResult = Test-Connection -Source $Source -ComputerName $Target -Count $PacketCount -ErrorAction Stop
        $ipAddress = $pingResult.IPV4Address | Select-Object -First 1
        $latencyResult = $pingResult | Measure-Object ResponseTime -Maximum -Minimum |
            Select-Object @{Name='Source Computer'; Expression={$Source}},
                          @{Name='Target Computer'; Expression={$Target}},
                          @{Name='IP Address'; Expression={$ipAddress}},
                          @{Name='Packet Count'; Expression={$PacketCount}},
                          @{Name='Maximum Time(ms)'; Expression={$_.Maximum}},
                          @{Name='Minimum Time(ms)'; Expression={$_.Minimum}},
                          @{Name='Average Time(ms)'; Expression={($_.Sum / $_.Count)}},
                          @{Name='Status'; Expression={"Ping Successful"}}
        $latencyResult
    } catch {
        Write-Host "Unable to ping $Target" -ForegroundColor Red
        [PSCustomObject]@{
            'Source Computer' = $Source
            'Target Computer' = $Target
            'IP Address' = $null
            'Packet Count' = $PacketCount
            'Maximum Time(ms)' = $null
            'Minimum Time(ms)' = $null
            'Average Time(ms)' = $null
            'Status' = "Unable to ping"
        }
    }
}

# Read the content of the servers.txt file into an array
$serversFile = ".\servers.txt"  # Replace with the actual path to your servers.txt file
$serverList = Get-Content -Path $serversFile

# Create an empty array to store the results
$results = @()

# Initialize a counter to track progress
$totalServers = $serverList.Count
$progressCounter = 0

# Loop through each server and execute the Check-Latency function
foreach ($server in $serverList) {
    $progressCounter++
    Write-Progress -Activity 'Checking Latency' -Status "Progress: $($progressCounter * 100 / $totalServers) % Completed" -PercentComplete ($progressCounter * 100 / $totalServers)

    $result = Check-Latency -Target $server
    $results += $result
}

# Export the results to a CSV file
$outputFile = ".\DC_latency_results.csv"  # Replace with the desired path for the CSV file
$results | Export-Csv -Path $outputFile -NoTypeInformation

# Email the CSV file as an attachment
$from = "latencytest@abc.com"
$to = "abc@abc.com"
$subject = "DC Latency Results"
$body = "Please find attached DC latency results."
$smtpServer = "relayserverip"

Send-MailMessage -From $from -To $to -Subject $subject -Body $body -Attachments $outputFile -SmtpServer $smtpServer

Write-Host ("Results exported to $outputFile and sent via email") -ForegroundColor Yellow
