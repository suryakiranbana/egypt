# Get all GPOs
$GPOs = Get-GPO -All | Sort-Object DisplayName 
$DomainName = $env:USERDOMAIN

# Initialize an empty array to store results
$Results = @()

# Loop through each GPO
foreach ($GPO in $GPOs) {

Write-Host "Searching Unliked GPOs in $GPO" -ForegroundColor Green
    
# Check if the GPO has links
    $Report = $GPO | Get-GPOReport -ReportType XML
    if ($Report -match "<LinksTo>") {

# If GPO has links, skip and continue to the next GPO
        continue
    }

# If GPO doesn't have links, add it to results
        $Results += [PSCustomObject]@{
	Domain = $DomainName        
	DisplayName = $GPO.DisplayName
        GUID = $GPO.Id
        CreationTime = $GPO.CreationTime
        ModificationTime = $GPO.ModificationTime
    }
}

# Export results to CSV
$Results | Export-Csv -Path "GPOsWithoutLinks.csv" -NoTypeInformation