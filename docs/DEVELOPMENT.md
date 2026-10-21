# 开发、构建与打包

全部命令在仓库根目录运行。需要 Apple Silicon Mac、macOS 14+ 构建环境、Command Line Tools 和 Python 3。首次安装开发工具见 README；项目无第三方构建依赖。

## 构建

```sh
python3 app/build.py
```

构建脚本使用 `xcrun swiftc -O`，目标 `arm64-apple-macosx14.0`，生成图标、合成示例和 `app/dist/FileSearch.app`，执行临时签名及严格签名验证。不是 Xcode 项目、SwiftPM 包或 Universal 构建。

图标母版为 `app/Assets/AppIcon.png`，`build_icons.py` 使用系统 `sips` 和 `iconutil` 生成多尺寸 ICNS。生成资源、缓存与应用包被 `.gitignore` 排除。

## 功能与布局验证

```sh
python3 app/test.py
python3 app/test.py --layout
```

核心测试创建 `app/testdata/<UUID>/` 隔离目录。报告为 `app/results/core-tests.json`；查看检查结果与 `automatic_fsevents_tested`。宿主阻止 FSEvents 时相关自动更新场景会跳过，不能宣称全套通过。

`--layout` 追加不显示窗口的 AppKit 约束、外观、事件和设置持久化检查，报告文件沿用 `app/results/layout-tests-v08.json` 名称。打开、定位和复制动作使用记录器，不产生真实外部文件操作；`visual_screenshot_verified=false` 表示未做实际视觉验收。

隔离手动启动，避免写入默认个人状态目录：

```sh
app/dist/FileSearch.app/Contents/MacOS/FileSearch --state "$PWD/app/testdata/manual-state"
```

直接运行二进制前退出已有测试实例，避免多实例混淆。正常使用应从应用包启动。

## 开发包

先构建，再执行：

```sh
python3 app/package.py
python3 app/package.py --launch
```

第二条会打包、解压至新目录、使用独立状态启动并检查示例查询与正常退出。输出位于 `app/release/`，包括 ZIP、SHA-256 校验和及 verification 测试目录。不要对外发送 verification 目录。

ZIP 为本机临时签名的开发包，未公证；本仓库首轮上传不附预编译应用，也未创建 GitHub Release。正式分发需要另外完成签名、公证、跨机器安装和兼容性验收。

源码包导出：

```sh
python3 app/package_source.py
```

该脚本保留原 v0.10 白名单，仅导出应用核心、图标、构建测试脚本及源码试用说明；**不会包含本仓库全部文档、性能生成器或完整 Git 历史**。需要完整项目请克隆仓库。源码包根目录的 `SHA256SUMS` 只用于检查包内文件，不能验证作者身份。

## 合成查询基准

先运行一次构建或测试以建立输出目录，再生成百万条合成元数据：

```sh
python3 technical-validation/src/generate.py technical-validation/data/run-20261020 --counts 1000000
python3 app/benchmark.py
```

路径中的日期是原脚本约定目录名，不代表这次运行日期。生成器拒绝覆盖已有数据；重新复现实验请使用新目录并相应修改 `app/benchmark.py` 的 `source` 路径。它只生成元数据，不扫描个人目录，也不创建百万个真实文件。

输出为 `app/results/query-benchmark-v07.json` 和 `query-oracle-v07.json`；文件名与基准内部版本沿用 v0.7，当前源码复跑需同时记录实际提交 SHA。独立 SQLite oracle 核对总数和前 500 项排序。基准只覆盖进程内热查询，不覆盖 UI、冷启动、首次文件枚举或多机表现。
