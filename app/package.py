from pathlib import Path
import argparse,hashlib,json,plistlib,shutil,subprocess,tempfile,time,uuid

root=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--launch',action='store_true');args=parser.parse_args()
release=root/'release';release.mkdir(exist_ok=True)
archive=release/'FileSearch-v0.11-macOS-arm64.zip'
source=root/'dist/FileSearch.app'
subprocess.run(['codesign','--verify','--deep','--strict',str(source)],check=True)
assert not list(source.rglob('*.appex')), 'Unexpected embedded extension'
assert 'CFBundleURLTypes' not in plistlib.loads((source/'Contents/Info.plist').read_bytes())
assert plistlib.loads((source/'Contents/Info.plist').read_bytes()).get('CFBundleIconFile')=='AppIcon.icns'
icon=source/'Contents/Resources/AppIcon.icns'
assert icon.read_bytes()[:4]==b'icns'
quickstart='''# FileSearch v0.11 测试版

适用 Apple Silicon Mac。最低部署目标 macOS 14，本次实测 macOS 26.6.2。
解压后将 FileSearch.app 拖入“应用程序”再打开；默认只搜索随附示例。
在主窗口“设置→添加目录”主动选择自己的内置磁盘目录后，才开始收录。

- 在“设置→界面语言”选择简体中文或 English，即时切换并保存。用户文件名与路径保持原样。
- 示例为周末笔记、阅读清单、每日清单和每周计划等通用场景。
- 单击选中，双击打开；右键提供打开、复制路径、在 Finder 中显示。
- 主界面可以按文件夹／文件、自定义后缀筛选；后缀随输入即时按前缀匹配，x、xl 都匹配 xlsx。可只输入后缀，多个后缀用逗号或空格分隔。路径详情只在主界面显示。
- 设置可开启极简桌面窗，仅含搜索输入与结果列表；设置入口保留在主窗口与菜单栏。
- 毛玻璃开启时透明度仅作用于背景，文字保持清晰；关闭毛玻璃后使用实色窗口。
- 结果列表可滚动，搜索针对完整已收录集合，当前最多展示前 500 项。
- 关闭主窗口不退出后台；请从菜单栏“退出文件搜索”退出。

本包已包含编译完成的 FileSearch.app，无需安装开发工具；解压并将应用拖入“应用程序”。当前只支持 Apple 芯片。首次启动如果被系统拦截，接收者应先确认来源，再按苹果“隐私与安全性”中的提示处理，受管设备可能不允许。
正式分发需要 Developer ID 签名和苹果公证；当前包不具备这些条件。

这是临时签名、未公证的公开测试包；首次打开仍可能受到 macOS 安全检查。
全盘范围引导、完整权限恢复、正式启动性能仍未完成。
索引及设置在本机，默认不上传数据；本程序没有联网功能。
'''
with tempfile.TemporaryDirectory(prefix='package-v011-',dir=root/'build') as staging:
    folder=Path(staging)/'FileSearch-v0.11';folder.mkdir()
    shutil.copytree(source,folder/'FileSearch.app',symlinks=True,ignore=shutil.ignore_patterns('.DS_Store'))
    (folder/'使用说明.md').write_text(quickstart)
    (folder/'README-English.md').write_bytes((root/'README.en.md').read_bytes())
    subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(folder),str(archive)],check=True)
checksum=hashlib.sha256(archive.read_bytes()).hexdigest()
(release/(archive.name+'.sha256')).write_text(checksum+'  '+archive.name+'\n')
destination=release/('verification-v011-'+uuid.uuid4().hex[:8]);destination.mkdir()
subprocess.run(['ditto','-x','-k',str(archive),str(destination)],check=True)
bundle=destination/'FileSearch-v0.11/FileSearch.app'
subprocess.run(['codesign','--verify','--deep','--strict',str(bundle)],check=True)
relative='Contents/MacOS/FileSearch'
assert hashlib.sha256((bundle/relative).read_bytes()).digest()==hashlib.sha256((source/relative).read_bytes()).digest()
report={'version':'0.11','archive':str(archive),'sha256':checksum,'bytes':archive.stat().st_size,'extracted_app':str(bundle),'embedded_extensions_absent':not bool(list(bundle.rglob('*.appex'))),'strict_signature_verified':True,'executable_hash_matches':True,'launch_tested':False}
report['app_icon_verified']=(bundle/'Contents/Resources/AppIcon.icns').read_bytes()==icon.read_bytes()
assert report['app_icon_verified']
if args.launch:
    runs=[]
    for language in ('zh-Hans','en'):
        smoke=root/('results/package-smoke-v011-'+language+'.json')
        if smoke.exists():smoke.unlink()
        start=time.perf_counter()
        process=subprocess.Popen([str(bundle/relative),'--state',str(destination/('isolated-state-'+language)),'--language',language,'--smoke-report',str(smoke)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        try:
            _,stderr=process.communicate(timeout=20)
            exited=process.returncode==0
        except subprocess.TimeoutExpired:
            process.terminate();_,stderr=process.communicate(timeout=5);exited=False
        data=json.loads(smoke.read_text()) if smoke.exists() else {}
        expected_tooltip='FileSearch · File Search' if language=='en' else '文件搜索 · FileSearch'
        expected_menu=['Open','Copy Path','Show in Finder'] if language=='en' else ['打开','复制路径','在 Finder 中显示']
        run={'language':language,'clean_shutdown':exited,'whole_smoke_seconds':time.perf_counter()-start,'stderr':stderr.decode(errors='replace')[-1500:],'smoke':data}
        run['menu_bar_icon_verified']=data.get('menu_bar_icon_template') is True and data.get('menu_bar_icon_width')==18 and data.get('menu_bar_tooltip')==expected_tooltip
        run['bundled_sample_independent']=len(data.get('root_paths',[]))==1 and data['root_paths'][0].startswith(str(bundle))
        run['query_verified']=set(data.get('results',[]))=={'Notes backup.tar.gz','Archived notes.pdf','Weekend notes.pdf'}
        run['language_verified']=data.get('interface_language')==language and data.get('context_titles')==expected_menu and data.get('window_title')==('FileSearch' if language=='en' else '文件搜索')
        runs.append(run)
    report['launch_tested']=True;report['localizations']=runs
    for key in ['clean_shutdown','menu_bar_icon_verified','bundled_sample_independent','query_verified','language_verified']:
        report[key]=all(run[key] for run in runs)
(root/'results/package-check-v011.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
if args.launch:assert report['language_verified'] and report['menu_bar_icon_verified'] and report['clean_shutdown'] and report['bundled_sample_independent'] and report['query_verified'],report
print(archive)
