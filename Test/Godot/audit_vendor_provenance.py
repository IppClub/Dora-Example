#!/usr/bin/env python3
"""Audit fixed upstream Godot and registered Dora source delta.

The original vendor import pins EOL attributes only; the current upstream tree
and archive independently establish the source baseline.

Only registered/non-ignored source is inventoried. Ignored SCons caches and
build outputs are not asserted absent or safe. No source, Git index or refs are
modified. This is provenance/integrity, not patch correctness or runtime proof.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[2] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import tarfile
import tempfile

ROOT = ENGINE_ROOT
SOURCE = ROOT / 'Source/3rdParty/Godot'
PREFIX = 'Source/3rdParty/Godot/'
UPSTREAM = 'ed1daf0bf001b61586d9930840f2f1394092c079'
IMPORT = '199c2c69c0e707808ad189200922bf71d04057b8'
ARCHIVE_SHA = 'e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a'
REGISTRY = ROOT / 'Tools/Godot/vendor/SOURCE_DELTA.json'


def sha(data):return hashlib.sha256(data).hexdigest()


def blob(data):return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def git(arguments, input=None):
    env = os.environ.copy();env['GIT_NO_LAZY_FETCH'] = '1';env['GIT_OPTIONAL_LOCKS'] = '0'
    return subprocess.check_output(['git', *arguments],cwd=ROOT,env=env,input=input)


def safe(name):
    path=PurePosixPath(name)
    assert name and not path.is_absolute() and '..' not in path.parts and path.as_posix()==name and not any(c in name for c in '\\\r\n\t\0'), 'Unsafe source path'


def tree(arguments, prefix=''):
    result={}
    for row in git([*arguments,'ls-tree','-rz',UPSTREAM] if not prefix else ['ls-tree','-rz',IMPORT,'--',prefix]).split(b'\0')[:-1]:
        header,path=row.split(b'\t');mode,kind,oid=header.split();name=path.decode().removeprefix(prefix);safe(name)
        assert kind==b'blob' and mode in (b'100644',b'100755'), 'Unsupported upstream tree entry'
        result[name]=(mode.decode(),oid.decode())
    return result


def attributes(names):
    raw=git(['check-attr','--source='+IMPORT,'-z','--stdin','text','eol'],b''.join((PREFIX+n).encode()+b'\0' for n in sorted(names))).split(b'\0')[:-1]
    assert len(raw)%3==0
    result={}
    for i in range(0,len(raw),3):
        path,key,value=(x.decode() for x in raw[i:i+3]);result.setdefault(path.removeprefix(PREFIX),{})[key]=value
    assert result.keys()==names
    assert all(x['text'] in ('set','unset','auto','unspecified') for x in result.values())
    return result


def canonical(data, attrs):
    text=attrs['text']
    if text=='set' or (text=='auto' and b'\0' not in data[:8000]):return data.replace(b'\r\n',b'\n')
    return data


def source_names(source):
    if source.resolve()==SOURCE.resolve():
        return {n.decode().removeprefix(PREFIX) for n in git(['ls-files','-z','--cached','--others','--exclude-standard','--',PREFIX]).split(b'\0')[:-1] if (ROOT/n.decode()).exists() or (ROOT/n.decode()).is_symlink()}
    # Replicas used for negative controls contain source only, no ignored caches.
    return {p.relative_to(source).as_posix() for p in source.rglob('*') if not p.is_dir() or p.is_symlink()}


def read_source(source,name):
    safe(name);path=source/name
    assert not path.is_symlink() and path.resolve().is_relative_to(source.resolve()), 'Source symlink or path escape'
    assert path.is_file(), 'Missing registered source: '+name
    assert stat.S_ISREG(path.stat().st_mode), 'Non-regular source input'
    return path.read_bytes(), '100755' if path.stat().st_mode&0o111 else '100644'


def inventory(archive,upstream_git,source):
    assert sha(archive.read_bytes())==ARCHIVE_SHA, 'Unrecognized Godot source archive'
    official=tree(['--git-dir='+str(upstream_git.resolve())])
    assert len(official)==13989, 'Unexpected pinned upstream inventory'
    names=source_names(source);assert set(official)<=names, 'Missing vendored upstream source'
    attrs=attributes(names|official.keys());deltas=[];snapshots={};before={};patches={};normalized=[];raw_identical=0
    def read(name):
        data,mode=read_source(source,name);before[name]=sha(data);value=canonical(data,attrs[name]);snapshots[name]={'mode':mode,'canonical_sha256':sha(value),'raw_sha256':sha(data)};return data,value,mode
    seen=set()
    with tarfile.open(archive) as tar:
        for member in tar:
            if member.isdir():continue
            assert member.isfile() and member.name.startswith('godot-4.7.2-stable/'), 'Unexpected source archive member'
            name=member.name.removeprefix('godot-4.7.2-stable/');safe(name);assert name not in seen;seen.add(name)
            data=tar.extractfile(member).read();mode='100755' if member.mode&0o111 else '100644';value=canonical(data,attrs[name]);identity=(mode,blob(value))
            assert official[name]==identity, 'Archive differs from fixed upstream Git object: '+name
            if blob(data)!=blob(value):
                assert attrs[name]['text'] in ('set','auto') and attrs[name]['eol']=='crlf', 'Unexplained import EOL conversion'
                normalized.append(name)
            current,content,current_mode=read(name)
            if current==data and current_mode==mode:raw_identical+=1
            if content!=value or current_mode!=mode:
                deltas.append({'path':name,'status':'modified','mode':current_mode,'canonical_sha256':sha(content),'upstream_canonical_sha256':sha(value)})
                patches[name]=(value,content)
    assert seen==official.keys()
    for name in sorted(names-official.keys()):
        data,content,mode=read(name)
        deltas.append({'path':name,'status':'added','mode':mode,'canonical_sha256':sha(content),'upstream_canonical_sha256':None});patches[name]=(b'',content)
    metadata=json.loads((source/'UPSTREAM.json').read_text());assert metadata['upstream_commit']==UPSTREAM and metadata['source_archive_sha256']==ARCHIVE_SHA and metadata['upstream_file_count']==len(official)
    deltas.sort(key=lambda x:x['path']);patch=[]
    for row in deltas:
        name=row['path'];old,new=patches[name]
        assert (not old or old.endswith(b'\n')) and (not new or new.endswith(b'\n')), 'Non-newline-terminated patch needs explicit support'
        patch.extend(difflib.unified_diff(old.decode().splitlines(True),new.decode().splitlines(True),fromfile='a/'+name if row['status']=='modified' else '/dev/null',tofile='b/'+name))
    patch=''.join(patch).encode()
    proposal={'schema':2,'upstream_commit':UPSTREAM,'source_archive_sha256':ARCHIVE_SHA,'attributes_baseline_commit':IMPORT,
        'policy':'Canonical Git text/EOL content using attributes from the fixed initial import; no other content normalization',
        'upstream_files':len(official),'registered_current_files':len(names),'archive_crlf_to_git_lf_files':sorted(normalized),
        'delta_patch_sha256':sha(patch),'files':deltas}
    for name,value in before.items():
        data,mode=read_source(source,name)
        assert sha(data)==value and mode==snapshots[name]['mode'], 'Source changed during provenance audit'
    assert source_names(source)==names, 'Source inventory changed during provenance audit'
    assert sha(archive.read_bytes())==ARCHIVE_SHA, 'Archive changed during provenance audit'
    return proposal,patch,patches,snapshots,raw_identical


def reconstruct(proposal,patch,patches):
    with tempfile.TemporaryDirectory(prefix='dora-godot-source-delta-') as temp:
        work=Path(temp)/'tree';work.mkdir();file=Path(temp)/'delta.patch';file.write_bytes(patch)
        for row in proposal['files']:
            name=row['path'];target=work/name;target.parent.mkdir(parents=True,exist_ok=True)
            if row['status']=='modified':target.write_bytes(patches[name][0])
        result=subprocess.run(['patch','--batch','--fuzz=0','-p1','-i',str(file)],cwd=work,capture_output=True,text=True)
        assert result.returncode==0 and 'offset' not in result.stdout and 'fuzz' not in result.stdout, 'Dora delta reconstruction failed: '+result.stdout+result.stderr
        expected={row['path'] for row in proposal['files']};assert {p.relative_to(work).as_posix() for p in work.rglob('*') if p.is_file()}==expected
        for row in proposal['files']:
            target=work/row['path'];assert sha(target.read_bytes())==row['canonical_sha256'];target.chmod(0o755 if row['mode']=='100755' else 0o644)
        return result.stdout


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--archive',type=Path,required=True);parser.add_argument('--upstream-git',type=Path,required=True);parser.add_argument('--source-root',type=Path,default=SOURCE);parser.add_argument('--registry',type=Path,default=REGISTRY);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--propose',action='store_true');args=parser.parse_args()
    assert not args.output.exists(), 'Use a fresh evidence directory'
    code_sha=sha(Path(__file__).read_bytes());proposal,patch,patches,snapshots,raw_identical=inventory(args.archive,args.upstream_git,args.source_root)
    args.output.mkdir(parents=True);(args.output/'proposal.json').write_text(json.dumps(proposal,indent=2)+'\n');(args.output/'delta.patch').write_bytes(patch)
    if not args.propose:
        registry_sha=sha(args.registry.read_bytes());registered=json.loads(args.registry.read_text())
        for row in registered['files']:safe(row['path'])
        assert registered==proposal, 'Registered Dora source delta differs; review the new proposal'
    log=reconstruct(proposal,patch,patches);(args.output/'reconstruction.log').write_text(log)
    (args.output/'source-inventory.json').write_text(json.dumps(snapshots,sort_keys=True,indent=2)+'\n')
    assert sha(Path(__file__).read_bytes())==code_sha
    if not args.propose:assert sha(args.registry.read_bytes())==registry_sha, 'Source registry changed during audit'
    result={'scope':__doc__,'upstream_archive_git_files_verified':proposal['upstream_files'],'current_registered_files':len(snapshots),
        'modified_files':sum(x['status']=='modified' for x in proposal['files']),'added_files':sum(x['status']=='added' for x in proposal['files']),
        'thirdparty_delta_files':[x['path'] for x in proposal['files'] if x['path'].startswith('thirdparty/')],
        'archive_crlf_files_verified':len(proposal['archive_crlf_to_git_lf_files']),'current_raw_upstream_identical_files':raw_identical,
        'reconstructed_delta_files':len(proposal['files']),'delta_patch_sha256':sha(patch),'source_inventory_sha256':sha((args.output/'source-inventory.json').read_bytes()),
        'audit_sha256':code_sha,'source_files_modified':False,'runtime_executed':False}
    if args.propose:
        result.update(proposal_generated=True,registered_delta_verified=False);filename='proposal-verification.json'
    else:
        result.update(passed=True,complete=False,registered_delta_verified=True,registry_sha256=sha(args.registry.read_bytes()));filename='verification.json'
    (args.output/filename).write_text(json.dumps(result,indent=2)+'\n');print(('PROPOSAL' if args.propose else 'PASS')+f": {proposal['upstream_files']} upstream files, {result['modified_files']} modifications, {result['added_files']} additions; no source changed")


if __name__=='__main__':main()
