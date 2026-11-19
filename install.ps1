# 安装：注册登录自启的计划任务并立即启动 / Install: register a logon task and start it now
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'ReplayWatcher.ps1'
if (-not (Test-Path $script)) { throw "ReplayWatcher.ps1 not found next to install.ps1" }

# 去掉“来自网络”标记，避免被执行策略拦截 / Remove the downloaded-from-internet mark
Get-ChildItem $PSScriptRoot -Filter *.ps1 | Unblock-File

$action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$trigger  = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew

# 停掉已在运行的旧实例，让修改后的配置生效 / Stop any running instance so changes take effect
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'ReplayWatcher\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Seconds 1

Register-ScheduledTask -TaskName 'ReplayWatcher' -Action $action -Trigger $trigger -Settings $settings `
    -Description 'Keep NVIDIA Instant Replay on; turn it off while selected apps run.' -Force | Out-Null
Start-ScheduledTask -TaskName 'ReplayWatcher'

Write-Host "ReplayWatcher 已安装并启动 / installed and running."
Write-Host "日志 / Log: $(Join-Path $PSScriptRoot 'ReplayWatcher.log')"
