ipconfig /flushdns
remove-item *.html
$ServerListFile = ".\ServerList.txt"  
$ServerList = Get-Content $ServerListFile -ErrorAction SilentlyContinue 
$Result = @() 
ForEach($computername in $ServerList) 
{
write-Host -ForegroundColor Green "=========$computername==============="
$AVGProc = Get-WmiObject -computername $computername win32_processor | Measure-Object -property LoadPercentage -Average | Select Average
$OS = gwmi -Class win32_operatingsystem -computername $computername |Select-Object @{Name = "MemoryUsage"; Expression = {“{0:N2}” -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize) }}
$vol = Get-WmiObject -Class win32_Volume -ComputerName $computername -Filter "DriveLetter = 'C:'" |Select-object @{Name = "C PercentFree"; Expression = {“{0:N2}” -f  (($_.FreeSpace / $_.Capacity)*100) } }
$lboot = gwmi -Class win32_operatingsystem -computername $computername | %{ $_.ConvertToDateTime($_.LastBootUpTime) }
  
$result += [PSCustomObject] @{ 
        ServerName = "$computername"
        CPULoad = "$($AVGProc.Average)%"
        MemLoad = "$($OS.MemoryUsage)%"
        CDrive = "$($vol.'C PercentFree')%"
    LastBoot = "$lboot"
    }
 
    $Outputreport = "<HTML><TITLE> APAC TEAM Center Server Health Check & Utilization Report </TITLE>
                     <BODY background-color=deepskyblue>
                     <font color =""#99000"" face=""Microsoft Tai le"">
                     <H2> APAC Server Health Check & Utilization Report </H2></font>
                     <Table border=1 cellpadding=0 cellspacing=0>
                     <TR bgcolor=deepskyblue align=center>
                       <TD><B>Server Name</B></TD>
                       <TD><B>Avrg.CPU Utilization</B></TD>
                       <TD><B>Memory Utilization</B></TD>
                       <TD><B>C Drive Utilization</B></TD>
                       <TD><B>Last Boot Time</B></TD></TR>"
                        
    Foreach($Entry in $Result) 
    
        { 
          if(($Entry.CpuLoad) -or ($Entry.memload) -ge "80") 
          { 
            $Outputreport += "<TR bgcolor=#FFCC99>" 
          } 
          else
           {
            $Outputreport += "<TR>" 
          }
     $Outputreport += "<TD>$($Entry.Servername)</TD><TD align=center>$($Entry.CPULoad)</TD><TD align=center>$($Entry.MemLoad)</TD><TD align=center>$($Entry.Cdrive)</TD><TD align=center>$($Entry.LastBoot)</TD></TR>"
        }
     $Outputreport += "</Table></BODY></HTML>" 
        } 
 
$Outputreport | out-file .\cpumemeorydiskutilization.html
##$Invoke-Expression .\cpumemeorydiskutilization.html
##Send email functionality from below line, use it if you want   
$smtpServer = "1.1.1.1"
$smtpFrom = a@b.com"
$smtpTo = "a@b.com"
$messageSubject = "Team Center Servers Health report"
$message = New-Object System.Net.Mail.MailMessage $smtpfrom, $smtpto
$message.Subject = $messageSubject
$message.IsBodyHTML = $true
$message.Body = "<head><pre>$style</pre></head>"
$message.Body += Get-Content .\cpumemeorydiskutilization.html
$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($message)