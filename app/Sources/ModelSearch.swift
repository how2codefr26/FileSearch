import Foundation
import Darwin

func canonical(_ s:String)->String {
    String(String.UnicodeScalarView(s.precomposedStringWithCanonicalMapping.unicodeScalars.map { $0.value >= 65 && $0.value <= 90 ? UnicodeScalar($0.value+32)! : $0 }))
}
enum SearchFailure:Error,CustomStringConvertible {
    case message(String)
    var description:String { if case .message(let m)=self{return m};return "无法完成操作" }
}
struct SuffixFilter:Equatable {
    let values:[String]
    init(_ raw:String)throws {
        let parts=canonical(raw).split { $0.isWhitespace || ",;，；".contains($0) }.map(String.init)
        var unique=[String]()
        for var p in parts {
            if p.hasPrefix("."){p.removeFirst()}
            guard !p.isEmpty,!p.contains(where:{"/\\*?\"'\0".contains($0)}),!p.hasPrefix("."),!p.contains("..") else {
                throw SearchFailure.message("请输入有效后缀，例如 pdf、xlsx、tar.gz；多个后缀用逗号或空格分隔。")
            }
            if !unique.contains(p){unique.append(p)}
        }
        values=unique
    }
}
struct FileEntry:Equatable {
    var id:Int64=0; var root:UInt32; var path:String;var name:String;var norm:String;var kind:UInt32;var modified:Int64;var dev:UInt64;var ino:UInt64
    var identity:String { "\(dev):\(ino)" }
    var parent:String { (path as NSString).deletingLastPathComponent }
    var kindLabel:String {
        if L10n.language == .english{return kind==1 ? "Folder":kind==2 ? "Package":kind==3 ? "Link":"File"}
        return kind==1 ? "文件夹":kind==2 ? "软件包":kind==3 ? "链接":"文件"
    }
}
struct RootScope { var id:UInt32;var path:String;var sample:Bool;var volume:String }
struct SearchOptions { var text:String;var suffixes:[String]=[];var kind:Int = -1;var roots:Set<UInt32>=[];var sort:String="relevance";var limit:Int=50 }
struct SearchPage {var entries:[FileEntry];var total:Int;var generation:UInt64}
final class CancellationGate:@unchecked Sendable {
    private let lock=NSLock();private var value=0
    func next()->Int{lock.lock();defer{lock.unlock()};value+=1;return value}
    func valid(_ token:Int)->Bool{lock.lock();defer{lock.unlock()};return value==token}
}
// Versioned private cache. Canonical SQLite state is always the rebuild source.
struct PackedEntry {
    var rawOff,rawLen,normOff,normLen,parent,kind,root,reserved:UInt32
    var id:Int64;var modified:Int64;var dev:UInt64;var ino:UInt64
}
struct PackedParent {var rawOff,rawLen,normOff,normLen:UInt32}
struct Ranked {var row:Int;var rank:Int}
final class SearchSnapshot:@unchecked Sendable {
    let storage:NSData;let base:UnsafeRawPointer;let rows:UnsafePointer<PackedEntry>;let parents:UnsafePointer<PackedParent>;let pool:UnsafePointer<UInt8>
    let count:Int;let parentCount:Int;let generation:UInt64
    init(url:URL)throws {
        storage=try NSData(contentsOf:url,options:.alwaysMapped);base=storage.bytes
        guard storage.length>=40,MemoryLayout<PackedEntry>.stride==64 else{throw SearchFailure.message("索引缓存头不完整，需要重建。")}
        guard memcmp(base,"MACIDX02",8)==0 else{throw SearchFailure.message("索引缓存版本不匹配，需要重建。")}
        let n=base.load(fromByteOffset:8,as:UInt64.self),d=base.load(fromByteOffset:16,as:UInt64.self),b=base.load(fromByteOffset:24,as:UInt64.self)
        guard n<=UInt64((storage.length-40)/64),d<=UInt64(storage.length/16),b<=UInt64(storage.length),40+n*64+d*16+b==UInt64(storage.length) else{throw SearchFailure.message("索引缓存长度不一致，需要重建。")}
        count=Int(n);parentCount=Int(d);generation=base.load(fromByteOffset:32,as:UInt64.self)
        rows=base.advanced(by:40).assumingMemoryBound(to:PackedEntry.self);parents=base.advanced(by:40+count*64).assumingMemoryBound(to:PackedParent.self);pool=base.advanced(by:40+count*64+parentCount*16).assumingMemoryBound(to:UInt8.self)
        func bounds(_ o:UInt32,_ l:UInt32)->Bool{UInt64(o)+UInt64(l)<=b}
        for i in 0..<parentCount {let x=parents[i];guard bounds(x.rawOff,x.rawLen),bounds(x.normOff,x.normLen) else{throw SearchFailure.message("父目录缓存损坏，需要重建。")}}
        for i in 0..<count {let x=rows[i];guard Int(x.parent)<parentCount,bounds(x.rawOff,x.rawLen),bounds(x.normOff,x.normLen),x.kind<=3 else{throw SearchFailure.message("条目缓存损坏，需要重建。")}}
    }
    func text(_ o:UInt32,_ l:UInt32)->String{String(decoding:UnsafeBufferPointer(start:pool.advanced(by:Int(o)),count:Int(l)),as:UTF8.self)}
    func path(_ i:Int,normalized:Bool=false)->String{
        let r=rows[i],p=parents[Int(r.parent)]
        return normalized ? text(p.normOff,p.normLen)+"/"+text(r.normOff,r.normLen) : text(p.rawOff,p.rawLen)+"/"+text(r.rawOff,r.rawLen)
    }
    func entry(_ i:Int)->FileEntry {
        let r=rows[i];return FileEntry(id:r.id,root:r.root,path:path(i),name:text(r.rawOff,r.rawLen),norm:text(r.normOff,r.normLen),kind:r.kind,modified:r.modified,dev:r.dev,ino:r.ino)
    }
    func compare(_ a:Ranked,_ b:Ranked,_ sort:String)->Bool{
        let x=rows[a.row],y=rows[b.row]
        if sort=="relevance" && a.rank != b.rank{return a.rank<b.rank}
        if sort=="name" {
            let n=min(Int(x.normLen),Int(y.normLen));let c=memcmp(pool.advanced(by:Int(x.normOff)),pool.advanced(by:Int(y.normOff)),n)
            if c != 0{return c<0};if x.normLen != y.normLen{return x.normLen<y.normLen}
        }else if x.modified != y.modified{return x.modified>y.modified}
        let ap=path(a.row,normalized:true),bp=path(b.row,normalized:true)
        if ap != bp{return ap.utf8.lexicographicallyPrecedes(bp.utf8)}
        return path(a.row).utf8.lexicographicallyPrecedes(path(b.row).utf8)
    }
    func search(_ q:SearchOptions,gate:CancellationGate?=nil,token:Int=0)->SearchPage? {
        let words=canonical(q.text).split(whereSeparator:{$0.isWhitespace}).map(String.init)
        if words.isEmpty && q.suffixes.isEmpty{return SearchPage(entries:[],total:0,generation:generation)}
        let terms=words.map{Data($0.utf8) as NSData},phrase=Data(words.joined(separator:" ").utf8) as NSData
        let suffixes=q.suffixes.map{Data(("."+$0).utf8) as NSData}
        let limit=max(1,min(q.limit,500));var heap=[Ranked]();heap.reserveCapacity(limit);var total=0
        for i in 0..<count {
            if i%4096==0,let gate,!gate.valid(token){return nil}
            let r=rows[i]
            if !q.roots.contains(r.root){continue}
            if (q.kind==0 && r.kind != 0 && r.kind != 2)||(q.kind==1 && r.kind != 1){continue}
            let name=pool.advanced(by:Int(r.normOff)),len=Int(r.normLen)
            if !suffixes.isEmpty {
                if r.kind != 0 && r.kind != 2{continue}
                // Every non-leading dot begins a possible suffix chain, including tar.gz.
                // Match its prefix while typing, without allocating a String for each row.
                if !suffixes.contains(where:{len>$0.length && memmem(name.advanced(by:1),len-1,$0.bytes,$0.length) != nil}){continue}
            }
            var matches=true
            for t in terms {if memmem(name,len,t.bytes,t.length)==nil{matches=false;break}}
            if !matches{continue};total+=1
            let p=phrase.length==0 ? nil:memmem(name,len,phrase.bytes,phrase.length),atStart=p != nil && p==UnsafeMutableRawPointer(mutating:name)
            let hit=Ranked(row:i,rank:atStart ? (len==phrase.length ? 0:1):(p==nil ? 3:2))
            if heap.count<limit {
                heap.append(hit);var j=heap.count-1
                while j>0 {let parent=(j-1)/2;if !compare(heap[parent],heap[j],q.sort){break};heap.swapAt(parent,j);j=parent}
            }else if compare(hit,heap[0],q.sort){
                heap[0]=hit;var j=0
                while j*2+1<heap.count {
                    var c=j*2+1;if c+1<heap.count && compare(heap[c],heap[c+1],q.sort){c+=1}
                    if !compare(heap[j],heap[c],q.sort){break};heap.swapAt(j,c);j=c
                }
            }
        }
        guard gate?.valid(token) ?? true else{return nil}
        return SearchPage(entries:heap.sorted{compare($0,$1,q.sort)}.map{entry($0.row)},total:total,generation:generation)
    }
}

struct ScanResult {var entries:[FileEntry];var failures:[String]}
func scanDirectory(_ directory:String,root:RootScope,excluded:[String]=[],cancel:()->Bool={false})->ScanResult {
    let fm=FileManager.default;var found=[FileEntry](),failures=[String](),visited=Set<String>()
    let rootURL=URL(fileURLWithPath:directory)
    var rootStat=stat();guard lstat(root.path,&rootStat)==0 else{return ScanResult(entries:[],failures:[root.path])}
    var allowedDevices:Set<Int32>=[rootStat.st_dev]
    if root.path=="/" {var dataStat=stat();if lstat("/System/Volumes/Data",&dataStat)==0{allowedDevices.insert(dataStat.st_dev)}}
    if let identity=currentIdentity(directory){visited.insert(identity)}
    func read(_ u:URL)->FileEntry? {
        var s=stat();guard lstat(u.path,&s)==0 else{failures.append(u.path);return nil}
        let mode=s.st_mode & S_IFMT
        let isPackage=(try? u.resourceValues(forKeys:[.isPackageKey]).isPackage)==true
        let kind:UInt32=mode==S_IFLNK ? 3:isPackage ? 2:mode==S_IFDIR ? 1:0
        return FileEntry(root:root.id,path:u.path,name:u.lastPathComponent,norm:canonical(u.lastPathComponent),kind:kind,modified:Int64(s.st_mtimespec.tv_sec)*1000+Int64(s.st_mtimespec.tv_nsec)/1000000,dev:UInt64(UInt32(bitPattern:s.st_dev)),ino:UInt64(s.st_ino))
    }
    if directory != root.path,let selfEntry=read(rootURL){found.append(selfEntry);if selfEntry.kind != 1{return ScanResult(entries:found,failures:failures)}}
    guard let enumerator=fm.enumerator(at:rootURL,includingPropertiesForKeys:[.isPackageKey],options:[],errorHandler:{u,_ in failures.append(u.path);return true}) else{return ScanResult(entries:found,failures:[directory])}
    for case let u as URL in enumerator {
        if cancel(){break}
        if excluded.contains(where:{u.path==$0 || u.path.hasPrefix($0+"/")}){enumerator.skipDescendants();continue}
        guard let e=read(u) else{continue}
        if e.kind==1 && !allowedDevices.contains(Int32(bitPattern:UInt32(e.dev))){failures.append(u.path);enumerator.skipDescendants();continue}
        // A symlink is a leaf. Directory identity dedup applies only to directories.
        if e.kind==3 || e.kind==2{enumerator.skipDescendants()}
        if e.kind==1 {
            if !visited.insert(e.identity).inserted{enumerator.skipDescendants();continue}
        }
        found.append(e)
    }
    if !failures.isEmpty {found.removeAll{e in failures.contains{e.path==$0 || e.path.hasPrefix($0+"/")}}}
    return ScanResult(entries:found,failures:failures)
}
func currentIdentity(_ path:String)->String? {
    var s=stat();guard lstat(path,&s)==0 else{return nil};return "\(UInt64(UInt32(bitPattern:s.st_dev))):\(s.st_ino)"
}
