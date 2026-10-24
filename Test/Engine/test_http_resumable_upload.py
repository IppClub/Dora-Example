#!/usr/bin/env python3
"""Persistent upload store regressions; --engine --large adds a >2 GiB client/engine restart test."""
import argparse, hashlib, json, os, signal, subprocess, tempfile
from pathlib import Path
from test_http_resource_limits import ROOT, MIB, post, raw, healthy, wait_for

CODE = r'''
#include "Http/HttpUploadStore.h"
#include <cassert>
using namespace Dora::HttpUpload;
static std::string hash(std::string_view text) {char out[65];assert(DoraXrtSha256Hex(text.data(),text.size(),out));return out;}
int main(int argc,char**argv) {
 auto root=fs::canonical(argv[1]); auto workspace=utf8(root);
 Store store; std::string content="first chunk|second chunk", checksum=hash(content), id=hash("session");
 auto call=[&](std::string action,uint64_t offset=0,std::string_view body="",std::string chunk="") {
  return store.handle(workspace,"","nested/项目.bin",id,checksum,content.size(),action,offset,body,chunk);
 };
 assert(call("status").offset==0);
 assert(call("chunk",0,"first chunk|",hash("wrong")).status==422);
 assert(call("status").offset==0);
 assert(call("chunk",0,"first chunk|",hash("first chunk|")).offset==12);
 assert(call("chunk",0,"first chunk|",hash("first chunk|")).status==409);
 assert(!fs::exists(root/"nested/项目.bin"));
 auto data=root/".upload"/"resume"/id/"data";
 {auto file=open(data,true,true);assert(file);assert(fwrite("uncommitted tail",1,16,file.get())==16);}
 // A new Store is a new process: on-disk metadata is the only checkpoint.
 Store restarted;
 assert(restarted.handle(workspace,"","nested/项目.bin",id,checksum,content.size(),"status",0,"","").offset==12);
 assert(fs::file_size(data)==12);
 assert(call("complete").status==409);
 assert(call("chunk",12,"second chunk",hash("second chunk")).offset==content.size());
 assert(call("complete").complete);
 assert(fs::file_size(root/"nested/项目.bin")==content.size());
 assert(call("status").complete && call("complete").complete);
 {auto file=open(root/"nested/项目.bin",true);assert(file);assert(fwrite("edited",1,6,file.get())==6);}
 assert(call("status").offset==0 && !call("status").complete);
 assert(call("chunk",0,content,checksum).status==200 && call("complete").complete);
 assert(store.handle(workspace,"","../escape",id,checksum,content.size(),"status",0,"","").status==400);
 assert(store.handle(workspace,"..","escape",id,checksum,content.size(),"status",0,"","").status==403);
 assert(store.handle(workspace,".upload/resume","evil",id,checksum,content.size(),"status",0,"","").status==403);
 assert(store.handle(workspace,"","normal","../bad",checksum,content.size(),"status",0,"","").status==400);
 fs::create_directory_symlink(root.parent_path(),root/"outside");
 assert(store.handle(workspace,"outside","escape",id,checksum,content.size(),"status",0,"","").status==403);
 // Failed final integrity verification resets progress, preserving old content.
 std::string badid=hash("bad"), expected=hash("expected");
 auto bad=[&](std::string action,std::string_view body="") {return store.handle(workspace,"","nested/项目.bin",badid,expected,8,action,0,body,hash(body));};
 assert(bad("status").status==200); assert(bad("chunk","tampered").status==200);
 assert(bad("complete").status==422); assert(bad("status").offset==0);
 assert(fs::file_size(root/"nested/项目.bin")==content.size());
 // 64-bit offset handling: sparse checkpoint past 2 GiB, with a real append.
 std::string largeid=hash("large");auto session=root/".upload"/"resume"/largeid;fs::create_directory(session);
 {auto file=open(session/"data",true);assert(file);}
 uint64_t offset=2147483648ull+17;fs::resize_file(session/"data",offset);
 std::string meta=std::to_string(offset)+"\n"+std::to_string(offset+1)+"\n"+checksum+"\n"+utf8(root/"large.bin");
 {auto file=open(session/"meta",true);assert(file);assert(fwrite(meta.data(),1,meta.size(),file.get())==meta.size());}
 auto result=store.handle(workspace,"","large.bin",largeid,checksum,offset+1,"chunk",offset,"x",hash("x"));
 assert(result.status==200 && result.offset==offset+1);
 assert(fs::file_size(session/"data")==offset+1);
 // Abandoned checkpoints expire without touching recent uploads.
 fs::last_write_time(session/"meta",fs::file_time_type::clock::now()-std::chrono::hours(23));
 call("status");assert(fs::exists(session));
 fs::last_write_time(session/"meta",fs::file_time_type::clock::now()-std::chrono::hours(25));
 call("status");assert(!fs::exists(session));
 puts("Persistent store: checkpoints/restart, interrupted tails, duplicate chunks, checksum failure, atomic publication, traversal/symlinks, >2 GiB offsets and expiry: PASS");
}
'''

def fixture(temp):
    source=temp/'test.cpp';source.write_text(CODE)
    obj=temp/'network.o';exe=temp/'test'
    subprocess.run(['clang','-std=c11','-pthread','-w','-g','-fsanitize=address,undefined','-I'+str(ROOT/'Source'),'-I'+str(ROOT/'Source/3rdParty'),'-c',str(ROOT/'Source/Http/XrtNetwork.c'),'-o',str(obj)],check=True)
    subprocess.run(['clang++','-std=c++20','-pthread','-g','-fsanitize=address,undefined','-I'+str(ROOT/'Source'),str(source),str(obj),'-o',str(exe)],check=True)
    workspace=temp/'workspace';workspace.mkdir()
    subprocess.run([str(exe),str(workspace)],check=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})

CLIENT = r'''
import {open} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const [root,temp,filePath,mode] = process.argv.slice(2);
const {build} = createRequire(root+'/Tools/dora-dora/package.json')('esbuild');
await build({entryPoints:[root+'/Tools/dora-dora/src/UploadFile.ts'],bundle:true,format:'esm',platform:'node',outfile:temp+'/upload.mjs'});
const {uploadFile} = await import(pathToFileURL(temp+'/upload.mjs'));
const disk = await open(filePath); const info=await disk.stat();
const file={name:'超过2G.bin',size:info.size,slice(start,end){return {async arrayBuffer(){const buffer=Buffer.alloc(Math.min(end,info.size)-start);const {bytesRead}=await disk.read(buffer,0,buffer.length,start);if(bytesRead!==buffer.length)throw Error('short read');return buffer.buffer;}};}};
const originalFetch = globalThis.fetch;
let firstOffset=null, stopped=false, interrupted=false;
globalThis.fetch = async (url,init) => {
 init={...init,headers:{...init.headers,'Sec-Fetch-Site':'same-origin'}};
 const query=new URL(url).searchParams;
 if(stopped)throw new TypeError('simulated connection outage');
 if(query.get('action')==='chunk') {
  const offset=Number(query.get('offset'));if(firstOffset===null)firstOffset=offset;
  const response=await originalFetch(url,init);
  if(mode==='interrupt' && offset>=8*1024*1024 && response.ok){stopped=true;interrupted=true;throw new TypeError('lost acknowledgement');}
  return response;
 }
 return originalFetch(url,init);
};
try {
 await uploadFile('http://localhost:8866/upload?path=ResumeProbe&name='+encodeURIComponent(file.name),file);
 if(mode==='interrupt')throw Error('expected outage');
 if(!(firstOffset>=12*1024*1024))throw Error('did not resume from saved checkpoint: '+firstOffset);
 console.log('Real upload client resumed after engine restart at '+firstOffset+' bytes; completed '+file.size+' bytes');
} catch(error) {
 if(mode!=='interrupt'||!interrupted||error.reason!=='networkError')throw error;
 console.log('Real upload client stopped after lost acknowledgement; confirmed data retained');
} finally {await disk.close();}
'''

def engine_test(engine,temp,large):
    profile=temp/'profile';profile.mkdir();client=temp/'client.mjs';client.write_text(CLIENT)
    sample=temp/'source.bin';size=(2048*MIB+12345 if large else 33*MIB)
    with sample.open('wb') as file:
        file.truncate(size);file.write(b'header: resumable upload');file.seek(size-4);file.write(b'tail')
    env={**os.environ,'CFFIXED_USER_HOME':str(profile),'XDG_DATA_HOME':str(profile/'data')}
    proc=None
    with (temp/'engine.log').open('w+') as log:
        def start():
            process=subprocess.Popen([str(engine),'--asset',str(ROOT/'Assets')],cwd=ROOT/'Assets',env=env,stdout=log,stderr=log)
            wait_for(lambda:process.poll() is None and healthy(8866),30)
            return process
        def stop(process):
            process.send_signal(signal.SIGTERM);process.wait(timeout=10);assert process.returncode==0
        try:
            proc=start()
            code,data=post(8866,'/status');assert code==200
            writable=Path(json.loads(data)['writablePath']);assert profile in writable.parents
            dest=writable/'ResumeProbe';dest.mkdir()
            denied=b'POST /upload/resumable HTTP/1.1\r\nHost: localhost:8866\r\nOrigin: https://untrusted.invalid\r\nSec-Fetch-Site: cross-site\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
            assert raw(8866,denied)[0] in (401,403)
            # Existing target must survive the entire interrupted transfer.
            target=dest/'超过2G.bin';target.write_bytes(b'previous version')
            subprocess.run(['node',str(client),str(ROOT),str(temp),str(sample),'interrupt'],check=True,timeout=180)
            assert target.read_bytes()==b'previous version'
            checkpoint=list((writable/'.upload'/'resume').glob('*/meta'));assert len(checkpoint)==1
            assert int(checkpoint[0].read_text().splitlines()[0])>=12*MIB
            # Ordinary temporary files must be cleared while resume is retained.
            ordinary=writable/'.upload'/'files';ordinary.mkdir(exist_ok=True)
            (ordinary/'unfinished.bin').write_bytes(b'temporary')
            loose=writable/'.upload'/'old-upload.bin';loose.write_bytes(b'old temporary')
            download=writable/'.download';download.mkdir(exist_ok=True)
            (download/'unfinished.zip').write_bytes(b'temporary')
            stop(proc);proc=None
            proc=start()
            assert not ordinary.exists() and not loose.exists() and not download.exists()
            assert checkpoint[0].exists(), 'Startup removed resumable checkpoint'
            subprocess.run(['node',str(client),str(ROOT),str(temp),str(sample),'resume'],check=True,timeout=300)
            assert target.stat().st_size==size
            def digest(file):
                hasher=hashlib.sha256()
                with file.open('rb') as stream:
                    while block:=stream.read(MIB):hasher.update(block)
                return hasher.hexdigest()
            assert digest(sample)==digest(target)
            assert not list((writable/'.upload'/'resume').glob('*/data'))
            from test_http_resource_limits import upload
            assert upload(8866,4096,path='/upload?path=ResumeProbe')[0]==200
            assert (dest/'large.bin').read_bytes()==b'x'*4096
            sentinel=dest/'recovery.lua';sentinel.write_text('return true')
            code,data=post(8866,'/read',{'path':str(sentinel)})
            assert code==200 and json.loads(data)['content']=='return true'
            print(f'Real engine/client: {size} bytes, lost response, restart, checkpoint resume, atomic replacement and exact SHA-256: PASS',flush=True)
        except BaseException:
            log.flush();log.seek(0);print(log.read()[-3000:],flush=True);raise
        finally:
            if proc is not None and proc.poll() is None:stop(proc)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--engine',type=Path);parser.add_argument('--large',action='store_true');args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='dora-resume-') as name:
        temp=Path(name);fixture(temp)
        if args.engine:engine_test(args.engine.resolve(),temp,args.large)
