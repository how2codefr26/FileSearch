import Foundation
import CoreServices

final class IndexService:@unchecked Sendable {
    let queue=DispatchQueue(label:"local.filesearch.index",qos:.utility)
    let directory:URL;let sampleRoot:String
    var onUpdate:(([RootScope],SearchSnapshot?,String,[String])->Void)?
    private var store:IndexStore?;private var roots=[RootScope]();private var snapshot:SearchSnapshot?
    private var stream:FSEventStreamRef?;private var dirty=Set<String>();private var latest:UInt64=0;private var paused=false;private var scheduled:DispatchWorkItem?
    private var failed=[String]();private var stopping=false;private var notifiedHistory=false;private var watching=false
    init(directory:URL,sampleRoot:String){self.directory=directory;self.sampleRoot=sampleRoot}
    func emit(_ state:String){let r=roots,s=snapshot,f=failed;let label=(!watching && !roots.isEmpty) ? state+" · 通知不可用，请手动核对":state;DispatchQueue.main.async{[weak self] in self?.onUpdate?(r,s,label,f)}}
    func start(){queue.async{[self] in
        do{
            let s=try IndexStore(directory:directory);store=s
            if s.meta("initialized")==nil {try s.addRoot(sampleRoot,sample:true);try s.setMeta("initialized","1")}
            roots=try s.roots();latest=UInt64(s.meta("event_id") ?? "0") ?? 0
            var cache=try? SearchSnapshot(url:directory.appendingPathComponent("snapshot.bin"))
            if (cache==nil || cache?.generation != s.generation),s.meta("baseline_complete")=="1"{cache=try s.writeSnapshot()}
            if let cache,cache.generation==s.generation{snapshot=cache;emit("正在核对退出期间的变化…")}
            if !startStream(since:snapshot==nil ? UInt64(kFSEventStreamEventIdSinceNow):latest){emit("文件通知不可用；可手动重新核对目录。")}
            if snapshot==nil {latest=FSEventsGetCurrentEventId();rescanAll()}else if roots.isEmpty{emit("请添加搜索目录。")}
        }catch{emit("索引无法载入：\(error)")}
    }}
    private func startStream(since:UInt64)->Bool{
        stopStream();guard !roots.isEmpty else{return true};notifiedHistory=false
        var context=FSEventStreamContext(version:0,info:Unmanaged.passUnretained(self).toOpaque(),retain:nil,release:nil,copyDescription:nil)
        stream=FSEventStreamCreate(nil,{_,info,n,paths,flags,ids in
            let owner=Unmanaged<IndexService>.fromOpaque(info!).takeUnretainedValue();let p=paths.assumingMemoryBound(to:UnsafePointer<CChar>.self)
            for i in 0..<n {owner.received(String(cString:p[i]),flags:flags[i],id:ids[i])}
        },&context,roots.map{$0.path} as CFArray,since,0.10,FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents|kFSEventStreamCreateFlagWatchRoot|kFSEventStreamCreateFlagNoDefer))
        guard let stream else{return false};FSEventStreamSetDispatchQueue(stream,queue);watching=FSEventStreamStart(stream);return watching
    }
    private func stopStream(){watching=false;if let stream{FSEventStreamStop(stream);FSEventStreamInvalidate(stream);FSEventStreamRelease(stream);self.stream=nil}}
    private func received(_ path:String,flags:UInt32,id:UInt64){
        guard !stopping else{return}
        if flags & UInt32(kFSEventStreamEventFlagHistoryDone) != 0 {
            notifiedHistory=true;if dirty.isEmpty && snapshot != nil{emit(failed.isEmpty ? "范围已核对":"部分位置不可访问")};return
        }
        if path==directory.path || path.hasPrefix(directory.path+"/"){return}
        latest=max(latest,id)
        let all=UInt32(kFSEventStreamEventFlagMustScanSubDirs|kFSEventStreamEventFlagUserDropped|kFSEventStreamEventFlagKernelDropped|kFSEventStreamEventFlagEventIdsWrapped|kFSEventStreamEventFlagRootChanged)
        if flags & all != 0 {for r in roots{dirty.insert(r.path)}}else{
            for r in roots where path==r.path || path.hasPrefix(r.path=="/" ? "/":r.path+"/") {
                let parent=(path as NSString).deletingLastPathComponent;dirty.insert(parent.count>=r.path.count ? parent:r.path)
            }
        }
        if dirty.count>200{dirty=Set(roots.map{$0.path})}
        scheduleReconcile()
    }
    private func scheduleReconcile(){
        guard !paused else{emit("已暂停，结果可能过期");return};scheduled?.cancel()
        let work=DispatchWorkItem{[weak self] in self?.reconcileDirty()};scheduled=work;queue.asyncAfter(deadline:.now()+0.15,execute:work)
    }
    private func reconcileDirty(){
        guard let store,!paused,!stopping,!dirty.isEmpty else{return}
        let pending=dirty.sorted{$0.count<$1.count};dirty=[];var minimal=[String]()
        for p in pending where !minimal.contains(where:{p==$0 || p.hasPrefix($0=="/" ? "/":$0+"/")}){minimal.append(p)}
        emit("正在更新文件位置…")
        do{
            let previous=UInt64(store.meta("event_id") ?? "0") ?? 0
            for path in minimal {
                guard let root=roots.first(where:{path==$0.path || path.hasPrefix($0.path=="/" ? "/":$0.path+"/")}) else{continue}
                let result=scanDirectory(path,root:root,excluded:[directory.path]);failed.removeAll{$0==path || $0.hasPrefix(path+"/")};failed+=result.failures
                try store.reconcile(path,root:root,result:result,event:previous)
            }
            try store.setMeta("event_id",String(latest))
            snapshot=try store.writeSnapshot();emit(failed.isEmpty ? "范围已核对":"部分位置不可访问")
        }catch{emit("更新未完成：\(error)")}
    }
    private func rescanAll(){
        guard let store,!stopping else{return};emit("正在收录所选目录…");failed=[]
        do{
            let previous=UInt64(store.meta("event_id") ?? "0") ?? 0
            for r in roots {let result=scanDirectory(r.path,root:r,excluded:[directory.path]);failed+=result.failures;try store.reconcile(r.path,root:r,result:result,event:previous)}
            try store.setMeta("event_id",String(latest));try store.setMeta("baseline_complete","1")
            snapshot=try store.writeSnapshot();emit(failed.isEmpty ? "范围已核对":"部分位置不可访问")
        }catch{emit("收录未完成：\(error)")}
    }
    func refresh(){queue.async{[self] in rescanAll()}}
    func setPaused(_ value:Bool){queue.async{[self] in paused=value;if value{scheduled?.cancel();emit("已暂停，结果可能过期")}else{if dirty.isEmpty{dirty=Set(roots.map{$0.path})};scheduleReconcile()}}}
    func addRoot(_ url:URL){queue.async{[self] in
        do{
            let p=url.resolvingSymlinksInPath().standardizedFileURL.path
            let volume=try url.resourceValues(forKeys:[.volumeIsInternalKey,.volumeIsLocalKey])
            guard volume.volumeIsLocal==true,volume.volumeIsInternal==true else{throw SearchFailure.message("此开发版仅支持本机内置磁盘目录。外置与网络磁盘暂未验收。")}
            guard p != directory.path && !p.hasPrefix(directory.path+"/") else{throw SearchFailure.message("索引数据目录不能作为搜索范围。")}
            if roots.contains(where:{p==$0.path || p.hasPrefix($0.path=="/" ? "/":$0.path+"/") || currentIdentity(p)==currentIdentity($0.path)}){emit("该目录已包含在现有范围中。");return}
            try store?.addRoot(p,sample:false);roots=try store?.roots() ?? [];latest=FSEventsGetCurrentEventId();_ = startStream(since:latest);rescanAll()
        }catch{emit("添加目录失败：\(error)")}
    }}
    func removeRoot(_ id:UInt32){queue.async{[self] in do{try store?.removeRoot(id);roots=try store?.roots() ?? [];_ = startStream(since:latest);rescanAll()}catch{emit("移除目录失败：\(error)")}}}
    func shutdown(_ completion:@escaping()->Void){queue.async{[self] in
        stopping=true;scheduled?.cancel();stopStream();store=nil
        // AppKit may run a nested termination loop inside a main-queue callback.
        // Reply on the main run loop so the serial main queue cannot block its own reply.
        RunLoop.main.perform(inModes:[.common]){completion()}
    }}
}
