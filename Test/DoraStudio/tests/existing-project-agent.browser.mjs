import assert from 'node:assert/strict';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_AGENT_TEST_URL,account=process.env.STUDIO_AGENT_TEST_ACCOUNT_NAME,password=process.env.STUDIO_AGENT_TEST_ACCOUNT_PASSWORD;
if(!origin||!account||!password)throw new Error('Set the live Studio URL and invited account credentials');
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const context=await browser.newContext({ignoreHTTPSErrors:true}),page=await context.newPage(),errors=[];
page.on('pageerror',error=>errors.push(error.message));
try{
  await page.goto(origin);
  await page.getByText('尚未登录，可继续本地编辑').waitFor();
  await page.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  await page.getByLabel('账号名').fill(account);
  await page.getByLabel('密码').fill(password);
  await page.getByRole('button',{name:'登录账号'}).click();
  await page.getByText('账号已连接').waitFor();

  const name=`空白项目 Agent 验收 ${Date.now().toString(36)}`;
  await page.getByRole('button',{name:/新建 \/ 导入/}).click();
  await page.getByRole('button',{name:/新建空白项目/}).click();
  await page.getByLabel('项目名称',{exact:true}).fill(name);
  await page.getByRole('button',{name:'创建并进入 Studio'}).click();
  await page.getByRole('heading',{name,exact:true}).waitFor();
  await page.locator('iframe[title="Dora Agent 宿主"]').waitFor({state:'attached',timeout:45000});
  await page.locator('.project-agent-spinner').waitFor({state:'visible',timeout:45000});
  await page.locator('.project-agent-spinner').waitFor({state:'detached',timeout:45000});
  await page.getByRole('link',{name:'返回首页'}).click();
  await page.getByRole('heading',{name:/从一个想法/}).waitFor();
  const projectCard=page.getByRole('button',{name:new RegExp(name)});
  let launchAttempts=0,allowLaunch=false;
  await page.route('**/api/projects/**',async route=>{
    if(route.request().method()==='GET')await new Promise(resolve=>setTimeout(resolve,300));
    if(route.request().method()==='POST'&&route.request().url().endsWith('/agent-launch')){launchAttempts++;if(!allowLaunch){await route.fulfill({status:503,body:'temporary launch failure'});return;}}
    await route.continue();
  });
  await projectCard.click();
  await page.locator('.project-link-progress').waitFor();
  assert.equal(await page.locator('.project-open-backdrop').count(),0,'Project synchronization must not cover the workspace with a modal');
  await page.getByRole('heading',{name,exact:true}).waitFor();
  assert.ok(launchAttempts>0,'Opening must attempt the Agent connection immediately after synchronization');
  const reconnect=page.getByRole('button',{name:'重新连接 Agent',exact:true});
  await reconnect.waitFor();
  allowLaunch=true;
  await reconnect.click();
  await page.locator('.project-agent-spinner').waitFor({state:'visible',timeout:45000});
  await page.locator('iframe[title="Dora Agent 宿主"]').waitFor({state:'attached',timeout:45000});
  await page.locator('.project-agent-spinner').waitFor({state:'detached',timeout:45000});
  assert.equal(await page.locator('.project-link-progress').count(),0,'Project-card progress is removed when Agent connection finishes');
  await page.getByRole('button',{name:'项目信息',exact:true}).click();
  await page.locator('.project-danger-zone').getByRole('button',{name:'删除项目',exact:true}).click();
  await page.getByRole('dialog',{name:`删除项目“${name}”？`}).getByRole('button',{name:'删除项目',exact:true}).click();
  await page.getByRole('heading',{name:/从一个想法/}).waitFor();
  assert.equal(await page.getByRole('button',{name:new RegExp(name)}).count(),0,'Deleted project must leave the local catalog immediately');
  await page.reload();
  await page.getByRole('heading',{name:/从一个想法/}).waitFor();
  assert.equal(await page.getByRole('button',{name:new RegExp(name)}).count(),0,'Deleted cloud project must not return after reload');
  assert.deepEqual(errors,[]);
  console.log('Existing project acceptance: compact project-card sync, automatic Agent connection, manual reconnect and cloud-backed deletion passed');
}finally{await context.close();await browser.close();}
