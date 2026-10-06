from pathlib import Path
import ctypes as c
from ctypes import wintypes as w
import subprocess,json,time

base=Path(__file__).parent
source=Path('D:/project/useless/resources/infinite-build-dome-survival')
godot='D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
class Entry(c.Structure):
    _fields_=[('size',w.DWORD),('usage',w.DWORD),('pid',w.DWORD),('heap',c.c_size_t),('module',w.DWORD),('threads',w.DWORD),('parent',w.DWORD),('priority',w.LONG),('flags',w.DWORD),('exe',w.WCHAR*260)]
k=c.WinDLL('kernel32',use_last_error=True)
k.CreateToolhelp32Snapshot.argtypes=[w.DWORD,w.DWORD];k.CreateToolhelp32Snapshot.restype=w.HANDLE
k.Process32FirstW.argtypes=[w.HANDLE,c.POINTER(Entry)]
k.Process32NextW.argtypes=[w.HANDLE,c.POINTER(Entry)]
k.CloseHandle.argtypes=[w.HANDLE]
def foreign(root=0):
    h=k.CreateToolhelp32Snapshot(2,0); e=Entry();e.size=c.sizeof(e); rows={}
    ok=k.Process32FirstW(h,c.byref(e))
    while ok:
        rows[e.pid]=(e.parent,e.exe)
        ok=k.Process32NextW(h,c.byref(e))
    k.CloseHandle(h)
    def owned(pid):
        for _ in range(20):
            if pid==root and root:return True
            if pid not in rows:return False
            pid=rows[pid][0]
        return False
    return [pid for pid,(_,name) in rows.items() if 'godot' in name.lower() and pid!=27304 and not owned(pid)]

jobs=[(f'clean-{v}-2',v,[]) for v in ['both','no_spray','no_glow','original','native']]
jobs += [('profile-original','original',['--profile','--seconds=3']),('profile-both','both',['--profile','--seconds=3']),('diagnostic-no-warning','both',['--profile','--hide-warning-diagnostic','--seconds=3']),('moving-original','original',['--moving','--seconds=8']),('capture-original','original',['--capture','--seconds=3']),('capture-both','both',['--capture','--seconds=3'])]
for name,variant,flags in jobs:
    attempt=0
    while True:
        attempt+=1
        while foreign():
            print('WAIT_OTHER_ENGINE',foreign(),flush=True);time.sleep(5)
        output=base/(name if attempt==1 else name+f'-retry{attempt}')
        cmd=['python',str(source/'scripts/tools/run_godot_background.py'),'--godot',godot,'--log',str(output/'engine.log'),'--timeout','100','--','--path',str(base/'project'),'--scene','res://scenes/tests/hammer_lightning_review.tscn','--','--output='+str(output),'--variant='+variant]+flags
        with (base/'runner-last.log').open('w',encoding='utf-8') as log:
            proc=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT)
            overlaps=set()
            while proc.poll() is None:
                overlaps.update(foreign(proc.pid));time.sleep(.5)
        print((base/'runner-last.log').read_text(encoding='utf-8'),flush=True)
        if proc.returncode or not (output/'result.json').exists():raise SystemExit(name+' failed')
        audit={'overlapping_engine_pids':list(overlaps),'accepted':not overlaps,'job':name}
        (output/'concurrency.json').write_text(json.dumps(audit),encoding='utf-8')
        if overlaps:
            print('EXCLUDE_OVERLAP',name,overlaps,flush=True)
            continue
        d=json.loads((output/'result.json').read_text(encoding='utf-8'))
        print(json.dumps({'job':name,'active':d['active'],'counters':d['counters'],'costs':d['costs']}),flush=True)
        break
