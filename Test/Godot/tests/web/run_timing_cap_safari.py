#!/usr/bin/env python3
"""Extract actual Godot get_image pixels in installed Safari, then verify them.

Uses existing Safari remote-automation permission. Owns its WebDriver session,
local server and window; never changes Safari preferences or runtime files.
"""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
from pathlib import Path
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = ENGINE_ROOT
OBSERVER = b'''<script>
window.__capShutdown={calls:0,completed:0};
window.addEventListener('dora-statechange',()=>{
 const g=window.Module?.doraGodotRuntime;
 if(!g||g.__capObserved)return;
 g.__capObserved=true;
 const shutdown=g._dora_web_shutdown;
 g._dora_web_shutdown=(...args)=>{
  window.__capShutdown.calls++;
  const result=shutdown(...args);
  window.__capShutdown.completed++;
  return result;
 };
});
</script>'''


def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--package', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--buffers', type=int, choices=(2, 3, 4), required=True)
    a = p.parse_args(); package = a.package.resolve(); out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    metadata = json.loads((package/'timing-cap-source.json').read_text())
    assert metadata['buffers'] == a.buffers
    init = Path(__file__).with_name('acceptance_init.js')
    names = ['index.html','dora-player-runtime.js','dora-player-runtime.wasm','dora-player-runtime.data',
             'dora-web-manifest.json','godot/dora-godot.js','godot/dora-godot.wasm',
             'godot/shared_gl.mjs','godot/runtime_bridge.mjs','timing-cap-source.json']
    artifacts = {name:digest(package/name) for name in names}
    manifest=json.loads((package/'dora-web-manifest.json').read_text())
    entry=next(f for f in manifest['files'] if f['path']==manifest['entry'])
    fixture=(package/urllib.parse.urlsplit(entry['url']).path.lstrip('/')).resolve()
    assert fixture.is_relative_to(package) and digest(fixture)==entry['sha256']
    assert b'DORA_WEB_CAP_DONE' in fixture.read_bytes()
    report = dict(passed=False,browser_engine='safari',browser_headless=False,artifacts=artifacts,metadata=metadata,
                  instrumentation_sha256=digest(init),shutdown_observer_sha256=hashlib.sha256(OBSERVER).hexdigest())
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    session=None;driver=None;server=None;endpoint=None;logs=[]

    def request(method,path,payload=None):
        body=None if payload is None else json.dumps(payload).encode()
        req=urllib.request.Request(endpoint+path,data=body,method=method,headers={'Content-Type':'application/json'})
        try:
            with opener.open(req,timeout=150 if path.endswith('/url') else 60) as response:value=json.load(response)['value']
        except urllib.error.HTTPError as error:
            raise RuntimeError(json.loads(error.read())) from error
        assert not isinstance(value,dict) or 'error' not in value,value
        return value

    def execute(code,*args):
        return request('POST',f'/session/{session}/execute/sync',{'script':code,'args':list(args)})

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            name=urllib.parse.unquote(urllib.parse.urlsplit(self.path).path).lstrip('/') or 'index.html'
            if name=='favicon.ico':self.send_response(204);self.end_headers();return
            file=init if name=='__dora_acceptance_init.js' else (package/name).resolve()
            if file!=init and not file.is_relative_to(package):self.send_error(403);return
            if not file.is_file():self.send_error(404);return
            data=file.read_bytes()
            if name=='index.html':
                assert b'<head>' in data
                data=data.replace(b'<head>',b'<head><script src="/__dora_acceptance_init.js"></script>'+OBSERVER,1)
            self.send_response(200)
            self.send_header('Content-Type',mimetypes.guess_type(file.name)[0] or 'application/octet-stream')
            self.send_header('Content-Length',str(len(data)))
            for key,value in [('Cache-Control','no-store'),('Cross-Origin-Opener-Policy','same-origin'),('Cross-Origin-Embedder-Policy','require-corp')]:self.send_header(key,value)
            self.end_headers();self.wfile.write(data)
        def log_message(self,*args):pass

    try:
        with socket.socket() as probe:probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
        endpoint=f'http://127.0.0.1:{port}'
        with (out/'driver.log').open('w') as log:
            driver=subprocess.Popen(['/usr/bin/safaridriver','-p',str(port)],stdout=log,stderr=subprocess.STDOUT)
        report['driver_pid']=driver.pid;report['driver_port']=port
        for _ in range(100):
            assert driver.poll() is None,'Owned SafariDriver exited'
            try:request('GET','/status');break
            except (OSError,urllib.error.URLError):time.sleep(.1)
        else:raise TimeoutError('Owned SafariDriver unavailable')
        value=request('POST','/session',{'capabilities':{'alwaysMatch':{'browserName':'safari'}}})
        session=value['sessionId'];report['capabilities']=value['capabilities'];report['browser']=value['capabilities'].get('browserVersion')
        request('POST',f'/session/{session}/timeouts',{'pageLoad':120000,'script':30000,'implicit':0})
        request('POST',f'/session/{session}/window/rect',{'x':0,'y':40,'width':1280,'height':800})
        server=ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
        request('POST',f'/session/{session}/url',{'url':f'http://127.0.0.1:{server.server_port}/'})
        deadline=time.monotonic()+90;copied=False
        while time.monotonic()<deadline:
            state=execute('''const h=window.Module,g=h?.doraGodotRuntime,e=window.__doraAcceptance;
                const state=document.documentElement.dataset.doraState;
                let files=null;
                if(g?.FS&&h?.FS){
                 if(g.FS.analyzePath('/game/godot/clock-a.png').exists)h.FS.writeFile('/user/cap-a.ready','ready');
                 if(g.FS.analyzePath('/game/godot/result.json').exists){
                  files={};for(const n of ['clock-a.png','clock-b.png','result.json'])files[n]=Array.from(g.FS.readFile('/game/godot/'+n));
                  h.FS.writeFile('/user/cap.done','copied');
                 }
                }
                return {state,evidence:e||{logs:[],errors:[],warnings:[]},files,crossOriginIsolated};''')
            evidence=state['evidence'];logs=evidence['logs'];report['last_state']=dict(state=state['state'],crossOriginIsolated=state['crossOriginIsolated'])
            assert state['state']!='faulted',state['state']
            assert not any(not text.startswith('Blocking on the main thread is very dangerous') for text in evidence['errors']),evidence['errors']
            if state['files'] and not copied:
                for name,data in state['files'].items():(out/name).write_bytes(bytes(data))
                copied=True
            if copied and (any('DORA_WEB_CAP_DONE' in line for line in logs) or metadata.get('host_shutdown') and state['state']=='stopped'):break
            time.sleep(.02)
        else:raise TimeoutError('Native Safari Godot CPU readback timed out')
        assert copied and state['crossOriginIsolated']
        if state['state']!='stopped':execute("Module.ccall('dora_web_stop','number',[],[]);return true;")
        deadline=time.monotonic()+15
        while execute("return document.documentElement.dataset.doraState;")!='stopped':
            assert time.monotonic()<deadline,'Normal Safari teardown timed out';time.sleep(.1)
        teardown=execute('return {state:document.documentElement.dataset.doraState,platform:Module.doraWebPlatform.state,libgodot_shutdown:window.__capShutdown,gpu_lifecycle:Module.doraTestAudioMetrics};')
        assert not teardown['platform']['active'] and teardown['libgodot_shutdown']==dict(calls=1,completed=1),teardown
        hashes={**metadata['fixture'],**metadata['adapters']}
        sources=execute('const result={host:{},godot:{}};for(const n of arguments[0]){result.host[n]=Array.from(Module.FS.readFile("/game/godot/"+n));result.godot[n]=Array.from(Module.doraGodotRuntime.FS.readFile("/game/godot/"+n));}return result;',list(hashes))
        source_hashes={side:{name:hashlib.sha256(bytes(data)).hexdigest() for name,data in files.items()} for side,files in sources.items()}
        assert source_hashes['host']==source_hashes['godot']==hashes
        assert all(digest(package/name)==sha for name,sha in artifacts.items()) and digest(init)==report['instrumentation_sha256']
        evidence=execute('return window.__doraAcceptance;');logs=evidence['logs']
        assert not any(not text.startswith('Blocking on the main thread is very dangerous') for text in evidence['errors'])
        assert not any(re.search(r'GL_INVALID|INVALID_OPERATION|INVALID_VALUE|INVALID_ENUM',text) for text in evidence['warnings'])
        report.update(passed=True,source_hashes_verified=True,source_hashes=source_hashes,teardown=teardown,
                      browser_errors=evidence['errors'],browser_warnings=evidence['warnings'],
                      scope='Installed native Safari: actual Godot heap CPU pixels, resize, exact source hashes, observed LibGodot shutdown; strict pixel verifier additionally required')
        (out/'run.log').write_text('\n'.join(logs)+'\n');(out/'execution.json').write_text(json.dumps(report,indent=2)+'\n')
        subprocess.run([sys.executable,str(ROOT/str(test_path('Tools/Godot/tests/verify_timing_cap.py'))),str(out),'--engine-readback','--web-execution','--buffers',str(a.buffers)],check=True)
    except BaseException as error:
        report.update(passed=False,error=repr(error));(out/'verification.json').unlink(missing_ok=True)
        raise
    finally:
        report['logs']=logs;(out/'execution.json').write_text(json.dumps(report,indent=2)+'\n');(out/'run.log').write_text('\n'.join(logs)+'\n')
        if session:
            try:request('DELETE',f'/session/{session}')
            except Exception:pass
        if driver and driver.poll() is None:
            driver.terminate()
            try:driver.wait(timeout=10)
            except subprocess.TimeoutExpired:driver.kill();driver.wait()
        if server:server.shutdown();server.server_close()


if __name__=='__main__':main()
