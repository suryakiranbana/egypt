$conditionalforwarder = ("100.100.100.100","200.200.200.200")
# Read the list of servers from servers.txt
$servers = Get-Content -Path ".\ServerList.txt"

# Initialize an array to store all the results
$resultsArray = @()

# Loop through each server and execute the script
foreach ($server in $servers) {
    Write-Host "Checking DNS Server $server..." -ForegroundColor Yellow
    $session = New-PSSession -ComputerName $server
    $result = Invoke-Command -Session $session -ScriptBlock {
        param ($conditionalforwarder)
        $result = $conditionalforwarder | ForEach-Object {Test-NetConnection $_ -Port 53 -WarningAction SilentlyContinue} | Select-Object sourceaddress, remoteaddress, remoteport, tcptestsucceeded
        $result
    } -ArgumentList $conditionalforwarder
    Remove-PSSession -Session $session

    # Check if the result is not null before adding it to the array
    if ($result -ne $null) {
        $resultsArray += $result
    }
}

# Check if any results were generated before exporting to CSV
if ($resultsArray.Count -gt 0) {
    $resultsArray | Export-Csv -Path ".\DNSResults.csv" -NoTypeInformation
    Write-Host "Results exported to DNSResults.csv" -ForegroundColor Green
} else {
    Write-Host "No results to export." -ForegroundColor Red