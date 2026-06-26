# netEasycloudOpener

解决 Windows 上双击/右键 `.ncm` 文件时网易云音乐只打开软件不播放的问题。

## 快速使用

1. 下载 `install.bat`
2. 双击运行（会**自动检测**网易云音乐的安装位置）
3. 完成，双击任意 `.ncm` 文件即可播放

如需卸载，运行 `uninstall.bat`。

## 原理

网易云音乐是单实例应用。双击 `.ncm` 文件时通过命令行传参 → IPC 转发有 bug → 只开窗口不播放。
拖拽文件到窗口走 `WM_DROPFILES` 消息 → 正常。本工具模拟拖拽。

```
双击 .ncm → install.bat 劫持文件关联 → DropHelper.exe 发送 WM_DROPFILES → 播放
```

## 文件

| 文件 | 类型 | 说明 |
|------|------|------|
| `install.bat` | 发布 | 一键安装器（自包含，无需额外文件） |
| `uninstall.bat` | 发布 | 一键卸载器 |
| `DropHelper.cs` | 源码 | DropHelper.exe 的 C# 源码 |

安装后生成（由 install.bat 自动创建）：

| 文件 | 说明 |
|------|------|
| `DropHelper.exe` | WM_DROPFILES 发送工具 |
| `ncm-launcher.ps1` | PowerShell 调度脚本 |
| `auto-repair.ps1` | 开机自修复 |
| `startup-repair.bat` | 开机启动入口 |

## 安装细节

`install.bat` 自动执行以下步骤：

1. **检测网易云音乐位置** — 从现有文件关联提取（右键"打开方式"中选择的路径）→ 搜索常见安装路径 → 从运行中进程探测 → 让用户手动选择
2. **生成运行文件** — 将嵌入的 DropHelper.exe (base64) 和脚本写入安装目录
3. **注册文件关联** — 劫持 `Applications\cloudmusic.exe` 的 Shell\Open\Command
4. **设置自修复** — 放入 Windows 启动文件夹，检测云音乐更新覆盖后自动修复
5. **验证** — 检查所有文件和注册表项

## 卸载

运行 `uninstall.bat`：
- 恢复原始文件关联
- 移除自修复启动项
- 清理注册表

## 自修复机制

网易云音乐启动时可能重新注册 `Applications\cloudmusic.exe` 的命令行，覆盖我们的劫持。

`auto-repair.ps1` 在每次 Windows 开机时静默运行，检测劫持是否被覆盖并自动修复。对性能无影响（仅一次注册表读取）。

## 依赖

- Windows 10 / 11
- PowerShell（系统自带）
- .NET Framework 4.x（系统自带）
- 网易云音乐客户端

## License

MIT
