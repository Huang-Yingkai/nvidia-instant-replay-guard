# ReplayWatcher - 让 NVIDIA 即时回放一直保持开启，夸克运行时自动关闭
#
# 行为：
#   - 平时：即时回放被关掉（手动、NVIDIA 自己、重启后等）就自动重新打开
#   - 夸克(quark.exe) 运行期间：保持关闭；夸克全部退出后自动重新打开
#
# 原理（新版 NVIDIA App 已移除本地 HTTP 接口，keep-instant-replay-on 等工具失效）：
#   - 状态：注册表 NVSPCAPS\{1B1D3DAA-...}，1=开 0=关
#   - 开关：模拟 NVIDIA App 中“切换即时回放”的快捷键，从注册表 IRToggleHKey* 读取，
#           你在 NVIDIA 里改了快捷键也能自动跟上
#
# 配置：
$PauseProcesses   = @('quark')   # 这些程序运行时关闭即时回放（进程名，不带 .exe）
$CheckSeconds     = 3            # 检查间隔
$BackoffSeconds   = 60           # 切换失败后（例如 NVIDIA 因受保护内容拒绝开启）等待多久再试

$ErrorActionPreference = 'SilentlyContinue'

# 单实例
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\ReplayWatcher_Mutex', [ref]$created)
if (-not $created) { exit }

Add-Type @"
using System; using System.Runtime.InteropServices;
public static class RWKeys { [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra); }
"@

$RegPath = 'HKCU:\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS'
$RegName = '{1B1D3DAA-601D-49E5-8508-81736CA28C6D}'
$LogFile = Join-Path $PSScriptRoot 'ReplayWatcher.log'

function Write-Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

function Get-RegInt($name) {
    $v = (Get-ItemProperty -Path $RegPath -Name $name).$name
    if ($null -eq $v) { return $null }
    if ($v -is [byte[]]) { return [BitConverter]::ToInt32($v, 0) }
    return [int]$v
}

function Get-ReplayOn {
    $v = Get-RegInt $RegName
    if ($null -eq $v) { return $null }
    return ($v -eq 1)
}

# 读取“切换即时回放”快捷键（虚拟键码列表），读不到就用默认 Alt+Shift+F10
function Get-ToggleKeys {
    $count = Get-RegInt 'IRToggleHKeyCount'
    $keys = @()
    if ($count -gt 0) { for ($i = 0; $i -lt $count; $i++) { $k = Get-RegInt "IRToggleHKey$i"; if ($k) { $keys += [byte]$k } } }
    if ($keys.Count -eq 0) { $keys = @([byte]0x12, [byte]0x10, [byte]0x79) }
    return ,$keys
}

function Send-ToggleHotkey {
    $keys = Get-ToggleKeys
    foreach ($k in $keys) { [RWKeys]::keybd_event($k, 0, 0, [UIntPtr]::Zero) }
    Start-Sleep -Milliseconds 80
    [array]::Reverse($keys)
    foreach ($k in $keys) { [RWKeys]::keybd_event($k, 0, 2, [UIntPtr]::Zero) }
}

function Set-Replay([bool]$on) {
    if ((Get-ReplayOn) -eq $on) { return $true }
    Send-ToggleHotkey
    for ($i = 0; $i -lt 16; $i++) {
        Start-Sleep -Milliseconds 500
        if ((Get-ReplayOn) -eq $on) { return $true }
    }
    return $false
}

function Get-PausingProcess {
    foreach ($n in $PauseProcesses) { if (Get-Process -Name $n) { return $n } }
    return $null
}

Write-Log "ReplayWatcher 已启动（保持开启；暂停于: $($PauseProcesses -join ', ')）"
$lastReason = ''
$retryAt = [datetime]::MinValue
$chromeRetryPaused = $false

while ($true) {
    if ($chromeRetryPaused -and -not (Get-Process -Name 'chrome')) {
        $chromeRetryPaused = $false
        Write-Log 'Chrome 已完全退出，恢复开启即时回放'
    }

    $overlay = Get-Process -Name 'NVIDIA Overlay'
    $state = Get-ReplayOn

    if ($overlay -and $null -ne $state -and (Get-Date) -ge $retryAt) {
        $pauser = Get-PausingProcess
        $want = -not $pauser
        $reason = if ($pauser) { "$pauser 运行中" } else { '无暂停程序' }

        if ($reason -ne $lastReason) {
            Write-Log "状态变化：$reason，目标=$(if ($want) {'开'} else {'关'})"
            $lastReason = $reason
        }

        if ($state -ne $want -and -not ($want -and $chromeRetryPaused)) {
            if (Set-Replay $want) {
                Write-Log "已$(if ($want) {'开启'} else {'关闭'})即时回放"
            } elseif ($want -and (Get-Process -Name 'chrome')) {
                $chromeRetryPaused = $true
                Write-Log '开启即时回放失败，暂停重试，直到 Chrome 完全退出'
            } else {
                Write-Log "$(if ($want) {'开启'} else {'关闭'})失败，$BackoffSeconds 秒后重试"
                $retryAt = (Get-Date).AddSeconds($BackoffSeconds)
            }
        }
    }

    Start-Sleep -Seconds $CheckSeconds
}
