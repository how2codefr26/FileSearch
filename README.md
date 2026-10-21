<p align="center">
  <img src="docs/assets/app-icon.png" width="128" alt="FileSearch 应用图标">
</p>

# FileSearch

**让文件搜索，随手可用。**

FileSearch 是一款原生 macOS 文件名搜索工具。输入记得的名称片段，配合后缀即时筛选，在主搜索窗口或常驻桌面搜索窗中找到已收录的文件与文件夹。

使用 Swift / AppKit 构建，以 SQLite 保存本地索引、以 FSEvents 跟踪目录变化；搜索不依赖 Spotlight 的索引内容，无账号、云端查询或 AI 服务，应用没有联网功能。

**当前版本：v0.11 测试版，支持简体中文与 English。** 支持 Apple Silicon，最低构建目标为 macOS 14；现有验证来自 M1 / macOS 26.6.2。尚未完成正式分发签名、公证及跨系统兼容性验收。

[English](README.en.md) · [使用指南](docs/USAGE.md) · [开发与验证](docs/DEVELOPMENT.md) · [实现架构](docs/ARCHITECTURE.md) · [验证记录](docs/VALIDATION.md) · [路线图](docs/ROADMAP.md)

## 为什么做 FileSearch

当你只记得文件的一部分名称时，FileSearch 帮你快速缩小范围。按名称与后缀查找笔记、照片、阅读清单或文件夹，从搜索直接完成打开和定位。

它专注于**名称和后缀直达 + 桌面反复查找**的组合体验。当前没有全文搜索、文件内容预览、复杂搜索语法或批量文件管理。

## 已实现的功能

| 功能 | 当前行为 |
| --- | --- |
| 中英文界面 | 简体中文／English 即时切换，保留查询、窗口位置和设置 |
| 多词名称检索 | 空格分开的名称词同时匹配；支持中文、Unicode NFC 规范化和 ASCII 大小写归一化 |
| 后缀随输随筛 | `x` 匹配 `xlsx`、`xls`、`xml` 等，`xl` 缩小到 `xlsx`、`xls`、`xlsm`；支持复合后缀与多个后缀 |
| 只按格式搜索 | 名称留空也可输入 `pdf`、`xl` 等后缀；多个后缀用逗号、分号或空格分隔，取并集 |
| 主搜索窗口 | 文件／文件夹筛选、相关度／名称／修改时间排序、命中总数、可选路径详情 |
| 常驻桌面搜索窗 | 仅搜索输入和结果列表；位置与显示偏好保存在本机 |
| 原生操作 | 单击选中、双击打开；右键打开、复制路径、在 Finder 中显示；支持键盘选择 |
| 外观设置 | 紧凑／标准／宽松三档结果密度；桌面窗玻璃、0–70% 背景透明度或实色模式 |
| 目录管理 | 主动添加内置磁盘目录、移除范围、暂停／恢复收录及手动重新核对 |
| 本地持久化 | SQLite 索引、版本化内存映射搜索快照、FSEvents 变化核对与历史事件补录 |
| 菜单栏入口 | 文件夹与搜索镜组合图标，支持系统明暗主题；全局快捷键为 `⌃⌥Space` |

查询针对完整已收录集合，界面最多展示排序后的前 **500** 项。结果数较多时应增加名称词或后缀条件。

## 下载应用，无需编译

**[下载 FileSearch v0.11 · Apple Silicon](https://github.com/how2codefr26/FileSearch/raw/refs/tags/v0.11/downloads/FileSearch-v0.11-macOS-arm64.zip)** · [SHA-256 校验文件](https://github.com/how2codefr26/FileSearch/raw/refs/tags/v0.11/downloads/FileSearch-v0.11-macOS-arm64.zip.sha256) · [版本说明与全部文件](https://github.com/how2codefr26/FileSearch/releases/tag/v0.11)

1. 下载并解压 ZIP，把 **FileSearch.app** 拖入“应用程序”。
2. 双击启动；初次先搜索随附的日常示例，再在“设置 → 添加目录…”选择自己的目录。
3. 在“设置 → 界面语言”中选择简体中文或 English，即时生效并保存。

应用包已包含可执行程序、图标、示例和中英文说明；使用者不需要 Python、Swift 或 Xcode。当前只提供 M 系列 Mac 版本，最低目标 macOS 14；Intel 尚不支持。

**首次打开须知：** 当前测试包采用临时签名，尚未经过苹果公证。下载后 macOS 可能阻止首次打开，因此不能保证所有设备都能无提示双击运行。请先核对来源，按系统安全提示和设备管理要求处理；不要关闭系统安全保护。详情见[安装说明](docs/INSTALLATION.md)。

## 从源码构建

### 环境要求

- Apple Silicon（M 系列）Mac；macOS 14 或以上为构建目标。
- Apple Command Line Tools（含 Swift 编译器、macOS SDK 和系统工具）。
- 可用的 Python 3；源码仅使用 Python 标准库。用 `python3 --version` 检查，缺失时先安装。
- 不要求完整 Xcode；构建无需下载第三方依赖。首次安装开发工具需要联网。

### 从源码构建

```sh
xcode-select --install
git clone https://github.com/how2codefr26/FileSearch.git
cd FileSearch
python3 app/build.py
open app/dist/FileSearch.app
```

如果开发工具已安装，跳过安装步骤。成功后应用位于 `app/dist/FileSearch.app`，可在退出旧实例后拖入“应用程序”文件夹。

这是本机临时签名的开发构建，**未经过苹果公证**。源码可见不代表应用已达到正式发布标准；受管理设备的策略仍可能限制运行。

### 第一次搜索

1. 启动后先试搜随附示例：名称输入 `notes`，后缀输入 `pdf, tar.gz`。
2. 在“设置 → 添加目录…”中选择需要搜索的**内置本地磁盘目录**。
3. 等待收录完成，再输入自己的文件名。默认不会自动收录个人目录或整块磁盘。
4. 需要桌面随手查找时，在设置开启“显示常驻桌面搜索窗”。

| 名称 | 后缀 | 含义 |
| --- | --- | --- |
| `Weekend notes` | `pdf` | 名称同时包含两个词，且后缀链以 `pdf` 开头 |
| `Weekly plan` | `xl` | 查找名称包含“Weekly plan”的 Excel 类后缀文件 |
| 留空 | `pdf, xl` | 在已收录范围查找匹配任一后缀的文件 |
| `Notes` | `tar.g` | 匹配如 `Notes backup.tar.gz` 的复合后缀 |

后缀输入采用前缀语义：`pdf` 也可能匹配 `pdfx`；不表示严格等于某一扩展名。名称中的 `AND`、`*`、`?` 按字面字符处理，尚无布尔或通配符语法。

快捷操作：`↑↓` 选择，`Enter` 打开，`⌘Enter` 在 Finder 定位，`Esc` 收起主窗口。关闭主窗口后后台继续运行；完全退出请使用菜单栏“退出文件搜索”。快捷键冲突与实际硬件触发仍需在自己的环境验证。

## 数据与隐私

索引与设置默认存放于：

```text
~/Library/Application Support/LocalFileSearch/
```

应用枚举所选目录中的名称和必要元数据，不读取文件正文进行全文索引；没有网络请求、遥测或云端同步代码。名称、路径和元数据本身也可能敏感，应按个人文件管理本机索引。打开文件时会交给系统默认应用，该应用的行为不由 FileSearch 控制。

本仓库仅包含源码、构建与测试脚本、图标、合成数据生成器和说明。构建缓存、索引数据库、个人设置、测试目录与开发机日志不进入版本库；编译好的应用放在 downloads 下载目录，并在 Releases 提供直达链接。详见[隐私与安全说明](docs/PRIVACY.md)。

## 架构概览

```text
用户选择的目录
   ↓ 首次枚举 / FSEvents 变化通知
IndexService：合并待核对目录、暂停恢复、历史事件处理
   ↓ 事务更新
SQLite：目录、文件身份、元数据与事件检查点
   ↓ 生成并原子替换
版本化二进制快照（内存映射）
   ↓ 后台检索、全量计数、排序与旧查询取消
AppKit：主窗口 / 桌面搜索窗 / 菜单栏
```

更多模块职责和边界见[实现架构](docs/ARCHITECTURE.md)。

## 测试与性能

```sh
python3 app/test.py
python3 app/test.py --layout
```

测试只创建仓库内的隔离样例。必须检查 `app/results/core-tests.json` 中的 `automatic_fsevents_tested`：为 `false` 时，不能将自动同步算作已通过。布局检查不等同人工视觉验收。

本版使用日常主题的百万条**合成元数据**重新验证查询，并通过独立 SQLite oracle 核对命中总数与前 500 项排序。该实验不包含首次扫描、UI 延迟或完整启动，也不代表与其他产品的性能比较。实际结果和边界见[验证记录](docs/VALIDATION.md)。

## 项目结构

```text
app/
  Sources/                  Swift / AppKit 程序与索引实现
  Tests/                    核心、布局、合成查询基准
  Assets/                   图标母版与设计说明
  build.py / build_icons.py 本机编译、图标生成与临时签名
  test.py                   隔离功能和布局验证
  benchmark.py              百万条合成查询及 SQLite 独立校验
  package.py                开发应用包与可选启动验证
  package_source.py         源码包白名单导出
technical-validation/src/   确定性合成元数据生成器
docs/                       使用、开发、架构、隐私、验证与路线图
CHANGELOG.md                版本演进
CONTRIBUTING.md             问题反馈与贡献说明
```

## 当前边界与后续方向

- 当前只接受内置本地磁盘目录；外置磁盘、网络卷、云盘占位文件及多卷行为尚未完整验证。
- 不跟随符号链接、不展开软件包内部；不同路径的硬链接保留。索引目录固定排除。
- 尚无完整全盘引导、权限恢复、逐范围覆盖报告、SQLite 损坏恢复和大目录扫描峰值控制。
- 尚未完成 Intel 构建、macOS 14/15 实机兼容矩阵、多屏／空间／输入法／VoiceOver 等全面验收。
- 系统小组件已于 v0.8 移除，当前桌面体验由常驻窗口提供。
- Developer ID 签名、公证、跨机器安装、完整启动与唤出性能仍待完善。

后续优先级见[路线图](docs/ROADMAP.md)，并以实际验收结果更新，暂无承诺发布日期。

## 反馈、贡献与许可

欢迎通过 [Issues](https://github.com/how2codefr26/FileSearch/issues) 提交复现步骤、系统版本和已脱敏的错误信息。请勿上传个人索引、真实文件路径、证书或密钥。

应用包可下载到本机试用。**源码目前尚未选定开源许可证。** 公开仓库用于展示、审阅和交流，不表示授予任意复制、修改、分发或商用的许可证。第三方使用与贡献前请先与仓库所有者确认授权。详见[许可说明](docs/LICENSING.md)及[贡献说明](CONTRIBUTING.md)。
