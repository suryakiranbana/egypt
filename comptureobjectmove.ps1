$TargetOU = "DC=test,DC=com"
$ADComputers = Get-Content .\computers.txt
foreach ($computerName in $ADComputers) {
try {
if (($currentComputer = Get-ADComputer -Identity $computerName -ErrorAction Stop)) {
Move-ADObject -Identity $currentComputer -TargetPath $TargetOU -ErrorAction Stop
Add-Content c:\temp\move.log -Value "OKAY: Moved $($computerName) to $TargetOU" 
}
}
catch {
Add-Content c:\temp\move.log -Value "FAIL: $($_.Exception.Message)" 
}
}