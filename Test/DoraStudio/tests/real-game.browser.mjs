import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdir,writeFile} from 'node:fs/promises';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_REAL_MODEL_URL,dbPath=process.env.STUDIO_REAL_MODEL_DB,hostOrigin=process.env.STUDIO_REAL_MODEL_HOST_URL;
const account=process.env.STUDIO_REAL_MODEL_ACCOUNT,password=process.env.STUDIO_REAL_MODEL_PASSWORD;
if(!origin||!dbPath||!hostOrigin||!account||!password)throw new Error('Set the HTTPS Studio/Agent host URLs, database path and existing creator login');
const ledgerState=()=>{
  const ledger=openModelLedger(dbPath,{requireConfigurationVersion:true});
  try{
    const events=ledger.audit({limit:1000}),finishes=events.filter(item=>item.action==='finish'&&item.accountId===account);
    return {spent:ledger.scope('account',account).spent,finishIds:finishes.map(item=>item.requestId)};
  }finally{ledger.close();}
};
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const context=await browser.newContext({ignoreHTTPSErrors:true}),page=await context.newPage(),errors=[];
page.on('pageerror',error=>errors.push(error.message));
page.setDefaultTimeout(30000);

const openStudio=async()=>{
  for(let attempt=0;attempt<3;attempt++){
    await page.goto(origin,{waitUntil:'domcontentloaded'});
    if(await page.getByRole('button',{name:'登录 / 邀请码注册'}).isVisible({timeout:10000}).catch(()=>false))return;
    await page.waitForTimeout(500);
  }
  throw new Error('Studio shell did not render after three clean navigations');
};

const selectModel=async()=>{
  await page.locator('.idea-model-select').getByRole('button',{name:'刷新'}).click();
  const select=page.getByLabel('本次创作使用的共享模型'),options=select.locator('option:not([value=""])');await options.first().waitFor({state:'attached'});
  const label=process.env.STUDIO_REAL_MODEL_LABEL;
  if(label){const matches=options.filter({hasText:label});assert.equal(await matches.count(),1);await select.selectOption(await matches.first().getAttribute('value'));}
  else await select.selectOption(await options.first().getAttribute('value'));
};
const waitForRound=async(revision,spentBefore)=>{
  const receipts=[page.getByText(`修改已核对到本机 r${revision}`,{exact:false}),page.getByText(`已核对并保存到本机 r${revision}`,{exact:false})];
  const ready=page.getByText(`可继续第 ${revision+1} 轮创作`,{exact:false}),deadline=Date.now()+240000;
  let nextReport=0;
  while(Date.now()<deadline){
    const received=(await Promise.all(receipts.map(receipt=>receipt.isVisible().catch(()=>false)))).some(Boolean);
    if(received&&await ready.isVisible().catch(()=>false))return;
    const current=ledgerState(),delta=current.spent-spentBefore;
    if(delta>650000000n)throw new Error(`real model round exceeded the ¥0.65 acceptance safety threshold: ${Number(delta)/1e9}`);
    if(Date.now()>=nextReport){
      const activities=await page.locator('.agent-activity summary').allInnerTexts().catch(()=>[]);
      console.log(JSON.stringify({waitingForRevision:revision,spentDeltaYuan:Number(delta)/1e9,finishRequests:current.finishIds.length,activities:activities.slice(-8)}));nextReport=Date.now()+10000;
    }
    await page.waitForTimeout(1000);
  }
  throw new Error(`real model round ${revision} timed out`);
};
const inspectRound=async name=>{
  const frame=page.frames().find(item=>item.url().startsWith(hostOrigin+'/agent-host/'));assert.ok(frame,'dedicated Agent host must remain attached');
  const result=await frame.evaluate(async()=>{
    const fs=Module.FS,root='/user/studio-project',hash=bytes=>{let value=2166136261;for(const byte of bytes){value^=byte;value=Math.imul(value,16777619);}return value>>>0;};
    const sources=[];const walk=dir=>{for(const item of fs.readdir(dir)){if(item==='.'||item==='..'||item==='.agent')continue;const path=dir+'/'+item,stat=fs.stat(path);if(fs.isDir(stat.mode))walk(path);else{const bytes=new Uint8Array(fs.readFile(path));sources.push({path:path.slice(root.length+1),bytes:bytes.length,hash:hash(bytes)});}}};walk(root);sources.sort((a,b)=>a.path.localeCompare(b.path));
    const visionDir=root+'/.agent/vision',files=fs.analyzePath(visionDir).exists?fs.readdir(visionDir).filter(item=>item.endsWith('.png')).sort():[];if(!files.length)throw new Error('No previewGame capture found');
    const pngBytes=new Uint8Array(fs.readFile(visionDir+'/'+files.at(-1))),bitmap=await createImageBitmap(new Blob([pngBytes],{type:'image/png'}));
    const canvas=new OffscreenCanvas(bitmap.width,bitmap.height),ctx=canvas.getContext('2d');ctx.drawImage(bitmap,0,0);const pixels=ctx.getImageData(0,0,bitmap.width,bitmap.height).data;
    let visible=0,colorful=0;for(let i=0;i<pixels.length;i+=4){const r=pixels[i],g=pixels[i+1],b=pixels[i+2],a=pixels[i+3];if(a>0&&(r+g+b)>45)visible++;if(a>0&&Math.max(r,g,b)-Math.min(r,g,b)>30)colorful++;}
    const result={sources,sourceHash:hash(new TextEncoder().encode(JSON.stringify(sources))),visionCount:files.length,pngHash:hash(pngBytes),width:bitmap.width,height:bitmap.height,visible,colorful,png:[...pngBytes]};bitmap.close();return result;
  });
  assert.ok(result.sources.length>0,'Agent must create author files');assert.ok(result.width>0&&result.height>0&&result.visible>1000,'previewGame must capture a visible non-empty game frame');
  await mkdir('apps/web/artifacts/real-mvp',{recursive:true});await writeFile(`apps/web/artifacts/real-mvp/${name}.png`,Uint8Array.from(result.png));delete result.png;return result;
};

try{
  const before=ledgerState();
  await openStudio();await page.getByRole('button',{name:'登录 / 邀请码注册'}).click();await page.getByLabel('账号名').fill(account);await page.getByLabel('密码').fill(password);
  await page.getByRole('button',{name:'登录账号'}).click();await page.getByText('账号已连接').waitFor();await selectModel();
  const projectCountBefore=await page.getByRole('navigation',{name:'本机项目'}).getByRole('button').count();
  await page.getByLabel('游戏创意').fill('创建一个最小可试玩的单文件 Lua 点击得分游戏：仅 require("Dora")，创建一个 DrawNode，设置 size=Size(740,340)，用 drawPolygon/drawDot、Vec2、Color 和固定局部坐标画玩家与目标，用一排小圆点数量表示得分；在这个 DrawNode 的 onTapBegan 中处理点击，最后只用 Director.ui:addChild 加入该节点。不要使用 Label、Draw.clear、Director.entry.size 或 enterEntryAsync。完成一次 build 和一次 previewGame 截图后立即结束。');
  await page.getByRole('button',{name:'新建并启动 Agent 创作'}).click();await page.locator('.agent-task').first().waitFor({timeout:60000});await waitForRound(1,before.spent);
  assert.ok(await page.locator('.agent-activity summary').filter({hasText:'edit_file'}).count()>0,'real model must use the original edit tool');
  assert.ok(await page.locator('.agent-activity summary').filter({hasText:'build'}).count()>0,'real model must use the original build tool');
  // previewGame is injected into the original execute_command tool, so the UI
  // records execute_command. The captured PNG inspected below is the proof that
  // the injected preview operation actually completed.
  assert.ok(await page.locator('.agent-activity summary').filter({hasText:'execute_command'}).count()>0,'real model must invoke the original command tool for preview');
  const round1=await inspectRound('deepseek-round-1'),after1=ledgerState();assert.ok(after1.spent>before.spent);

  await page.getByLabel('Agent 描述').fill('只做一处继续修改：在同一个 DrawNode 上用 drawPolygon 加入一个明显的新障碍。完成一次 build 和一次 previewGame 截图后立即结束，不要扩展其他功能。');await page.getByRole('button',{name:'发送 ↑'}).click();await waitForRound(2,after1.spent);
  const round2=await inspectRound('deepseek-round-2'),after2=ledgerState();assert.notEqual(round2.sourceHash,round1.sourceHash);assert.notEqual(round2.pngHash,round1.pngHash);assert.ok(round2.visionCount>round1.visionCount);assert.ok(after2.spent>after1.spent);

  let failedLaunch=false;await page.route('**/api/projects/*/agent-launch',async route=>{if(route.request().method()==='POST'&&!failedLaunch){failedLaunch=true;await route.fulfill({status:503,body:'injected launch failure'});}else await route.continue();});
  await page.reload();await page.getByText('账号已连接').waitFor();const projectCountAfterReload=await page.getByRole('navigation',{name:'本机项目'}).getByRole('button').count();assert.equal(projectCountAfterReload,projectCountBefore+1);
  await page.getByRole('navigation',{name:'本机项目'}).getByRole('button').first().click();await page.getByRole('button',{name:'继续准备创作'}).click();await page.getByText('继续准备未完成',{exact:false}).waitFor({timeout:15000});assert.equal(failedLaunch,true);
  const afterFailure=ledgerState();assert.equal(afterFailure.spent,after2.spent);assert.deepEqual(afterFailure.finishIds,after2.finishIds,'failed launch must not dispatch or settle another model request');
  await page.getByRole('button',{name:'继续准备创作'}).click();await page.getByText('可继续第 3 轮创作',{exact:false}).waitFor({timeout:120000});
  await page.getByLabel('Agent 描述').fill('只做一处继续修改：在同一个 DrawNode 上增加明显的背景矩形并放大得分圆点。完成一次 build 和一次 previewGame 截图后立即结束。');await page.getByRole('button',{name:'发送 ↑'}).click();await waitForRound(3,after2.spent);
  const round3=await inspectRound('deepseek-round-3'),after3=ledgerState();assert.notEqual(round3.sourceHash,round2.sourceHash);assert.notEqual(round3.pngHash,round2.pngHash);assert.ok(round3.visionCount>round2.visionCount);assert.ok(after3.spent>after2.spent);
  assert.equal(new Set(after3.finishIds).size,after3.finishIds.length,'each real provider request must settle at most once');
  await page.getByRole('button',{name:'版本记录'}).click();for(const revision of [0,1,2])await page.getByRole('button',{name:`恢复 r${revision}`}).waitFor();
  await page.screenshot({path:'apps/web/artifacts/real-mvp/studio-final.png',fullPage:true});assert.deepEqual(errors,[]);
  console.log(JSON.stringify({result:'passed',projectCount:projectCountAfterReload,spentNanoCny:String(after3.spent),finishRequests:after3.finishIds.length,rounds:[round1,round2,round3]}));
}catch(error){
  await mkdir('apps/web/artifacts/real-mvp',{recursive:true});
  const diagnostic={message:error instanceof Error?error.message:String(error),ledger:(()=>{const value=ledgerState();return {spentNanoCny:String(value.spent),finishRequests:value.finishIds.length};})(),intent:await page.locator('.idea-intent').innerText().catch(()=>''),agent:await page.locator('.agent-pane').innerText().catch(()=>''),activities:await page.locator('.agent-activity summary').allInnerTexts().catch(()=>[]),pageErrors:errors};
  await writeFile('apps/web/artifacts/real-mvp/failure.json',JSON.stringify(diagnostic,null,2));await page.screenshot({path:'apps/web/artifacts/real-mvp/failure.png',fullPage:true}).catch(()=>{});throw error;
}finally{await context.close();await browser.close();}
