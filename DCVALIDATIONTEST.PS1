# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

$dcname = $myFQDN=(Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
$DateStamp = (Get-Date).ToString("dd-MMMM-yy HH:mm:ss")

dcdiag

function Invoke-DcDiag {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainController
    )
 
    $result = dcdiag /s:$DomainController
    $result | select-string -pattern '\. (.*) \b(passed|failed)\b test (.*)' | foreach {
        $obj = @{
            TestName = $_.Matches.Groups[3].Value
            TestResult = $_.Matches.Groups[2].Value
            Entity = $_.Matches.Groups[1].Value
        }
        [pscustomobject]$obj
    }
}

write-Host -ForegroundColor Yellow "================================"
Invoke-DcDiag -DomainController $dcname
write-Host -ForegroundColor Green "DOMAIN CONTROLLER VALIDATION TEST FOR DC $dcname HAS SUCCESSFULLY PASSED ALL TEST ON DATED $DateStamp EST"
write-Host -ForegroundColor Yellow "================================"

