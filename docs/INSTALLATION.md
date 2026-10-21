# 下载与安装 FileSearch

## 适用设备

当前应用包适用于 Apple Silicon（M 系列）Mac，最低构建目标 macOS 14。已在 M1 / macOS 26.6.2 验证；其他 macOS 版本尚未完成完整兼容测试。Intel Mac 尚不支持。

## 安装已编译的应用

1. 从 [GitHub Release v0.11](https://github.com/how2codefr26/FileSearch/releases/tag/v0.11) 下载 **FileSearch-v0.11-macOS-arm64.zip**。
2. 解压，将 **FileSearch.app** 拖入“应用程序”。升级时先退出旧实例，再替换旧应用。
3. 双击 FileSearch.app。无需安装 Python、Swift、Xcode 或任何第三方依赖。
4. 初次仅收录应用自带的示例文件。进入“设置 → 添加目录…”选择需要搜索的内置磁盘目录，等待收录完成。
5. 在“设置 → 界面语言”切换简体中文或 English；需要桌面搜索时开启“显示常驻桌面搜索窗”。

ZIP 内另附中英文说明。源码包面向希望自行构建或审阅代码的使用者，普通试用请选择上面的 macOS 应用 ZIP。

## 首次启动与系统安全检查

当前应用采用本机临时签名，**尚无 Developer ID 签名和苹果公证**。应用已编译完成，但从互联网下载后，macOS 可能阻止首次打开。因此，“无需编译”不表示所有设备都能无提示运行。

如系统阻止打开，请先确认文件来自本仓库发布页并核对校验值，再依据 macOS 的实际提示和设备管理规定处理；如系统提供“隐私与安全性 → 仍要打开”，由使用者自行决定。受管理设备可能不允许。不要关闭 Gatekeeper、移除系统保护或运行来历不明的放行脚本。

要实现面向所有用户更顺畅的首次安装，后续仍需 Developer ID 签名、公证和另一台设备上的实际下载验收。当前没有完成这一验收。

## 可选：核对下载完整性

从同一发布页下载同名 `.sha256` 文件，在两个文件所在目录运行：

```sh
shasum -a 256 -c FileSearch-v0.11-macOS-arm64.zip.sha256
```

显示 `OK` 表示文件内容与校验清单一致。校验值用于完整性核对，不能替代签名、公证或来源判断。

## 首次试用

名称输入 `notes`，后缀输入 `pdf, tar.gz`，可找到周末笔记、归档笔记和笔记备份等自带样例。也可仅输入后缀 `xl` 查找每周计划表格。添加个人目录后，名称和路径仍是自己的原始内容，不会被翻译或上传。

关闭主窗口后应用继续在菜单栏运行；完全退出请使用菜单栏退出项。更新应用不会自动删除默认数据目录 `~/Library/Application Support/LocalFileSearch/`。

## English quick start

Download the **macOS arm64 application ZIP**, unzip it, drag FileSearch.app into Applications, and open it. No developer tools or compilation are required. The app currently targets Apple Silicon Macs and macOS 14+; only M1 / macOS 26.6.2 has been tested.

Select **English** in **设置 → 界面语言**, then add your internal-disk folders from Settings. The bundled examples cover notes, reading lists and weekly plans.

This beta is ad-hoc signed and **not notarized**. macOS may block first launch after an internet download. Verify the source and follow your system's security prompts and device policy. Do not disable system protections. Cross-device first-launch validation remains incomplete.
