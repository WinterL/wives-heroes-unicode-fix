# 致曾是勇者的人妻们：Unicode 启动修复

[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

这是 Windows Steam 版《致曾是勇者的人妻们／かつて勇者だった妻達へ》的**非官方实验性补丁**。它修改三个文件，解决吉里吉里 2 的 ANSI → Unicode 启动错误，同时保留原有繁体中文系统区域设置和 UTF-8 代码页。不需要日语系统环境、Locale Emulator 或更换引擎。

**验证状态：**测试组合已通过原先的启动失败点，创建带游戏标题的窗口并生成初始设置。完整菜单显示、实际游玩、音频及存档／读档**尚未验证**。详见 [测试记录](TESTING.md)。

## 游戏及外部项目

- [Steam：App 4358140](https://store.steampowered.com/app/4358140/)
- [DLsite 原作：RJ01464205](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)：仅用于识别原作，**未测试或支持 DLsite 版**。
- [本次使用的 utf8hack 源码与发行版](https://github.com/uyjulian/utf8hack)：上游 README 署名的原作者为 **miahmie**。
- [吉里吉里 2 仓库中的原始 utf8hack 源码](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)

## 支持版本与测试环境

| 项目 | 已测试的值 |
|---|---|
| Steam build | **25049578** |
| 标题画面使用的游戏版本数据 | 本体 **0.26.6.22**；Patch 1 **1.26.6.12**；Patch 2 **2.26.7.23** |
| 吉里吉里 2 引擎文件版本 | **2.32.2.426**，不是游戏版本 |
| Windows | **Windows 11 Pro 25H2，26200.9457，x64** |
| 非 Unicode 程序系统区域／用户区域格式 | **zh-TW／zh-TW** |
| 系统 ANSI／OEM 代码页 | **65001／65001（UTF-8）** |
| 插件 | utf8hack **v1.2.0，intel32.clang** |

版本号来自本地游戏中供标题画面使用的元数据；并未获取标题画面截图。只测试了上述 Steam 数据组合。工具会检查 [supported_versions.json](supported_versions.json) 中的 EXE 和三个数据包 SHA-256 作为参考；不匹配只警告并继续，不需要 `--force`。修补位置仍须存在预期的字体字节。Windows 10、其他系统区域和其他商店版本均未验证。即使 Windows 是 64 位，游戏仍需 **32 位插件**。

## 新手安装步骤

1. 关闭游戏。Windows 10／11 自带 Windows PowerShell 5.1，**不需要安装 Python**。
2. 在本仓库选择 **Code → Download ZIP**。如果 Windows 标记 ZIP 为已阻止，右键 → **属性 → 解除锁定 → 应用**，再**全部解压缩**。不要在 ZIP 内直接运行。
3. 从 [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0) 下载 **`utf8hack.intel32.clang.7z`**，用 [7-Zip](https://www.7-zip.org/) 等兼容工具解压，保留 **`utf8hack.dll`**。本仓库不附带插件二进制文件。
4. Steam 中右键点击游戏 → **管理 → 浏览本地文件**，记下包含 `yuusyatsuma.eXe` 和 `data.xp3` 的文件夹。
5. 双击本仓库的 **`Apply.cmd`**。先选择**游戏文件夹**，再选择解压出来的 **`utf8hack.dll`**，确认安装。对话框为英文。校验大型数据包需要一点时间。
6. 工具会先在游戏目录的 **`.unicode-fix-backup`** 中备份原文件，再应用补丁。版本或插件哈希不符时只警告并继续；不同的现有插件会先备份再替换。请保留备份。
7. Steam → 游戏**属性 → 通用 → 启动选项**，清除此前指向独立测试副本的启动命令；本方案留空即可。照常点击**开始游戏**。

不需要修改 Windows 语言或重启。工具不会自动下载或上传内容，只修改选中的游戏目录。`savedata` 不会被改动；独立测试副本中的进度不会自动迁移。

## 原理与改动

| 文件 | 改动 |
|---|---|
| `yuusyatsuma.eXe` | 在偏移 `0x2C82EA` 将 CP932 字体名称 `ＭＳ Ｐゴシック` 改为 ASCII `MS PGothic`，补零保持原长度，其他 EXE 字节不变。 |
| `yuusyatsuma.cf` | 设置 `readencoding=Shift_JIS`，保留其他设置、编码、BOM 和换行。`\xNN` 是引擎配置语法。 |
| `utf8hack.tpm` | 将选择的上游 DLL 以 `.tpm` 名称放入游戏目录，让引擎在脚本前加载；它在内存中接管文字读取，以 CP932 解码脚本。 |

只加插件能修复脚本读取，但测试仍在原生 Layer 初始化时失败；字体名称修复解决第二处转换错误。游戏数据包、翻译、存档格式和 Windows 代码页都不变。吉里吉里 Z 另有菜单兼容问题，不属于本补丁。

## 还原与故障处理

- 关闭游戏，双击 **`Restore.cmd`** 并选择同一目录。它还原备份文件；只有原先没有插件时才移除新增插件。存档和备份保留。
- 文件在修补后被 Steam 或其他程序改动时，自动还原会拒绝覆盖。先保留备份并确认情况。
- 还原或安装失败后需要重装时，先将已有 `.unicode-fix-backup` 妥善移到游戏目录以外。工具不会覆盖旧备份。
- 版本或插件 SHA-256 不符：仅警告，继续安装，但兼容性未验证。命令行输出警告，GUI 完成后也会显示警告摘要。
- 修补位置的字体字节须符合原始或已修补标记；无法识别仍会停止。备份完整性和还原冲突检查继续严格执行，用于保护文件，不是版本白名单。
- 权限或锁定错误：关闭游戏并检查目录写入权限。安装失败会尝试回滚已完成的写入。
- Steam 更新／验证完整性可能覆盖修补后的 EXE 和配置，但留下新增插件。更新后不要盲目使用旧补丁。
- 此插件是实验性运行时修补；如果被安全软件拦截，请核查来源和警报，不要关闭防护。

启动器使用 Windows PowerShell 和现有执行策略，不修改系统策略，也不使用 Bypass。若组织策略禁止脚本，请按管理员批准的方式处理。

## 命令行与测试

```text
powershell.exe -NoProfile -File .\patch.ps1 -Action check -GameDirectory "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes"
powershell.exe -NoProfile -File .\patch.ps1 -Action apply -GameDirectory "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes" -PluginPath "D:\Downloads\utf8hack.dll"
powershell.exe -NoProfile -File .\patch.ps1 -Action restore -GameDirectory "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes"
powershell.exe -NoProfile -File .\test_patch.ps1
```

请将示例路径替换为自己的路径。`-Action check` 不会修改文件。[TESTING.md](TESTING.md) 说明测试边界及可选的本地集成测试。

## 许可、隐私与删除请求

本仓库原创工具、脚本、测试和文档采用 **[MIT License](LICENSE)**。游戏、引擎和 utf8hack 保持其原有权利及许可；MIT 不适用于它们，也不授予分发修改后游戏 EXE 的许可。见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

仓库文件名均为 ASCII，不含个人安装路径、账户凭证、存档、游戏素材或原始用户日志。备份仅保存在用户电脑上，其清单不含绝对路径。本项目未经发行商或上游作者背书。

如有版权、许可、署名或其他疑虑，**请通过 [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues) 联系维护者申请删除**，注明相关文件／链接及原因。维护者将审查并酌情移除。请勿附上游戏文件或私人数据。私人仓库的 Issues 仅限有访问权限的用户使用。
