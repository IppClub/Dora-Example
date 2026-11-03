#!/usr/bin/env python3
"""Retain strict paired Linux matrix results and external scheduler observations.

The caller owns any concurrent workload. A phase label alone is not proof of
load, and successful collection does not turn a failed acceptance into a pass.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def audio_metrics(log):
    patterns = {
        'drained': r'GodotAudio drained: produced=(\d+), consumed=(\d+), nonzeroProduced=(\d+), nonzeroConsumed=(\d+), underrunFrames=(\d+)',
        'callbacks': r'GodotAudio callbacks: count=(\d+), maxRequest=(\d+), maxGapUs=(\d+), underrunEvents=(\d+)',
        'underruns': r'GodotAudio underrun: callback=(\d+), requested=(\d+), received=(\d+), atUs=(\d+), gapUs=(\d+), produced=(\d+)',
        'producer': r'DORA_PCM_PRODUCER loops=(\d+) maxGapUs=(\d+) maxMixUs=(\d+) events=(\d+) targetFrames=(\d+)',
    }
    return {name: [list(map(int, match)) for match in re.findall(pattern, log)] for name, pattern in patterns.items()}


def process_sample(binary, emulator):
    samples = []
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():
            continue
        try:
            args = (proc / 'cmdline').read_bytes().split(b'\0')
            expected = [os.fsencode(emulator), os.fsencode(binary)] if emulator else [os.fsencode(binary)]
            if args[:len(expected)] != expected:
                continue
            threads = []
            for task in (proc / 'task').iterdir():
                try:
                    name = (task / 'comm').read_text().strip()
                    if 'PCM' not in name and 'Audio' not in name:
                        continue
                    threads.append(dict(tid=int(task.name), name=name,
                                        schedstat=list(map(int, (task / 'schedstat').read_text().split())),
                                        stat=(task / 'stat').read_text().strip()))
                except (FileNotFoundError, ProcessLookupError):
                    pass
            samples.append(dict(pid=int(proc.name), threads=threads))
        except (FileNotFoundError, ProcessLookupError):
            pass
    return samples


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('binary', 'old-runtime-package', 'new-runtime-package', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    for name in ('emulator', 'abi-python', 'abi-python-home'):
        p.add_argument('--' + name, type=Path)
    p.add_argument('--phase', choices=('baseline', 'browser-load'), required=True)
    p.add_argument('--order', nargs='+', choices=('old', 'new'), default=('old', 'new', 'new', 'old'))
    a = p.parse_args()
    assert sys.platform == 'linux'
    assert bool(a.emulator) == bool(a.abi_python) == bool(a.abi_python_home)
    root = ENGINE_ROOT
    out = a.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    binary = a.binary.resolve(); emulator = a.emulator.resolve() if a.emulator else None
    packages = {key: getattr(a, key + '_runtime_package').resolve() for key in ('old', 'new')}
    sys.path.insert(0, str(root/'Tools/Godot'))
    from verify_package import verify
    libraries = {}
    for key, package in packages.items():
        verify(package)
        meta = json.loads((package/'manifest.json').read_text()); assert meta['graphics_backend']=='egl'
        lib = package/meta['library']; libraries[key] = dict(path=str(lib), sha256=digest(lib))
    assert libraries['old']['sha256'] != libraries['new']['sha256']
    host_hash = digest(binary)
    rows = []
    for index, key in enumerate(a.order):
        case = out/f'{index}-{key}'; started = time.time()
        command = [sys.executable, str(root/str(test_path('Tools/Godot/tests/run_linux_runtime_matrix.py'))),
                   '--binary', str(binary), '--runtime-package', str(packages[key]),
                   '--results', str(case), '--environment', 'virtual-machine', '--scenarios', '3']
        if emulator:
            command += ['--emulator',str(emulator),'--abi-python',str(a.abi_python.resolve()),
                        '--abi-python-home',str(a.abi_python_home.resolve())]
        (out/'stage.json').write_text(json.dumps(dict(case=case.name,phase=a.phase,time=started)))
        env = {k:v for k,v in os.environ.items() if not k.startswith(('DORA_GODOT_','DORA_BUILD_'))}
        env.update(GALLIUM_DRIVER='llvmpipe',LIBGL_ALWAYS_SOFTWARE='1',LP_NUM_THREADS='2')
        with (out/(case.name+'-driver.log')).open('w') as log, (out/(case.name+'-scheduler.jsonl')).open('w') as trace:
            child = subprocess.Popen(command,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
            (out/'process.json').write_text(json.dumps(dict(pid=child.pid,command=command,time=started)))
            while child.poll() is None:
                sample = dict(unix=time.time(),monotonic_ns=time.monotonic_ns(),processes=process_sample(binary,emulator),
                              cpu_pressure=Path('/proc/pressure/cpu').read_text(),cpu_stat=Path('/proc/stat').read_text().splitlines()[0])
                trace.write(json.dumps(sample)+'\n'); trace.flush(); time.sleep(.05)
            code = child.wait()
        raw = case/'3'; content=(raw/'run.log').read_text(); metrics=audio_metrics(content)
        assert json.loads((raw/'resource-metrics.json').read_text())['exit_code']==0,'Native test failed; inspect before continuing'
        assert 'destroy: Logger.' in content
        assert len(metrics['drained'])==len(metrics['callbacks'])==len(metrics['producer'])==2
        abi=json.loads((raw/'abi-preboot/verification.json').read_text());assert abi['passed'] and abi['library_sha256']==libraries[key]['sha256']
        assert digest(binary)==host_hash and digest(Path(libraries[key]['path']))==libraries[key]['sha256']
        row=dict(case=case.name,phase=a.phase,library=key,runtime_sha256=libraries[key]['sha256'],
                 started_unix=started,ended_unix=time.time(),strict_exit_code=code,
                 strict_acceptance_passed=code==0,metrics=metrics,log_sha256=digest(raw/'run.log'),
                 scheduler_sha256=digest(out/(case.name+'-scheduler.jsonl')))
        rows.append(row);(out/'progress.json').write_text(json.dumps(rows,indent=2));print(json.dumps(row),flush=True)
    report=dict(collection_completed=True,phase=a.phase,cases=rows,host_sha256=host_hash,libraries=libraries,
                strict_acceptance_passed=all(row['strict_acceptance_passed'] for row in rows),
                scope='Paired strict three-buffer functional matrix, explicit QEMU/llvmpipe; external load and causality require separate evidence')
    (out/'result.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)


if __name__ == '__main__':
    main()
