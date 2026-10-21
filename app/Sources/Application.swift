import AppKit
import Carbon
import ServiceManagement

final class SettingsDocument:NSView {override var isFlipped:Bool {true}}

final class SettingsController:NSObject {
    weak var owner:ApplicationDelegate?;let window:NSWindow
    let stack=NSStackView();let details=NSButton(checkboxWithTitle:"主窗口显示路径详情",target:nil,action:nil);let desktop=NSButton(checkboxWithTitle:"显示常驻桌面搜索窗",target:nil,action:nil)
    let density=NSSegmentedControl(labels:ResultDensity.allCases.map{$0.title},trackingMode:.selectOne,target:nil,action:nil)
    let rootsStack=NSStackView();let state=NSTextField(wrappingLabelWithString:"");let pause=NSButton(title:"暂停收录",target:nil,action:nil);var paused=false
    let glass=NSButton(checkboxWithTitle:"毛玻璃背景",target:nil,action:nil)
    let transparency=NSSlider(value:15,minValue:0,maxValue:70,target:nil,action:nil)
    let transparencyValue=NSTextField(labelWithString:"15%")
    var appearanceSave:DispatchWorkItem?
    init(owner:ApplicationDelegate){
        self.owner=owner;window=NSWindow(contentRect:NSRect(x:0,y:0,width:580,height:560),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false);super.init();window.title="文件搜索设置";window.isReleasedWhenClosed=false;window.minSize=NSSize(width:540,height:430);window.center()
        let scroll=NSScrollView(frame:window.contentView!.bounds);scroll.autoresizingMask=[.width,.height];scroll.hasVerticalScroller=true;scroll.drawsBackground=false
        let document=SettingsDocument();document.translatesAutoresizingMaskIntoConstraints=false;scroll.documentView=document;window.contentView!.addSubview(scroll)
        document.widthAnchor.constraint(equalTo:scroll.contentView.widthAnchor).isActive=true
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12;stack.translatesAutoresizingMaskIntoConstraints=false;document.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:document.leadingAnchor,constant:22),stack.trailingAnchor.constraint(equalTo:document.trailingAnchor,constant:-22),stack.topAnchor.constraint(equalTo:document.topAnchor,constant:20),stack.bottomAnchor.constraint(equalTo:document.bottomAnchor,constant:-20)])
        let title=NSTextField(labelWithString:"搜索与展示");title.font = .systemFont(ofSize:18,weight:.medium);stack.addArrangedSubview(title)
        details.target=self;details.action=#selector(changeDetails);stack.addArrangedSubview(details)
        let line=NSStackView();line.spacing=12;line.addArrangedSubview(NSTextField(labelWithString:"结果密度"));density.target=self;density.action=#selector(changeDensity);density.setAccessibilityLabel("结果展示密度");line.addArrangedSubview(density);stack.addArrangedSubview(line)
        desktop.target=self;desktop.action=#selector(changeDesktop);stack.addArrangedSubview(desktop)
        glass.target=self;glass.action=#selector(changeGlass);stack.addArrangedSubview(glass)
        let appearanceRow=NSStackView();appearanceRow.spacing=10;appearanceRow.addArrangedSubview(NSTextField(labelWithString:"背景透明度"));transparency.target=self;transparency.action=#selector(changeTransparency);transparency.isContinuous=true;transparency.setAccessibilityLabel("桌面搜索背景透明度");appearanceRow.addArrangedSubview(transparency);transparency.setContentHuggingPriority(.defaultLow,for:.horizontal);transparencyValue.alignment = .right;transparencyValue.widthAnchor.constraint(equalToConstant:40).isActive=true;appearanceRow.addArrangedSubview(transparencyValue);stack.addArrangedSubview(appearanceRow);appearanceRow.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let appearanceHint=NSTextField(wrappingLabelWithString:"透明度只影响背景，文字保持清晰。关闭毛玻璃后使用实色窗口。")
        appearanceHint.font = .systemFont(ofSize:11);appearanceHint.textColor = .secondaryLabelColor;stack.addArrangedSubview(appearanceHint);appearanceHint.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        stack.addArrangedSubview(NSBox.separator())
        stack.addArrangedSubview(NSTextField(labelWithString:"搜索目录"));rootsStack.orientation = .vertical;rootsStack.alignment = .leading;rootsStack.spacing=7;stack.addArrangedSubview(rootsStack);rootsStack.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let buttons=NSStackView();buttons.spacing=8;buttons.addArrangedSubview(NSButton(title:"添加目录…",target:self,action:#selector(addRoot)));buttons.addArrangedSubview(NSButton(title:"重新核对",target:self,action:#selector(refresh)));pause.target=self;pause.action=#selector(togglePause);buttons.addArrangedSubview(pause);stack.addArrangedSubview(buttons)
        let login=NSButton(checkboxWithTitle:"登录时启动",target:self,action:#selector(changeLogin));login.state=SMAppService.mainApp.status == .enabled ? .on:.off;stack.addArrangedSubview(login)
        state.font = .systemFont(ofSize:11);state.textColor = .secondaryLabelColor;stack.addArrangedSubview(state);state.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let hint=NSTextField(wrappingLabelWithString:"快捷键 ⌃⌥Space 唤出搜索。索引和设置保留在本机。")
        hint.font = .systemFont(ofSize:11);hint.textColor = .secondaryLabelColor;stack.addArrangedSubview(hint);hint.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        reload()
    }
    func show(){reload();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    func reload(){guard let owner else{return};details.state=owner.preferences.details ? .on:.off;desktop.state=owner.preferences.desktop ? .on:.off;density.selectedSegment=ResultDensity.allCases.firstIndex(of:owner.preferences.density) ?? 1
        glass.state=owner.preferences.desktopGlass ? .on:.off;glass.isEnabled=owner.preferences.desktop;transparency.isEnabled=owner.preferences.desktop && owner.preferences.desktopGlass
        transparency.doubleValue=((1-owner.preferences.clampedDesktopOpacity)*100).rounded();transparencyValue.stringValue="\(Int(transparency.doubleValue))%"
        for v in rootsStack.arrangedSubviews{rootsStack.removeArrangedSubview(v);v.removeFromSuperview()}
        for root in owner.roots {
            let row=NSStackView();row.spacing=8;let label=NSTextField(labelWithString:(root.sample ? "示例文件：":"")+root.path);label.lineBreakMode = .byTruncatingMiddle;label.setContentCompressionResistancePriority(.defaultLow,for:.horizontal);label.font = .systemFont(ofSize:11);label.toolTip=root.path;row.addArrangedSubview(label)
            let remove=NSButton(title:"移除",target:self,action:#selector(removeRoot(_:)));remove.tag=Int(root.id);row.addArrangedSubview(remove);rootsStack.addArrangedSubview(row);row.widthAnchor.constraint(equalTo:rootsStack.widthAnchor).isActive=true
        }
        state.stringValue=owner.indexState+(owner.failures.isEmpty ? "":"\n已发现 \(owner.failures.count) 处访问缺口；其中文件总数未知。")
    }
    @objc func changeDetails(){owner?.preferences.details=details.state == .on;owner?.settingsChanged()}
    @objc func changeDensity(){owner?.preferences.density=ResultDensity.allCases[density.selectedSegment];owner?.settingsChanged()}
    @objc func changeDesktop(){owner?.setDesktop(desktop.state == .on)}
    @objc func changeGlass(){owner?.preferences.desktopGlass=glass.state == .on;owner?.desktopController?.applySurface();owner?.savePreferences();reload()}
    @objc func changeTransparency(){
        let value=min(70,max(0,transparency.doubleValue.rounded()));transparency.doubleValue=value;owner?.preferences.desktopOpacity=1-value/100;transparencyValue.stringValue="\(Int(value))%";owner?.desktopController?.applySurface()
        appearanceSave?.cancel();let save=DispatchWorkItem{[weak self] in self?.owner?.savePreferences()};appearanceSave=save;DispatchQueue.main.asyncAfter(deadline:.now()+0.2,execute:save)
    }
    @objc func addRoot(){owner?.chooseRoot(parent:window)}
    @objc func removeRoot(_ b:NSButton){guard let owner else{return};let id=UInt32(b.tag);owner.enabledRoots.remove(id);owner.main.schedule(preserve:true);owner.desktopController?.schedule(preserve:true);owner.service.removeRoot(id)}
    @objc func refresh(){owner?.service.refresh()}
    @objc func togglePause(){paused.toggle();pause.title=paused ? "继续收录":"暂停收录";owner?.service.setPaused(paused)}
    @objc func changeLogin(_ b:NSButton){do{if b.state == .on{try SMAppService.mainApp.register()}else{try SMAppService.mainApp.unregister()}}catch{b.state=SMAppService.mainApp.status == .enabled ? .on:.off;state.stringValue="无法修改登录启动：\(error.localizedDescription)"}}
}
extension NSBox {static func separator()->NSBox{let b=NSBox();b.boxType = .separator;return b}}

final class ApplicationDelegate:NSObject,NSApplicationDelegate {
    let boot:UInt64
    init(boot:UInt64){self.boot=boot;super.init()}
    var preferences=Preferences();var roots=[RootScope]();var enabledRoots=Set<UInt32>();var snapshot:SearchSnapshot?;var indexState="正在载入本地索引…";var failures=[String]()
    var service:IndexService!;var main:SearchController!;var desktopController:SearchController?;var settings:SettingsController?
    var statusItem:NSStatusItem!;var hotkey:EventHotKeyRef?;var eventHandler:EventHandlerRef?
    var stateDirectory:URL!;var prefURL:URL!;var readyMs:Double=0;var updateCount=0
    func applicationDidFinishLaunching(_ notification:Notification){
        let args=CommandLine.arguments
        if let i=args.firstIndex(of:"--state"),args.indices.contains(i+1){stateDirectory=URL(fileURLWithPath:args[i+1])}else{stateDirectory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("LocalFileSearch",isDirectory:true)}
        do{try FileManager.default.createDirectory(at:stateDirectory,withIntermediateDirectories:true)}catch{let a=NSAlert();a.messageText="无法创建本地数据目录";a.informativeText=error.localizedDescription;a.runModal();NSApp.terminate(nil);return}
        prefURL=stateDirectory.appendingPathComponent("preferences.json");preferences=Preferences.load(from:prefURL)
        buildMenus();main=SearchController(owner:self,desktop:false);main.show();readyMs=Double(DispatchTime.now().uptimeNanoseconds-boot)/1e6
        let sample=Bundle.main.resourceURL!.appendingPathComponent("SampleFiles").path
        service=IndexService(directory:stateDirectory,sampleRoot:sample)
        service.onUpdate={[weak self] roots,snapshot,state,failures in
            guard let self else{return};self.roots=roots;self.enabledRoots=Set(roots.map{$0.id});self.snapshot=snapshot;self.indexState=state;self.failures=failures;self.updateCount+=1
            self.main.schedule(preserve:true);self.desktopController?.schedule(preserve:true);self.settings?.reload()
        }
        service.start();registerHotkey();if preferences.desktop{setDesktop(true)}
        if let i=args.firstIndex(of:"--smoke-report"),args.indices.contains(i+1){runSmoke(destination:args[i+1],attempt:0)}
    }
    func buildMenus(){
        let bar=NSMenu(),appItem=NSMenuItem(),appMenu=NSMenu();appItem.submenu=appMenu;appMenu.addItem(withTitle:"设置…",action:#selector(showSettings),keyEquivalent:",").target=self;appMenu.addItem(.separator());appMenu.addItem(withTitle:"退出文件搜索",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");bar.addItem(appItem)
        let editItem=NSMenuItem(title:"编辑",action:nil,keyEquivalent:""),editMenu=NSMenu(title:"编辑");editItem.submenu=editMenu
        for(t,a,k) in [("剪切",#selector(NSText.cut(_:)),"x"),("复制",#selector(NSText.copy(_:)),"c"),("粘贴",#selector(NSText.paste(_:)),"v"),("全选",#selector(NSText.selectAll(_:)),"a")]{editMenu.addItem(withTitle:t,action:a,keyEquivalent:k)}
        bar.addItem(editItem);NSApp.mainMenu=bar
        statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength);statusItem.button?.image=MenuBarIcon.make();statusItem.button?.toolTip="文件搜索 · FileSearch"
        let menu=NSMenu();menu.addItem(withTitle:"打开搜索  ⌃⌥Space",action:#selector(showMain),keyEquivalent:"").target=self;menu.addItem(withTitle:"设置…",action:#selector(showSettings),keyEquivalent:"").target=self;menu.addItem(.separator());menu.addItem(withTitle:"退出文件搜索",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");statusItem.menu=menu
    }
    func registerHotkey(){
        var spec=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),{_,_,info in let owner=Unmanaged<ApplicationDelegate>.fromOpaque(info!).takeUnretainedValue();DispatchQueue.main.async{owner.showMain()};return noErr},1,&spec,Unmanaged.passUnretained(self).toOpaque(),&eventHandler)
        let result=RegisterEventHotKey(UInt32(kVK_Space),UInt32(controlKey|optionKey),EventHotKeyID(signature:0x46494C45,id:1),GetApplicationEventTarget(),0,&hotkey)
        if result != noErr{indexState="快捷键暂不可用，请从菜单栏打开。"}
    }
    @objc func showMain(){main?.show()}
    @objc func showSettings(){if settings==nil{settings=SettingsController(owner:self)};settings?.show()}
    func chooseRoot(parent:NSWindow){let panel=NSOpenPanel();panel.canChooseFiles=false;panel.canChooseDirectories=true;panel.allowsMultipleSelection=true;panel.prompt="加入搜索范围";panel.message="仅索引你选择目录中的名称和必要元数据。";panel.beginSheetModal(for:parent){[weak self] response in if response == .OK{for url in panel.urls{self?.service.addRoot(url)}}}}
    func settingsChanged(){savePreferences();main.applyPreferences();desktopController?.applyPreferences();settings?.reload()}
    func savePreferences(){guard prefURL != nil else{return};do{try preferences.save(to:prefURL)}catch{indexState="设置未能保存：\(error.localizedDescription)"}}
    func setDesktop(_ value:Bool){preferences.desktop=value;savePreferences();if value{if desktopController==nil{desktopController=SearchController(owner:self,desktop:true)};desktopController?.applyPreferences();desktopController?.show(focus:false);desktopController?.schedule()}else{desktopController?.window.orderOut(nil)};settings?.reload()}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{false}
    func terminationTrace(_ text:String){if CommandLine.arguments.contains("--smoke-report"){FileHandle.standardError.write(Data(("FileSearch lifecycle: "+text+"\n").utf8))}}
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply{terminationTrace("requested");savePreferences();if let hotkey{UnregisterEventHotKey(hotkey)};if let eventHandler{RemoveEventHandler(eventHandler)};guard let service else{return .terminateNow};service.shutdown{[self] in terminationTrace("index stopped; replying");NSApp.reply(toApplicationShouldTerminate:true);terminationTrace("reply returned")};return .terminateLater}
    func runSmoke(destination:String,attempt:Int){DispatchQueue.main.asyncAfter(deadline:.now()+0.15){[self] in
        guard snapshot != nil else{if attempt<100{runSmoke(destination:destination,attempt:attempt+1)}else{NSApp.terminate(nil)};return}
        main.search.stringValue="合同";main.suffix.stringValue="pdf, .tar.gz";main.schedule()
        DispatchQueue.main.asyncAfter(deadline:.now()+0.2){[self] in
            let report:[String:Any]=["version":"0.10","window_prepared_from_main_ms":readyMs,"entries":snapshot?.count ?? 0,"roots":roots.count,"root_paths":roots.map{$0.path},"executable_path":Bundle.main.executablePath ?? "","query":"合同","suffixes":"pdf, .tar.gz","results":main.displayed.map{$0.name},"state":indexState,"main_search_font":main.search.font?.pointSize ?? 0,"desktop_search_font":desktopController?.search.font?.pointSize ?? 0,"background_transparency_percent":Int(((1-preferences.clampedDesktopOpacity)*100).rounded()),"desktop_glass":preferences.desktopGlass,"menu_bar_icon_template":statusItem.button?.image?.isTemplate ?? false,"menu_bar_icon_width":statusItem.button?.image?.size.width ?? 0,"menu_bar_tooltip":statusItem.button?.toolTip ?? "","footprint_note":"This smoke report is functional and not a full performance acceptance run."]
            try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:destination));NSApp.terminate(nil)
        }
    }}
}
