# Define output file
$OutputFile = ".\" + $env:computername + "LdapPriorityDisableAutoCreationNS-" + (Get-Date -Format dd-MMM-yyyy) +  ".txt"

# Start the transcript
Start-Transcript -Path $OutputFile -Append

# Get FQDN of hostname
$HostName = [System.Net.Dns]::GetHostName()
$FQDN = [System.Net.Dns]::GetHostEntry($HostName).HostName
#Write-Output $FQDN
write-Host -ForegroundColor Green "Domain Controller Name : $FQDN"

# Create or modify registry key
$RegKey = New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Name 'LdapSrvPriority' -Value "500" -PropertyType DWORD -Force
Write-Output $RegKey

# Get registry key properties
$RegProperties = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters
Write-Output $RegProperties
Write-Host -ForegroundColor Green "Regkey Edit Successfully Completed for Registry Value LdapSrvPriority"

# Restart Netlogon service
Write-Host -ForegroundColor Green "Restarting Netlogon service of DC $FQDN"
net stop Netlogon
net start Netlogon

# Test domain controller registration
Write-Host -ForegroundColor Green "Executing nltest /server:$FQDN /dsregdns"
$NltestOutput = nltest /server:$FQDN /dsregdns
Write-Output $NltestOutput

#Clear DNS cache:
Write-Host -ForegroundColor Green "Executing dnscmd $FQDN /clearcache"
$dnscache = dnscmd $FQDN /clearcache
Write-Output $dnscache
Write-Host -ForegroundColor Green "DNSCache is successfully cleared for DC $FQDN"

# Perform nslookup
Write-Host -ForegroundColor Green "Executing nslookup"
$NslookupOutput = nslookup -type=all _ldap._tcp.dc._msdcs
Write-Output $NslookupOutput

Stop-Transcript