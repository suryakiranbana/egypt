#Import Module Best Practices for Powershell v2. In v3 the module gets automatically loaded.

Remove-Item –path C:\Users\basusuad\dcdiagscript\* -include *.csv,*.log,*.htm –recurse

Import-Module BestPractices
$DateStamp = (Get-Date).ToString("dd-MMMM-yy HH:mm:ss")
$FileDateStamp = Get-Date -Format yyyyMMdd
#Set Variables
#$date1 = get-date -UFormat "%Y%m%d%H%M%S"
#$date2 = get-date -UFormat "%d%m%y"
$date = (Get-Date).ToString("HHmm-ddMMyyyy")
$dcdiagcom = "dcdiag"
$dcdiaglog = "C:\Users\basusuad\dcdiagscript\dcdiag$date.log"
$dcdiagargs = @('/a', '/c', '/v', "/f:$dcdiaglog ")
$repadmincom = "repadmin"
$repadminargs = @('/showrepl', '*', '/verbose', '/all', '/intersite')
$repadminlog =   "C:\Users\basusuad\dcdiagscript\repl$date.log"
$ADbparesultcsv = "C:\Users\basusuad\dcdiagscript\ADBpaResult$date.csv"

# Get the replication info.
$myRepInfo = @(repadmin /replsum * /bysrc /bydest /sort:delta)
 
# Initialize our array.
$cleanRepInfo = @()
   # Start @ #10 because all the previous lines are junk formatting
   # and strip off the last 4 lines because they are not needed.
    for ($i=10; $i -lt ($myRepInfo.Count-4); $i++) {
            if($myRepInfo[$i] -ne ""){
            # Remove empty lines from our array.
            $myRepInfo[$i] -replace '\s+', " "           
            $cleanRepInfo += $myRepInfo[$i]            
            }
            }           
$finalRepInfo = @()  
            foreach ($line in $cleanRepInfo) {
            $splitRepInfo = $line -split '\s+',8
            if ($splitRepInfo[0] -eq "Source") { $repType = "Source" }
            if ($splitRepInfo[0] -eq "Destination") { $repType = "Destination" }
           
            if ($splitRepInfo[1] -notmatch "DSA") {      
            # Create an Object and populate it with our values.
           $objRepValues = New-Object System.Object
               $objRepValues | Add-Member -type NoteProperty -name DSAType -value $repType # Source or Destination DSA
               $objRepValues | Add-Member -type NoteProperty -name Hostname  -value $splitRepInfo[1] # Hostname
               $objRepValues | Add-Member -type NoteProperty -name Delta  -value $splitRepInfo[2] # Largest Delta
               $objRepValues | Add-Member -type NoteProperty -name Fails -value $splitRepInfo[3] # Failures
               #$objRepValues | Add-Member -type NoteProperty -name Slash  -value $splitRepInfo[4] # Slash char
               $objRepValues | Add-Member -type NoteProperty -name Total -value $splitRepInfo[5] # Totals
               $objRepValues | Add-Member -type NoteProperty -name PctError  -value $splitRepInfo[6] # % errors  
               $objRepValues | Add-Member -type NoteProperty -name ErrorMsg  -value $splitRepInfo[7] # Error code
          
            # Add the Object as a row to our array   
            $finalRepInfo += $objRepValues
           
            }
            }
$html = $finalRepInfo|ConvertTo-Html -Fragment       
           
$xml = [xml]$html

$attr = $xml.CreateAttribute("id")
$attr.Value='diskTbl'
$xml.table.Attributes.Append($attr)


$rows=$xml.table.selectNodes('//tr')
for($i=1;$i -lt $rows.count; $i++){
    $value=$rows.Item($i).LastChild.'#text'
    if($value -ne $null){
       $attr=$xml.CreateAttribute('style')
       $attr.Value='background-color: red;'
       [void]$rows.Item($i).Attributes.Append($attr)
    }
   
    else {
       $value
       $attr=$xml.CreateAttribute('style')
       $attr.Value='background-color: green;'
       [void]$rows.Item($i).Attributes.Append($attr)
    }
}

#embed a CSS stylesheet in the html header
$html=$xml.OuterXml|Out-String
$style='<style type=text/css>#diskTbl { background-color: white; } 
td, th { border:1px solid black; border-collapse:collapse; }
th { color:white; background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px } table { margin-left:50px; }</style>'

ConvertTo-Html -head $style -body $html -Title "DC Replication Report"|Out-File C:\Users\basusuad\dcdiagscript\ADReplicationReport.htm

 
#Run the cmd commands calling the args.
&cmd /c $dcdiagcom $dcdiagargs
&cmd /c $repadmincom $repadminargs > $repadminlog
 
#Run the Best Practice Analayser
#invoke-bpamodel -ModelId Microsoft/Windows/DirectoryServices
#Format the results
#get-bparesult -ModelID Microsoft/Windows/DirectoryServices | Where { $_.Severity -ne "Information" } | Export-CSV -Path $ADbparesultcsv
######Email Report #########

#Set email variables
$EmailFrom = "dcdiag-daily-mon@moodys.com"
$EmailTo = "Suvajit.Basu@nttdata.com"
$Subject = "Daily MOODYS.NET Forest Replication & DCDIAG Health Check Report Dated $DateStamp EST"
$Body = "<head><pre>$style</pre></head>"
$body+= Get-Content "C:\Users\basusuad\dcdiagscript\ADReplicationReport.htm"
$SMTPServer = "mailrelay.nslb.ad.moodys.net"

#Email the log files.
Send-MailMessage -Subject $Subject -Body $body -BodyAsHtml -SmtpServer $SMTPServer -Priority High -To $EmailTo -From $EmailFrom -Attachments $repadminlog
