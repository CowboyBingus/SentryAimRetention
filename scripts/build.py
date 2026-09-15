"""Build and verify the archive-only sentry module. Never install or launch."""
import json
import os
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
from archive import GAME,LUA,EXE_SHA,GAME_DLL_SHA,ARCHIVE,sha,make_archive
from module import build_module
from package import package_release

MODULE='mods/cowboybingus/sentry_aim_retention'
REVISION='data-v2'
VERSION='1.0.1'
def run(args,**kwargs):
    p=subprocess.run(list(map(str,args)),capture_output=True,text=True,**kwargs)
    if p.returncode: raise RuntimeError(p.stdout+p.stderr)
    return p.stdout

def main():
    build=ROOT/'build';build.mkdir(exist_ok=True)
    for relative,expected in [('bin/helldivers2.exe',EXE_SHA),('data/game/game.dll',GAME_DLL_SHA)]:
        if sha((GAME/relative).read_bytes())!=expected: raise ValueError('Unsupported game build')
    for p in (ROOT/'src').glob('*.lua'):
        if any(s in p.read_text() for s in ('VirtualAlloc','VirtualProtect','FlushInstructionCache',
            'CreateRemoteThread','RtlAddFunctionTable','LoadLibrary')):
            raise ValueError('Executable modification API in '+p.name)
    env=dict(os.environ,LUA_PATH=str(LUA.parent/'?.lua')+';;')
    tests=run([LUA,ROOT/'tests/test_aim.lua',ROOT/'src',ROOT/'tests/gatling_target_loss.lua'],env=env)
    tests+=run([LUA,ROOT/'tests/test_firing.lua',ROOT/'src',ROOT/'tests/firing_sweeps.lua'],env=env)
    tests+=run([LUA,ROOT/'tests/test_loader.lua',ROOT/'src'],env=env)
    tests+=run([LUA,ROOT/'tests/test_snapshot.lua',ROOT/'src'],env=env)
    tests+=run([LUA,ROOT/'tests/test_windows_api.lua',ROOT/'src'],env=env)
    resources=build_module(ROOT,build,MODULE,'aim_data.lua',REVISION)
    (build/ARCHIVE).write_bytes(make_archive(resources))
    for suffix in ('.stream','.gpu_resources'): (build/(ARCHIVE+suffix)).write_bytes(b'')
    files={f'data/{ARCHIVE}{s}':f'build/{ARCHIVE}{s}' for s in ('','.stream','.gpu_resources')}
    report={'name':'Sentry Aim Retention','slug':'SentryAimRetention','revision':REVISION,'version':VERSION,
        'guid':'2c158cef-8455-461c-8113-6a207a60b692',
        'description':'Sentry aim retention with selective Gatling and machine-gun firing pauses during broad sweeps. Small adjustments can keep firing. Requires Bingus Shared Loader loader-v6 or newer / API 1.',
        'game_exe_sha256':EXE_SHA,'game_dll_sha256':GAME_DLL_SHA,
        'deployment_files':files,'files':{p:sha((ROOT/p).read_bytes()) for p in files.values()},
        'requires':[{'name':'Bingus Shared Loader','api':1,'revision':'loader-v6'}],
        'module':MODULE,'runtime_verified':False,'status':'release',
        'executable_memory_changed':False,'custom_dlls':0,'boot_replaced':False,
        'write':{'scope':'validated locally authoritative autonomous sentry instances',
            'direct_bytes_per_hold':24,'direct_fields':['last raw aim','last computed aim'],
            'native_control_fields':['retention bit 2','horizontal speed','vertical speed','fire mode'],
            'protection':'existing MEM_PRIVATE/PAGE_READWRITE only'},
        'native_calls':['game.dll+0x6b7f20','game.dll+0xf2b450','game.dll+0xf2b360','game.dll+0x74ddf0'],
        'sweep_policy':{'profiles':['Gatling','Machine gun'],'pause_degrees':[12,8],
            'resume_degrees':[4,3],'settle_seconds':0.06,'max_unsettled_seconds':0.20,
            'preserves_native_trigger_and_spinup_timer':True},
        'validation_limits':['Lua/native frame ordering not verified',
            'projectile direction and residual burst not verified with the mod installed',
            'scan release inferred from native behavior node and explicit point transition',
            'host/client authority and non-Gatling combat not verified'],
        'offline_tests':tests.strip(),
        'source_sha256':{p.relative_to(ROOT).as_posix():sha(p.read_bytes())
            for folder,pattern in [('src','*.lua'),('tests','*.*'),('scripts','*.py')]
            for p in (ROOT/folder).glob(pattern)}}
    release=package_release(ROOT,build,report)
    tests+=run([sys.executable,ROOT/'tests/test_package.py',release])
    tests+=run([sys.executable,ROOT/'scripts/privacy_audit.py','--zip',release])
    tests+=run([sys.executable,ROOT/'scripts/source_release.py'])
    report['offline_tests']=tests.strip()
    report['release']={'path':os.path.relpath(release,ROOT),'sha256':sha(release.read_bytes())}
    (build/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
    (build/'offline-tests.txt').write_text(tests)
    print(tests.strip());print('Built '+str(release)+'; full release '+VERSION+'.')
if __name__=='__main__':main()
