DNSServerZone -computername hostname1 | Where-Object {$_.ZoneType -eq 'Forwarder'}

$computerNames = @('hostname1', 'hostname2')
DNSServerZone -ComputerName $computerNames | Where-Object {$_.ZoneType -eq 'Forwarder'}
~~~~~~
$computerNames = @('hostname1', 'hostname2')
foreach ($computerName in $computerNames) {
    Get-DnsServerZone -ComputerName $computerName | Where-Object {$_.ZoneType -eq 'Forwarder'}
}
~~~~~~
$computerNames = (Get-Content .\ServerList.txt)
foreach ($computerName in $computerNames) {
    Get-DnsServerZone -ComputerName $computerName | Where-Object {$_.ZoneType -eq 'Forwarder'}
}

~~~~~~~~~~~~~~~~~~~
$computerNames = @('hostname1', 'hostname2')
$results = @()
foreach ($computerName in $computerNames) {
    $dnsZones = Get-DnsServerZone -ComputerName $computerName | Where-Object {$_.ZoneType -eq 'Forwarder'}
    $results += $dnsZones
}
$results | Export-Csv -Path 'output.csv' -NoTypeInformation
~~~~~~~~~~~~~~~~~

$computerNames = @('hostname1', 'hostname2')
$results = @()

foreach ($computerName in $computerNames) {
    $dnsZones = Get-DnsServerZone -ComputerName $computerName | Where-Object {$_.ZoneType -eq 'Forwarder'}
    
    foreach ($zone in $dnsZones) {
        $result = [PSCustomObject]@{
            'ComputerName' = $computerName
            'ZoneName'     = $zone.ZoneName
            'ZoneType'     = $zone.ZoneType
            # Add more properties as needed
        }
        $results += $result
    }
}

$results | Export-Csv -Path '.\output.csv' -NoTypeInformation
~~~~~~~~~~~~~~~~~~~~~
$computerNames = @(
hostname1'
hostname2'
)
$results = @()

foreach ($computerName in $computerNames) {
Write-Host "Checking DNS Conditional Forwarders on $computerName..." -ForegroundColor Yellow
    $dnsZones = Get-DnsServerZone -ComputerName $computerName | Where-Object {$_.ZoneType -eq 'Forwarder'}
    
    foreach ($zone in $dnsZones) {
        $result = [PSCustomObject]@{
            'ComputerName' = $computerName
            'ZoneName'     = $zone.ZoneName
            'ZoneType'     = $zone.ZoneType
            'DNSConditionalForwordersIP'    = $zone.MasterServers
            # Add more properties as needed
        }
        $results += $result
    }
}

$results | Export-Csv -Path '.\DNSConditionalForwarders.csv' -NoTypeInformation
~~~~~~~~~~~~~~~~~~~~~
$computerNames = @(
'host1',
'host2'
)
$results = @()

foreach ($computerName in $computerNames) {
Write-Host "Checking DNS Conditional Forwarders on $computerName..." -ForegroundColor Yellow
    $dnsZones = Get-DnsServerZone -ComputerName $computerName | Where-Object {$_.ZoneType -eq 'Forwarder'}
    
    foreach ($zone in $dnsZones) {
        $result = [PSCustomObject]@{
            'ComputerName' = $computerName
            'ZoneName'     = $zone.ZoneName
            'ZoneType'     = $zone.ZoneType
            'DNSConditionalForwordersIP'    = $zone.MasterServers
            # Add more properties as needed
        }
        $results += $result
    }
}

$results | Export-Csv -Path '.\DNSConditionalForwarders.csv' -NoTypeInformation
~~~~~~~~~~~~~~~~~~~~~~~~~






