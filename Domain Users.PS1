# Define the domain and search filter
$domain = "dpmaincontrollerip"
$searchFilter = "(&(objectCategory=person)(objectClass=user)(!(sAMAccountName=sa_*))(!(sAMAccountName=sys_*)))"

# Connect to the Active Directory domain
try {
    $domainObject = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
    $domainObject.Filter = $searchFilter
    $domainObject.SearchRoot = [ADSI]"LDAP://$domain"
    $domainObject.PageSize = 1000

    # Perform the search and count the results
    $result = $domainObject.FindAll()
    $userCount = $result.Count

    # Output the total number of users
    Write-Host "Total number of domain users (excluding sa_ and sys_ accounts): $userCount"
}
catch {
    Write-Host "Error: $_.Exception.Message"
}
