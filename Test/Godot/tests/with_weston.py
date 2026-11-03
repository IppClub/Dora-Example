#!/usr/bin/env python3
"""Run a test in an isolated GL-rendered Wayland compositor and clean it up.
Requires Weston 12+; its actual renderer is retained in the log, not assumed.
Example: python3 Tools/Godot/tests/with_weston.py -- Tools/Godot/test_linux.sh
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse,os,signal,subprocess,tempfile,time
from pathlib import Path
root=ENGINE_ROOT
parser=argparse.ArgumentParser()
parser.add_argument('--logs',type=Path,default=root/'build/godot-runtime/weston-test')
parser.add_argument('--timeout',type=int,help='Explicit command watchdog, e.g. for slow translated functional tests')
parser.add_argument('command',nargs=argparse.REMAINDER)
args=parser.parse_args();args.logs.mkdir(parents=True,exist_ok=True)
command=args.command[1:] if args.command[:1]==['--'] else args.command
assert command, 'Provide a test command after --'
assert args.timeout is None or args.timeout > 0, 'Timeout must be positive'
with tempfile.TemporaryDirectory(prefix='dora-godot-wl-') as temporary:
    env=os.environ.copy();env.pop('DISPLAY',None)
    env.update(XDG_RUNTIME_DIR=temporary,WAYLAND_DISPLAY='wayland-dora',SDL_VIDEODRIVER='wayland')
    process=None
    try:
        with (args.logs/'process.log').open('w') as log:
            process=subprocess.Popen(['weston','--backend=headless','--renderer=gl','--width=1920','--height=1080',
                '--socket=wayland-dora','--idle-time=0','--no-config','--log='+str((args.logs/'weston.log').resolve())],
                env=env,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        for _ in range(100):
            assert process.poll() is None, 'Weston exited; inspect '+str(args.logs/'weston.log')
            if (Path(temporary)/'wayland-dora').exists(): break
            time.sleep(.1)
        else: raise RuntimeError('Weston socket was not ready')
        timeout=max(300+int(env.get("DORA_GODOT_TEST_SOAK_FRAMES","0"))/30,
                    240+int(env.get('DORA_GODOT_TEST_CYCLES','0'))*10)
        if args.timeout is not None:
            timeout=args.timeout
        result=subprocess.run(command,env=env,timeout=timeout)
        raise SystemExit(result.returncode)
    finally:
        if process and process.poll() is None:
            os.killpg(process.pid,signal.SIGTERM)
            try: process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid,signal.SIGKILL);process.wait()
