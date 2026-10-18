#!/usr/bin/env python3
"""Bounded production HTTP ingress, disk uploads, admission and recovery.

Default: ASan/UBSan native wire fixture. --engine additionally exercises the real
IDE on 8866/8868 in an isolated profile (no existing engine may occupy them).
"""
import argparse, hashlib, http.client, json, os, select, socket, subprocess, tempfile, time
from pathlib import Path
ROOT = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd())).resolve()
MIB = 1024 * 1024
CODE = r'''
#include "Source/Http/XrtNetwork.c"
#include <assert.h>
typedef struct { size_t bytes, sum; } Totals;
static int faultMode;
static char readonlyPath[4096];
static FILE* spool(ptr context) {
 if(faultMode==1)return NULL;
 if(faultMode==2)return fopen(readonlyPath,"rb");
 return DoraXrtOpenUploadFile(context);
}
static int part(void* unused, const DoraXrtMultipartFileView* p) {
 Totals* total=(Totals*)unused; assert(p->bodyFile && !p->body);
 char buffer[65536]; assert(!fseek(p->bodyFile,(long)p->bodyOffset,SEEK_SET));
 size_t left=p->bodyLen; total->bytes+=left;
 while(left){size_t n=left<sizeof(buffer)?left:sizeof(buffer);assert(fread(buffer,1,n,p->bodyFile)==n);
 for(size_t i=0;i<n;i++)total->sum+=(unsigned char)buffer[i];left-=n;} return 1;
}
static int head(void* unused,const DoraXrtHttpServerRequest* r){
 (void)unused;if(strcmp(r->path,"/upload"))return 0;
 const char* auth=DoraXrtHttpServerRequestHeader(r,"X-Test-Auth");return auth&&!strcmp(auth,"yes")?1:401;
}
static int defer(void* unused, const char* path) { (void)unused; return !strcmp(path,"/upload"); }
static int request(void* unused,const DoraXrtHttpServerRequest* r,DoraXrtHttpServerResponse* response){
 (void)unused;char answer[200];Totals total={0};
 if(!strcmp(r->path,"/storage/create-fail"))faultMode=1;
 if(!strcmp(r->path,"/storage/write-fail"))faultMode=2;
 if(!strcmp(r->path,"/storage/reset"))faultMode=0;
 if(!strcmp(r->path,"/upload")){
  assert(r->uploadAuthorized && r->bodyFile && !r->body);
  int result=DoraXrtMultipartFileForEachFile(DoraXrtHttpServerRequestHeader(r,"Content-Type"),r->bodyFile,r->bodyLen,512u*1024u*1024u,part,&total);
  if(result!=1){DoraXrtHttpServerResponseSetStatus(response,400,NULL);return 1;}
 }
 snprintf(answer,sizeof(answer),"{\"success\":true,\"bytes\":%zu,\"sum\":%zu}",total.bytes,total.sum);
 DoraXrtHttpServerResponseSetBodyCopy(response,answer,strlen(answer),"application/json");return 1;
}
int main(int argc,char**argv){
 DoraXrtHttpServerEvents events={0};events.onRequest=request;events.onUploadHead=head;events.shouldDefer=defer;events.temporaryDirectory=argv[1];
 snprintf(readonlyPath,sizeof(readonlyPath),"%s/readonly",argv[1]);FILE* empty=fopen(readonlyPath,"wb");assert(empty);fclose(empty);
 DoraXrtHttpServer* h=DoraXrtHttpServerCreate(0,512u*1024u*1024u,&events,NULL);assert(h);
 h->native->tConfig.OpenSpoolFile=spool;
 DoraXrtWebSocketServerEvents wsEvents={0};
 DoraXrtWebSocketServer* ws=DoraXrtWebSocketServerCreate(0,16u*1024u*1024u,&wsEvents,NULL);assert(ws);
 printf("%u %u\n",xrtHttpdBoundPort(h->native),xrtWsServerBoundPort(ws->native));fflush(stdout);
 getchar();DoraXrtHttpServerDestroy(h);DoraXrtWebSocketServerDestroy(ws);
 /* Let detached timeout holds retire while sanitizer can still observe them. */
 xrtSleep(1100);return 0;
}
'''

def connect(port):
    return socket.create_connection(('127.0.0.1', port), 5)

def status(sock):
    sock.settimeout(5)
    response = http.client.HTTPResponse(sock)
    response.begin()
    data = response.read()
    return response.status, data

def raw(port, headers, data=b''):
    with connect(port) as s:
        s.sendall(headers + data)
        return status(s)

def post(port, path='/info', payload=None):
    body = json.dumps(payload or {}).encode()
    return raw(port, f'POST {path} HTTP/1.1\r\nHost: localhost:{port}\r\nContent-Type: application/json\r\nSec-Fetch-Site: same-origin\r\nContent-Length: {len(body)}\r\nConnection: close\r\n\r\n'.encode(), body)

def wait_for(check, timeout=8):
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        try:
            if check(): return
        except (OSError, http.client.HTTPException): pass
        time.sleep(.05)
    raise AssertionError('Timed out waiting for recovery')

def healthy(port):
    code,_=raw(port,f'GET / HTTP/1.1\r\nHost: localhost:{port}\r\nConnection: close\r\n\r\n'.encode())
    return code==200

def headers(port,path,length=None,chunked=False,auth=True,expect=False):
    value=f'POST {path} HTTP/1.1\r\nHost: localhost:{port}\r\nSec-Fetch-Site: same-origin\r\nConnection: close\r\n'
    value+='Content-Type: multipart/form-data; boundary=dora-test\r\n' if path.split('?')[0]=='/upload' else 'Content-Type: application/json\r\n'
    if auth:value+='X-Test-Auth: yes\r\n'
    value+= 'Transfer-Encoding: chunked\r\n' if chunked else f'Content-Length: {length}\r\n'
    if expect:value+='Expect: 100-continue\r\n'
    return (value+'\r\n').encode()

def upload(port, size, *, chunked=False, path='/upload', auth=True):
    prefix=b'--dora-test\r\nContent-Disposition: form-data; name="file"; filename="large.bin"\r\nContent-Type: application/octet-stream\r\n\r\n'
    suffix=b'\r\n--dora-test--\r\n'
    with connect(port) as s:
        s.sendall(headers(port,path,len(prefix)+size+len(suffix),chunked,auth))
        def send(data):
            s.sendall(f'{len(data):x}\r\n'.encode()+data+b'\r\n' if chunked else data)
        send(prefix)
        left=size
        while left:
            n=min(left,65536);send(b'x'*n);left-=n
        send(suffix)
        if chunked:s.sendall(b'0\r\n\r\n')
        return status(s)

def reject_closed(s):
    try:
        s.sendall(b'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n')
        s.settimeout(3)
        return s.recv(1)==b''
    except (ConnectionError,OSError): return True

def connection_exhaustion(http_port, ws_port):
    # Incomplete headers consume an admitted TCP connection without large bodies.
    for port,limit in ((http_port,64),(ws_port,16)):
        held=[]
        try:
            for _ in range(limit):
                s=connect(port);s.sendall(b'GET / HTTP/1.1\r\n');held.append(s)
            time.sleep(.3)
            # Ensure all admitted connections are still alive, so this is actual saturation.
            for s in held:
                assert not select.select([s],[],[],0)[0], 'Admitted connection closed early'
            for _ in range(8):
                with connect(port) as extra:assert reject_closed(extra), f'{port}: cap not enforced'
        finally:
            for s in held:s.close()
        wait_for(lambda:healthy(http_port))
        print(f'connection cap {limit}, rejected overflow, HTTP/IDE recovery: PASS',flush=True)
    # Handshake works again after freeing WS slots.
    with connect(ws_port) as s:
        s.sendall(f'GET / HTTP/1.1\r\nHost: localhost:{ws_port}\r\nOrigin: http://localhost:{http_port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n'.encode())
        assert b'101 Switching Protocols' in s.recv(4096)
    print('WebSocket upgrade after exhaustion: PASS',flush=True)

def fixture(temp):
    source=temp/'fixture.c';exe=temp/'fixture';source.write_text(CODE)
    subprocess.run([os.environ.get('CC','cc'),'-std=c11','-pthread','-w','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer','-I',str(ROOT),'-I',str(ROOT/'Source'),'-I',str(ROOT/'Source/3rdParty'),str(source),'-lm','-o',str(exe)],check=True)
    with (temp/'fixture.log').open('w+') as log:
        proc=subprocess.Popen([str(exe),str(temp)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=log,text=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
        try:
            line=proc.stdout.readline();assert line,line
            port,ws_port=map(int,line.split())
            assert healthy(port)
            for path,limit in (('/info',8*MIB),('/upload',512*MIB)):
                code,_=raw(port,headers(port,path,limit+1,expect=True));assert code==413,(path,code)
                code,_=raw(port,headers(port,path,chunked=True)+f'{limit+1:x}\r\n'.encode());assert code==413,(path,code)
            assert raw(ws_port,b'GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 536870912\r\n\r\n')[0]==400
            assert raw(ws_port,b'GET / HTTP/1.1\r\nHost: localhost\r\nX-Oversize: '+b'x'*65536)[0]==431
            assert raw(port,headers(port,'/upload',100,auth=False,expect=True))[0]==401
            assert healthy(port)
            print('Content-Length/chunked oversize rejected before body; pre-body authorization: PASS',flush=True)
            for chunked in (False,True):
                code,data=upload(port,12*MIB,chunked=chunked)
                assert code==200,(code,data)
                result=json.loads(data);assert result['bytes']==12*MIB and result['sum']==12*MIB*120,result
            print('12 MiB disk uploads, Content-Length and chunked, exact contents: PASS',flush=True)
            # Boundary-like bytes and delimiters split across the parser's read window.
            payload=b'a'*65529+b'\r\n--dora-testX\x00binary'+b'b'*65530
            multipart=(b'--dora-test\r\nContent-Disposition: form-data; name="file"; filename="one.bin"\r\n\r\n'+payload+
                b'\r\n--dora-test\r\nContent-Disposition: form-data; name="file"; filename="two.bin"\r\n\r\nsecond\r\n--dora-test--\r\n')
            code,data=raw(port,headers(port,'/upload',len(multipart)),multipart)
            assert code==200,(code,data)
            result=json.loads(data);assert result['bytes']==len(payload)+6 and result['sum']==sum(payload+b'second'),result
            broken=multipart[:-20]
            assert raw(port,headers(port,'/upload',len(broken)),broken)[0]==400
            assert raw(port,headers(port,'/info',8*MIB),b'x'*(8*MIB))[0]==200
            with connect(port) as wire:
                wire.sendall(headers(port,'/info',chunked=True)+b'800000\r\n'+b'x'*(8*MIB)+b'\r\n1\r\n')
                assert status(wire)[0]==413
            assert raw(port,b'POST / HTTP/1.1\r\nHost: localhost\r\nX-Oversize: '+b'x'*65536)[0]==431
            for fault in ('create-fail','write-fail'):
                assert post(port,'/storage/'+fault)[0]==200
                assert raw(port,headers(port,'/upload',5),b'hello')[0]==507
                assert post(port,'/storage/reset')[0]==200
                assert upload(port,128)[0]==200
            print('multipart binary/window/truncation, cumulative chunk limit, header cap, spool failures + lease recovery: PASS',flush=True)
            small=[]
            try:
                for _ in range(6):
                    wire=connect(port);wire.sendall(headers(port,'/info',10000)+b'x');small.append(wire)
                time.sleep(.15)
                assert not select.select(small,[],[],0)[0], 'Small bodies were limited by request count instead of bytes'
                assert post(port)[0]==200
            finally:
                for wire in small:wire.close()
            time.sleep(.1)
            print('shared byte budget preserves concurrent small IDE requests: PASS',flush=True)
            for path,slots in (('/info',4),('/upload',2)):
                held=[]
                try:
                    for _ in range(slots):
                        s=connect(port);s.sendall(headers(port,path,8*MIB if path=='/info' else 10000)+b'x');held.append(s)
                    time.sleep(.15)
                    assert not select.select(held,[],[],0)[0]
                    assert raw(port,headers(port,path,8*MIB if path=='/info' else 10000,expect=True))[0]==503
                    assert healthy(port)
                finally:
                    for s in held:s.close()
                wait_for(lambda:healthy(port))
                # Successfully admitting a body again proves the body lease was returned.
                if path=='/info':assert post(port)[0]==200
                else:assert upload(port,128)[0]==200
            print('buffer/upload budgets reject before allocation; disconnect returns leases: PASS',flush=True)
            connection_exhaustion(port,ws_port)
            # Idle partial HTTP and WS handshakes must expire and release admission.
            idle=[connect(port),connect(ws_port)]
            for s in idle:s.sendall(b'GET / HTTP/1.1\r\n')
            time.sleep(16.5)
            for s in idle:
                s.settimeout(2)
                try:data=s.recv(4096)
                except ConnectionResetError:data=b''
                assert not data or b'408' in data,data
                s.close()
            assert healthy(port)
            print('idle HTTP/WS handshake timeout and recovery: PASS',flush=True)
        finally:
            if proc.poll() is None:
                proc.stdin.write('\n');proc.stdin.flush()
                try:proc.wait(timeout=10)
                except subprocess.TimeoutExpired:proc.kill();proc.wait()
            log.seek(0);errors=log.read()
            assert proc.returncode==0,(proc.returncode,errors)
            assert 'ERROR: AddressSanitizer' not in errors and 'runtime error:' not in errors,errors

def engine_tests(engine, temp, hold=False):
    import signal, threading, urllib.parse
    for port in (8866,8868):
        with socket.socket() as probe:
            probe.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
            probe.bind(('0.0.0.0',port))
    profile=temp/'engine-profile';profile.mkdir()
    with (temp/'engine.log').open('w+') as log:
        proc=subprocess.Popen([str(engine),'--asset',str(ROOT/'Assets')],cwd=ROOT/'Assets',stdout=log,stderr=log,
            env={**os.environ,'CFFIXED_USER_HOME':str(profile),'XDG_DATA_HOME':str(profile/'data')})
        try:
            wait_for(lambda:proc.poll() is None and healthy(8866),30)
            code,data=post(8866,'/status');assert code==200
            writable=Path(json.loads(data)['writablePath'])
            assert profile in writable.parents, f'Profile isolation failed: {writable}'
            destination=writable/'ResourceLimitProbe';destination.mkdir()
            def ide_roundtrip():
                assert healthy(8866)
                code,data=raw(8866,b'GET / HTTP/1.1\r\nHost: localhost:8866\r\nConnection: close\r\n\r\n')
                assert code==200 and b'<html' in data.lower(),(code,data[:100])
                code,data=post(8866,'/assets');assert code==200 and json.loads(data)['key']==str(writable)
                file=destination/'recovery.lua'
                code,data=post(8866,'/write',{'path':str(file),'content':'return "IDE recovered"\n'})
                assert code==200 and json.loads(data)['success'],(code,data)
                code,data=post(8866,'/read',{'path':str(file)})
                assert code==200 and json.loads(data)['content']=='return "IDE recovered"\n',(code,data)
            ide_roundtrip()
            for path,limit in (('/info',8*MIB),('/upload?path=ResourceLimitProbe',512*MIB)):
                assert raw(8866,headers(8866,path,limit+1,expect=True))[0]==413
                assert raw(8866,headers(8866,path,chunked=True)+f'{limit+1:x}\r\n'.encode())[0]==413
            ide_roundtrip()
            print('real engine: oversize fixed/chunked requests + IDE read/write recovery: PASS',flush=True)
            # A request with an untrusted Origin must fail before accepting upload bytes.
            bad=headers(8866,'/upload?path=ResourceLimitProbe',100,expect=True).replace(b'Connection: close\r\n',b'Connection: close\r\nOrigin: https://untrusted.invalid\r\n')
            assert raw(8866,bad)[0] in (401,403)
            assert not list(writable.glob('.dora-upload-*'))
            # Sample real process RSS while uploading well beyond the ordinary API cap.
            def rss():
                return int(subprocess.check_output(['ps','-o','rss=','-p',str(proc.pid)]).strip())*1024
            baseline=rss();samples=[baseline];stop=threading.Event()
            def sample():
                while not stop.wait(.03):
                    samples.append(rss())
            sampler=threading.Thread(target=sample);sampler.start()
            try:
                for size,chunked in ((511*MIB,False),(12*MIB,True)):
                    code,data=upload(8866,size,chunked=chunked,path='/upload?path=ResourceLimitProbe')
                    assert code==200,(code,data)
                    file=destination/'large.bin'
                    assert file.stat().st_size==size
                    expected=hashlib.sha256();actual=hashlib.sha256()
                    with file.open('rb') as stream:
                        while block:=stream.read(65536):
                            actual.update(block);expected.update(b'x'*len(block))
                    assert actual.digest()==expected.digest()
                    file.unlink()
            finally:
                stop.set();sampler.join()
            delta=max(samples)-baseline
            assert delta<64*MIB,f'Upload RSS grew by {delta/MIB:.1f} MiB'
            print(f'real engine: 511 MiB fixed + 12 MiB chunked uploads, SHA-256 exact; peak RSS delta {delta/MIB:.2f} MiB: PASS',flush=True)
            # Aborted uploads release both spool permits without publishing partial files.
            held=[]
            try:
                for _ in range(2):
                    s=connect(8866);s.sendall(headers(8866,'/upload?path=ResourceLimitProbe',10000)+b'--dora-test\r\n');held.append(s)
                time.sleep(.15)
                assert raw(8866,headers(8866,'/upload?path=ResourceLimitProbe',10000,expect=True))[0]==503
            finally:
                for s in held:s.close()
            wait_for(lambda:healthy(8866))
            assert upload(8866,4096,path='/upload?path=ResourceLimitProbe')[0]==200
            assert (destination/'large.bin').read_bytes()==b'x'*4096
            assert not list(writable.glob('.dora-upload-*'))
            print('real engine: upload exhaustion, cancellation cleanup and subsequent upload: PASS',flush=True)
            connection_exhaustion(8866,8868)
            ide_roundtrip()
            print('real engine: IDE assets/tree/read/save work after HTTP + WS exhaustion: PASS',flush=True)
            if hold:
                print(f'BROWSER ACCEPTANCE READY http://localhost:8866/ workspace={destination}',flush=True)
                input('Press Enter after browser acceptance to stop the isolated engine: ')
        except BaseException:
            log.flush();log.seek(0);print(log.read()[-4000:],flush=True)
            raise
        finally:
            proc.send_signal(signal.SIGTERM) if proc.poll() is None else None
            try:proc.wait(timeout=8)
            except subprocess.TimeoutExpired:proc.kill();proc.wait();raise AssertionError('Engine failed to shut down')
            assert proc.returncode==0,proc.returncode
    for port in (8866,8868):
        with socket.socket() as probe:
            probe.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
            probe.bind(('0.0.0.0',port))
    print('real engine: clean shutdown and both ports released: PASS',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--engine',type=Path);parser.add_argument('--hold',action='store_true');parser.add_argument('--engine-only',action='store_true');args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='dora-http-limits-') as name:
        if not args.engine_only: fixture(Path(name))
        if args.engine: engine_tests(args.engine.resolve(),Path(name),args.hold)
