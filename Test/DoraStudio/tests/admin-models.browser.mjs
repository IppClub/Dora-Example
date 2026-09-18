import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdir,writeFile} from 'node:fs/promises';
import {openLoginStore} from '../apps/server/login-store.mjs';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_LOGIN_TEST_URL,dbPath=process.env.STUDIO_LOGIN_TEST_DB;
if(!origin||!dbPath)throw new Error('Launch HTTPS frontend and API with an empty test database first');
const bootstrapStore=openLoginStore(dbPath),bootstrap=bootstrapStore.issueInvite({administrator:true});bootstrapStore.close();
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const adminContext=await browser.newContext({ignoreHTTPSErrors:true}),admin=await adminContext.newPage(),errors=[];
admin.on('pageerror',error=>errors.push(error.message));
let creatorContext;
try{
  await admin.goto(origin);await admin.getByText('尚未登录，可继续本地编辑').waitFor();
  await admin.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  await admin.getByRole('button',{name:'邀请码注册',exact:true}).click();
  await admin.getByLabel('邀请码').fill(bootstrap.code);
  await admin.getByLabel('账号名').fill('studio-model-admin');
  await admin.getByLabel('密码').fill('studio-model-acceptance-password-123');
  await admin.getByRole('button',{name:'创建账号并登录'}).click();
  await admin.getByText('账号已连接').waitFor();
  await admin.getByRole('button',{name:'共享 API 管理',exact:true}).click();
  const dialog=admin.getByRole('dialog',{name:'共享 API 管理'});
  await dialog.getByRole('button',{name:'导入共享 API 配置'}).click();
  await dialog.getByLabel('配置名称').fill('创作共享模型');
  await dialog.getByLabel('共享供应商').selectOption('openai');
  await dialog.getByLabel('模型标识').fill('fixture-model');
  await dialog.getByLabel('输入单价').fill('1');
  await dialog.getByLabel('输出单价').fill('2');
  await dialog.getByRole('button',{name:'保存配置（默认停用）'}).click();
  await dialog.getByText('尚未导入或已撤销',{exact:false}).waitFor();
  await dialog.getByLabel('共享 API Key').fill('test-only-browser-provider-key');
  await dialog.getByRole('button',{name:'加密保存密钥'}).click();
  await dialog.getByText('已加密托管',{exact:false}).waitFor();
  await dialog.getByLabel('API 最大并发').fill('2');
  await dialog.getByRole('button',{name:'保存 API 并发'}).click();
  await dialog.getByText('0/2 正在使用',{exact:false}).waitFor();
  await dialog.getByRole('button',{name:'启用共享配置'}).click();
  await dialog.getByText('已启用 · 配置 v',{exact:false}).waitFor();
  assert.equal(await dialog.getByText('test-only-browser-provider-key').count(),0,'shared credential must not be displayed');
  await dialog.getByRole('button',{name:'关闭共享 API 管理'}).click();
  await admin.getByRole('button',{name:'账号管理'}).click();
  await admin.getByRole('button',{name:'邀请新账号'}).click();
  await admin.getByRole('button',{name:'生成邀请码'}).click();
  const code=await admin.locator('.admin-invitation code').innerText();assert.match(code,/^[A-Za-z0-9_-]{43}$/);
  await admin.getByRole('button',{name:'关闭账号管理'}).click();
  creatorContext=await browser.newContext({ignoreHTTPSErrors:true});const creator=await creatorContext.newPage();
  const promptConsole=[];creator.on('pageerror',error=>errors.push(error.message));creator.on('console',message=>{if(message.text().startsWith('Studio Agent prompt command:'))promptConsole.push(message.text());});
  await creator.goto(origin);await creator.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  await creator.getByRole('button',{name:'邀请码注册',exact:true}).click();
  await creator.getByLabel('邀请码').fill(code);
  await creator.getByLabel('账号名').fill('studio-model-creator');
  await creator.getByLabel('密码').fill('studio-creator-acceptance-password-123');
  await creator.getByRole('button',{name:'创建账号并登录'}).click();
  await creator.getByText('账号已连接').waitFor();
  assert.equal(await creator.getByRole('button',{name:'共享 API 管理'}).count(),0,'creator cannot open administrator pool');
  await admin.getByRole('button',{name:'共享 API 管理',exact:true}).click();
  const allocations=admin.getByRole('dialog',{name:'共享 API 管理'});
  await allocations.getByRole('button',{name:'账号与逐 API 授权'}).click();
  await allocations.getByLabel('授权账号名').fill('studio-model-creator');
  await allocations.getByRole('button',{name:'读取账号授权'}).click();
  await allocations.getByText('尚未分配账号模型额度').waitFor();
  await allocations.getByLabel('账号金额上限').fill('10');
  await allocations.getByLabel('账号模型并发').fill('2');
  await allocations.getByRole('button',{name:'保存账号总额度'}).click();
  await allocations.getByText('已用 ¥0',{exact:false}).waitFor();
  await allocations.getByLabel('选择授权 API').selectOption({label:'创作共享模型 · 可用'});
  await allocations.getByLabel('逐 API 金额上限').fill('5');
  await allocations.getByLabel('逐 API 并发').fill('1');
  await allocations.getByRole('button',{name:'分配逐 API 授权'}).click();
  await allocations.getByText('已有授权',{exact:false}).waitFor();
  await allocations.getByRole('button',{name:'关闭共享 API 管理'}).click();
  await creator.getByRole('button',{name:'模型与用量'}).click();
  const settings=creator.getByRole('dialog',{name:'模型与用量设置'});
  await settings.getByRole('button',{name:'平台额度'}).click();
  await settings.getByLabel('查看共享模型额度').selectOption({label:'创作共享模型 · fixture-model'});
  await settings.getByText('¥5.00',{exact:false}).waitFor();
  assert.equal(await settings.getByText('test-only-browser-provider-key').count(),0);
  assert.equal((await creator.request.get(origin+'/api/admin/shared-models')).status(),403);
  assert.deepEqual(errors,[]);
  if(process.env.STUDIO_AGENT_TEST_HOST_URL&&process.env.STUDIO_FIXTURE_URL){
    await creator.getByRole('button',{name:'关闭模型设置'}).click();
    await creator.locator('.idea-model-select').getByRole('button',{name:'刷新'}).click();
    await creator.getByLabel('本次创作使用的共享模型').selectOption({label:'创作共享模型 · fixture-model'});
    await creator.getByLabel('游戏创意').fill('请做一个能点击跳跃、收集星光的小游戏。');
    await creator.getByRole('button',{name:'新建并启动 Agent 创作'}).click();
    try{await creator.locator('.agent-task').first().waitFor({timeout:30000});}
    catch(error){
      console.error('Agent prompt diagnostic:',JSON.stringify({intent:await creator.locator('.idea-intent').innerText().catch(()=>''),alerts:await creator.getByRole('alert').allInnerTexts(),agent:await creator.locator('.agent-pane').innerText().catch(()=>''),iframeCount:await creator.locator('iframe[src*="/agent-host/"]').count(),promptConsole,pageErrors:errors}));
      throw error;
    }
    await creator.locator(`iframe[src^="${process.env.STUDIO_AGENT_TEST_HOST_URL}/agent-host/"]`).waitFor({state:'attached'});
    let calls=0;for(let attempt=0;attempt<80;attempt++){
      calls=(await (await fetch(process.env.STUDIO_FIXTURE_URL+'/stats')).json()).calls;
      if(calls>0)break;await new Promise(resolve=>setTimeout(resolve,250));
    }
    assert.ok(calls>0,'original Agent must actually dispatch a supplier request');
    if(process.env.STUDIO_FIXTURE_GAME==='1'){
      await creator.getByLabel('当前 Agent 任务').getByText('已完成',{exact:true}).waitFor({timeout:60000});
      if(process.env.STUDIO_FIXTURE_BUILD==='1'){
        const stats=await (await fetch(process.env.STUDIO_FIXTURE_URL+'/stats')).json();
        if(process.env.STUDIO_FIXTURE_SCRIPT_INVALID==='1'){
          assert.equal(stats.buildSucceeded,false,'original Agent build must reject invalid script');
          assert.match(stats.buildReport,process.env.STUDIO_FIXTURE_SCRIPT_BUILD==='yarn'?/expected node to start with 'title:' metadata/:/line|syntax|error|Build failed/i);
        }else{
          assert.equal(stats.buildSucceeded,true,`original Agent build must pass: ${stats.buildReport}`);
          await creator.locator('.agent-activity summary').filter({hasText:'build'}).getByText('已完成').waitFor();
        }
      }
      if(process.env.STUDIO_FIXTURE_COMMAND==='1'){
        const stats=await (await fetch(process.env.STUDIO_FIXTURE_URL+'/stats')).json();
        assert.equal(stats.commandSucceeded,true,`original Agent execute_command must run: ${stats.commandReport}`);
        assert.match(stats.commandReport,/STUDIO_FIXTURE_COMMAND_OK/);
        await creator.locator('.agent-activity summary').filter({hasText:'execute_command'}).getByText('已完成').waitFor();
      }
      if(process.env.STUDIO_FIXTURE_PREVIEW==='1'){
        const stats=await (await fetch(process.env.STUDIO_FIXTURE_URL+'/stats')).json();
        assert.equal(stats.previewSucceeded,true,`original Agent previewGame must pass: ${stats.previewReport}`);
        assert.equal(stats.previewFrameCount,1);
        assert.match(stats.previewReport,/\.agent\/vision\//);
        const hostFrame=creator.frames().find(frame=>frame.url().startsWith(process.env.STUDIO_AGENT_TEST_HOST_URL+'/agent-host/'));
        assert.ok(hostFrame,'dedicated Agent host must remain attached');
        const frame=await hostFrame.evaluate(async()=>{
          const dir='/user/studio-project/.agent/vision';
          const files=Module.FS.readdir(dir).filter(name=>name.endsWith('.png'));
          if(files.length!==1)return {files:files.length};
          const bytes=Module.FS.readFile(dir+'/'+files[0]);
          const bitmap=await createImageBitmap(new Blob([new Uint8Array(bytes)],{type:'image/png'}));
          const canvas=new OffscreenCanvas(bitmap.width,bitmap.height),ctx=canvas.getContext('2d');
          ctx.drawImage(bitmap,0,0);const pixels=ctx.getImageData(0,0,bitmap.width,bitmap.height).data;
          let greenPixels=0;for(let index=0;index<pixels.length;index+=4)if(pixels[index+1]>120&&pixels[index+1]>pixels[index]+45&&pixels[index+1]>pixels[index+2]+30)greenPixels++;
          const result={files:files.length,png:[...bytes.slice(0,8)],width:bitmap.width,height:bitmap.height,greenPixels,bytes:[...bytes]};
          bitmap.close();return result;
        });
        assert.deepEqual(frame.png,[137,80,78,71,13,10,26,10]);
        assert.ok(frame.width>0&&frame.height>0,'original Agent preview must store a decodable Player capture');
        assert.ok(frame.greenPixels>10000,`captured game frame must contain the fixture drawing, not a blank or host-UI-only image: ${frame.greenPixels}`);
        await mkdir('apps/web/artifacts/agent-preview',{recursive:true});
        await writeFile('apps/web/artifacts/agent-preview/fixture-player-capture.png',Uint8Array.from(frame.bytes));
      }
      await creator.getByRole('button',{name:'资源',exact:true}).click();
      if(process.env.STUDIO_FIXTURE_SCRIPT_BUILD){
        const kind=process.env.STUDIO_FIXTURE_SCRIPT_BUILD;
        const hostFrame=creator.frames().find(frame=>frame.url().startsWith(process.env.STUDIO_AGENT_TEST_HOST_URL+'/agent-host/'));
        assert.ok(hostFrame);
        if(process.env.STUDIO_FIXTURE_XML_PLAY==='1'){
          const entrySource=await hostFrame.evaluate(()=>Module.FS.readFile('/user/studio-project/init.lua',{encoding:'utf8'}));
          assert.match(entrySource,/require\("main"\)/);
          assert.match(entrySource,/Director\.ui:addChild\(node\)/);
          assert.ok(await creator.locator('.agent-activity summary').filter({hasText:'edit_file'}).count()>=2,'original Agent must create both XML view and playable Lua entry');
        }
        const result=await hostFrame.evaluate(kind=>({source:Module.FS.readFile(`/user/studio-project/main.${kind}`,{encoding:'utf8'}),
          lua:Module.FS.analyzePath('/user/studio-project/main.lua').exists?Module.FS.readFile('/user/studio-project/main.lua',{encoding:'utf8'}):undefined}),kind);
        if(process.env.STUDIO_FIXTURE_SCRIPT_INVALID==='1'){
          assert.match(result.source,/STUDIO_FIXTURE_INVALID/);
          if(kind==='lua')assert.equal(result.lua,result.source,'failed Lua check must not rewrite the author source');
          else assert.equal(result.lua,undefined,'failed script build must not generate Lua');
        }else if(process.env.STUDIO_FIXTURE_TIC80==='1'){
          assert.match(result.source,/^-- tic80\ncls\(0\)/);
          assert.match(result.lua,kind==='yue'?/^-- tic80\n-- \[yue\]: main\.yue\n/:/^-- tic80\n-- \[tl\]: main\.tl\ncls\(0\)/);
        }else{
          assert.match(result.source,kind==='tl'?/STUDIO_FIXTURE_TEAL_READY/:kind==='yarn'?/STUDIO_FIXTURE_YARN_READY/:kind==='yue'?/STUDIO_FIXTURE_YUE_READY/:kind==='xml'?/STUDIO_FIXTURE_XML_READY/:/STUDIO_FIXTURE_LUA_READY/);
          if(kind==='yarn')assert.equal(result.lua,undefined,'Yarn build only checks; no generated Lua');
          else {
            assert.match(result.lua,kind==='tl'?/^-- \[tl\]: main\.tl\n/:kind==='yue'?/^-- \[yue\]: main\.yue\n/:kind==='xml'?/^-- \[xml\]: main\.xml\n/:/STUDIO_FIXTURE_LUA_READY/);
            if(kind==='xml')assert.match(result.lua,/STUDIO_FIXTURE_XML_READY/,'XML conversion must retain the fixture node, not just its source header');
          }
        }
      }else assert.match(await creator.getByLabel('项目代码').inputValue(),/STUDIO_FIXTURE_GAME_READY/);
      if(process.env.STUDIO_FIXTURE_CONTINUATIONS==='1'){
        const spent=()=>{const current=openModelLedger(dbPath,{requireConfigurationVersion:true});try{return current.scope('account','studio-model-creator').spent;}finally{current.close();}};
        const visionColors=async()=>{
          const hostFrame=creator.frames().find(frame=>frame.url().startsWith(process.env.STUDIO_AGENT_TEST_HOST_URL+'/agent-host/'));assert.ok(hostFrame);
          return hostFrame.evaluate(async()=>{
            const dir='/user/studio-project/.agent/vision',files=Module.FS.readdir(dir).filter(name=>name.endsWith('.png'));let blue=0,yellow=0;
            for(const file of files){const bitmap=await createImageBitmap(new Blob([new Uint8Array(Module.FS.readFile(dir+'/'+file))],{type:'image/png'})),canvas=new OffscreenCanvas(bitmap.width,bitmap.height),ctx=canvas.getContext('2d');ctx.drawImage(bitmap,0,0);const pixels=ctx.getImageData(0,0,bitmap.width,bitmap.height).data;let currentBlue=0,currentYellow=0;for(let i=0;i<pixels.length;i+=4){if(pixels[i+2]>180&&pixels[i+2]>pixels[i]+80)currentBlue++;if(pixels[i]>180&&pixels[i+1]>140&&pixels[i+2]<140)currentYellow++;}blue=Math.max(blue,currentBlue);yellow=Math.max(yellow,currentYellow);bitmap.close();}
            return {files:files.length,blue,yellow};
          });
        };
        const firstSpent=spent();
        await creator.getByLabel('Agent 描述').fill('增加雨滴效果，并保持游戏可试玩。');
        await creator.getByRole('button',{name:'发送 ↑'}).click();
        await creator.getByText('可继续第 3 轮创作',{exact:false}).waitFor({timeout:60000});
        await creator.getByRole('button',{name:'资源',exact:true}).click();
        assert.match(await creator.getByLabel('项目代码').inputValue(),/STUDIO_FIXTURE_RAIN_READY/);
        const rainVision=await visionColors();assert.ok(rainVision.files>=2&&rainVision.blue>10000,`rain continuation must produce a distinct blue Player frame: ${JSON.stringify(rainVision)}`);
        const secondSpent=spent();assert.ok(secondSpent>firstSpent,'first continuation must add an independently settled model charge');
        let failedLaunch=false;
        await creator.route('**/api/projects/*/agent-launch',async route=>{
          if(route.request().method()==='POST'&&!failedLaunch){failedLaunch=true;await route.fulfill({status:503,body:'injected launch failure'});}
          else await route.continue();
        });
        await creator.reload();await creator.getByText('账号已连接').waitFor();
        await creator.getByRole('navigation',{name:'本机项目'}).getByRole('button').first().click();
        await creator.getByRole('button',{name:'继续准备创作'}).click();
        await creator.getByText('继续准备未完成',{exact:false}).waitFor({timeout:15000});
        assert.equal(failedLaunch,true);
        await creator.getByRole('button',{name:'继续准备创作'}).click();
        await creator.getByText('可继续第 3 轮创作',{exact:false}).waitFor({timeout:60000});
        await creator.getByLabel('Agent 描述').fill('再增加星光效果，并继续使用原工具试玩。');
        await creator.getByRole('button',{name:'发送 ↑'}).click();
        await creator.getByText('可继续第 4 轮创作',{exact:false}).waitFor({timeout:60000});
        await creator.getByRole('button',{name:'资源',exact:true}).click();
        assert.match(await creator.getByLabel('项目代码').inputValue(),/STUDIO_FIXTURE_STAR_READY/);
        const starVision=await visionColors();assert.ok(starVision.files>=3&&starVision.yellow>10000,`star continuation must produce a distinct yellow Player frame: ${JSON.stringify(starVision)}`);
        const thirdSpent=spent();assert.ok(thirdSpent>secondSpent,'second continuation must add another independently settled model charge');
        await creator.getByRole('button',{name:'版本记录'}).click();
        for(const revision of [0,1,2])await creator.getByRole('button',{name:`恢复 r${revision}`}).waitFor();
      }
      await creator.getByText('尚未编译',{exact:true}).waitFor();
      assert.equal(await creator.locator('.runtime-surface iframe').count(),0,'author writeback must not invent an extra compile/play run');
    }
    const ledger=openModelLedger(dbPath,{requireConfigurationVersion:true});
    try{assert.ok(ledger.scope('account','studio-model-creator').spent>0n);assert.ok(ledger.scope('grant',ledger.grantsForAccount('studio-model-creator')[0].grantId).spent>0n);}
    finally{ledger.close();}
    assert.deepEqual(errors,[]);
    console.log('Original Dora Agent prompt browser acceptance: project, grant, dedicated WASM task, fixture supplier request and durable RMB usage passed');
    if(process.env.STUDIO_FIXTURE_GAME==='1')console.log('Original Dora Agent edit tool browser acceptance: author r1 automatically received without Studio-side compile/play passed');
    if(process.env.STUDIO_FIXTURE_BUILD==='1')console.log(process.env.STUDIO_FIXTURE_SCRIPT_INVALID==='1'
      ?`Original Dora Agent build tool browser acceptance: invalid ${process.env.STUDIO_FIXTURE_SCRIPT_BUILD??'script'} diagnostic returned to model without Studio-side compile passed`
      :'Original Dora Agent build tool browser acceptance: browser compiler invoked only by tool and returned success passed');
    if(process.env.STUDIO_FIXTURE_COMMAND==='1')console.log('Original Dora Agent Lua command browser acceptance: bounded tool executed in dedicated host passed');
    if(process.env.STUDIO_FIXTURE_PREVIEW==='1')console.log('Original Dora Agent previewGame browser acceptance: isolated Player capture written under Agent vision directory passed');
    if(process.env.STUDIO_FIXTURE_CONTINUATIONS==='1')console.log('Studio continuation acceptance: two sequential prompts changed one project through r3 with checkpoints and independent RMB settlement passed');
  }
  console.log('Shared model admin browser acceptance: invite+password, staged encrypted pool, account/grant limits and creator ¥5 allowance passed');
}finally{await creatorContext?.close();await adminContext.close();await browser.close();}
