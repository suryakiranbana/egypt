Param(
    [Parameter(Mandatory=$false)]
    [string]$domainName,

    [Parameter(Mandatory=$false)]
    [switch]$ReportFile,

    [Parameter(Mandatory=$false)]
    [switch]$SendEmail
)

# Global Variables
$now = Get-Date
$date = $now.ToShortDateString()
[array]$allDomainControllers = @()
$reportime = Get-Date
$forestInfo = Get-ADForest
$forestname = $($forestInfo.Name)
$reportemailsubject = "$forestname Forest Controllers Health Report"


# Functions

# Function to get all domains in the forest
Function Get-AllDomains {
    Write-Verbose "..running function Get-AllDomains"
    (Get-ADForest).Domains
}

# Function to get all domain controllers in a specified domain
Function Get-AllDomainControllers($domainNameInput) {
    Write-Verbose "..running function Get-AllDomainControllers"
    Get-ADDomainController -Filter * -Server $domainNameInput
}

# Function to test the name against DNS
Function Get-DomainControllerNSLookup($domainNameInput) {
    Write-Verbose "..running function Get-DomainControllerNSLookup"
    try {
        $domainControllerNSLookupResult = Resolve-DnsName $domainNameInput -Type A | select -ExpandProperty IPAddress
        $domainControllerNSLookupResult = 'Success'
    } catch {
        $domainControllerNSLookupResult = 'Fail'
    }
    return $domainControllerNSLookupResult
}

# Function to test the connectivity to the domain controller
Function Get-DomainControllerPingStatus($domainNameInput) {
    Write-Verbose "..running function Get-DomainControllerPingStatus"
    $pingStatus = Test-Connection $domainNameInput -Count 1 -Quiet

    If ($pingStatus -eq $true) {
        $domainControllerPingStatus = "Success"
    } Else {
        $domainControllerPingStatus = 'Fail'
    }

    return $domainControllerPingStatus
}

# Function to test the domain controller uptime
Function Get-DomainControllerUpTime($domainNameInput) {
    Write-Verbose "..running function Get-DomainControllerUpTime"
    If ((Test-Connection $domainNameInput -Count 1 -quiet) -eq $True) {
        try {
            $W32OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $domainNameInput -ErrorAction SilentlyContinue
            $timespan = $W32OS.ConvertToDateTime($W32OS.LocalDateTime) - $W32OS.ConvertToDateTime($W32OS.LastBootUpTime)
            [int]$uptime = "{0:00}" -f $timespan.TotalDays
        } catch {
            $uptime = 'WMI Failure'
        }
    } Else {
        $uptime = '0'
    }
    return $uptime
}

# Function to check the DIT file drive space
Function Get-DITFileDriveSpace($domainNameInput) {
    Write-Verbose "..running function Get-DITFileDriveSpace"
    If ((Test-Connection $domainNameInput -Count 1 -quiet) -eq $True) {
        try {
            $key = "SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
            $valuename = "DSA Database file"
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $domainNameInput)
            $regkey = $reg.opensubkey($key)
            $NTDSPath = $regkey.getvalue($valuename)
            $NTDSPathDrive = $NTDSPath.ToString().Substring(0, 2)
            $NTDSPathFilter = '"' + 'DeviceID=' + "'" + $NTDSPathDrive + "'" + '"'
            $NTDSDiskDrive = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $domainNameInput -ErrorAction SilentlyContinue | ? { $_.DeviceID -eq $NTDSPathDrive }
            $NTDSPercentFree = [math]::Round($NTDSDiskDrive.FreeSpace / $NTDSDiskDrive.Size * 100)
        } catch {
            $NTDSPercentFree = 'WMI Failure'
        }
    } Else {
        $NTDSPercentFree = '0'
    }
    return $NTDSPercentFree
}

# Function to run the three DCDiag tests and save them in a variable for later processing
Function Get-DomainControllerServices($domainNameInput) {
    Write-Verbose "..running function DomainControllerServices"
    $thisDomainControllerServicesTestResult = New-Object PSObject
    $thisDomainControllerServicesTestResult | Add-Member NoteProperty -name DNSService -Value $null
    $thisDomainControllerServicesTestResult | Add-Member NoteProperty -name NTDSService -Value $null
    $thisDomainControllerServicesTestResult | Add-Member NoteProperty -name NETLOGONService -Value $null

    If ((Test-Connection $domainNameInput -Count 1 -quiet) -eq $True) {
        If ((Get-Service -ComputerName $domainNameInput -Name DNS -ErrorAction SilentlyContinue).Status -eq 'Running') {
            $thisDomainControllerServicesTestResult.DNSService = 'Success'
        } Else {
            $thisDomainControllerServicesTestResult.DNSService = 'Fail'
        }
        If ((Get-Service -ComputerName $domainNameInput -Name NTDS -ErrorAction SilentlyContinue).Status -eq 'Running') {
            $thisDomainControllerServicesTestResult.NTDSService = 'Success'
        } Else {
            $thisDomainControllerServicesTestResult.NTDSService = 'Fail'
        }
        If ((Get-Service -ComputerName $domainNameInput -Name netlogon -ErrorAction SilentlyContinue).Status -eq 'Running') {
            $thisDomainControllerServicesTestResult.NETLOGONService = 'Success'
        } Else {
            $thisDomainControllerServicesTestResult.NETLOGONService = 'Fail'
        }
    } Else {
        $thisDomainControllerServicesTestResult.DNSService = 'Fail'
        $thisDomainControllerServicesTestResult.NTDSService = 'Fail'
        $thisDomainControllerServicesTestResult.NETLOGONService = 'Fail'
    }

    return $thisDomainControllerServicesTestResult
}

Function Get-DomainControllerDCDiagTestResults($domainNameInput){
Write-Verbose "..running function Get-DomainControllerDCDiagTestResults"

$DCDiagTestResults = New-Object Object 
If ((Test-Connection $domainNameInput -Count 1 -quiet) -eq $True)
{

$DCDiagTest = (Dcdiag.exe /s:$domainNameInput /test:services /test:KnowsOfRoleHolders /test:Advertising) -split ('[\r\n]')

    $DCDiagTestResults | Add-Member -Type NoteProperty -Name "ServerName" -Value $domainNameInput
        $DCDiagTest | %{ 
        Switch -RegEx ($_) 
        { 
         "Starting"      { $TestName   = ($_ -Replace ".*Starting test: ").Trim() } 
         "passed test|failed test" { If ($_ -Match "passed test") {  
         $TestStatus = "Passed"  
         # $TestName 
         # $_ 
         }  
         Else  
         {  
         $TestStatus = "Failed"  
          # $TestName 
         # $_ 
         } } 
        } 
        If ($TestName -ne $Null -And $TestStatus -ne $Null) 
        { 
         $DCDiagTestResults | Add-Member -Name $("$TestName".Trim()) -Value $TestStatus -Type NoteProperty -force 
         $TestName = $Null; $TestStatus = $Null 
        } 
        } 
return $DCDiagTestResults
}

Else {
$DCDiagTestResults | Add-Member -Type NoteProperty -Name "ServerName" -Value $domainNameInput
$DCDiagTestResults | Add-Member -Name Advertising -Value 'Failed' -Type NoteProperty -force 
$DCDiagTestResults | Add-Member -Name KnowsOfRoleHolders -Value 'Failed' -Type NoteProperty -force 
$DCDiagTestResults | Add-Member -Name Services -Value 'Failed' -Type NoteProperty -force 
}



return $DCDiagTestResults
}
##########
Function Get-DomainControllerDCDiagReplicationsTestResults($domainNameInput) {
    Write-Verbose "..running function Get-DomainControllerDCDiagReplicationsTestResults"
    
    $timeout = 60
    Add-Type -AssemblyName microsoft.visualbasic 
    $cmp = "microsoft.visualbasic.strings" -as [type]
    
    $sysvol = Start-Job -ScriptBlock {param($domainNameInput) dcdiag /test:Replications /s:$domainNameInput} -ArgumentList $domainNameInput
    Wait-Job $sysvol -Timeout $timeout

    $DCDiagReplicationsTestResults = New-Object PSObject

    if ($sysvol.State -eq "Running") {
        Write-Host "$domainNameInput `t Replications Test TimeOut" 
        Stop-Job $sysvol
    } else {
        $sysvol1 = Receive-Job $sysvol
        if ($cmp::instr($sysvol1, "passed test Replications")) {
            Write-Host "$domainNameInput `t Replications Test passed"
            $DCDiagReplicationsTestResults | Add-Member -Type NoteProperty -Name "ReplicationsTest" -Value "Passed"
        } else {
            Write-Host "$domainNameInput `t Replications Test Failed"
            $DCDiagReplicationsTestResults | Add-Member -Type NoteProperty -Name "ReplicationsTest" -Value "Failed"
        }
    }

    return $DCDiagReplicationsTestResults
}
##########

# Function to get a shortened version of the Windows Server OS
Function Get-ShortenedOSVersion($fullOSVersion) {
    switch -Wildcard ($fullOSVersion) {
        '*2016 Datacenter*' { return '2016 DC' }
        '*2016 Standard*'   { return '2016 STD' }
        '*2019 Datacenter*' { return '2019 DC' }
        '*2019 Standard*'   { return '2019 STD' }
        default             { return $fullOSVersion }
    }
}

# Function to check the server OS version.
Function Get-DomainControllerOSVersion ($domainNameInput){
    Write-Verbose "..running function Get-DomainControllerOSVersion"
    $W32OSVersion = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $domainNameInput -ErrorAction SilentlyContinue).Caption
    return (Get-ShortenedOSVersion $W32OSVersion)
}

#This function determines if the machine type is a physical or virtual machine.

Function Get-DomainControllerMachineType ($domainNameInput){
    Write-Verbose "..running function Get-DomainControllerMachineType"
    $thisComputerSystemInfo = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $domainNameInput -ErrorAction SilentlyContinue

    if ($thisComputerSystemInfo.Manufacturer -eq "Xen") {
        $MachineType = "AWS"
    } elseif ($thisComputerSystemInfo.Manufacturer -eq "Microsoft Corporation") {
        $MachineType = "Azure"
    } elseif ($thisComputerSystemInfo.Manufacturer -eq "VMware, Inc." -or $thisComputerSystemInfo.Manufacturer -eq "VMware") {
        $MachineType = "OnPrem VM"
    } else {
        $MachineType = "Unknown"
    }
    return $MachineType
}

#This function checks the free space on the OS drive
Function Get-DomainControllerOSDriveFreeSpace ($domainNameInput){
Write-Verbose "..running function Get-DomainControllerOSDriveFreeSpace"

If ((Test-Connection $domainNameInput -Count 1 -quiet) -eq $True)
{
try{
$thisOSDriveLetter = (Get-WmiObject Win32_OperatingSystem -ComputerName $domainNameInput -ErrorAction SilentlyContinue).SystemDrive
$thisOSPathFilter = '"' + 'DeviceID=' + "'" + $thisOSDriveLetter + "'" + '"'
$thisOSDiskDrive = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $domainNameInput -ErrorAction SilentlyContinue | ?{$_.DeviceID -eq $thisOSDriveLetter}
$thisOSPercentFree =  [math]::Round($thisOSDiskDrive.FreeSpace/$thisOSDiskDrive.Size*100)
}

catch [exception] {
$thisOSPercentFree = 'WMI Failure'
}
}
return $thisOSPercentFree
}

#This function generates HTML code from the results of the above functions.
Function New-ServerHealthHTMLTableCell(){
    param( $lineitem )
    $htmltablecell = $null
    
    switch ($($reportline."$lineitem"))
    {
        $success {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "Success" {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "Passed" {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "Pass" {$htmltablecell = "<td class=""pass"">$($reportline."$lineitem")</td>"}
        "Warn" {$htmltablecell = "<td class=""warn"">$($reportline."$lineitem")</td>"}
        "Access Denied" {$htmltablecell = "<td class=""warn"">$($reportline."$lineitem")</td>"}
        "Fail" {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "Failed" {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "Could not test server uptime." {$htmltablecell = "<td class=""fail"">$($reportline."$lineitem")</td>"}
        "Could not test service health. " {$htmltablecell = "<td class=""warn"">$($reportline."$lineitem")</td>"}
        "Unknown" {$htmltablecell = "<td class=""warn"">$($reportline."$lineitem")</td>"}
        default {$htmltablecell = "<td>$($reportline."$lineitem")</td>"}
    }
    
    return $htmltablecell
}

if (!($domainName)){
Write-Host "..no domain specified, using all domains in forest" -ForegroundColor Yellow
$allDomains = Get-AllDomains
$reportFileName = 'forest_health_report_' + (Get-ADForest).name + '.html'
}

Else{
Write-Host "..domain name specified on cmdline"
$allDomains = $domainName
$reportFileName = 'dc_health_report_' + $domainName + '.html'
}

foreach ($domain in $allDomains){
Write-Host "..testing domain" $domain -ForegroundColor Green
[array]$allDomainControllers = Get-AllDomainControllers $domain
$totalDCtoProcessCounter = $allDomainControllers.Count
$totalDCProcessCount = $allDomainControllers.Count 

foreach ($domainController in $allDomainControllers){
    $stopWatch = [system.diagnostics.stopwatch]::StartNew()
    Write-Host "..testing domain controller" "(${totalDCtoProcessCounter} of ${totalDCProcessCount})" $domainController.HostName -ForegroundColor Cyan 
    $DCDiagTestResults = Get-DomainControllerDCDiagTestResults $domainController.HostName
	$DCDiagReplicationsTestResults = Get-DomainControllerDCDiagReplicationsTestResults $domainController.HostName
    $thisDomainController = New-Object PSObject
    $thisDomainController | Add-Member NoteProperty -name Server -Value $null
    $thisDomainController | Add-Member NoteProperty -name Site -Value $null
    $thisDomainController | Add-Member NoteProperty -name "OS Version" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "Machine Type" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "Operation Master Roles" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "DNS" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "Ping" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "Uptime (hrs)" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "DIT Free Space (%)" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "OS Free Space (%)" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "DNS Service" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "NTDS Service" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "NetLogon Service" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "DCDIAG: Advertising" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "DCDIAG: FSMO" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "DCDIAG: Services" -Value $null
	$thisDomainController | Add-Member NoteProperty -name "DCDIAG: Replications" -Value $null
    $thisDomainController | Add-Member NoteProperty -name "Processing Time" -Value $null
    $OFS = "`r`n"
    $thisDomainController.Server = ($domainController.HostName).ToLower()
    $thisDomainController.Site = $domainController.Site
    $thisDomainController."OS Version" = (Get-DomainControllerOSVersion $domainController.hostname)
    $thisDomainController."Machine Type" = (Get-DomainControllerMachineType $domainController.hostname)

$thisDomainController."Operation Master Roles" = (Get-ADDomainController -Server $domainController.HostName | Select-Object -ExpandProperty OperationMasterRoles)

    $thisDomainController.DNS = Get-DomainControllerNSLookup $domainController.HostName
    $thisDomainController.Ping = Get-DomainControllerPingStatus $domainController.HostName
    $thisDomainController."Uptime (hrs)" = Get-DomainControllerUpTime $domainController.HostName
    $thisDomainController."DIT Free Space (%)" = Get-DITFileDriveSpace $domainController.HostName
    $thisDomainController."OS Free Space (%)" = Get-DomainControllerOSDriveFreeSpace $domainController.HostName
    $thisDomainController."DNS Service" = (Get-DomainControllerServices $domainController.HostName).DNSService
    $thisDomainController."NTDS Service" = (Get-DomainControllerServices $domainController.HostName).NTDSService
    $thisDomainController."NetLogon Service" = (Get-DomainControllerServices $domainController.HostName).NETLOGONService
    $thisDomainController."DCDIAG: Advertising" = $DCDiagTestResults.Advertising
    $thisDomainController."DCDIAG: FSMO" = $DCDiagTestResults.KnowsOfRoleHolders
    $thisDomainController."DCDIAG: Services" = $DCDiagTestResults.Services
    $thisDomainController."DCDIAG: Replications" = $DCDiagReplicationsTestResults.ReplicationsTest
	$thisDomainController."Processing Time" = $stopWatch.Elapsed.Seconds
    [array]$allTestedDomainControllers += $thisDomainController
    $totalDCtoProcessCounter -- 
    }
    
}

# Sort the array based on server status (Fail/Failed first)
$allTestedDomainControllers = $allTestedDomainControllers | Sort-Object {
    if ($_.Ping -eq 'Fail' -or $_.'DCDIAG: Advertising' -eq 'Failed' -or $_.'DCDIAG: FSMO' -eq 'Failed' -or $_.'DCDIAG: Services' -eq 'Failed') {
        0  # Servers with Fail/Failed will be sorted first
    } else {
        1  # Others will be sorted after
    }
} -Descending


    #Common HTML head and styles
    $htmlhead="<html>
                <style>
                BODY{font-family: Arial; font-size: 8pt;}
                H1{font-size: 16px;}
                H2{font-size: 14px;}
                H3{font-size: 12px;}
                TABLE{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
                TH{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
                TD{border: 1px solid black; padding: 5px; }
                td.pass{background: #7FFF00;}
                td.warn{background: #FFE600;}
                td.fail{background: #FF0000; color: #ffffff;}
                td.info{background: #85D4FF;}
                </style>
                <body>
                <h1 align=""left"">Domain Controller Health Check Report</h1>
                <h3 align=""left"">Generated: $reportime</h3>"
                   
    #Domain Controller Health Report Table Header
    $htmltableheader = "<h3>Domain Controller Health Summary</h3>
                        <h3>Forest: $((Get-ADForest).Name)</h3>
                        <p>
                        <table>
                        <tr>
                        <th>Server</th>
                        <th>Site</th>
                        <th>OS Version</th>
                        <th>Machine Type</th>
                        <th>Operation Master Roles</th>
                        <th>DNS</th>
                        <th>Ping</th>
                        <th>Uptime (days)</th>
                        <th>DIT Free Space (%)</th>
                        <th>OS Free Space (%)</th>
                        <th>DNS Service</th>
                        <th>Active Directory Domain Services</th>
                        <th>NetLogon Service</th>
                        <th>DCDIAG: Advertising</th>
                        <th>DCDIAG: FSMO</th>
                        <th>DCDIAG: Services</th>
                        <th>DCDIAG: Replications</th>
			<th>Processing Time</th>
                        </tr>"

    #Domain Controller Health Report Table
    $serverhealthhtmltable = $serverhealthhtmltable + $htmltableheader

# Arrays to store servers that failed and passed
$failedServers = @()
$passedServers = @()

    #This section will process through the $allTestedDomainControllers array object and create and colour the HTML table based on certain conditions.
    foreach ($reportline in $allTestedDomainControllers)
    {
      
      if (Test-Path variable:fsmoRoleHTML)

        {
            Remove-Variable fsmoRoleHTML
        }
    
        if (($reportline."Operation Master Roles") -gt 0)
        {
            foreach ($line in $reportline."Operation Master Roles")
            {
                if ($line.count -gt 0)
    
                {
                [array]$fsmoRoleHTML += $line.ToString() + '<br>'
                }
            }
        }

                else 
                    {
                        $fsmoRoleHTML += 'None<br>'
                    }
    
        $htmltablerow = "<tr>"
        $htmltablerow += "<td>$($reportline.server)</td>"
        $htmltablerow += "<td>$($reportline.site)</td>"
        $htmltablerow += "<td>$($reportline."OS Version")</td>"
        $htmltablerow += "<td>$($reportline."Machine Type")</td>"
        $htmltablerow += "<td>$($fsmoRoleHTML)</td>"
        $htmltablerow += (New-ServerHealthHTMLTableCell "DNS" )                  
        $htmltablerow += (New-ServerHealthHTMLTableCell "Ping")
        
        if ($($reportline."uptime (hrs)") -eq "WMI Failure")
        {
            $htmltablerow += "<td class=""warn"">Could not test server uptime.</td>"        
        }
        elseif ($($reportline."Uptime (hrs)") -eq $string17)
        {
            $htmltablerow += "<td class=""warn"">$string17</td>"
        }
        else
        {
            $hours = [int]$($reportline."Uptime (hrs)")
            if ($hours -le 0)
            {
                $htmltablerow += "<td class=""warn"">$hours</td>"
            }
            else
            {
                $htmltablerow += "<td class=""pass"">$hours</td>"
            }
        }

        $space = $reportline."DIT Free Space (%)"
        
            if ($space -eq "WMI Failure")
            {
            $htmltablerow += "<td class=""warn"">Could not test server free space.</td>"        
            }
            elseif ($space -le 15)
            {
                $htmltablerow += "<td class=""warn"">$space</td>"
            }
            else
            {
                $htmltablerow += "<td class=""pass"">$space</td>"
            }

        $osSpace = $reportline."OS Free Space (%)"
        
            if ($osSpace -eq "WMI Failure")
            {
            $htmltablerow += "<td class=""warn"">Could not test server free space.</td>"        
            }
            elseif ($osSpace -le 15)
            {
                $htmltablerow += "<td class=""warn"">$osSpace</td>"
            }
            else
            {
                $htmltablerow += "<td class=""pass"">$osSpace</td>"
            }

          $htmltablerow += (New-ServerHealthHTMLTableCell "DNS Service")
          $htmltablerow += (New-ServerHealthHTMLTableCell "NTDS Service")
          $htmltablerow += (New-ServerHealthHTMLTableCell "NetLogon Service")
          $htmltablerow += (New-ServerHealthHTMLTableCell "DCDIAG: Advertising")
          $htmltablerow += (New-ServerHealthHTMLTableCell "DCDIAG: FSMO")
          $htmltablerow += (New-ServerHealthHTMLTableCell "DCDIAG: Services")
		  $htmltablerow += (New-ServerHealthHTMLTableCell "DCDIAG: Replications")
          
          $averageProcessingTime = ($allTestedDomainControllers | measure -Property "Processing Time" -Average).Average
          if ($($reportline."Processing Time") -gt $averageProcessingTime)
            {
                $htmltablerow += "<td class=""warn"">$($reportline."Processing Time")</td>"        
            }
        elseif ($($reportline."Processing Time") -le $averageProcessingTime)
        {
            $htmltablerow += "<td class=""pass"">$($reportline."Processing Time")</td>"
        }
            
          [array]$serverhealthhtmltable = $serverhealthhtmltable + $htmltablerow
		  
		  # Determine whether the server failed or passed based on your criteria
    $serverStatus = "Pass"  # Adjust this based on your criteria

    if ($serverStatus -eq "Fail" -or $serverStatus -eq "Failed") {
        $failedServers += $reportline
    } else {
        $passedServers += $reportline
    }
		  
		  
        }      

    $serverhealthhtmltable = $serverhealthhtmltable + "</table></p>"

    $htmltail = "* Forest Domain Controllers HealthCheck Report.<br>
    * DNS test is performed using Resolve-DnsName.
                </body>
                </html>"

    $htmlreport = $htmlhead + $serversummaryhtml + $dagsummaryhtml + $serverhealthhtmltable + $dagreportbody + $htmltail
    
     if ($ReportFile)
    {
        $htmlreport | Out-File $reportFileName -Encoding UTF8
    }


# Export the HTML report to a file named DomainControllerHealth.html
$htmlFilePath = ".\DomainControllerHealth.html"

# Save the HTML report to the specified file
$htmlreport | Out-File -FilePath $htmlFilePath -Encoding UTF8

# Output a message indicating the file path
Write-Host "HTML report saved to: $htmlFilePath" -ForegroundColor Green

# Define Bcc recipient email address
$BccRecipient = 'no-email@abc.com'

# SMTP settings
$smtpsettings = @{
    To         = 'toemail'
    From       = 'fromemail'
    Subject    = "$reportemailsubject - $now"
    SmtpServer = 'ipaddress'
    Body       = $htmlreport
    BodyAsHtml = $true
    Encoding   = [System.Text.Encoding]::UTF8
}

# Attach the HTML report to the email
$smtpsettings.Attachments = $htmlFilePath

# Add Bcc recipient to SMTP settings
$smtpsettings.Bcc = $BccRecipient

try {
    Send-MailMessage @smtpsettings
    Write-Host "Email sent successfully." -ForegroundColor Green

} catch {
    Write-Host "Error sending email: $_" -ForegroundColor Red
}