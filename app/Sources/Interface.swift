import AppKit

// Reserved for a later Quick Look provider. No preview view or file body is loaded now.
protocol FilePreviewProviding {func attachPreview(for entry:FileEntry,to host:NSView)}
final class SearchPanel:NSPanel {override var canBecomeKey:Bool{true};override var canBecomeMain:Bool{true}}
final class FileRowView:NSTableCellView {
    var compact=false
    let name=NSTextField(labelWithString:"");let parent=NSTextField(labelWithString:"");let icon=NSImageView()
    override init(frame:NSRect){super.init(frame:frame);addSubview(icon);addSubview(name);addSubview(parent);name.font = .systemFont(ofSize:NSFont.systemFontSize);parent.font = .systemFont(ofSize:NSFont.smallSystemFontSize);parent.textColor = .secondaryLabelColor;name.lineBreakMode = .byTruncatingMiddle;parent.lineBreakMode = .byTruncatingMiddle}
    required init?(coder:NSCoder){fatalError()}
    override var backgroundStyle:NSView.BackgroundStyle {didSet{
        name.textColor=backgroundStyle == .emphasized ? .alternateSelectedControlTextColor:.labelColor
        parent.textColor=backgroundStyle == .emphasized ? .alternateSelectedControlTextColor:.secondaryLabelColor
    }}
    override func layout(){super.layout();let h=bounds.height;let x:CGFloat=compact ? 0:4;let size:CGFloat=compact ? 16:20;let textX:CGFloat=compact ? 22:30;icon.frame=NSRect(x:x,y:(h-size)/2,width:size,height:size);name.frame=NSRect(x:textX,y:h/2+1,width:max(0,bounds.width-textX-4),height:17);parent.frame=NSRect(x:textX,y:h/2-14,width:max(0,bounds.width-textX-4),height:14)}
    func configure(_ e:FileEntry){name.stringValue=e.name;parent.stringValue=e.parent;toolTip=e.path;icon.image=NSImage(systemSymbolName:e.kind==1 ? "folder":"doc",accessibilityDescription:e.kindLabel);setAccessibilityLabel(e.name+"，"+e.parent)}
}
final class ResultTableView:NSTableView {
    var menuProvider:(()->NSMenu?)?
    func menuForRow(_ row:Int)->NSMenu?{
        guard row>=0,row<numberOfRows else{deselectAll(nil);return nil}
        selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false)
        return menuProvider?()
    }
    override func menu(for event:NSEvent)->NSMenu?{menuForRow(row(at:convert(event.locationInWindow,from:nil)))}
}
final class ContextTarget:NSObject {
    let entry:FileEntry;let token:Int
    init(entry:FileEntry,token:Int){self.entry=entry;self.token=token}
}
final class SearchController:NSObject,NSSearchFieldDelegate,NSTableViewDataSource,NSTableViewDelegate,NSWindowDelegate,NSMenuItemValidation {
    weak var owner:ApplicationDelegate?
    let window:SearchPanel;let desktop:Bool
    let resultsScroll=NSScrollView()
    var surface:DesktopSurface?
    var detailWidth:NSLayoutConstraint!;var verticalDetailWidth:NSLayoutConstraint!;var scrollFullHeight:NSLayoutConstraint!;var scrollFullWidth:NSLayoutConstraint!
    let search=NSSearchField();let suffix=NSTextField();let kind=NSSegmentedControl(labels:[tr("全部"),tr("文件"),tr("文件夹")],trackingMode:.selectOne,target:nil,action:nil)
    let table=ResultTableView();let status=NSTextField(labelWithString:"");let errorLabel=NSTextField(labelWithString:"");let detailTitle=NSTextField(labelWithString:"");let detailPath=NSTextField(wrappingLabelWithString:"");let detailMeta=NSTextField(wrappingLabelWithString:"")
    let body=NSStackView();let detailStack=NSStackView();let emptyLabel=NSTextField(wrappingLabelWithString:"")
    let countLabel=NSTextField(labelWithString:"");let sort=NSPopUpButton()
    var displayed=[FileEntry]();var total=0;var limit=500;var pending:DispatchWorkItem?;let gate=CancellationGate();let worker=DispatchQueue(label:"local.filesearch.query",qos:.userInitiated)
    var openURL:(URL)->Bool={NSWorkspace.shared.open($0)}
    var revealURL:(URL)->Void={NSWorkspace.shared.activateFileViewerSelecting([$0])}
    var copyPath:(String)->Void={NSPasteboard.general.clearContents();NSPasteboard.general.setString($0,forType:.string)}
    var queryToken=0;var measured=[Double]();var previewProvider:FilePreviewProviding?
    init(owner:ApplicationDelegate,desktop:Bool){
        self.owner=owner;self.desktop=desktop
        let style:NSWindow.StyleMask=desktop ? [.borderless,.resizable,.nonactivatingPanel]:[.titled,.closable,.resizable]
        window=SearchPanel(contentRect:NSRect(x:0,y:0,width:desktop ? 360:700,height:desktop ? 280:480),styleMask:style,backing:.buffered,defer:false)
        super.init();window.delegate=self;window.title=desktop ? tr("桌面搜索"):tr("文件搜索");window.isReleasedWhenClosed=false;window.hidesOnDeactivate=false
        window.minSize=NSSize(width:desktop ? 260:600,height:desktop ? 160:400)
        if desktop {
            window.isOpaque=false;window.backgroundColor = .clear;window.titlebarAppearsTransparent=true;window.titleVisibility = .hidden;window.titlebarSeparatorStyle = .none;window.isMovableByWindowBackground=true
            let background=DesktopSurface(frame:window.contentView!.bounds);window.contentView=background;surface=background
        }
        if desktop {window.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.desktopIconWindow))+1);window.collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle];if !owner.preferences.desktopFrame.isEmpty{window.setFrame(from:owner.preferences.desktopFrame)}else{window.setFrameOrigin(NSPoint(x:40,y:120))}}else{window.center()}
        build();applyPreferences()
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(accessibilityChanged),name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
    }
    func label(_ text:String)->NSTextField{let v=NSTextField(labelWithString:text);v.textColor = .secondaryLabelColor;v.font = .systemFont(ofSize:11);return v}
    func build(){
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8;stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        let inset:CGFloat=desktop ? 8:16
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:inset),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-inset),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:desktop ? 8:14),stack.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:desktop ? -8:-12)])
        let searchRow=NSStackView();searchRow.spacing=8
        if desktop{search.cell=DesktopSearchCell(textCell:"");search.isEditable=true;search.isSelectable=true;search.cell?.isScrollable=true;search.isBezeled=true;search.drawsBackground=false}
        search.placeholderString=tr("文件名或文件夹名");search.font = .systemFont(ofSize:NSFont.systemFontSize);search.heightAnchor.constraint(equalToConstant:26).isActive=true;search.delegate=self;search.sendsSearchStringImmediately=true;search.setAccessibilityLabel(tr("文件名或文件夹名"))
        searchRow.addArrangedSubview(desktop ? desktopPlate(search):search)
        if !desktop{let settings=NSButton(title:tr("设置"),target:self,action:#selector(showSettings));settings.font = .systemFont(ofSize:NSFont.systemFontSize);searchRow.addArrangedSubview(settings)}
        stack.addArrangedSubview(searchRow);searchRow.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        kind.selectedSegment=0;kind.target=self;kind.action=#selector(changeKind);kind.setAccessibilityLabel(tr("条目类型"))
        suffix.placeholderString=tr("后缀：x、xl、pdf…");suffix.toolTip=tr("输入部分后缀即可检索，例如 x、xl 匹配 xlsx；多个后缀用逗号或空格分隔，留空不限。");suffix.font = .systemFont(ofSize:NSFont.systemFontSize);suffix.delegate=self;suffix.setAccessibilityLabel(tr("自定义文件格式后缀"))
        sort.addItems(withTitles:[tr("按相关度"),tr("按名称"),tr("按修改时间")]);sort.font = .systemFont(ofSize:NSFont.systemFontSize);sort.target=self;sort.action=#selector(filterChanged);sort.setAccessibilityLabel(tr("排序"))
        if !desktop{
            let filters=NSStackView();filters.spacing=8;filters.addArrangedSubview(kind);filters.addArrangedSubview(suffix);stack.addArrangedSubview(filters);filters.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true;suffix.widthAnchor.constraint(greaterThanOrEqualToConstant:140).isActive=true
            errorLabel.textColor = .systemRed;errorLabel.font = .systemFont(ofSize:11);errorLabel.maximumNumberOfLines=2;errorLabel.cell?.wraps=true;errorLabel.isHidden=true;stack.addArrangedSubview(errorLabel);errorLabel.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
            let meta=NSStackView();meta.spacing=8;countLabel.font = .systemFont(ofSize:11);countLabel.textColor = .secondaryLabelColor;meta.addArrangedSubview(countLabel);meta.addArrangedSubview(NSView());meta.addArrangedSubview(sort);stack.addArrangedSubview(meta);meta.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        }
        body.orientation = .horizontal;body.alignment = .top;body.spacing=14
        let scroll=resultsScroll;scroll.hasVerticalScroller=true;scroll.borderType = .noBorder
        let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier("entry"));column.width=desktop ? 340:600;table.addTableColumn(column);table.headerView=nil;table.style = .plain;table.intercellSpacing = .zero;table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle;table.delegate=self;table.dataSource=self;table.allowsMultipleSelection=false;table.target=self;table.doubleAction=#selector(openDoubleClicked);table.setAccessibilityLabel(tr("搜索结果"));table.menuProvider={[weak self] in self?.makeContextMenu()};scroll.documentView=table
        if desktop{scroll.drawsBackground=false;scroll.contentView.drawsBackground=false;table.backgroundColor = .clear}
        body.addArrangedSubview(scroll);scroll.setContentHuggingPriority(.defaultLow,for:.horizontal);scrollFullHeight=scroll.heightAnchor.constraint(equalTo:body.heightAnchor);scrollFullWidth=scroll.widthAnchor.constraint(equalTo:body.widthAnchor);scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:60).isActive=true
        detailStack.orientation = .vertical;detailStack.alignment = .leading;detailStack.spacing=10;detailTitle.font = .systemFont(ofSize:14,weight:.medium);detailTitle.lineBreakMode = .byTruncatingMiddle
        detailPath.font = .systemFont(ofSize:12);detailPath.isSelectable=true;detailMeta.font = .systemFont(ofSize:11);detailMeta.textColor = .secondaryLabelColor
        if !desktop{
            for v in [detailTitle,label(tr("完整路径")),detailPath,detailMeta]{detailStack.addArrangedSubview(v);v.widthAnchor.constraint(equalTo:detailStack.widthAnchor).isActive=true}
            body.addArrangedSubview(detailStack);detailWidth=detailStack.widthAnchor.constraint(equalToConstant:210);verticalDetailWidth=detailStack.widthAnchor.constraint(equalTo:body.widthAnchor)
        }
        stack.addArrangedSubview(body);body.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true;body.heightAnchor.constraint(greaterThanOrEqualToConstant:desktop ? 60:160).isActive=true
        if desktop{
            emptyLabel.font = .systemFont(ofSize:NSFont.systemFontSize);emptyLabel.textColor = .secondaryLabelColor;emptyLabel.alignment = .center;emptyLabel.translatesAutoresizingMaskIntoConstraints=false;body.addSubview(emptyLabel)
            NSLayoutConstraint.activate([emptyLabel.leadingAnchor.constraint(equalTo:body.leadingAnchor,constant:8),emptyLabel.trailingAnchor.constraint(equalTo:body.trailingAnchor,constant:-8),emptyLabel.centerYAnchor.constraint(equalTo:body.centerYAnchor)])
        }else{
            status.font = .systemFont(ofSize:11);status.textColor = .secondaryLabelColor;status.lineBreakMode = .byTruncatingMiddle;stack.addArrangedSubview(status);status.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        }
        updateSelection()
    }
    @objc func showSettings(){owner?.showSettings()}
    func applyPreferences(){guard let p=owner?.preferences else{return};detailStack.isHidden = desktop || !p.details;table.rowHeight=p.density.height;table.noteHeightOfRows(withIndexesChanged:IndexSet(integersIn:0..<displayed.count));table.reloadData();updateSelection();updateLayout();applySurface()}
    func updateLayout(){
        let vertical=window.frame.width<640
        if desktop{scrollFullHeight.isActive=true;return}
        detailWidth.isActive=false;verticalDetailWidth.isActive=false;scrollFullHeight.isActive=false;scrollFullWidth.isActive=false
        body.orientation=vertical ? .vertical:.horizontal;body.alignment=vertical ? .leading:.top
        detailPath.maximumNumberOfLines=vertical ? 2:0;detailPath.lineBreakMode=vertical ? .byTruncatingMiddle:.byWordWrapping
        detailMeta.isHidden=vertical
        if vertical{verticalDetailWidth.isActive=true;scrollFullWidth.isActive=true}else{detailWidth.isActive=true;scrollFullHeight.isActive=true}
    }
    @objc func accessibilityChanged(){applySurface()}
    func applySurface(){guard desktop,let p=owner?.preferences else{return};window.alphaValue=1;surface?.configure(opacity:p.clampedDesktopOpacity,glass:p.desktopGlass,reduceTransparency:NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)}
    deinit{NSWorkspace.shared.notificationCenter.removeObserver(self)}
    func show(focus:Bool=true){window.orderFront(nil);if focus{NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil);window.makeFirstResponder(search);search.selectText(nil)}}
    func controlTextDidChange(_ obj:Notification){
        if let field=obj.object as? NSTextField,let editor=field.currentEditor() as? NSTextView,editor.hasMarkedText(){invalidate();return}
        schedule()
    }
    func control(_ control:NSControl,textView:NSTextView,doCommandBy selector:Selector)->Bool{
        guard !textView.hasMarkedText() else{return false}
        if selector==#selector(NSResponder.moveDown(_:)){moveSelection(1);return true}
        if selector==#selector(NSResponder.moveUp(_:)){moveSelection(-1);return true}
        if selector==#selector(NSResponder.insertNewline(_:)){if NSApp.currentEvent?.modifierFlags.contains(.command)==true{revealSelected()}else{openSelected()};return true}
        if selector==#selector(NSResponder.cancelOperation(_:)){if desktop{window.resignKey()}else{window.orderOut(nil)};return true};return false
    }
    @objc func changeKind(){if kind.selectedSegment==2{suffix.stringValue="";suffix.isEnabled=false}else{suffix.isEnabled=true};schedule()}
    @objc func filterChanged(){schedule()}
    func setMessage(_ value:String){countLabel.stringValue=value;emptyLabel.stringValue=value;emptyLabel.isHidden = !displayed.isEmpty;resultsScroll.toolTip=value}
    func invalidate(){queryToken=gate.next();pending?.cancel();displayed=[];table.reloadData();setMessage(tr("正在查找…"));updateSelection()}
    func schedule(preserve:Bool=false){
        let selected=preserve ? selectedEntry():nil;invalidate()
        let filters:SuffixFilter
        do{filters=try SuffixFilter(desktop ? "":suffix.stringValue);errorLabel.isHidden=true}catch{errorLabel.stringValue=L10n.message("\(error)");errorLabel.isHidden=false;setMessage(tr("格式后缀无效"));return}
        guard let owner else{return};status.stringValue=L10n.message(owner.indexState)
        if search.stringValue.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && filters.values.isEmpty{setMessage(tr("输入名称或后缀开始搜索"));return}
        guard let snapshot=owner.snapshot else{setMessage(tr("目录收录完成后即可搜索"));return}
        let q=SearchOptions(text:search.stringValue,suffixes:filters.values,kind:kind.selectedSegment==0 ? -1:kind.selectedSegment==1 ? 0:1,roots:owner.enabledRoots,sort:["relevance","name","time"][sort.indexOfSelectedItem],limit:limit)
        let token=queryToken,started=DispatchTime.now().uptimeNanoseconds
        let work=DispatchWorkItem{[weak self] in guard let self,let page=snapshot.search(q,gate:self.gate,token:token) else{return};DispatchQueue.main.async{
            guard self.gate.valid(token) else{return};self.displayed=page.entries;self.total=page.total;self.table.reloadData()
            if let selected{if let i=self.displayed.firstIndex(where:{$0.path==selected.path && $0.identity==selected.identity}){self.table.selectRowIndexes(IndexSet(integer:i),byExtendingSelection:false)}}else if !self.displayed.isEmpty{self.table.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false)}
            self.setMessage(page.total==0 ? (owner.indexState=="范围已核对" ? tr("没有匹配的条目"):tr("当前已收录范围内未找到")):trf("%d 项结果 · 已显示 %d 项",page.total,page.entries.count))
            self.updateSelection();self.window.displayIfNeeded();self.measured.append(Double(DispatchTime.now().uptimeNanoseconds-started)/1e6)
        }}
        pending=work;worker.asyncAfter(deadline:.now()+0.015,execute:work)
    }
    func moveSelection(_ delta:Int){guard !displayed.isEmpty else{return};let row=max(0,min(displayed.count-1,table.selectedRow+delta));table.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false);table.scrollRowToVisible(row)}
    func selectedEntry()->FileEntry?{let i=table.selectedRow;return displayed.indices.contains(i) ? displayed[i]:nil}
    func updateSelection(){let e=selectedEntry();detailTitle.stringValue=e?.name ?? tr("选择结果查看详情");detailPath.stringValue=e?.path ?? "";if let e{let date=Date(timeIntervalSince1970:Double(e.modified)/1000);let formatter=DateFormatter();formatter.locale=L10n.locale;formatter.dateStyle = .medium;formatter.timeStyle = .short;detailMeta.stringValue=e.kindLabel+"\n"+trf("修改：%@",formatter.string(from:date))}else{detailMeta.stringValue=""}}
    func tableViewSelectionDidChange(_ notification:Notification){updateSelection()}
    func numberOfRows(in tableView:NSTableView)->Int{displayed.count}
    func tableView(_ tableView:NSTableView,viewFor column:NSTableColumn?,row:Int)->NSView?{let key=NSUserInterfaceItemIdentifier("FileRow");let view=(tableView.makeView(withIdentifier:key,owner:self) as? FileRowView) ?? FileRowView(frame:.zero);view.identifier=key;view.compact=desktop;view.configure(displayed[row]);return view}
    func checked(_ e:FileEntry)->FileEntry?{guard currentIdentity(e.path)==e.identity else{invalidate();setMessage(tr("目标已变化或不可访问，正在重新核对。"));owner?.service?.refresh();return nil};return e}
    func performOpen(_ e:FileEntry){guard let e=checked(e) else{return};if openURL(URL(fileURLWithPath:e.path)){if !desktop{window.orderOut(nil)}}else{status.stringValue=tr("无法打开该条目，请检查访问权限。")}}
    func performReveal(_ e:FileEntry){guard let e=checked(e) else{return};revealURL(URL(fileURLWithPath:e.path));if !desktop{window.orderOut(nil)}}
    @objc func openSelected(){if let e=selectedEntry(){performOpen(e)}}
    @objc func openDoubleClicked(){guard displayed.indices.contains(table.clickedRow) else{return};table.selectRowIndexes(IndexSet(integer:table.clickedRow),byExtendingSelection:false);openSelected()}
    @objc func revealSelected(){if let e=selectedEntry(){performReveal(e)}}
    func makeContextMenu()->NSMenu?{
        guard let e=selectedEntry() else{return nil};let menu=NSMenu();let target=ContextTarget(entry:e,token:queryToken)
        for (title,action) in [(tr("打开"),#selector(contextOpen(_:))),(tr("复制路径"),#selector(contextCopy(_:))),(tr("在 Finder 中显示"),#selector(contextReveal(_:)))]{let item=NSMenuItem(title:title,action:action,keyEquivalent:"");item.target=self;item.representedObject=target;menu.addItem(item)}
        return menu
    }
    func contextEntry(_ item:NSMenuItem)->FileEntry?{guard let target=item.representedObject as? ContextTarget,target.token==queryToken,displayed.contains(where:{$0.path==target.entry.path && $0.identity==target.entry.identity}) else{return nil};return target.entry}
    func validateMenuItem(_ menuItem:NSMenuItem)->Bool{contextEntry(menuItem) != nil}
    @objc func contextOpen(_ item:NSMenuItem){if let e=contextEntry(item){performOpen(e)}}
    @objc func contextReveal(_ item:NSMenuItem){if let e=contextEntry(item){performReveal(e)}}
    @objc func contextCopy(_ item:NSMenuItem){if let e=contextEntry(item){copyPath(e.path);status.stringValue=tr("已复制完整路径")}}
    func windowShouldClose(_ sender:NSWindow)->Bool{if desktop{owner?.setDesktop(false)}else{window.orderOut(nil)};return false}
    func windowDidMove(_ notification:Notification){if desktop{owner?.preferences.desktopFrame=window.frameDescriptor;owner?.savePreferences()}}
    func windowDidResize(_ notification:Notification){if scrollFullHeight != nil{updateLayout()};windowDidMove(notification)}
}
