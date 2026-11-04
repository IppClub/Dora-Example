#!/usr/bin/env python3
"""Native Safari smoke of the same real-project Web lifecycle fixture."""
import argparse,json,mimetypes,socket,subprocess,threading,time,urllib.request,urllib.parse
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('package',type=Path);p.add_argument('output',type=Path);a=p.parse_args();package=a.package.resolve();out=a.output.resolve();out.mkdir(parents=True)
scripts='\n'.join((Path(__file__).with_name(n)).read_text() for n in ['acceptance_init.js','project_switch_init.js'])
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  name=urllib.parse.unquote(urllib.parse.urlsplit(self.path).path).lstrip('/') or 'index.html';file=(package/name).resolve()
  if name=='favicon.ico':self.send_response(204);self.end_headers();return
  if name=='__switch_init.js':data=scripts.encode();mime='text/javascript'
  elif file.is_relative_to(package) and file.is_file():
   data=file.read_bytes();mime=mimetypes.guess_type(name)[0] or 'application/octet-stream'
   if name=='index.html':data=data.replace(b'<head>',b'<head><script src="/__switch_init.js"></script>',1)
  else:self.send_error(404);return
  self.send_response(200)
  for k,v in [('Content-Type',mime),('Content-Length',str(len(data))),('Cache-Control','no-store'),('Cross-Origin-Opener-Policy','same-origin'),('Cross-Origin-Embedder-Policy','require-corp')]:self.send_header(k,v)
  self.end_headers();self.wfile.write(data)
 def log_message(self,*args):pass
with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
endpoint=f'http://127.0.0.1:{port}';session=None;driver=None;server=None;result={'passed':False,'engine':'safari'}
def request(method,path,payload=None):
 data=None if payload is None else json.dumps(payload).encode()
 with urllib.request.urlopen(urllib.request.Request(endpoint+path,data=data,method=method,headers={'Content-Type':'application/json'}),timeout=150) as r:body=json.load(r)
 value=body.get('value')
 if isinstance(value,dict) and 'error' in value:raise RuntimeError(value)
 return value
def execute(script,*args):return request('POST',f'/session/{session}/execute/sync',{'script':script,'args':list(args)})
def wait(script,timeout=180):
 deadline=time.monotonic()+timeout
 while time.monotonic()<deadline:
  if execute(script):return
  time.sleep(.25)
 raise RuntimeError('Safari wait timed out: '+script)
try:
 with (out/'driver.log').open('w') as f:driver=subprocess.Popen(['/usr/bin/safaridriver','-p',str(port)],stdout=f,stderr=subprocess.STDOUT)
 for _ in range(100):
  assert driver.poll() is None
  try:request('GET','/status');break
  except OSError:time.sleep(.1)
 value=request('POST','/session',{'capabilities':{'alwaysMatch':{'browserName':'safari'}}});session=value['sessionId'];result['browser']=value['capabilities']['browserVersion']
 request('POST',f'/session/{session}/timeouts',{'pageLoad':120000,'script':30000,'implicit':0})
 request('POST',f'/session/{session}/window/rect',{'x':0,'y':40,'width':1280,'height':800})
 dims=execute('return {w:outerWidth-innerWidth,h:outerHeight-innerHeight};');request('POST',f'/session/{session}/window/rect',{'width':1280+dims['w'],'height':720+dims['h']})
 server=ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
 request('POST',f'/session/{session}/url',{'url':f'http://127.0.0.1:{server.server_port}/'})
 wait("return document.documentElement.dataset.doraState==='running';")
 point=execute("const r=Module.canvas.getBoundingClientRect();window.addEventListener('pointerdown',e=>window.__switchTrusted=e.isTrusted,{capture:true,once:true});return {x:Math.ceil(r.left+8),y:Math.floor(r.bottom-8)};")
 request('POST',f'/session/{session}/actions',{'actions':[{'type':'pointer','id':'mouse','parameters':{'pointerType':'mouse'},'actions':[{'type':'pointerMove','duration':0,'origin':'viewport',**point},{'type':'pointerDown','button':0},{'type':'pointerUp','button':0}]}]})
 wait("return Module.FS.analyzePath('/user/godot-switch/player.json').exists;")
 wait('return window.__projectSwitch.hashes.every(h=>Object.keys(h.files).length>0);')
 result.update(execute('''const {jobs,...switching}=window.__projectSwitch;const gl=Module.canvas.getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');return {player:JSON.parse(new TextDecoder().decode(Module.FS.readFile('/user/godot-switch/player.json'))),switching,evidence:window.__doraAcceptance,audio:Module.doraTestAudioMetrics,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),distinctHeaps:Module.HEAPU8.buffer!==Module.doraGodotRuntime.HEAPU8.buffer,trustedPointer:window.__switchTrusted,audioUnlocked:Module.doraWebPlatform.state.audioUnlocked};'''))
 assert result['trustedPointer'] and result['audioUnlocked']
 for i in range(1,result['player']['projects']+1):
  for c in 'abc':(out/f'{i}-{c}.png').write_bytes(bytes(execute("return Array.from(Module.FS.readFile(arguments[0]));",f'/user/godot-switch/{i}-{c}.png')))
 execute("Module.ccall('dora_web_stop','number',[],[]);return true;");wait("return document.documentElement.dataset.doraState==='stopped';",15)
 result['teardown']=execute("return {state:document.documentElement.dataset.doraState,platform:Module.doraWebPlatform.state,disposeAgain:Module.doraWebPlatform.dispose({notifyEngine:false}),imePresent:Boolean(document.querySelector('#dora-ime-input'))};")
 result['passed']=True
except Exception as error:
 result['error']=str(error)
 if session:
  try:result['lastState']=execute('return {state:document.documentElement.dataset.doraState,evidence:window.__doraAcceptance,switching:window.__projectSwitch};')
  except Exception:pass
 raise
finally:
 (out/'execution.json').write_text(json.dumps(result,indent=2)+'\n')
 if session:
  try:request('DELETE',f'/session/{session}')
  except Exception:pass
 if server:server.shutdown();server.server_close()
 if driver:
  driver.terminate()
  try:driver.wait(timeout=5)
  except subprocess.TimeoutExpired:driver.kill();driver.wait()
