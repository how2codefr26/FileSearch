# FileSearch v0.11

A native Mac utility for searching file and folder names in locations you choose. It includes a main window and an optional persistent desktop search window. There is no network functionality.

## Install and choose English

Unzip the application package, move FileSearch.app into Applications, and open it. In the main window click **设置**, then choose **English** next to **界面语言** in Settings. The interface changes immediately and remembers your choice.

The application starts in Simplified Chinese by default, including on an existing installation. Use the same language selector to switch back. File names and paths remain unchanged. Standard macOS dialogs and system-generated errors may follow your system language.

Initially, only the generated sample files are indexed. The examples use everyday topics: weekend notes, reading lists, daily lists, and weekly plans. In **Settings → Add Folder…**, choose the internal disk folders you want to search. Previously removed sample locations will not be added back automatically.

## Search

- Search by one or more words in a file or folder name.
- Type a partial extension: x or xl matches xlsx. Separate extensions with commas or spaces. You can leave the name empty and search by extension alone.
- Click once to select, double-click to open. Right-click for Open, Copy Path, and Show in Finder.
- In Settings, enable persistent desktop search, choose Compact / Standard / Spacious result density, and adjust glass and background transparency.
- Path details apply to the main window only. The desktop window contains the search field and results.
- Close the main window to keep running in the background; choose Quit FileSearch from the menu bar to exit.

## Build the source package

Requires an Apple Silicon Mac, macOS 14 or newer, Python 3 and the Apple Command Line Tools with Swift. Only M1 / macOS 26.6.2 has been tested by the developer; other systems still need validation. No third-party packages are downloaded during the build.

If needed, run `xcode-select --install` and follow Apple's installer. In Terminal, change to the extracted source package directory, then run:

```sh
python3 app/build.py
```

The generated app is `app/dist/FileSearch.app`. Quit any previous instance before installing the new copy. Run `python3 app/test.py --layout` for isolated tests. Check `automatic_fsevents_tested` in the core test report before considering automatic file updates validated.

The build remains ad-hoc signed and is not notarized. Source availability does not bypass device management or macOS security checks. The current build targets Apple Silicon only, shows up to 500 ranked results, and does not yet offer full disk permission onboarding, content search, or file previews.

Your index and settings remain in `~/Library/Application Support/LocalFileSearch/`. No public open-source license has been selected for this source trial package.
