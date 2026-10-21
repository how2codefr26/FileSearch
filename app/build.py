from pathlib import Path
import io,json,plistlib,shutil,subprocess,sys,tarfile,zipfile

ROOT=Path(__file__).resolve().parent
APP=ROOT/'dist/FileSearch.app';CONTENTS=APP/'Contents';MACOS=CONTENTS/'MacOS';RES=CONTENTS/'Resources';SAMPLE=RES/'SampleFiles'
# Remove only the generated extension directory when upgrading an existing build.
if (CONTENTS/'PlugIns').exists():shutil.rmtree(CONTENTS/'PlugIns')
# SampleFiles contains generated fixtures only; replace stale names on rebuild.
if SAMPLE.exists():shutil.rmtree(SAMPLE)
for p in (ROOT/'build',ROOT/'results',MACOS,SAMPLE):p.mkdir(parents=True,exist_ok=True)
subprocess.run([sys.executable,str(ROOT/'build_icons.py')],check=True)
shutil.copyfile(ROOT/'build/AppIcon.icns',RES/'AppIcon.icns')

def pdf():
    objects=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Contents 4 0 R >>',b'<< /Length 0 >>\nstream\n\nendstream']
    data=bytearray(b'%PDF-1.4\n');offsets=[0]
    for i,obj in enumerate(objects,1):offsets.append(len(data));data+=f'{i} 0 obj\n'.encode()+obj+b'\nendobj\n'
    xref=len(data);data+=b'xref\n0 5\n0000000000 65535 f \n'
    for off in offsets[1:]:data+=f'{off:010d} 00000 n \n'.encode()
    data+=f'trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode();return data

for folder in ('Documents','Downloads','Archive','Weekend'):(SAMPLE/folder).mkdir(exist_ok=True)
for rel in ('Documents/Weekend notes.pdf','Archive/Archived notes.pdf','Documents/Reading list.pdf'):(SAMPLE/rel).write_bytes(pdf())
texts={'Documents/Weekend notes.txt':'Sample weekend notes for local search and open testing.','Downloads/Reading notes.txt':'Sample reading notes.','Documents/每日清单.csv':'事项,完成\n整理书架,是\n','Downloads/Weekly plan.csv':'Day,Activity\nMonday,Read\n','Weekend/Readme.md':'# Weekend activities\n','Documents/cafe\u0301.txt':'Unicode example','Documents/.gitignore':'*.tmp\n','Documents/100%_plan.txt':'literal symbols'}
for rel,text in texts.items():(SAMPLE/rel).write_text(text)
for name in ('Documents/Notes backup.tar.gz','Downloads/Notes backup.gz'):
    with tarfile.open(SAMPLE/name,'w:gz') as archive:
        data=b'Example archive';item=tarfile.TarInfo('readme.txt');item.size=len(data);archive.addfile(item,io.BytesIO(data))

# A tiny valid XLSX fixture, not a user workbook.
with zipfile.ZipFile(SAMPLE/'Documents/Weekly plan.xlsx','w',zipfile.ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml','<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>')
    z.writestr('_rels/.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
    z.writestr('xl/workbook.xml','<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sample" sheetId="1" r:id="rId1"/></sheets></workbook>')
    z.writestr('xl/_rels/workbook.xml.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>')
    z.writestr('xl/worksheets/sheet1.xml','<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Weekly plan</t></is></c></row></sheetData></worksheet>')

sources=sorted((ROOT/'Sources').glob('*.swift'))
common=['xcrun','swiftc','-O','-target','arm64-apple-macosx14.0','-module-cache-path',str(ROOT/'build/module-cache')]
subprocess.run(common+[str(p) for p in sources]+['-o',str(MACOS/'FileSearch')],check=True)
info={'CFBundleIdentifier':'local.filesearch.app','CFBundleExecutable':'FileSearch','CFBundleName':'FileSearch','CFBundleDisplayName':'FileSearch','CFBundleIconFile':'AppIcon.icns','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.11','CFBundleVersion':'11','LSMinimumSystemVersion':'14.0','LSUIElement':True,'NSHighResolutionCapable':True}
(CONTENTS/'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['codesign','--force','--sign','-',str(APP)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(APP)],check=True)
(ROOT/'results/build.json').write_text(json.dumps({'app':str(APP),'version':'0.11','target':'arm64-macos14','icon':'AppIcon.icns','embedded_extensions':[],'signing':'ad-hoc; personal development build, not notarized'},ensure_ascii=False,indent=2))
print(APP)
