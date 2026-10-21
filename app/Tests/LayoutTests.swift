import AppKit

// Real AppKit contracts and action dispatch, with file operations replaced by recorders.
@main struct LayoutTests {
    static func main()throws {
        _ = NSApplication.shared
        let temp=URL(fileURLWithPath:"app/testdata/layout-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
        try Data("example".utf8).write(to:temp.appendingPathComponent("a.txt"))
        try Data("example".utf8).write(to:temp.appendingPathComponent("b.txt"))
        let owner=ApplicationDelegate(boot:DispatchTime.now().uptimeNanoseconds)
        owner.prefURL=temp.appendingPathComponent("preferences.json")
        let main=SearchController(owner:owner,desktop:false),desktop=SearchController(owner:owner,desktop:true)
        owner.main=main;owner.desktopController=desktop
        var checks=[[String:Any]]()
        func check(_ name:String,_ condition:Bool){guard condition else{FileHandle.standardError.write(Data(("FAILED "+name+"\n").utf8));exit(1)};checks.append(["case":name,"passed":true]);print("OK \(name)")}
        func layout(_ c:SearchController){c.window.contentView!.layoutSubtreeIfNeeded()}
        func alpha(_ c:SearchController)->CGFloat{NSColor(cgColor:c.surface!.layer!.backgroundColor!)!.alphaComponent}
        layout(main);layout(desktop)
        check("mac-system-font",desktop.search.font==NSFont.systemFont(ofSize:NSFont.systemFontSize))
        let stack=desktop.window.contentView!.subviews.compactMap{$0 as? NSStackView}.first!
        check("desktop-only-search-and-results",stack.arrangedSubviews.count==2 && desktop.suffix.superview==nil && desktop.sort.superview==nil && desktop.kind.superview==nil && desktop.status.superview==nil)
        check("desktop-no-title-buttons",!desktop.window.styleMask.contains(.titled) && desktop.window.standardWindowButton(.closeButton)==nil)
        check("desktop-editable-search",desktop.search.isEditable && desktop.search.isSelectable)
        owner.preferences.desktopOpacity=0.3;desktop.applySurface()
        check("high-transparency-keeps-text-opaque",desktop.window.alphaValue==1 && desktop.search.alphaValue==1 && desktop.table.alphaValue==1 && abs(desktop.surface!.glass.alphaValue-0.3)<0.001)
        owner.preferences.details=true;main.applyPreferences();desktop.applyPreferences();layout(main);layout(desktop)
        check("details-main-only",!main.detailStack.isHidden && desktop.detailStack.isHidden && desktop.detailStack.superview==nil)
        check("desktop-results-full-width",desktop.resultsScroll.frame.width>=desktop.window.contentView!.bounds.width-17)
        desktop.window.setContentSize(NSSize(width:260,height:160));layout(desktop)
        check("desktop-minimum-layout",desktop.search.frame.width>200 && desktop.resultsScroll.frame.height>=60)
        owner.preferences.desktopGlass=false;desktop.applySurface()
        check("glass-off-is-solid",desktop.surface!.glass.isHidden && alpha(desktop)==1 && desktop.window.alphaValue==1)
        desktop.window.appearance=NSAppearance(named:.aqua);desktop.surface!.viewDidChangeEffectiveAppearance()
        let light=NSColor(cgColor:desktop.surface!.layer!.backgroundColor!)!.usingColorSpace(.deviceRGB)!.redComponent
        desktop.window.appearance=NSAppearance(named:.darkAqua);desktop.surface!.viewDidChangeEffectiveAppearance()
        let dark=NSColor(cgColor:desktop.surface!.layer!.backgroundColor!)!.usingColorSpace(.deviceRGB)!.redComponent
        check("solid-theme-follows-appearance",dark<light)
        desktop.window.appearance=nil
        desktop.surface!.configure(opacity:0.3,glass:true,reduceTransparency:true)
        check("reduced-transparency-solid-fallback",alpha(desktop)==1 && desktop.surface!.glass.isHidden)
        owner.preferences.desktopGlass=true;desktop.applySurface()
        check("glass-on-clears-solid-layer",alpha(desktop)==0)
        let root=RootScope(id:1,path:temp.path,sample:true,volume:"fixture")
        let entries=scanDirectory(temp.path,root:root).entries.filter{$0.name.hasSuffix(".txt")}.sorted{$0.name<$1.name}
        desktop.displayed=entries;desktop.table.reloadData();layout(desktop)
        let row=desktop.table.view(atColumn:0,row:0,makeIfNecessary:true) as! FileRowView;row.layoutSubtreeIfNeeded()
        check("desktop-icon-tight-inset",row.icon.frame.minX==0 && row.name.frame.minX==22 && desktop.table.style == .plain)
        main.displayed=entries;main.table.reloadData();layout(main)
        var opened=[URL](),revealed=[URL](),copied=[String]()
        main.openURL={opened.append($0);return true};main.revealURL={revealed.append($0)};main.copyPath={copied.append($0)}
        check("single-click-selects-only",main.table.action==nil && main.table.doubleAction==#selector(SearchController.openDoubleClicked))
        main.table.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false)
        check("selection-has-no-open-side-effect",opened.isEmpty)
        let menu=main.table.menuForRow(1)!
        check("right-click-selects-target-row",main.selectedEntry()!.path==entries[1].path)
        check("context-actions-present",menu.items.map{$0.title}==["打开","复制路径","在 Finder 中显示"])
        let copy=menu.items[1];main.contextCopy(copy);main.contextReveal(menu.items[2]);main.contextOpen(menu.items[0])
        check("context-action-target-correct",copied==[entries[1].path] && opened.map{$0.path}==[entries[1].path] && revealed.map{$0.path}==[entries[1].path])
        main.invalidate();main.contextCopy(copy)
        check("stale-menu-cannot-act",!main.validateMenuItem(copy) && copied.count==1)
        check("empty-area-has-no-context-menu",main.table.menuForRow(-1)==nil)
        main.openDoubleClicked();check("empty-double-click-cannot-open",opened.count==1)
        main.displayed=[entries[1]];main.table.reloadData();main.table.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false)
        try FileManager.default.moveItem(atPath:entries[1].path,toPath:entries[1].path+".old")
        try Data("replaced".utf8).write(to:URL(fileURLWithPath:entries[1].path))
        main.openSelected();check("replaced-file-not-opened",opened.count==1 && main.displayed.isEmpty)
        check("main-no-action-buttons",main.window.contentView!.subviews.flatMap{$0.subviews}.compactMap{$0 as? NSButton}.allSatisfy{!["复制路径","在 Finder 中显示","打开"].contains($0.title)})
        let settings=SettingsController(owner:owner);settings.window.contentView!.layoutSubtreeIfNeeded()
        check("settings-scrollable",settings.window.contentView!.subviews.first is NSScrollView)
        owner.preferences.desktop=true;settings.reload();check("glass-controls-enabled",settings.transparency.isEnabled)
        settings.transparency.doubleValue=60.2;settings.changeTransparency()
        check("background-only-live-update",abs(desktop.surface!.glass.alphaValue-0.4)<0.001 && desktop.window.alphaValue==1)
        RunLoop.current.run(until:Date().addingTimeInterval(0.3))
        check("transparency-persisted",abs(Preferences.load(from:owner.prefURL).desktopOpacity-0.4)<0.001)
        settings.glass.state = .off;settings.changeGlass()
        check("solid-mode-disables-slider",!settings.transparency.isEnabled && alpha(desktop)==1 && !Preferences.load(from:owner.prefURL).desktopGlass)
        for name in ["报价.xlsx","报价.xml","报价.txt"]{try Data().write(to:temp.appendingPathComponent(name))}
        let store=try IndexStore(directory:temp.appendingPathComponent("search-state"))
        try store.addRoot(temp.path,sample:true);let scope=try store.roots()[0]
        try store.reconcile(temp.path,root:scope,result:scanDirectory(temp.path,root:scope,excluded:[store.directory.path]),event:0)
        owner.snapshot=try store.writeSnapshot();owner.enabledRoots=[scope.id]
        main.search.stringValue="报价"
        func typeSuffix(_ value:String,_ expected:Set<String>){
            main.suffix.stringValue=value;main.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:main.suffix))
            let deadline=Date().addingTimeInterval(3)
            while Date()<deadline && Set(main.displayed.map{$0.name}) != expected{RunLoop.current.run(until:Date().addingTimeInterval(0.01))}
            check("suffix-input-event-\(value)-name-\(main.search.stringValue)",Set(main.displayed.map{$0.name})==expected)
        }
        typeSuffix("x",["报价.xlsx","报价.xml"]);typeSuffix("xl",["报价.xlsx"]);typeSuffix("xlsx",["报价.xlsx"])
        main.search.stringValue="";typeSuffix("xl",["报价.xlsx"])
        main.search.stringValue="报价";typeSuffix("",["报价.xlsx","报价.xml","报价.txt"])
        let output:[String:Any]=["count":checks.count,"checks":checks,"visual_screenshot_verified":false,"note":"Invisible AppKit layout and safe action dispatch checks; open/reveal/copy recorded without external side effects."]
        try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"app/results/layout-tests-v08.json"))
        print("\(checks.count) layout checks passed")
    }
}
