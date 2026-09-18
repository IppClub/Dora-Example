import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const html=await readFile('dist/agent-host/index.html'),script=await readFile('dist/agent-host/page.js');
const cases=['unauthorized','oversize','redirect','missing-features','missing-engine'];
const counts=Object.fromEntries(cases.map(name=>[name,{features:0,engine:0}]));
let parentOrigin,redirects=0;
const host=createServer((req,res)=>{
  const [,name,file]=new URL(req.url,'http://local').pathname.split('/');
  if(req.url==='/redirect-target'){redirects++;res.end('{}');return;}
  if(!cases.includes(name)){res.writeHead(404);res.end();return;}
  if(file==='index.html'){res.setHeader('Content-Type','text/html');res.end(html);return;}
  if(file==='page.js'){res.setHeader('Content-Type','text/javascript');res.end(script);return;}
  if(file==='host-config.json'){
    if(name==='unauthorized'){res.writeHead(401);res.end();return;}
    if(name==='oversize'){res.end(' '.repeat(20000));return;}
    if(name==='redirect'){res.writeHead(302,{Location:'/redirect-target'});res.end();return;}
    res.end(JSON.stringify({version:1,parentOrigin,accountId:'test',projectId:name,generation:'g',projectRoot:'/game',title:'Test'}));return;
  }
  if(file==='dora-web-features.json'){
    counts[name].features++;
    if(name==='missing-features'){res.writeHead(404);res.end();return;}
    res.end('{"studioAgentHost":true}');return;
  }
  if(file==='dora-player-runtime.js')counts[name].engine++;
  res.writeHead(404);res.end();
});
await new Promise(done=>host.listen(0,'127.0.0.1',done));
const hostOrigin=`http://127.0.0.1:${host.address().port}`;
const parent=createServer((req,res)=>{
  const name=new URL(req.url,'http://local').searchParams.get('case');
  if(!cases.includes(name)){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type','text/html');res.end(`<script>window.failures=[];addEventListener('message',event=>{if(event.origin===${JSON.stringify(hostOrigin)})window.failures.push(event.data);});</script><iframe src="${hostOrigin}/${name}/index.html"></iframe>`);
});
await new Promise(done=>parent.listen(0,'127.0.0.1',done));
parentOrigin=`http://127.0.0.1:${parent.address().port}`;
let browser;const errors=[];
try {
  browser=await chromium.launch({headless:true,executablePath:process.env.STUDIO_CHROME_PATH});
  for(const name of cases){
    const page=await browser.newPage();page.on('pageerror',error=>errors.push(error.message));
    await page.goto(parentOrigin+'/?case='+name);
    await page.frameLocator('iframe').getByRole('status').filter({hasText:'启动失败'}).waitFor();
    if(name.startsWith('missing-'))await page.waitForFunction(()=>window.failures.length>0);
    const failures=await page.evaluate(()=>window.failures);
    assert.equal(failures.length,name.startsWith('missing-')?1:0);
    if(failures.length)assert.deepEqual(failures[0],{type:'studio-agent-failed',version:1,projectId:name,generation:'g',code:'initialization-failed'});
    assert.equal(counts[name].engine,name==='missing-engine'?1:0);
    assert.equal(counts[name].features,name.startsWith('missing-')?1:0);
    await page.close();
  }
  assert.equal(redirects,0);assert.deepEqual(errors,[]);
  console.log(JSON.stringify({passed:true,cases,counts,redirects,errors}));
}finally{
  await browser?.close();await Promise.all([new Promise(done=>host.close(done)),new Promise(done=>parent.close(done))]);
}
