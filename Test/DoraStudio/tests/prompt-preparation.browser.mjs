import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {openLoginStore} from '../apps/server/login-store.mjs';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_AGENT_TEST_URL,dbPath=process.env.STUDIO_AGENT_TEST_DB,hostOrigin=process.env.STUDIO_AGENT_TEST_HOST_URL;
if(!origin||!dbPath||!hostOrigin)throw new Error('Launch HTTPS frontend, API and dedicated Agent host first');
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const context=await browser.newContext({ignoreHTTPSErrors:true}),page=await context.newPage(),errors=[];
const existingName=process.env.STUDIO_AGENT_TEST_ACCOUNT_NAME;
page.on('pageerror',error=>errors.push(error.message));
try{
  await page.goto(origin);
  await page.getByText('尚未登录，可继续本地编辑').waitFor();
  await page.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  if(existingName){
    await page.getByLabel('账号名').fill(existingName);
    await page.getByLabel('密码').fill(process.env.STUDIO_AGENT_TEST_ACCOUNT_PASSWORD??'studio-idea-acceptance-password-123');
    await page.getByRole('button',{name:'登录账号'}).click();
  }else{
    const store=openLoginStore(dbPath),invite=store.issueInvite({administrator:false});store.close();
    await page.getByRole('button',{name:'邀请码注册',exact:true}).click();
    await page.getByLabel('邀请码').fill(invite.code);
    await page.getByLabel('账号名').fill(`studio-idea-${Date.now().toString(36)}`);
    await page.getByLabel('密码').fill('studio-idea-acceptance-password-123');
    await page.getByRole('button',{name:'创建账号并登录'}).click();
  }
  await page.getByText('账号已连接').waitFor();
  const idea='雨夜小猫在屋顶收集星光，点击跳跃。';
  const submit=page.getByRole('button',{name:'新建并启动 Agent 创作'});
  assert.equal(await submit.isDisabled(),true,'empty prompt must not submit');
  await page.locator('.idea-model-select').getByRole('button',{name:'刷新'}).click();
  const grant=page.getByLabel('本次创作使用的共享模型');
  await grant.locator('option:not([value=""])').first().waitFor({state:'attached',timeout:10000});
  await grant.selectOption(await grant.locator('option:not([value=""])').first().getAttribute('value'));
  await page.getByLabel('游戏创意').fill(idea);
  assert.equal(await submit.isEnabled(),true);
  let failedOnce=false;
  await page.route('**/api/projects/*',async route=>{
    if(route.request().method()==='PUT'&&!failedOnce){failedOnce=true;await route.fulfill({status:503,body:'temporary failure'});}
    else await route.continue();
  });
  await submit.click();
  await page.getByText('已创建的项目与原描述仍保留',{exact:false}).waitFor({timeout:15000});
  assert.equal(failedOnce,true);
  await page.getByRole('heading',{name:/雨夜小猫在屋顶收集星光/}).waitFor();
  assert.equal(await page.locator('.idea-intent').count(),0,'The initial prompt is not repeated above the workspace');
  await page.getByText('发送时会自动连接 Agent',{exact:true}).waitFor();
  assert.equal(await page.getByRole('navigation',{name:'本机项目'}).getByRole('button').count(),1,'failure must not create a second project');
  await page.reload();
  await page.getByText('账号已连接').waitFor();
  await page.getByRole('navigation',{name:'本机项目'}).getByRole('button').first().click();
  await page.getByText(idea,{exact:true}).waitFor();
  await page.getByText('Agent 已连接，可随时继续描述修改',{exact:true}).waitFor({timeout:45000});
  await page.locator(`iframe[src^="${hostOrigin}/agent-host/"]`).waitFor({state:'attached'});
  await page.getByRole('button',{name:/项目信息/}).click();await page.getByText('已自动保存',{exact:false}).waitFor();await page.getByRole('button',{name:'关闭项目信息'}).click();
  assert.equal(await page.getByRole('navigation',{name:'本机项目'}).getByRole('button').count(),1);
  await page.getByRole('button',{name:/新建 \/ 导入/}).click();
  await page.getByRole('button',{name:/新建空白项目/}).click();
  await page.getByLabel('项目名称',{exact:true}).fill('另一个空白作品');
  await page.getByRole('button',{name:'创建并进入 Studio'}).click();
  await page.getByRole('navigation',{name:'本机项目'}).getByRole('button',{name:/雨夜小猫/}).click();
  await page.getByText(idea,{exact:true}).waitFor();
  await page.getByText('Agent 已连接，可随时继续描述修改',{exact:true}).waitFor({timeout:45000});
  assert.deepEqual(errors,[]);
  console.log('Prompt preparation: empty guard, one-shot cloud failure, automatic recovery after reload, Agent sync and automatic reconnect after project switching passed');
}finally{await context.close();await browser.close();}
