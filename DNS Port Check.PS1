$Servers = 
'server1',
'server2'
$Ports   =  "53"
$Destination = "ipaddress"
$Results = @()
$Results = Invoke-Command $Servers {param($Destination,$Ports)
                $Object = New-Object PSCustomObject
                $Object | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $env:COMPUTERNAME
                $Object | Add-Member -MemberType NoteProperty -Name "Destination" -Value $Destination
                    Foreach ($P in $Ports){
                        $PortCheck = (Test-NetConnection -Port $p -ComputerName $Destination ).TcpTestSucceeded
                        If($PortCheck -notmatch "True|False"){$PortCheck = "ERROR"}
                        $Object | Add-Member Noteproperty "$("Port " + "$p")" -Value "$($PortCheck)"
                    }
                $Object
           } -ArgumentList $Destination,$Ports | select * -ExcludeProperty runspaceid, pscomputername
 
$Results | Out-GridView -Title "Testing Ports"
 
$Results | Format-Table -AutoSize

