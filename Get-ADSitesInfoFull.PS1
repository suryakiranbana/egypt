# Get a list of all domain controllers in the forest
$now = Get-Date
$forestInfo = Get-ADForest
$forestname = $($forestInfo.Name)
$reportemailsubject = "$forestname AD Sites Full Info Dated $now"

$DcList = (Get-ADForest).Domains | ForEach { Get-ADDomainController -Discover -DomainName $_ } | ForEach { Get-ADDomainController -Server $_.Name -filter * } | Select Site, Name, Domain

# Get all replication subnets from Sites & Services
$Subnets = Get-ADReplicationSubnet -filter * -Properties * | Select Name, Site, Location, Description

# Create an empty array to build the subnet list
$ResultsArray = @()

# Loop through all subnets and build the list
ForEach ($Subnet in $Subnets) {

    $SiteName = ""
    $SiteDesc = ""
    
    if ($Subnet.Site -ne $null) { 
        $SiteName = $Subnet.Site.Split(',')[0].Trim('CN=')
        $SiteDesc = (Get-ADReplicationSite -Filter { Name -eq $SiteName }).Description
    }

    $DcInSite = $False
    If ($DcList.Site -Contains $SiteName) { $DcInSite = $True }

    $RA = New-Object PSObject
    $RA | Add-Member -type NoteProperty -name "Subnet"           -Value $Subnet.Name
    $RA | Add-Member -type NoteProperty -name "SiteName"         -Value $SiteName
    $RA | Add-Member -type NoteProperty -name "SiteDescription"  -Value $SiteDesc
    $RA | Add-Member -type NoteProperty -name "DcInSite"         -Value $DcInSite
    $RA | Add-Member -type NoteProperty -name "SiteLoc"          -Value $Subnet.Location
    $RA | Add-Member -type NoteProperty -name "SiteDesc"         -Value $Subnet.Description

    # Find the DCs in the current site and add them to the object
    $DcsInSite = $DcList | Where-Object { $_.Site -eq $SiteName } | Select-Object -ExpandProperty Name
    $RA | Add-Member -type NoteProperty -name "DCName"           -Value ($DcsInSite -join ', ')

    $ResultsArray += $RA

}

# Export the array as a CSV file
$ResultsArray | Sort Subnet | Export-Csv .\ADSitesInfoFull.csv -nti
Write-Host "CSV report saved to: .\ADSitesInfoFull.csv" -ForegroundColor Green

# Export the array as an HTML file with styling
$Html = $ResultsArray | Sort Subnet | ConvertTo-Html -Head @"
<style>
    body {
        font-family: 'Arial', sans-serif;
        margin: 20px;
    }

    table {
        border-collapse: collapse;
        width: 100%;
    }

    th, td {
        border: 1px solid #dddddd;
        text-align: left;
        padding: 8px;
    }

    th {
        background-color: #f2f2f2;
    }

    h2 {
        color: #333;
    }
</style>
"@
$Html | Out-File .\ADSitesInfoFull.html -Encoding UTF8

# Export the HTML report to a file named ADSitesInfoFull.html
$htmlFilePath = ".\ADSitesInfoFull.html"
$csvFilePath  = ".\ADSitesInfoFull.csv"
# Output a message indicating the file path
Write-Host "HTML report saved to: $htmlFilePath" -ForegroundColor Green

$forestInfo = Get-ADForest
$forestname = $($forestInfo.Name)

# Define Bcc recipient email address
$BccRecipient = 'no-email@abc.com'

# Convert HTML content to a single string
$HtmlString = $Html -join "`r`n"

# SMTP settings
$smtpsettings = @{
    To         = 'abc@abc.com'
    Cc         = 'no-email@abc.com'
    From       = 'abc@abc.com'
    Subject    = "$reportemailsubject"
    SmtpServer = 'ipaddress'
    Body       = $HtmlString
    BodyAsHtml = $true
    Encoding   = [System.Text.Encoding]::UTF8
}

# Attach the HTML report to the email
$smtpsettings.Attachments = @($htmlFilePath, $csvFilePath)

# Add Bcc recipient to SMTP settings
$smtpsettings.Bcc = $BccRecipient

try {
    Send-MailMessage @smtpsettings
    Write-Host "Email sent successfully." -ForegroundColor Green

} catch {
    Write-Host "Error sending email: $_" -ForegroundColor Red
}
