# Get all domain controllers in the forest
$forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$domainControllers = $forest.Sites | ForEach-Object {
    $_.Servers | ForEach-Object {
        $_.Name
    }
}

# Array to store certificate information
$certificates = @()

# Loop through each domain controller
foreach ($dc in $domainControllers) {
    Write-Host "Exporting Machine AutoEnrollment Certificate Details From $dc..."
    
    # Query certificates remotely
    $dcCertificates = Invoke-Command -ComputerName $dc -ScriptBlock {
        Get-ChildItem "Cert:\LocalMachine\My" | Where-Object {
            $_.Subject -like "*" -and $_.Issuer -match "AutoEnrollment Issuing CA"
        } | Sort-Object -Property NotAfter -Descending
    }

    # Select only the certificate with the latest expiration date
    $latestCert = $dcCertificates | Select-Object -First 1

    if ($latestCert -ne $null) {
        # Add certificate information to the array
        $certInfo = [PSCustomObject]@{
            'DomainController' = $dc
            'Subject' = $latestCert.Subject
            'Issuer' = $latestCert.Issuer
            'ValidFrom' = $latestCert.NotBefore
            'ValidTo' = $latestCert.NotAfter
        }
        $certificates += $certInfo
    }
}

# Export the certificate information to a CSV file
$certificates | Export-Csv -Path "DC_Certificates.csv" -NoTypeInformation