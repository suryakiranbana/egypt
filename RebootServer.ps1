Get-Content -Path C:\temp\servers.txt |Where-Object {Test-Connection -ComputerName $_ -Quiet -Count 1} |
ForEach-Object {
Write-host "Restarting Server $_ " -ForegroundColor Yellow
Restart-Computer -ComputerName $_ -Force
Start-Sleep -s 0
}