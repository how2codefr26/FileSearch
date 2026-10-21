import Foundation
import SQLite3

@main struct CoreTests {
    static func main()throws {
        let workspace=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
        let testDir=workspace.appendingPathComponent("app/testdata/"+UUID().uuidString);let rootDir=testDir.appendingPathComponent("测试 100%_目录");let state=testDir.appendingPathComponent("state")
        try FileManager.default.createDirectory(at:rootDir,withIntermediateDirectories:true)
        let files=["计划.xlsx","计划.XLS","计划.xlsm","计划.xml","计划.txt","xlsx无后缀","笔记.pdf","大写笔记.PDF","笔记.tar.gz","笔记.gz","笔记.txt","归档 周末 笔记.pdf","周末 笔记.txt","cafe\u{301}.txt","e.txt",".gitignore",".config.json","100%_笔记.txt","AND.txt","literal*?.txt"]
        for n in files{try Data().write(to:rootDir.appendingPathComponent(n))}
        try FileManager.default.createDirectory(at:rootDir.appendingPathComponent("笔记文件夹"),withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:rootDir.appendingPathComponent("Demo.app/Contents"),withIntermediateDirectories:true)
        try Data().write(to:rootDir.appendingPathComponent("Demo.app/Contents/not-indexed.txt"))
        try FileManager.default.linkItem(at:rootDir.appendingPathComponent("笔记.pdf"),to:rootDir.appendingPathComponent("硬链接.pdf"))
        try FileManager.default.createSymbolicLink(at:rootDir.appendingPathComponent("loop"),withDestinationURL:rootDir)
        let store=try IndexStore(directory:state);try store.addRoot(rootDir.path,sample:false);let root=try store.roots()[0]
        let scan=scanDirectory(root.path,root:root,excluded:[state.path]);try store.reconcile(root.path,root:root,result:scan,event:10);var snapshot=try store.writeSnapshot()
        var checks=[[String:Any]]()
        func check(_ label:String,_ condition:Bool){if !condition { FileHandle.standardError.write(Data(("FAILED " + label + "\n").utf8)); exit(1) };checks.append(["case":label,"passed":condition]);print("OK \(label)")}
        func names(_ text:String,_ suffix:String="",_ kind:Int = -1)throws->Set<String>{Set(snapshot.search(SearchOptions(text:text,suffixes:try SuffixFilter(suffix).values,kind:kind,roots:[root.id]))!.entries.map{$0.name})}
        check("empty-query",try names(" ").isEmpty)
        check("suffix-custom-OR",try names("笔记","pdf, .tar.gz")==["笔记.pdf","大写笔记.PDF","笔记.tar.gz","归档 周末 笔记.pdf"])
        check("compound-suffix-boundary",try names("笔记","tar.gz")==["笔记.tar.gz"])
        check("suffix-single-last-segment",try names("笔记","gz")==["笔记.gz","笔记.tar.gz"])
        check("suffix-prefix-x",try names("计划","x")==["计划.xlsx","计划.XLS","计划.xlsm","计划.xml"])
        check("suffix-prefix-xl",try names("计划","xl")==["计划.xlsx","计划.XLS","计划.xlsm"])
        check("suffix-prefix-xlsx",try names("计划","xlsx")==["计划.xlsx"])
        check("suffix-only-no-name",try names("","XL")==["计划.xlsx","计划.XLS","计划.xlsm"])
        check("suffix-prefix-multiple",try names("计划","xl, t")==["计划.xlsx","计划.XLS","计划.xlsm","计划.txt"])
        check("suffix-prefix-compound",try names("笔记","tar.g")==["笔记.tar.gz"])
        check("suffix-prefix-compound-dot",try names("笔记","tar.")==["笔记.tar.gz"])
        check("suffix-prefix-no-extension-excluded",try names("无后缀","x").isEmpty)
        check("suffix-prefix-folder-excluded",try names("笔记","p",1).isEmpty)
        check("multiword-AND",try names("周末 笔记")==["周末 笔记.txt","归档 周末 笔记.pdf"])
        check("NFC",try names("café")==["cafe\u{301}.txt"])
        check("hidden-no-extension",try names("gitignore","gitignore").isEmpty)
        check("suffix-excludes-folder",try names("笔记","pdf",1).isEmpty)
        check("literal-symbol",try names("%")==["100%_笔记.txt"])
        check("literal-boolean",try names("AND")==["AND.txt"])
        check("literal-wildcards",try names("*?")==["literal*?.txt"])
        check("package-leaf",!scan.entries.contains{$0.path.contains("Demo.app/")})
        check("symlink-leaf",scan.entries.filter{$0.kind==3}.count==1)
        check("hardlink-two-paths",scan.entries.first{$0.name=="笔记.pdf"}!.identity==scan.entries.first{$0.name=="硬链接.pdf"}!.identity)
        check("exclude-all-roots",snapshot.search(SearchOptions(text:"笔记",roots:[]))!.total==0)
        for invalid in [".","../pdf","pdf/", "*.pdf", "tar..gz", "pdf\\txt"] {do{_ = try SuffixFilter(invalid);check("invalid-\(invalid)",false)}catch{check("invalid-\(invalid)",true)}}
        check("suffix-normalization",try SuffixFilter(" PDF，.pdf; tar.gz ").values==["pdf","tar.gz"])
        let prefURL=state.appendingPathComponent("prefs.json");let pref=Preferences(details:true,density:.spacious,desktop:true,desktopFrame:"test-frame");try pref.save(to:prefURL);check("preferences-roundtrip",Preferences.load(from:prefURL)==pref)
        check("default-layout",Preferences().details==false && Preferences().density == .standard && Preferences().desktop==false)
        let legacy=Data(#"{"details":true,"density":"compact","desktop":true,"desktopFrame":"old-position"}"#.utf8)
        let migrated=try JSONDecoder().decode(Preferences.self,from:legacy)
        check("legacy-preferences-preserved",migrated.details && migrated.density == .compact && migrated.desktop && migrated.desktopFrame=="old-position")
        check("legacy-glass-defaults",migrated.desktopGlass && migrated.desktopOpacity==0.85)
        var custom=migrated;custom.desktopGlass=false;custom.desktopOpacity=0.42;try custom.save(to:prefURL)
        check("desktop-appearance-roundtrip",Preferences.load(from:prefURL)==custom)
        let clipped=try JSONDecoder().decode(Preferences.self,from:Data(#"{"desktopOpacity":-100}"#.utf8))
        check("desktop-opacity-clamped",clipped.desktopOpacity==0.3)
        check("legacy-language-default",migrated.language == .simplifiedChinese)
        custom.language = .english;try custom.save(to:prefURL)
        check("language-persisted",Preferences.load(from:prefURL).language == .english)
        let unknownLanguage=try JSONDecoder().decode(Preferences.self,from:Data(#"{"language":"future","details":true}"#.utf8))
        check("unknown-language-preserves-settings",unknownLanguage.language == .simplifiedChinese && unknownLanguage.details)
        L10n.language = .english
        check("english-dynamic-state",L10n.message("范围已核对 · 通知不可用，请手动核对")=="Index up to date · Notifications unavailable; refresh manually")
        check("english-result-format",trf("%d 项结果 · 已显示 %d 项",12,5)=="12 results · Showing 5")
        check("english-file-type",snapshot.search(SearchOptions(text:"笔记",suffixes:["pdf"],roots:[root.id]))!.entries.first!.kindLabel=="File")
        L10n.language = .simplifiedChinese
        check("checkpoint-not-advanced",store.meta("event_id")=="10")
        let cacheURL=state.appendingPathComponent("snapshot.bin");try Data("broken".utf8).write(to:cacheURL)
        do{_ = try SearchSnapshot(url:cacheURL);check("corrupt-cache-rejected",false)}catch{check("corrupt-cache-rejected",true)}
        snapshot=try store.writeSnapshot();check("cache-rebuild-from-sqlite",snapshot.count==scan.entries.count)
        let gate=CancellationGate();let old=gate.next();_ = gate.next();check("obsolete-query-cancelled",snapshot.search(SearchOptions(text:"笔记",roots:[root.id]),gate:gate,token:old)==nil)

        // A real event -> dirty-directory -> SQLite -> packed snapshot -> query loop.
        var latest:SearchSnapshot?;var roots=[RootScope]();var phase="";var updates=0
        var service:IndexService?=IndexService(directory:testDir.appendingPathComponent("live-state"),sampleRoot:rootDir.path)
        func connect(){service!.onUpdate={r,s,status,_ in roots=r;latest=s;phase=status;updates+=1};service!.start()}
        func wait(_ label:String,_ predicate:()->Bool){let deadline=Date().addingTimeInterval(10);while !predicate() && Date()<deadline{RunLoop.current.run(until:Date().addingTimeInterval(0.01))};check(label,predicate())}
        connect();wait("live-initial",{latest != nil})
        let currentRoot=roots[0].id
        func contains(_ term:String)->Bool{(latest?.search(SearchOptions(text:term,roots:[currentRoot]))?.total ?? 0)>0}
        let supportsEvents = !phase.contains("通知不可用")
        if supportsEvents {
            try Data().write(to:rootDir.appendingPathComponent("增量新增.pdf"));wait("live-create",{contains("增量新增")})
            try FileManager.default.moveItem(at:rootDir.appendingPathComponent("增量新增.pdf"),to:rootDir.appendingPathComponent("增量改名.pdf"));wait("live-rename",{contains("增量改名") && !contains("增量新增")})
            try FileManager.default.removeItem(at:rootDir.appendingPathComponent("增量改名.pdf"));wait("live-delete",{!contains("增量改名")})
            service!.setPaused(true);wait("pause-status",{phase.contains("已暂停")});try Data().write(to:rootDir.appendingPathComponent("暂停期间.txt"));RunLoop.current.run(until:Date().addingTimeInterval(0.4));check("paused-no-new-rows",!contains("暂停期间"));service!.setPaused(false);wait("resume-catches-up",{contains("暂停期间")})
        }
        var stopped=false;service!.shutdown{stopped=true};wait("service-stops",{stopped});service=nil
        try Data().write(to:rootDir.appendingPathComponent("退出期间新增.txt"));latest=nil
        service=IndexService(directory:testDir.appendingPathComponent("live-state"),sampleRoot:rootDir.path);connect();wait("persisted-restart",{latest != nil})
        if supportsEvents{wait("history-replay-after-exit",{contains("退出期间新增")})}
        stopped=false;service!.shutdown{stopped=true};wait("final-stop",{stopped})
        let migration=testDir.appendingPathComponent("migration"),previous=migration.appendingPathComponent("OldSamples"),updated=migration.appendingPathComponent("NewSamples"),personal=migration.appendingPathComponent("MyFiles"),migrationState=migration.appendingPathComponent("state")
        for folder in [previous,updated,personal]{try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)}
        for (folder,name) in [(previous,"Old sample.txt"),(updated,"Weekend notes.txt"),(personal,"My notes.txt")]{try Data("fixture".utf8).write(to:folder.appendingPathComponent(name))}
        do{
            let prior=try IndexStore(directory:migrationState)
            try prior.addRoot(previous.path,sample:true);try prior.addRoot(personal.path,sample:false)
            for root in try prior.roots(){try prior.reconcile(root.path,root:root,result:scanDirectory(root.path,root:root),event:0)}
            try prior.setMeta("initialized","1");try prior.setMeta("baseline_complete","1");try prior.setMeta("sample_revision","old");_ = try prior.writeSnapshot()
        }
        latest=nil;roots=[]
        service=IndexService(directory:migrationState,sampleRoot:updated.path,sampleRevision:"general-v1");connect();wait("sample-migration-start",{latest != nil})
        let migratedNames=Set(latest!.search(SearchOptions(text:"",suffixes:["txt"],roots:Set(roots.map{$0.id})))!.entries.map{$0.name})
        check("sample-migration-removes-old-results",migratedNames==["Weekend notes.txt","My notes.txt"])
        check("sample-migration-preserves-user-root",roots.contains{$0.path==personal.path && !$0.sample})
        check("sample-migration-preserves-files",FileManager.default.fileExists(atPath:personal.appendingPathComponent("My notes.txt").path) && FileManager.default.fileExists(atPath:previous.appendingPathComponent("Old sample.txt").path))
        service!.removeRoot(roots.first{$0.sample}!.id);wait("sample-removal-honored",{!roots.contains{$0.sample}})
        stopped=false;service!.shutdown{stopped=true};wait("migration-stop",{stopped})
        latest=nil;service=IndexService(directory:migrationState,sampleRoot:updated.path,sampleRevision:"general-v1");connect();wait("sample-removed-restart",{latest != nil})
        check("removed-samples-not-reintroduced",!roots.contains{$0.sample})
        stopped=false;service!.shutdown{stopped=true};wait("migration-final-stop",{stopped})
        let result:[String:Any]=["checks":checks,"count":checks.count,"automatic_fsevents_tested":supportsEvents,"fixture":rootDir.path,"live_updates":updates,"last_state":phase]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:workspace.appendingPathComponent("app/results/core-tests.json"))
        print("\(checks.count) checks passed; FSEvents=\(supportsEvents)")
    }
}
