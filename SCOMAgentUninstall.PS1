$computers = 'server1','server1', 'server1'
foreach($server in $computers)
{
     $server
     $app = Get-WmiObject -Class Win32_Product -computername $server | ? {$_.Name -eq 'Microsoft Monitoring Agent'}
     $var = ($app.Uninstall() ).returnvalue
if($var -eq 0)
    {
   write-host "Successfully Uninstalled Microsoft Monitoring Agent or was not found."
    }
    else
    {
     Write-host "Microsoft Monitoring Agent Uninstallation Failed"
     
    }
   
}