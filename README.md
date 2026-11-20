# NVIDIA Instant Replay Guard

[中文](#中文) | [English](#english)

让 NVIDIA 即时回放（Instant Replay）一直保持开启，在指定程序运行时自动关闭。
Keep NVIDIA Instant Replay always on, and turn it off automatically while selected apps are running.

---

## 中文

### 解决什么问题

NVIDIA 即时回放经常会"自己关掉"：重启后、遇到受保护内容后、多显示器切换后……等你打完一局精彩的游戏想保存时，才发现回放根本没开。

但有些程序又**不适合**开着回放（比如会触发 NVIDIA 受保护内容检测、或者你不想被录进去的应用）。

ReplayWatcher 在后台做两件事：

- **平时**：即时回放被关掉就在几秒内自动重新打开
- **指定程序运行时**（默认是夸克浏览器 `quark.exe`）：保持关闭；程序退出后自动恢复开启

### 为什么不用现有工具

| 工具 | 问题 |
|---|---|
| [keep-instant-replay-on](https://github.com/piotrpdev/keep-instant-replay-on) | 依赖 NVIDIA 本地 HTTP 接口，**新版 NVIDIA App 已移除该接口**，无法使用 |
| [AlwaysShadow](https://github.com/Verpous/AlwaysShadow) | 白名单程序运行时只是"停止干预"，**不会主动关闭**回放 |

ReplayWatcher 是一个纯 PowerShell 脚本，无需编译、无需安装任何依赖，代码不到 120 行，一眼就能看懂它在做什么。

### 工作原理

- **读取状态**：注册表 `HKCU\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS` 下的 `{1B1D3DAA-601D-49E5-8508-81736CA28C6D}`（`1` = 开，`0` = 关）
- **切换开关**：模拟 NVIDIA App 中"切换即时回放"的快捷键。快捷键从同一注册表的 `IRToggleHKey*` 中读取，你在 NVIDIA 里改了快捷键也会自动跟上
- **防止死循环**：切换失败（例如 NVIDIA 因受保护内容拒绝开启）时等待 60 秒再重试，不会疯狂按键
- 只在 NVIDIA 覆盖层运行时才会操作

### 系统要求

- Windows 10 / 11（自带 Windows PowerShell 5.1 即可）
- 已安装 **NVIDIA App**，并在设置中**开启游戏内覆盖**
- 已在 NVIDIA App 中设置好即时回放（时长、保存位置等）

### 安装

1. 下载本仓库（右上角 **Code → Download ZIP**），解压到一个**固定位置**，例如 `C:\Users\你的用户名\ReplayWatcher`
   > 不要放在"下载"等临时文件夹，计划任务会一直引用这个路径
2. 在该文件夹中打开 PowerShell，运行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

安装后会立即在后台启动（通过 `conhost --headless`，完全没有窗口），以后每次登录 Windows 都会自动运行。计划任务还会每 5 分钟检查一次，脚本意外退出会被自动重新拉起。

### 配置

用记事本打开 `ReplayWatcher.ps1`，修改开头的配置：

```powershell
$PauseProcesses = @('quark')   # 这些程序运行时关闭即时回放（进程名，不带 .exe）
$CheckSeconds   = 3            # 检查间隔（秒）
$BackoffSeconds = 60           # 切换失败后等待多久再试（秒）
```

例如再加上 PotPlayer：`@('quark', 'PotPlayerMini64')`。进程名可以在任务管理器 →"详细信息"中查看。

修改后重新运行一次 `install.ps1` 即可生效。

### 日志

运行记录写在同目录的 `ReplayWatcher.log`：

```
2026-11-20 07:16:03  ReplayWatcher 已启动（保持开启；暂停于: quark）
2026-11-20 07:16:04  已开启即时回放
2026-11-20 07:16:13  状态变化：quark 运行中，目标=关
2026-11-20 07:16:14  已关闭即时回放
2026-11-20 07:16:26  状态变化：无暂停程序，目标=开
2026-11-20 07:16:26  已开启即时回放
```

### 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

然后删除文件夹即可。

### 常见问题

**切换回放时输入法被切换了？**
NVIDIA 默认快捷键是 `Alt+Shift+F10`，而 `Alt+Shift` 也是 Windows 切换输入法的快捷键。建议在 NVIDIA 覆盖层（`Alt+Z`）→ 设置 → 键盘快捷方式中，把"切换即时回放"改成 `Ctrl+Shift+F10`。脚本会自动读取新快捷键，无需修改。

**回放一直开不起来，日志反复显示"开启失败"？**
通常是有程序正在播放受保护内容（如 Netflix、部分音乐软件），NVIDIA 会拒绝开启回放。可以把该程序加到 `$PauseProcesses`，或在 NVIDIA App 中关闭"桌面捕获"。

**会被游戏反作弊检测吗？**
脚本只读取注册表并模拟一次快捷键，不注入任何进程、不读写游戏内存。

---

## English

### What it does

NVIDIA Instant Replay tends to turn itself off — after a reboot, after protected content plays, after display changes — and you only notice when you try to save that clutch round.

At the same time, there are apps you **don't** want it running with (apps that trigger NVIDIA's protected-content detection, or that you simply don't want captured).

ReplayWatcher runs in the background and:

- **Normally**: turns Instant Replay back on within seconds whenever it gets turned off
- **While selected apps run** (default: Quark browser, `quark.exe`): keeps it off, then turns it back on once they exit

### Why not an existing tool

| Tool | Limitation |
|---|---|
| [keep-instant-replay-on](https://github.com/piotrpdev/keep-instant-replay-on) | Relies on NVIDIA's local HTTP API, which **the new NVIDIA App removed** |
| [AlwaysShadow](https://github.com/Verpous/AlwaysShadow) | Whitelisted apps only make it *stop enforcing*; it **does not turn Instant Replay off** |

ReplayWatcher is a single PowerShell script — no build step, no dependencies, under 120 lines you can read in a minute.

### How it works

- **Reads state** from `HKCU\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS\{1B1D3DAA-601D-49E5-8508-81736CA28C6D}` (`1` = on, `0` = off)
- **Toggles** by simulating NVIDIA App's "Toggle Instant Replay" hotkey, read from the `IRToggleHKey*` values in the same key — so a custom hotkey just works
- **Backs off** for 60 s if a toggle doesn't take effect (e.g. NVIDIA refuses because of protected content), instead of hammering the hotkey
- Only acts while the NVIDIA Overlay is running

### Requirements

- Windows 10 / 11 (built-in Windows PowerShell 5.1)
- **NVIDIA App** installed with the **in-game overlay enabled**
- Instant Replay configured in NVIDIA App (length, save location, etc.)

### Install

1. Download this repo (**Code → Download ZIP**) and extract it to a **permanent location**, e.g. `C:\Users\<you>\ReplayWatcher`
   > Not your Downloads folder — the scheduled task points at this path
2. Open PowerShell in that folder and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

It starts immediately via `conhost --headless` (no window at all) and runs on every Windows logon. A 5-minute watchdog trigger relaunches it if it ever exits.

### Configure

Edit the top of `ReplayWatcher.ps1`:

```powershell
$PauseProcesses = @('quark')   # Instant Replay is off while any of these run (process name, no .exe)
$CheckSeconds   = 3            # Poll interval (seconds)
$BackoffSeconds = 60           # Wait after a failed toggle (seconds)
```

For example, add PotPlayer: `@('quark', 'PotPlayerMini64')`. Find process names in Task Manager → Details.

Re-run `install.ps1` to apply changes.

### Log

Activity is written to `ReplayWatcher.log` next to the script (messages are in Chinese).

### Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Then delete the folder.

### FAQ

**My keyboard layout / IME switches when it toggles.**
The default hotkey is `Alt+Shift+F10`, and `Alt+Shift` is also Windows' input-language switch. Change "Toggle Instant Replay" to e.g. `Ctrl+Shift+F10` in the NVIDIA Overlay (`Alt+Z`) → Settings → Keyboard shortcuts. The script picks up the new hotkey automatically.

**It keeps logging "failed to enable".**
Something is likely playing protected content (Netflix, some music apps) and NVIDIA refuses to enable Instant Replay. Add that app to `$PauseProcesses`, or turn off Desktop capture in NVIDIA App.

**Is it safe with anti-cheat?**
It only reads the registry and sends a hotkey. It does not inject into or read/write any game process.

---

## Credits

Approach informed by [AlwaysShadow](https://github.com/Verpous/AlwaysShadow) (registry state + hotkey method for the new NVIDIA App).

## License

[MIT](LICENSE)
