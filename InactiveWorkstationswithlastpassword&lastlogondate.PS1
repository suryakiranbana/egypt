Import-Module activedirectory
[int]$ComputerPasswordAgeDays = 365
$ExportFile = "d:\InactiveWorkstations.csv"
$ComputerStaleDate = (Get-Date).AddDays(-$ComputerPasswordAgeDays)
$InactiveWorkstations = Get-ADComputer -filter { (passwordLastSet -le $ComputerStaleDate) -and (OperatingSystem -notlike "*Server*") -and (OperatingSystem -like "*Windows*") } -properties Name, DistinguishedName, OperatingSystem,OperatingSystemServicePack, passwordLastSet,LastLogonDate,Description
$InactiveWorkstations | export-csv $ExportFile