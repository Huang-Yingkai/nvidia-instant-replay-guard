# 卸载：停止并删除计划任务 / Uninstall: stop and remove the scheduled task
Stop-ScheduledTask -TaskName 'ReplayWatcher' -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'ReplayWatcher' -Confirm:$false -ErrorAction SilentlyContinue

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'ReplayWatcher\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Write-Host "ReplayWatcher 已卸载 / uninstalled. 可以删除此文件夹 / You can delete this folder now."
