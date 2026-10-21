from pathlib import Path
import json, math, sqlite3, subprocess, unicodedata

root=Path(__file__).resolve().parent
source=root.parent/'technical-validation/data/run-20261020/index-1000000.sqlite'
subprocess.run(['xcrun','swiftc','-O','-parse-as-library','-target','arm64-apple-macosx14.0',
                '-module-cache-path',str(root/'build/module-cache'),str(root/'Sources/ModelSearch.swift'),
                str(root/'Sources/Store.swift'),str(root/'Tests/QueryBenchmark.swift'),'-o',str(root/'build/query-benchmark')],check=True)
output=root/'results/query-benchmark-v07.json'
subprocess.run([str(root/'build/query-benchmark'),str(source),str(root/'testdata/benchmark-v07'),str(output)],check=True)
report=json.loads(output.read_text())
connection=sqlite3.connect(f'file:{source}?mode=ro',uri=True)
checks=[]
for case in report['cases']:
    words=unicodedata.normalize('NFC',case['query']).translate(str.maketrans('ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')).split()
    phrase=' '.join(words)
    conditions=['instr(f.norm,?)>0' for _ in words];parameters=list(words)
    if case['suffixes']:
        conditions+=['f.kind IN (0,2)','('+' OR '.join('instr(substr(f.norm,2),?)>0' for _ in case['suffixes'])+')']
        for suffix in case['suffixes']:parameters.append('.'+suffix)
    where=' AND '.join(conditions)
    count=connection.execute('SELECT count(*) FROM files f WHERE '+where,parameters).fetchone()[0]
    order='CASE WHEN f.norm=? THEN 0 WHEN instr(f.norm,?)=1 THEN 1 WHEN instr(f.norm,?)>0 THEN 2 ELSE 3 END,f.mtime DESC,(d.norm||\'/\'||f.norm) COLLATE BINARY,(d.path||\'/\'||f.name) COLLATE BINARY'
    ids=[row[0]+1 for row in connection.execute('SELECT f.id FROM files f JOIN dirs d ON f.dir=d.id WHERE '+where+' ORDER BY '+order+' LIMIT 500',parameters+[phrase]*3)]
    assert count==case['count'] and ids==case['top_ids'],case['query']
    checks.append({'query':case['query'],'count_matches':True,'ordered_top500_matches':True})
(root/'results/query-oracle-v07.json').write_text(json.dumps({'checks':checks,'passed':True},ensure_ascii=False,indent=2))
print('Independent SQLite oracle: all counts and ordered top 500 match')
