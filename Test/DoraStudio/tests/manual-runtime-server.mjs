import {createServer} from 'node:http';
import {createServer as createSecureServer} from 'node:https';
import {readFile} from 'node:fs/promises';
import {extname,resolve,sep} from 'node:path';

const root=resolve(import.meta.dirname,'../../build/studio-runtime');
const port=Number(process.env.STUDIO_MANUAL_RUNTIME_PORT??8951);
if(!Number.isSafeInteger(port)||port<1024||port>65535)throw new Error('Invalid runtime port');
const metadata=JSON.parse(await readFile(resolve(root,'studio-runtime.json'),'utf8'));
if(metadata.profile!=='dora-preset'||typeof metadata.engineBuild!=='string')throw new Error('Unsupported Studio runtime');

const tlsKey=process.env.STUDIO_RUNTIME_TLS_KEY,tlsCert=process.env.STUDIO_RUNTIME_TLS_CERT;
if(!!tlsKey!==!!tlsCert)throw new Error('Both runtime TLS files are required');
const listener=async(req,res)=>{
 res.setHeader('Cross-Origin-Opener-Policy','same-origin');
 res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
 res.setHeader('Cross-Origin-Resource-Policy','cross-origin');
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='GET'&&req.method!=='HEAD'){res.writeHead(405);res.end();return;}
 try{
  const path=resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
  if(!path.startsWith(root+sep))throw new Error('Invalid runtime path');
  const content=await readFile(path);
  res.setHeader('Content-Type',({'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.wasm':'application/wasm','.json':'application/json; charset=utf-8'})[extname(path)]??'application/octet-stream');
  res.setHeader('Content-Length',content.length);
  res.end(req.method==='HEAD'?undefined:content);
 }catch{res.writeHead(404);res.end();}
};
const server=tlsKey?createSecureServer({key:await readFile(tlsKey),cert:await readFile(tlsCert)},listener):createServer(listener);
server.listen(port,'127.0.0.1',()=>process.stdout.write(`Runtime: ${tlsKey?'https':'http'}://127.0.0.1:${port}/index.html\nEngine: ${metadata.engineBuild}\n`));
for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>server.close(()=>process.exit(0)));
