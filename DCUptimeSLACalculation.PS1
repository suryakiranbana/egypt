# Function to get server uptime
function GetServerUptime {
    param (
        [string]$serverFQDN
    )

    try {
        $session = New-CimSession -ComputerName $serverFQDN -ErrorAction Stop
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $session -ErrorAction Stop
        $uptimeInSeconds = $os.LastBootUpTime
        $uptimeInSeconds = (Get-Date) - $uptimeInSeconds
        return $uptimeInSeconds.TotalSeconds
    } catch {
        Write-Host "Failed to get information for $serverFQDN. Error: $_"
        return 0
    } finally {
        Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue
    }
}

# Function to calculate uptime percentage
function CalculateUptimePercentage {
    param (
        [int]$uptimeInSeconds,
        [int]$totalSeconds
    )

    $uptimePercentage = ($uptimeInSeconds / $totalSeconds) * 100
    return [math]::Round($uptimePercentage, 2)
}

# Function to send an email
function Send-Email {
    param (
        [string]$to,
        [string]$subject,
        [string]$body,
        [string]$attachmentPath
    )

    $smtpServer = "mailserverip"
    $smtpFrom = "a@b.com"
    $smtpTo = $to
    $messageSubject = $subject
    $messageBody = $body

    $mailmessage = New-Object system.net.mail.mailmessage 
    $mailmessage.from = ($smtpFrom)
    $mailmessage.To.add($smtpTo) 
    $mailmessage.Subject = $messageSubject 
    $mailmessage.Body = $messageBody 
    $mailmessage.IsBodyHTML = $true

    # Attach the HTML report
    if ($attachmentPath -ne $null -and $attachmentPath -ne "") {
        $attachment = New-Object Net.Mail.Attachment($attachmentPath)
        $mailmessage.Attachments.Add($attachment)
    }

    $smtp = New-Object Net.Mail.SmtpClient($smtpServer) 
    $smtp.Send($mailmessage)
}

# Main script
$serverList = Get-Content -Path ".\ServerListComboFQDN.txt"
$reportFilePath = ".\UptimeReport.html"

# Calculate total seconds in 30 days
$totalSecondsIn30Days = 30 * 24 * 60 * 60

# Initialize array to store server uptime data
$ServerUptimeData = @()

foreach ($server in $serverList) {
write-Host -ForegroundColor Yellow "=========$server===============" 
    $uptimeInSeconds = GetServerUptime -serverFQDN $server
    $uptimeInHours = [math]::Round($uptimeInSeconds / 3600, 2)
    $uptimePercentage = CalculateUptimePercentage -uptimeInSeconds $uptimeInSeconds -totalSeconds $totalSecondsIn30Days

    # Add server uptime data to the array
    $ServerUptimeData += [PSCustomObject]@{
        Server = $server
        UptimeInHours = $uptimeInHours
        UptimePercentage = $uptimePercentage
    }
}

# Generate HTML report
$HTMLReport = @"
<html>
<head>
    <style>
        table {
            border-collapse: collapse;
            width: 50%;
        }
        th, td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #4CAF50;
            color: white;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        tr:hover {
            background-color: #ffff99;
        }
    </style>
</head>
<body>
    <h2 style="color: #4CAF50;">Moody.net Domain Controller Monthy Uptime SLA Report (last 30 days)</h2>
    <table>
        <tr>
            <th>Domain Controller Name</th>
            <th>Uptime in Hours</th>
            <th>Uptime Percentage</th>
        </tr>
"@

foreach ($Data in $ServerUptimeData) {
    $HTMLReport += @"
        <tr>
            <td>$($Data.Server)</td>
            <td>$($Data.UptimeInHours)</td>
            <td>$($Data.UptimePercentage)%</td>
        </tr>
"@
}

$HTMLReport += @"
    </table>
</body>
</html>
"@

# Export HTML report to file
$HTMLReport | Out-File -FilePath $reportFilePath

Write-Host "Uptime report generated and saved to $reportFilePath"

# Check if the HTML report file exists before sending an email
if (Test-Path $reportFilePath) {
    # Send email with the HTML report as the message body
    Send-Email -to "abc@abc.com" -subject "Domain Controller Uptime SLA Report" -body $HTMLReport -attachmentPath (Resolve-Path $reportFilePath).Path
} else {
    Write-Host "Error: HTML report file not found at $reportFilePath. Email not sent."
}