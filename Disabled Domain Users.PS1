# Define the domain and search filter
$domain = "domainname"
$searchFilter = "(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2)(!(sAMAccountName=sa_*))(!(sAMAccountName=sys_*)))"

# Connect to the Active Directory domain
try {
    $domainObject = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
    $domainObject.Filter = $searchFilter
    $domainObject.SearchRoot = [ADSI]"LDAP://$domain"
    $domainObject.PageSize = 1000

    # Perform the search and count the results
    $result = $domainObject.FindAll()
    $disabledUserCount = $result.Count

    # Output the total number of disabled users
    Write-Host "Total number of disabled users (excluding sa_ and sys_ accounts): $disabledUserCount"
}
catch {
    Write-Host "Error: $_.Exception.Message"
}
