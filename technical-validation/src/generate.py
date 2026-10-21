"""Deterministic synthetic metadata only: does not enumerate personal files."""
from pathlib import Path
import argparse, json, sqlite3, struct, time, unicodedata, hashlib

def norm(s):
    return unicodedata.normalize('NFC', s).translate(str.maketrans('ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'))

TEMPLATES = [
    '美国 合同_{:07d}.pdf', '合同_美国_{:07d}.pdf', '仓租账单_{:07d}.xlsx',
    'invoice_{:07d}.PDF', 'Report_Final_{:07d}.docx', 'photo_{:07d}.jpg',
    'archive_{:07d}.tar.gz', '.hidden_{:07d}', '报价_{:07d}.xlsx',
    'notes_AND_OR_{:07d}.txt', '100%_plan*?_{:07d}.txt', 'cafe\u0301_{:07d}.txt',
    '项目_{:07d}', 'Documents_{:07d}', '开发依赖_{:07d}.json', 'ordinary_{:07d}.log',
]
SPECIAL = ['美国 合同','美国 合同.pdf','归档 美国 合同.pdf','合同_美国.pdf',
           'é.txt','e\u0301.txt','e.txt','AND.txt','OR.txt','NOT.txt','a_b%.txt',
           'literal*?.txt','a\\b.txt','.gitignore','archive.tar.gz','合同.xlsx',
           '合同.xlsx','美国 合同', 'Case.txt','case.txt']

def records(n):
    for i in range(n):
        name = SPECIAL[i] if i < len(SPECIAL) else TEMPLATES[(i * 7) % len(TEMPLATES)].format(i)
        kind = 1 if (i >= len(SPECIAL) and (i * 7) % 16 in (12,13)) or i == 17 else 0
        if i % 4999 == 0 and i >= len(SPECIAL): kind = 2
        yield i, name, norm(name), i % 1024, kind, (i * 7919) % 30001

def directory(i):
    extra = '/'.join(f'level{j}' for j in range(i % 7))
    return f'/Synthetic/Users/demo/{"Documents" if i%2==0 else "Downloads"}/{i:04d}' + ('/'+extra if extra else '')

def generate(n, out):
    out.mkdir(parents=True, exist_ok=True)
    binary = out / f'index-{n}.bin'
    dbpath = out / f'index-{n}.sqlite'
    if binary.exists() or dbpath.exists(): raise RuntimeError('Use a new output directory; refusing to overwrite a dataset')
    started = time.perf_counter()
    blob = bytearray()
    def add(s):
        b = s.encode('utf8'); off = len(blob); blob.extend(b); return off,len(b)
    dirs = []
    db = sqlite3.connect(dbpath)
    db.executescript('PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL; CREATE TABLE dirs(id INTEGER PRIMARY KEY,path TEXT,norm TEXT); CREATE TABLE files(id INTEGER PRIMARY KEY,name TEXT,norm TEXT,dir INTEGER,kind INTEGER,mtime INTEGER,ext TEXT);')
    for i in range(1024):
        p = directory(i); a=add(p); b = a if p == norm(p) else add(norm(p))
        dirs.append(struct.pack('<IIII',*a,*b)); db.execute('INSERT INTO dirs VALUES (?,?,?)',(i,p,norm(p)))
    rows = bytearray(); batch=[]
    for i,name,normalized,parent,kind,modified in records(n):
        raw = add(name); canonical = raw if name == normalized else add(normalized)
        ext = normalized.rsplit('.',1)[1] if '.' in normalized and not (normalized.startswith('.') and normalized.count('.')==1) else ''
        extb = ext.encode('utf8'); ext_off = canonical[0]+canonical[1]-len(extb)
        rows.extend(struct.pack('<IIIIIIIIq',*raw,*canonical,parent,ext_off,len(extb),kind,modified))
        batch.append((i,name,normalized,parent,kind,modified,ext))
        if len(batch) == 5000: db.executemany('INSERT INTO files VALUES (?,?,?,?,?,?,?)',batch); batch.clear()
    if batch: db.executemany('INSERT INTO files VALUES (?,?,?,?,?,?,?)',batch)
    db.commit(); db.close()
    with binary.open('wb') as f:
        f.write(struct.pack('<8sQQQ',b'MACIDX01',n,1024,len(blob)))
        f.write(rows); f.write(b''.join(dirs)); f.write(blob)
    result={'count':n,'seed':'formula-v1','generator_seconds':time.perf_counter()-started,
            'binary_bytes':binary.stat().st_size,'sqlite_bytes':dbpath.stat().st_size,
            'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),
            'real_files_created':0,'distribution':'16 templates, 20 edge entries; deterministic varied parents, depths and mtimes'}
    (out/f'dataset-{n}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps(result),flush=True)

if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('output');p.add_argument('--counts',nargs='+',type=int,default=[100000,1000000]);a=p.parse_args()
    for n in a.counts: generate(n,Path(a.output))
