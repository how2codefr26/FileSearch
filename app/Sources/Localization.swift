import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    var title: String { self == .english ? "English" : "简体中文" }
}

enum L10n {
    private static let lock = NSLock()
    private static var current: AppLanguage = .simplifiedChinese
    static var language: AppLanguage {
        get { lock.lock(); defer { lock.unlock() }; return current }
        set { lock.lock(); current = newValue; lock.unlock() }
    }
    static let english: [String: String] = [
        "文件搜索": "FileSearch",
        "桌面搜索": "Desktop Search",
        "文件搜索设置": "FileSearch Settings",
        "文件名或文件夹名": "File or folder name",
        "设置": "Settings",
        "全部": "All",
        "文件": "Files",
        "文件夹": "Folders",
        "软件包": "Package",
        "链接": "Link",
        "条目类型": "Item type",
        "后缀：x、xl、pdf…": "Extension: x, xl, pdf…",
        "输入部分后缀即可检索，例如 x、xl 匹配 xlsx；多个后缀用逗号或空格分隔，留空不限。": "Type part of an extension: x or xl matches xlsx. Separate multiple extensions with commas or spaces; leave empty for all.",
        "自定义文件格式后缀": "Custom file extensions",
        "按相关度": "Relevance",
        "按名称": "Name",
        "按修改时间": "Modified",
        "排序": "Sort order",
        "搜索结果": "Search results",
        "完整路径": "Full path",
        "正在查找…": "Searching…",
        "格式后缀无效": "Invalid extension filter",
        "输入名称或后缀开始搜索": "Enter a name or extension to search",
        "目录收录完成后即可搜索": "Search will be available when indexing finishes",
        "没有匹配的条目": "No matching items",
        "当前已收录范围内未找到": "No matches in the indexed locations",
        "选择结果查看详情": "Select a result for details",
        "目标已变化或不可访问，正在重新核对。": "The item changed or is unavailable. Checking again.",
        "无法打开该条目，请检查访问权限。": "Unable to open this item. Check access permissions.",
        "打开": "Open",
        "复制路径": "Copy Path",
        "在 Finder 中显示": "Show in Finder",
        "已复制完整路径": "Full path copied",
        "主窗口显示路径详情": "Show path details in the main window",
        "显示常驻桌面搜索窗": "Show persistent desktop search",
        "紧凑型": "Compact",
        "标准型": "Standard",
        "宽松型": "Spacious",
        "毛玻璃背景": "Glass background",
        "搜索与展示": "Search & Appearance",
        "结果密度": "Result density",
        "结果展示密度": "Result density",
        "背景透明度": "Background transparency",
        "桌面搜索背景透明度": "Desktop search background transparency",
        "透明度只影响背景，文字保持清晰。关闭毛玻璃后使用实色窗口。": "Transparency affects only the background. Text stays clear. Turn glass off for a solid background.",
        "搜索目录": "Search locations",
        "添加目录…": "Add Folder…",
        "重新核对": "Refresh Index",
        "暂停收录": "Pause Indexing",
        "继续收录": "Resume Indexing",
        "登录时启动": "Launch at login",
        "快捷键 ⌃⌥Space 唤出搜索。索引和设置保留在本机。": "Press ⌃⌥Space to search. Your index and settings stay on this Mac.",
        "示例文件：": "Sample files: ",
        "移除": "Remove",
        "无法创建本地数据目录": "Unable to create the local data folder",
        "正在载入本地索引…": "Loading local index…",
        "设置…": "Settings…",
        "退出文件搜索": "Quit FileSearch",
        "编辑": "Edit",
        "剪切": "Cut",
        "复制": "Copy",
        "粘贴": "Paste",
        "全选": "Select All",
        "文件搜索 · FileSearch": "FileSearch · File Search",
        "打开搜索  ⌃⌥Space": "Open Search  ⌃⌥Space",
        "快捷键暂不可用，请从菜单栏打开。": "Shortcut unavailable. Open search from the menu bar.",
        "加入搜索范围": "Add to Search",
        "仅索引你选择目录中的名称和必要元数据。": "Only names and required metadata in the selected folders will be indexed.",
        "界面语言": "Interface language",
        "范围已核对": "Index up to date",
        "部分位置不可访问": "Some locations are unavailable",
        "正在核对退出期间的变化…": "Checking changes made while the app was closed…",
        "文件通知不可用；可手动重新核对目录。": "File notifications are unavailable. Refresh locations manually.",
        "请添加搜索目录。": "Add a search folder.",
        "已暂停，结果可能过期": "Indexing paused; results may be outdated",
        "正在更新文件位置…": "Updating file locations…",
        "正在收录所选目录…": "Indexing selected folders…",
        "该目录已包含在现有范围中。": "This folder is already covered by an existing location.",
        "此开发版仅支持本机内置磁盘目录。外置与网络磁盘暂未验收。": "This build supports internal local disks only. External and network disks have not been validated.",
        "索引数据目录不能作为搜索范围。": "The index data folder cannot be added as a search location.",
        "无法完成操作": "Unable to complete the operation",
        "请输入有效后缀，例如 pdf、xlsx、tar.gz；多个后缀用逗号或空格分隔。": "Enter a valid extension such as pdf, xlsx or tar.gz. Separate multiple extensions with commas or spaces.",
        "索引缓存头不完整，需要重建。": "The index cache header is incomplete. Rebuild the index.",
        "索引缓存版本不匹配，需要重建。": "The index cache version does not match. Rebuild the index.",
        "索引缓存长度不一致，需要重建。": "The index cache length is invalid. Rebuild the index.",
        "父目录缓存损坏，需要重建。": "The parent folder cache is damaged. Rebuild the index.",
        "条目缓存损坏，需要重建。": "The item cache is damaged. Rebuild the index.",
        "无法打开本地索引。": "Unable to open the local index.",
        "无法保存索引进度。": "Unable to save index progress.",
        "无法读取搜索范围。": "Unable to read search locations.",
        "无法保存搜索目录。": "Unable to save search locations.",
        "无法更新目录范围。": "Unable to update the folder scope.",
        "无法写入目录索引。": "Unable to write the folder index.",
        "当前缓存格式超过容量，请缩小搜索范围。": "The cache capacity was exceeded. Reduce the search scope.",
        "索引读取失败，保留原有搜索缓存。": "Unable to read the index. The previous search cache has been preserved.",
        "%d 项结果 · 已显示 %d 项": "%d results · Showing %d",
        "修改：%@": "Modified: %@",
        "无法修改登录启动：%@": "Unable to change launch at login: %@",
        "设置未能保存：%@": "Unable to save settings: %@",
        "\n已发现 %d 处访问缺口；其中文件总数未知。": "\n%d locations could not be accessed; their file counts are unknown.",
        " · 通知不可用，请手动核对": " · Notifications unavailable; refresh manually",
        "设置未能保存：": "Unable to save settings: ",
        "索引无法载入：": "Unable to load index: ",
        "更新未完成：": "Update incomplete: ",
        "收录未完成：": "Indexing incomplete: ",
        "添加目录失败：": "Unable to add folder: ",
        "移除目录失败：": "Unable to remove folder: ",
    ]
    static func text(_ source: String) -> String { language == .english ? (english[source] ?? source) : source }
    static func message(_ raw: String) -> String {
        if let value = english[raw] { return language == .english ? value : raw }
        let suffix = " · 通知不可用，请手动核对"
        if raw.hasSuffix(suffix) { return message(String(raw.dropLast(suffix.count))) + text(suffix) }
        for prefix in ["设置未能保存：", "索引无法载入：", "更新未完成：", "收录未完成：", "添加目录失败：", "移除目录失败："] {
            if raw.hasPrefix(prefix) { return text(prefix) + message(String(raw.dropFirst(prefix.count))) }
        }
        return raw
    }
    static var locale: Locale { Locale(identifier: language.rawValue) }
}

func tr(_ source: String) -> String { L10n.text(source) }
func trf(_ source: String, _ arguments: CVarArg...) -> String {
    String(format: tr(source), locale: L10n.locale, arguments: arguments)
}
