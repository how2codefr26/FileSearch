<p align="center"><img src="docs/assets/app-icon.png" width="128" alt="FileSearch icon"></p>

# FileSearch

**Keep file search close at hand.**

A native macOS filename search utility built with Swift and AppKit. Search indexed file and folder names, narrow results with extension prefixes, and work from either a main window or a persistent desktop search window.

[中文介绍](README.md) · [Usage (Chinese)](docs/USAGE.md) · [Development (Chinese)](docs/DEVELOPMENT.md)

## Status

**v0.10 development prototype.** Apple Silicon only; deployment target macOS 14+. Existing testing was performed on M1 / macOS 26.6.2. This is an ad-hoc signed development build, not notarized or ready for general binary distribution. The interface is currently Chinese.

## Features

- Multiword filename matching: all space-separated terms must occur in the name.
- Live extension prefix filtering: `x` matches `xlsx` and `xml`; `xl` narrows to `xls`, `xlsx`, and `xlsm`. Compound extensions such as `tar.gz` are supported.
- Extension-only searches and multiple extension alternatives separated by commas, semicolons, or whitespace.
- File/folder filters, relevance/name/modification-time sorting, total match count, and optional path details in the main window.
- A minimal desktop window, three result densities, glass or solid backgrounds, and adjustable background transparency.
- Native selection, double-click to open, and contextual open/copy-path/reveal-in-Finder actions.
- Local SQLite storage, memory-mapped search snapshots, and FSEvents reconciliation for selected directories.
- Menu bar access and an implemented `Control–Option–Space` shortcut; hardware triggering and conflicts still need environment-specific validation.

Search counts all matching entries in the selected indexed scopes and displays up to the first **500** sorted results. Search uses filename substrings, NFC normalization and ASCII case normalization, not full-text search, regular expressions, wildcards, or full Unicode case folding.

## Build and run

Requirements: an Apple Silicon Mac, Apple Command Line Tools and Python 3. No third-party build dependencies are downloaded.

```sh
xcode-select --install
git clone https://github.com/how2codefr26/filesearch.git
cd filesearch
python3 app/build.py
open app/dist/FileSearch.app
```

Skip developer-tool installation if already installed. The build creates `app/dist/FileSearch.app`, generates synthetic sample files, and performs ad-hoc signing. Python 3 must be available separately if your tool installation does not provide it.

At first launch, only bundled samples are indexed. Use **设置 → 添加目录…** (Settings → Add directory) to select an internal local-disk directory. Enable **显示常驻桌面搜索窗** for the desktop window. Closing the main window keeps the process running; quit from the menu bar.

Use arrow keys to select, Enter to open, Command–Enter to reveal in Finder, and Escape to hide the main window.

## Privacy

The application has no network functionality, accounts, telemetry, cloud search, or AI services. It indexes names and necessary metadata rather than document contents. Default state lives in `~/Library/Application Support/LocalFileSearch/`; that state can still contain sensitive filenames and paths. External applications used to open files have their own behavior.

This repository excludes generated indexes, personal preferences, local test data, logs, build caches and precompiled applications. See [privacy notes](docs/PRIVACY.md).

## Validate

```sh
python3 app/test.py --layout
```

Tests create isolated fixtures under `app/testdata/`. Inspect `automatic_fsevents_tested` in `app/results/core-tests.json`: if false, automatic filesystem updates were not validated. Invisible AppKit layout tests do not replace visual interaction checks.

Historical v0.7 experiments used one million **synthetic metadata records**, 20 warm searches per case, and an independent SQLite count/top-500 ordering oracle. P95 varied roughly from 51 to 124 ms. These figures exclude initial scans, UI latency and startup, and are not a fresh v0.10 performance acceptance run or a comparison against competing products. See [validation](docs/VALIDATION.md) and [reproduction steps](docs/DEVELOPMENT.md).

## Architecture and limitations

Selected directories → initial enumeration / FSEvents → SQLite transactions → atomically replaced versioned snapshot → background search → native AppKit windows.

Only internal local disks are currently accepted. Symlinks are not followed and package contents are not expanded. Complete whole-disk onboarding, permission recovery, database recovery, large-scan memory control, Intel builds, cross-version testing, full-text search and file previews remain unfinished. The system WidgetKit extension was removed in v0.8; desktop search is provided by a persistent window.

See [architecture](docs/ARCHITECTURE.md), [roadmap](docs/ROADMAP.md), and [changelog](CHANGELOG.md).

## Feedback and licensing

Report reproducible problems through [Issues](https://github.com/how2codefr26/filesearch/issues), using fictional filenames and redacted diagnostics. Do not upload personal indexes or credentials.

**No open-source license has been selected.** A public repository is not a blanket license to copy, modify, redistribute or commercially use its contents. Contact the repository owner to confirm authorization before third-party use or contributions. See [licensing](docs/LICENSING.md) and [contribution notes](CONTRIBUTING.md).
