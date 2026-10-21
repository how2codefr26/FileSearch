import Foundation
import SQLite3

private let sqlTransient=unsafeBitCast(-1,to:sqlite3_destructor_type.self)
final class IndexStore {
    var db:OpaquePointer?;let directory:URL
    init(directory:URL)throws{
        self.directory=directory;try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        guard sqlite3_open_v2(directory.appendingPathComponent("index.sqlite").path,&db,SQLITE_OPEN_CREATE|SQLITE_OPEN_READWRITE,nil)==SQLITE_OK else{throw SearchFailure.message("无法打开本地索引。")}
        try run("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=3000; CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY,value TEXT NOT NULL); CREATE TABLE IF NOT EXISTS roots(id INTEGER PRIMARY KEY AUTOINCREMENT,path TEXT UNIQUE NOT NULL,sample INTEGER NOT NULL,volume TEXT NOT NULL); CREATE TABLE IF NOT EXISTS entries(id INTEGER PRIMARY KEY,root INTEGER NOT NULL,path TEXT UNIQUE NOT NULL,name TEXT NOT NULL,norm TEXT NOT NULL,kind INTEGER NOT NULL,modified INTEGER NOT NULL,dev INTEGER NOT NULL,ino INTEGER NOT NULL); CREATE INDEX IF NOT EXISTS by_root ON entries(root);")
    }
    deinit{sqlite3_close(db)}
    func run(_ sql:String)throws{if sqlite3_exec(db,sql,nil,nil,nil) != SQLITE_OK{throw SearchFailure.message(String(cString:sqlite3_errmsg(db)))}}
    func statement(_ sql:String)throws->OpaquePointer{
        var s:OpaquePointer?;guard sqlite3_prepare_v2(db,sql,-1,&s,nil)==SQLITE_OK,let s else{throw SearchFailure.message(String(cString:sqlite3_errmsg(db)))};return s
    }
    func bind(_ s:OpaquePointer,_ i:Int32,_ value:String){sqlite3_bind_text(s,i,value,-1,sqlTransient)}
    func string(_ s:OpaquePointer,_ i:Int32)->String{guard let p=sqlite3_column_text(s,i) else{return ""};return String(cString:p)}
    func meta(_ key:String)->String?{
        guard let s=try? statement("SELECT value FROM meta WHERE key=?") else{return nil};defer{sqlite3_finalize(s)};bind(s,1,key)
        return sqlite3_step(s)==SQLITE_ROW ? string(s,0):nil
    }
    func setMeta(_ key:String,_ value:String)throws{
        let s=try statement("INSERT INTO meta VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");defer{sqlite3_finalize(s)};bind(s,1,key);bind(s,2,value)
        guard sqlite3_step(s)==SQLITE_DONE else{throw SearchFailure.message("无法保存索引进度。")}
    }
    var generation:UInt64{UInt64(meta("generation") ?? "0") ?? 0}
    func roots()throws->[RootScope]{
        let s=try statement("SELECT id,path,sample,volume FROM roots ORDER BY id");defer{sqlite3_finalize(s)};var values=[RootScope]()
        var step=sqlite3_step(s)
        while step==SQLITE_ROW {values.append(RootScope(id:UInt32(sqlite3_column_int64(s,0)),path:string(s,1),sample:sqlite3_column_int(s,2) != 0,volume:string(s,3)));step=sqlite3_step(s)};guard step==SQLITE_DONE else{throw SearchFailure.message("无法读取搜索范围。")};return values
    }
    func addRoot(_ path:String,sample:Bool)throws{
        let vol=(try? URL(fileURLWithPath:path).resourceValues(forKeys:[.volumeUUIDStringKey]).volumeUUIDString) ?? "unknown"
        let s=try statement("INSERT OR IGNORE INTO roots(path,sample,volume) VALUES(?,?,?)");defer{sqlite3_finalize(s)};bind(s,1,path);sqlite3_bind_int(s,2,sample ? 1:0);bind(s,3,vol)
        guard sqlite3_step(s)==SQLITE_DONE else{throw SearchFailure.message("无法保存搜索目录。")}
    }
    func removeRoot(_ id:UInt32)throws{
        try run("BEGIN IMMEDIATE")
        do{try run("DELETE FROM entries WHERE root=\(id);DELETE FROM roots WHERE id=\(id)");try setMeta("generation",String(generation+1));try run("COMMIT")}catch{try? run("ROLLBACK");throw error}
    }
    func reconcile(_ scope:String,root:RootScope,result:ScanResult,event:UInt64)throws{
        try run("BEGIN IMMEDIATE")
        do{
            let del=try statement("DELETE FROM entries WHERE root=? AND (path=? OR substr(path,1,?)=?)")
            sqlite3_bind_int64(del,1,Int64(root.id));bind(del,2,scope);sqlite3_bind_int(del,3,Int32(scope.unicodeScalars.count+(scope=="/" ? 0:1)));bind(del,4,scope=="/" ? "/":scope+"/")
            guard sqlite3_step(del)==SQLITE_DONE else{sqlite3_finalize(del);throw SearchFailure.message("无法更新目录范围。")};sqlite3_finalize(del)
            let up=try statement("INSERT INTO entries(root,path,name,norm,kind,modified,dev,ino) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(path) DO UPDATE SET root=excluded.root,name=excluded.name,norm=excluded.norm,kind=excluded.kind,modified=excluded.modified,dev=excluded.dev,ino=excluded.ino")
            defer{sqlite3_finalize(up)}
            for e in result.entries{
                sqlite3_reset(up);sqlite3_clear_bindings(up);sqlite3_bind_int64(up,1,Int64(e.root));bind(up,2,e.path);bind(up,3,e.name);bind(up,4,e.norm);sqlite3_bind_int64(up,5,Int64(e.kind));sqlite3_bind_int64(up,6,e.modified);sqlite3_bind_int64(up,7,Int64(bitPattern:e.dev));sqlite3_bind_int64(up,8,Int64(bitPattern:e.ino))
                guard sqlite3_step(up)==SQLITE_DONE else{throw SearchFailure.message("无法写入目录索引。")}
            }
            try setMeta("generation",String(generation+1));try setMeta("event_id",String(event));try run("COMMIT")
        }catch{try? run("ROLLBACK");throw error}
    }
    func writeSnapshot()throws->SearchSnapshot{
        var pool=Data(),rowBytes=Data(),parentBytes=Data(),parentIDs=[String:UInt32]();var count:UInt64=0
        func add(_ s:String)throws->(UInt32,UInt32){let b=Data(s.utf8);guard pool.count+b.count<Int(UInt32.max) else{throw SearchFailure.message("当前缓存格式超过容量，请缩小搜索范围。")};let o=UInt32(pool.count);pool.append(b);return(o,UInt32(b.count))}
        let s=try statement("SELECT id,root,path,name,norm,kind,modified,dev,ino FROM entries ORDER BY id");defer{sqlite3_finalize(s)}
        var step=sqlite3_step(s)
        while step==SQLITE_ROW {
            let path=string(s,2),name=string(s,3),norm=string(s,4),parent=(path as NSString).deletingLastPathComponent
            let parentID:UInt32
            if let id=parentIDs[parent]{parentID=id}else{
                parentID=UInt32(parentIDs.count);parentIDs[parent]=parentID
                let a=try add(parent),b=parent.utf8.elementsEqual(canonical(parent).utf8) ? a:try add(canonical(parent));var p=PackedParent(rawOff:a.0,rawLen:a.1,normOff:b.0,normLen:b.1);parentBytes.append(Data(bytes:&p,count:16))
            }
            let a=try add(name),b=name.utf8.elementsEqual(norm.utf8) ? a:try add(norm)
            var r=PackedEntry(rawOff:a.0,rawLen:a.1,normOff:b.0,normLen:b.1,parent:parentID,kind:UInt32(sqlite3_column_int64(s,5)),root:UInt32(sqlite3_column_int64(s,1)),reserved:0,id:sqlite3_column_int64(s,0),modified:sqlite3_column_int64(s,6),dev:UInt64(bitPattern:sqlite3_column_int64(s,7)),ino:UInt64(bitPattern:sqlite3_column_int64(s,8)))
            rowBytes.append(Data(bytes:&r,count:64));count+=1;step=sqlite3_step(s)
        }
        guard step==SQLITE_DONE else{throw SearchFailure.message("索引读取失败，保留原有搜索缓存。")}
        var file=Data("MACIDX02".utf8)
        for var value in [count,UInt64(parentIDs.count),UInt64(pool.count),generation]{file.append(Data(bytes:&value,count:8))}
        file.append(rowBytes);file.append(parentBytes);file.append(pool)
        let destination=directory.appendingPathComponent("snapshot.bin");try file.write(to:destination,options:.atomic)
        return try SearchSnapshot(url:destination)
    }
}
