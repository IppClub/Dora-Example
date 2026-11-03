#!/usr/bin/env python3
"""Exercise actual source drift and EOL controls on a private source-only replica."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from audit_vendor_provenance import ROOT, SOURCE, REGISTRY, source_names


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--archive',type=Path,required=True);parser.add_argument('--upstream-git',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();assert not args.output.exists();args.output.mkdir(parents=True)
    tool=Path(__file__).with_name('audit_vendor_provenance.py');code_sha=sha(tool);registry_sha=sha(REGISTRY);names=source_names(SOURCE);controls=[]
    def run(case, source, expected=None, archive=None, registry=None):
        output=args.output/(case+'-report')
        command=['python3',str(tool),'--archive',str(archive or args.archive),'--upstream-git',str(args.upstream_git),'--source-root',str(source),'--registry',str(registry or REGISTRY),'--output',str(output)]
        result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True);(args.output/(case+'.log')).write_text(result.stdout+result.stderr)
        if expected:
            assert result.returncode!=0 and expected in result.stderr and not (output/'verification.json').exists(),(case,result.stderr)
            controls.append({'case':case,'rejected':True,'reason':expected})
        else:
            assert result.returncode==0,result.stderr
            report=json.loads((output/'verification.json').read_text());assert report['passed'] and report['registered_delta_verified'];controls.append({'case':case,'positive_verified':True})
        print(case, 'rejected' if expected else 'verified',flush=True)
    with tempfile.TemporaryDirectory(prefix='dora-godot-source-controls-') as temp:
        replica=Path(temp)/'source';replica.mkdir()
        # Real copies only: mutations must never follow hardlinks to source.
        for name in names:
            target=replica/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(SOURCE/name,target)
        run('source-replica-baseline',replica)
        for case,name in [('unregistered-upstream-edit','thirdparty/zlib/zlib.h'),('registered-bridge-edit','modules/dora_bridge/config.py')]:
            path=replica/name;original=path.read_bytes();path.write_bytes(original+b'\n/* unregistered source fixture */\n')
            run(case,replica,'Registered Dora source delta differs');path.write_bytes(original)
        path=replica/'unregistered_probe.cpp';path.write_text('int unregistered_probe;\n');run('unexpected-source',replica,'Registered Dora source delta differs');path.unlink()
        path=replica/'LICENSE.txt';original=path.read_bytes();mode=path.stat().st_mode;path.unlink();run('missing-license',replica,'Missing vendored upstream source');path.write_bytes(original);path.chmod(mode)
        path=replica/'core/core_bind.h';original=path.read_bytes();mode=path.stat().st_mode;path.unlink();path.symlink_to((SOURCE/'core/core_bind.h').resolve());run('source-symlink',replica,'Source symlink or path escape');path.unlink();path.write_bytes(original);path.chmod(mode)
        path.chmod(mode|0o111);run('unregistered-executable-mode',replica,'Registered Dora source delta differs');path.chmod(mode)
        invalid=Path(temp)/'invalid-registry.json';metadata=json.loads(REGISTRY.read_text());metadata['files'][0]['path']='../escape.cpp';invalid.write_text(json.dumps(metadata));run('unsafe-registry-path',replica,'Unsafe source path',registry=invalid)
        run('wrong-archive',replica,'Unrecognized Godot source archive',archive=SOURCE/'UPSTREAM.json')
        path=replica/'platform/android/java/gradlew.bat';original=path.read_bytes();assert b'\r\n' in original;path.write_bytes(original.replace(b'\r\n',b'\n'));run('registered-git-lf-checkout-variant',replica);path.write_bytes(original)
    run('original-source-after-controls',SOURCE)
    assert sha(tool)==code_sha and sha(REGISTRY)==registry_sha
    report={'passed':True,'scope':__doc__,'source_only_replica_files':len(names),'controls':controls,'negative_cases':sum(x.get('rejected',False) for x in controls),'positive_cases':sum(x.get('positive_verified',False) for x in controls),'audit_sha256':code_sha,'registry_sha256':registry_sha,'test_sha256':sha(Path(__file__)),'original_source_modified':False,'runtime_executed':False}
    (args.output/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS: 8 source/registry/archive rejections and 3 positive checks',flush=True)


if __name__=='__main__':main()
