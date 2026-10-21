import Foundation
import SQLite3
import Darwin

@main struct QueryBenchmark {
    static func main()throws {
        let args=CommandLine.arguments
        let store=try IndexStore(directory:URL(fileURLWithPath:args[2]))
        if store.meta("benchmark_fixture") != "million-v06" {
            try store.addRoot("/Synthetic",sample:true)
            let attach=try store.statement("ATTACH DATABASE ? AS fixture");store.bind(attach,1,args[1]);guard sqlite3_step(attach)==SQLITE_DONE else{throw SearchFailure.message("无法载入生成夹具")};sqlite3_finalize(attach)
            try store.run("BEGIN; DELETE FROM entries; INSERT INTO entries(id,root,path,name,norm,kind,modified,dev,ino) SELECT f.id+1,1,d.path||'/'||f.name,f.name,f.norm,f.kind,f.mtime,0,f.id+1 FROM fixture.files f JOIN fixture.dirs d ON f.dir=d.id; COMMIT;")
            try store.setMeta("generation","1");try store.setMeta("benchmark_fixture","million-v06")
            _ = try store.writeSnapshot()
        }
        let snapshot=try SearchSnapshot(url:store.directory.appendingPathComponent("snapshot.bin"))
        let cases:[(String,[String])]=[("合同",[]),("美国 合同",["pdf"]),("archive",["tar.gz"]),("1",[]),("not-found-qx",[]),("café",[]),("",["x"]),("",["xl"]),("archive",["tar."])]
        var results=[[String:Any]]()
        for (term,suffix) in cases {
            let q=SearchOptions(text:term,suffixes:suffix,roots:[1],limit:500)
            _ = snapshot.search(q)
            var times=[Double]();var page:SearchPage!
            for _ in 0..<20 {let start=DispatchTime.now().uptimeNanoseconds;page=snapshot.search(q);times.append(Double(DispatchTime.now().uptimeNanoseconds-start)/1e6)}
            let sorted=times.sorted()
            results.append(["query":term,"suffixes":suffix,"count":page.total,"top_ids":page.entries.map{$0.id},"samples_ms":times,"p50_ms":sorted[9],"p95_ms":sorted[18]])
        }
        var usage=rusage();getrusage(RUSAGE_SELF,&usage)
        let result:[String:Any]=["version":"0.7","records":snapshot.count,"limit":500,"repeats_per_case":20,"cases":results,"peak_process_bytes":usage.ru_maxrss,"scope":"Synthetic metadata; warm in-process search only, excludes UI and initial filesystem scan."]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:args[3]))
        print("\(snapshot.count) synthetic records; \(results.count) cases measured")
    }
}
