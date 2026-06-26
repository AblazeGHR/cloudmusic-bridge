# cloudmusic-bridge

解决 Windows 上双击/右键 `.ncm` 文件时网易云音乐只打开软件不播放的问题。

## 目录

- [快速开始](#快速开始)
- [问题背景](#问题背景)
- [安装](#安装)
- [卸载](#卸载)
- [自修复机制](#自修复机制)
- [移植到其他电脑](#移植到其他电脑)
- [注意事项与警告](#注意事项与警告)
- [故障排除](#故障排除)
- [技术原理](#技术原理)
- [文件说明](#文件说明)

## 快速开始

1. 下载 `install.bat`
2. 双击运行
3. 完成后双击任意 `.ncm` 文件即可播放

> install.bat 会自动检测网易云音乐的安装位置，无需手动配置。

## 问题背景

网易云音乐是**单实例应用**——同一时间只允许一个主窗口运行。

```
双击 .ncm 文件
  → Windows 执行: cloudmusic.exe "文件路径.ncm"
    → 如果网易云未运行 → 自己处理参数 → ✅ 正常播放
    → 如果网易云已在运行 → IPC 转发给已有窗口 → ❌ BUG：只激活窗口不播放
```

而**拖拽文件到窗口**走的是完全不同的机制——Windows 发送 `WM_DROPFILES` 消息给窗口，这条路径没有 bug，所以拖进去就能播。

本工具做的事情：

```
双击 .ncm 文件
  → 劫持文件关联，拦截到我们的启动器
  → 确保网易云已启动并窗口就绪
  → 用 DropHelper.exe 向窗口发送 WM_DROPFILES 消息（模拟拖拽）
  → ✅ 正常播放
```

## 安装

### 前提条件

| 要求 | 说明 |
|------|------|
| Windows 10 或 11 | 其他版本未测试 |
| 网易云音乐 | 需已安装，任意版本 |
| 管理员权限 | **不需要**。install.bat 只修改当前用户的注册表和启动项 |
| 杀毒软件 | 可能需要将 DropHelper.exe 加入白名单或关闭杀毒软件（见[注意事项](#注意事项与警告)） |

### 安装步骤

1. 将 `install.bat` 放到你希望安装的目录（推荐 `D:\Tools\cloudmusic-bridge\`）
2. **双击运行** `install.bat`
3. 安装器将自动执行以下操作，全程无需干预：
   - 自动检测网易云音乐安装路径
   - 生成 `DropHelper.exe`、`ncm-launcher.ps1` 等运行文件
   - 注册 `.ncm` 文件关联
   - 设置开机自修复
   - 验证安装完整性
4. 看到 "Installation Complete!" 即完成

### 安装器做了什么

```
[1/5] 检测网易云音乐位置
      ① 从现有文件关联提取（右键"打开方式"已选择的路径）
      ② 搜索常见安装路径
      ③ 从运行中进程探测
      ④ 弹出文件选择器手动指定（前三步都失败时）
      
[2/5] 生成运行文件
      DropHelper.exe     — 从 install.bat 内嵌的 base64 解码写入
      ncm-launcher.ps1   — 含检测到的网易云路径
      auto-repair.ps1    — 自修复脚本
      startup-repair.bat — 开机启动入口

[3/5] 注册文件关联
      修改以下注册表项（均在 HKCU，只影响当前用户）：
        HKCU\Software\Classes\.ncm
        HKCU\Software\Classes\NCMLauncher.ncm
        HKCU\Software\Classes\Applications\cloudmusic.exe

[4/5] 设置开机自修复
      复制 startup-repair.bat 到启动文件夹

[5/5] 验证
      检查所有文件是否存在、注册表是否正确
```

### 重新安装

如果系统重装、更换目录或修复故障，直接重新运行 `install.bat` 即可。它是**幂等**的——重复运行不会产生副作用。

## 卸载

1. 运行 `uninstall.bat`
2. 自动恢复以下内容：
   - 还原 `Applications\cloudmusic.exe` 的原始命令
   - 删除 `NCMLauncher.ncm` 注册项
   - 恢复 `.ncm` 默认关联
   - 移除开机自修复条目
3. 删除安装目录即可完全清理

## 自修复机制

### 为什么需要

网易云音乐在启动时/更新后可能会重新注册 `Applications\cloudmusic.exe\Shell\Open\Command`，覆盖我们的劫持，导致功能失效。

### 如何工作

- 每次 Windows **开机登录**时，Startup 文件夹中的 `startup-repair.bat` 会自动运行
- 它调用 `auto-repair.ps1`，检查注册表劫持是否还在
- 如果被覆盖，自动修复（几乎瞬间完成，不影响系统性能）
- 修复日志记录在 `%TEMP%\ncm-launcher-repair.log`

### 手动触发修复

如果需要在开机之外修复（比如网易云刚更新完），重新运行 `install.bat` 即可。

## 移植到其他电脑

1. 复制 `install.bat` 和 `uninstall.bat` 到目标电脑
2. 如果目标电脑的网易云音乐装在**非标准路径**（非 `Program Files` 或 `LocalAppData` 下的 `NetEase\CloudMusic`），安装器会自动通过文件关联和进程信息检测到
3. 运行 `install.bat`

> 无需复制其他文件——install.bat 包含了 DropHelper.exe（base64）和所有脚本，会自动生成。

## 注意事项与警告

### 杀毒软件误报

**`DropHelper.exe` 可能被杀毒软件（特别是 360、腾讯电脑管家）误报为木马。**

**原因**：DropHelper.exe 使用了以下 Windows API：
- `GlobalAlloc` / `GlobalLock` — 分配全局内存
- `PostMessage(WM_DROPFILES)` — 跨进程发送窗口消息
- `FindWindow` / `GetWindowThreadProcessId` — 查找其他进程窗口

这些 API 的**组合使用**恰好与某些恶意软件的行为特征重叠（消息注入攻击），会触发启发式扫描的误判。

**解决方案**：
1. 将 `DropHelper.exe` 或整个安装目录加入杀毒软件白名单
2. 或者将 `DropHelper.cs` 自行编译后替换

源码见仓库，可自行审查——没有网络通信、没有文件读写（除日志）、没有自启动，仅向网易云音乐窗口发送一条合法的文件拖拽消息。

### 网易云音乐更新

网易云音乐大版本更新可能改变：
- 安装路径 → 重新运行 `install.bat` 即可重新检测
- 窗口类名 → 需更新 `DropHelper.cs` 并重新编译

### 文件关联冲突

如果系统中安装了多个音乐播放器并都关联了 `.ncm`：
- Windows 的 `UserChoice`（"默认打开方式"）会记住上次的选择
- 本工具通过劫持 `Applications\cloudmusic.exe` 的命令行来实现，与 UserChoice 不冲突
- 如果选择了其他播放器作为默认，本工具不再生效

### 同时打开多个文件

每次双击 `.ncm` 文件都会正常播放，已运行的网易云音乐会切换到新歌曲（播放列表的行为取决于网易云自身设置）。

## 故障排除

| 现象 | 可能原因 | 解决方法 |
|------|---------|---------|
| 双击没反应 | 杀毒软件拦截了 DropHelper.exe | 将安装目录加入杀毒白名单 |
| 打开了网易云但不播放 | 劫持被覆盖（更新后） | 重启电脑（触发自修复）或重运行 install.bat |
| 安装器找不到网易云 | 网易云装在非标准路径 | 在安装器弹出的文件选择器中手动选择 cloudmusic.exe |
| 安装后过几天失效 | 自修复未正常运行 | 检查 `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\NCM-Hijack-Repair.bat` 是否存在 |
| PowerShell 报错 | 执行策略限制 | 安装器已使用 `-ExecutionPolicy Bypass`，应不受影响 |

### 调试

安装目录下的 `ncm-launcher.ps1` 每次运行都会写日志到 `%TEMP%\ncm-launcher.log`：

```
2026-06-26 17:37:17.287 | === START ===
2026-06-26 17:37:17.287 | Raw arg: D:\...\song.ncm
2026-06-26 17:37:17.287 | Resolved path: D:\...\song.ncm
2026-06-26 17:37:17.288 | cloudmusic.exe: D:\software\CloudMusic\cloudmusic.exe
2026-06-26 17:37:17.288 | Window found after 0ms: PID=4992 HWND=5180982
2026-06-26 17:37:17.288 | DropHelper output: ...WM_DROPFILES sent successfully...
2026-06-26 17:37:17.288 | === SUCCESS ===
```

如果看到 `=== SUCCESS ===` 但网易云仍不播放，可能是网易云版本不兼容，请提 issue。

## 技术原理

### 调用链

```
双击 .ncm
  → Windows Shell 查 UserChoice → Applications\cloudmusic.exe
    → Shell\Open\Command = powershell ... ncm-launcher.ps1 "%1"  [我们劫持的]
      → ncm-launcher.ps1:
          1. 检查网易云是否运行（未运行则启动并等窗口出现）
          2. 等窗口就绪（热启动 200ms / 冷启动 1.5s）
          3. 调用 DropHelper.exe 发送 WM_DROPFILES
        → DropHelper.exe:
          1. FindWindow 找到网易云主窗口
          2. GlobalAlloc 构造 DROPFILES 结构
          3. PostMessage(WM_DROPFILES) → 完全等效于拖拽
```

### 为什么不能直接改 UserChoice

Windows 10/11 的 `UserChoice` 注册表项包含 `Hash` 字段，是对 ProgID + 用户 SID 的校验和，防止程序静默劫持默认打开方式。无法在不触发 Windows 安全警告的情况下修改它。

因此采用**间接劫持**——不改 UserChoice 指向的 ProgID，而是修改该 ProgID 背后的命令行。

### 为什么杀软会误报

`DropHelper.exe` 同时使用了以下"敏感"API：
- 跨进程内存分配 (`GlobalAlloc`)
- 跨进程窗口消息 (`PostMessage`)
- 进程窗口枚举 (`FindWindow`)

这些是模拟拖拽所必需的合法操作，但恰好与部分恶意软件的行为指纹匹配。

## 文件说明

### 仓库文件（版本控制）

| 文件 | 说明 |
|------|------|
| `install.bat` | 自包含安装器。内嵌 DropHelper.exe（base64）和所有脚本 |
| `uninstall.bat` | 自包含卸载器 |
| `DropHelper.cs` | DropHelper.exe 的 C# 源码（可自行编译审查） |
| `README.md` | 本文档 |
| `.gitignore` | Git 忽略规则 |

### 安装后生成（不纳入版本控制）

| 文件 | 大小 | 说明 |
|------|------|------|
| `DropHelper.exe` | ~7.5 KB | 向网易云窗口发送 WM_DROPFILES 消息 |
| `ncm-launcher.ps1` | ~2 KB | PowerShell 调度脚本 |
| `auto-repair.ps1` | ~0.7 KB | 开机自修复（检查并修复被覆盖的劫持） |
| `startup-repair.bat` | ~0.1 KB | 开机启动入口（调用 auto-repair.ps1） |

### 运行时日志

| 文件 | 位置 | 说明 |
|------|------|------|
| `ncm-launcher.log` | `%TEMP%` | 每次打开文件的执行日志 |
| `ncm-launcher-repair.log` | `%TEMP%` | 自修复执行日志 |

### 注册表修改

| 路径 | 键 | 值 |
|------|------|------|
| `HKCU\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command` | (default) | `powershell.exe ... ncm-launcher.ps1 "%1"` |
| `HKCU\Software\Classes\NCMLauncher.ncm\Shell\Open\Command` | (default) | `powershell.exe ... ncm-launcher.ps1 "%1"` |
| `HKCU\Software\Classes\.ncm` | (default) | `NCMLauncher.ncm` |

均为 HKCU（当前用户），不影响系统其他用户。

## License

MIT
