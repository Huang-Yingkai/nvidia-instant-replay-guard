# 安装：注册登录自启的计划任务并立即启动 / Install: register a logon task and start it now
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'ReplayWatcher.ps1'
if (-not (Test-Path $script)) { throw "ReplayWatcher.ps1 not found next to install.ps1" }

# 去掉“来自网络”标记，避免被执行策略拦截 / Remove the downloaded-from-internet mark
Get-ChildItem $PSScriptRoot -Filter *.ps1 | Unblock-File

# 用 conhost --headless 启动：完全不创建窗口。
# 否则在 Win11 上默认终端是 Windows Terminal，-WindowStyle Hidden 藏不住窗口，
# 用户关掉那个终端窗口/标签页时脚本会被一起结束。
# Launch via headless conhost so no window is ever created. On Windows 11 the default
# terminal (Windows Terminal) ignores -WindowStyle Hidden, and closing it kills the script.
$action   = New-ScheduledTaskAction -Execute 'conhost.exe' `
            -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`""
# 登录时启动；另外每 5 分钟检查一次，脚本意外退出就重新拉起（已在运行则跳过）
# Start at logon, plus every 5 minutes as a watchdog (skipped while already running)
$trigger  = @(
    (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME),
    (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5))
)
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
