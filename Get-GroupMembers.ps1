$FilePath = ".\list.txt"
$fileContent = Get-Content -Path $FilePath

$groupMembers = foreach ($group_name in $fileContent) {
    foreach ($domain in (Get-ADForest).domains) {
        try {
            $Group = Get-ADGroup -Filter { Name -eq $group_name } -Server $domain -ErrorAction SilentlyContinue
            if ($null -eq $Group) {
                Write-Host "Group $group_name not found in domain $domain"
                continue
            }

            $members = Get-ADGroupMember -Identity $Group -Server $domain -Recursive

            foreach ($member in $members) {
                $member | Select-Object @{Name="Domain";Expression={$domain}}, @{Name="Group";Expression={$Group.Name}}, Name
            }

        } catch {
            Write-Host "Error retrieving group $group_name in domain $domain : $_"
        }
    }
}

$groupMembers | Sort-Object Domain, Group, Name | Export-CSV -Path ".\GroupMembers.csv" -NoTypeInformation
