# netEasycloudOpener

解决 Windows 上双击/右键 `.ncm` 文件时网易云音乐只打开软件不播放的问题。

## 问题

网易云音乐是单实例应用。双击 `.ncm` 文件时，Windows 通过命令行参数传递文件路径——新进程检测到已有实例后通过 IPC 转发，但这条 IPC 链路存在 bug，结果只激活窗口不加载文件。

拖拽文件到窗口却能正常播放，因为走的是 `WM_DROPFILES` 消息，完全不同的代码路径。

```
双击 .ncm → cloudmusic.exe "%1" → IPC 转发 → ❌ 失败
拖拽 .ncm → WM_DROPFILES 消息      → ✅ 正常
```

## 方案

劫持文件关联入口，用 `DropHelper.exe` 向网易云音乐窗口发送 `WM_DROPFILES` 消息，模拟拖拽。

```
双击 .ncm → registry 拦截 → ncm-launcher.ps1 → DropHelper.exe → WM_DROPFILES → ✅
```

## 文件

| 文件 | 说明 |
|------|------|
| `ncm-launcher.ps1` | PowerShell 启动器，调度 DropHelper |
| `DropHelper.exe` | 微型工具，向目标窗口发送 WM_DROPFILES |
| `DropHelper.cs` | DropHelper 的 C# 源码 |
| `register-handler.bat` | 一键安装注册 |
| `uninstall.bat` | 一键卸载恢复 |

## 安装

1. 确保 `ncm-launcher.ps1` 与 `DropHelper.exe` 在同一目录
2. **管理员身份**运行 `register-handler.bat`
3. 选择 `[1] Install Fix`
4. 完成，双击任意 `.ncm` 即可播放

## 卸载

管理员运行 `uninstall.bat`，恢复原始文件关联。

## 移植

1. 复制 `ncm-launcher.ps1`、`DropHelper.exe`、`register-handler.bat` 到目标电脑同一目录
2. 若网易云音乐装在非标准路径，编辑 `ncm-launcher.ps1` 中 `$searchPaths` 数组加入
3. 管理员运行 `register-handler.bat`
4. 完成

## 如何工作

### 注册表

修改三处：

```
HKCU\Software\Classes\.ncm → NCMLauncher.ncm

HKCU\Software\Classes\NCMLauncher.ncm\Shell\Open\Command
  → powershell.exe ... ncm-launcher.ps1 "%1"

HKCU\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command
  → powershell.exe ... ncm-launcher.ps1 "%1"
```

第三处是关键——`UserChoice`（Windows 记住的"默认打开方式"）指向 `Applications\cloudmusic.exe`，且有哈希保护无法修改。我们不改 UserChoice 本身，而是替换它指向的 ProgID 的命令。

### 启动器流程

```
1. 接收文件路径
2. 自动查找 cloudmusic.exe（常见路径 + 运行中进程）
3. 若未运行 → 启动并等待窗口就绪（最多 20s）
4. 调用 DropHelper.exe 发送 WM_DROPFILES
5. 最多重试 3 次
```

### DropHelper.exe

```
1. 找到 cloudmusic 主窗口句柄
2. 在全局内存构造 DROPFILES 结构（含文件路径）
3. PostMessage(WM_DROPFILES) → 完全等效于拖拽
```

## 依赖

- Windows 10 / 11
- PowerShell（系统自带）
- .NET Framework 4.x（系统自带）
- 网易云音乐客户端

## License

MIT
