import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_GATEWAY_TEST_URL;
const dbPath=process.env.STUDIO_GATEWAY_TEST_DB;
if(!origin||!dbPath)throw new Error('Launch the HTTPS frontend, API and Agent host with an existing admin, creator and shared configuration first');
const adminName=process.env.STUDIO_GATEWAY_ADMIN_NAME??'studio-model-admin';
const adminPassword=process.env.STUDIO_GATEWAY_ADMIN_PASSWORD??'studio-model-acceptance-password-123';
const creatorName=process.env.STUDIO_GATEWAY_CREATOR_NAME??'studio-model-creator';
const creatorPassword=process.env.STUDIO_GATEWAY_CREATOR_PASSWORD??'studio-creator-acceptance-password-123';
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const adminContext=await browser.newContext({ignoreHTTPSErrors:true}),creatorContext=await browser.newContext({ignoreHTTPSErrors:true});
const admin=await adminContext.newPage(),creator=await creatorContext.newPage(),errors=[];
for(const page of [admin,creator])page.on('pageerror',error=>errors.push(error.message));
async function login(page,name,password){
  await page.goto(origin);await page.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  await page.getByLabel('账号名').fill(name);await page.getByLabel('密码').fill(password);
  await page.getByRole('button',{name:'登录账号'}).click();await page.getByText('账号已连接').waitFor();
}
async function openAllowance(){
  await admin.getByRole('button',{name:'共享 API 管理',exact:true}).click();
  const dialog=admin.getByRole('dialog',{name:'共享 API 管理'});
  await dialog.getByRole('button',{name:'账号与逐 API 授权'}).click();
  await dialog.getByLabel('授权账号名').fill(creatorName);await dialog.getByRole('button',{name:'读取账号授权'}).click();
  await dialog.getByText('已用 ¥',{exact:false}).waitFor();
  await dialog.getByLabel('选择授权 API').selectOption({label:'创作共享模型 · 可用'});
  await dialog.getByText('已有授权',{exact:false}).waitFor();return dialog;
}
async function setGrantAmount(value){
  const dialog=await openAllowance();const input=dialog.getByLabel('逐 API 金额上限');
  await input.fill(value);await dialog.getByRole('button',{name:'调整逐 API 授权'}).click();
  await admin.waitForTimeout(500);
  await dialog.getByRole('button',{name:'关闭共享 API 管理'}).click();
}
async function refreshCreatorChoices(expectAvailable){
  await creator.locator('.idea-model-select').getByRole('button',{name:'刷新'}).click();
  const choices=creator.getByLabel('本次创作使用的共享模型').locator('option:not([value=""])');
  if(expectAvailable)await choices.first().waitFor({state:'attached'});
  else {
    await creator.locator('.idea-model-select small').getByText('尚无可用授权',{exact:false}).waitFor();
    assert.equal(await choices.count(),0);
  }
}
async function replaceSharedKey(dialog,key){
  await dialog.getByRole('button',{name:'停用共享配置'}).click();
  await dialog.getByText('已停用 · 配置 v',{exact:false}).waitFor();
  await dialog.getByLabel('共享 API Key').fill(key);await dialog.getByRole('button',{name:'加密保存密钥'}).click();
  await admin.waitForTimeout(500);
  await dialog.getByRole('button',{name:'启用共享配置'}).click();
  await dialog.getByText('已启用 · 配置 v',{exact:false}).waitFor();
}
try{
  await login(admin,adminName,adminPassword);await login(creator,creatorName,creatorPassword);
  await refreshCreatorChoices(true);

  await setGrantAmount('0');await refreshCreatorChoices(false);
  await setGrantAmount('5');await refreshCreatorChoices(true);

  await admin.getByRole('button',{name:'共享 API 管理',exact:true}).click();
  let dialog=admin.getByRole('dialog',{name:'共享 API 管理'});
  await dialog.getByRole('button',{name:/创作共享模型.*fixture-model/}).click();
  await dialog.getByRole('button',{name:'停用共享配置'}).click();
  await dialog.getByText('已停用 · 配置 v',{exact:false}).waitFor();
  await refreshCreatorChoices(false);
  await dialog.getByRole('button',{name:'启用共享配置'}).click();
  await dialog.getByText('已启用 · 配置 v',{exact:false}).waitFor();
  await refreshCreatorChoices(true);

  await replaceSharedKey(dialog,'intentionally-rejected-browser-key');
  await refreshCreatorChoices(true);
  await creator.getByLabel('本次创作使用的共享模型').selectOption({label:'创作共享模型 · fixture-model'});
  await creator.getByLabel('游戏创意').fill('验证供应商拒绝不会伪造结算。');
  await creator.getByRole('button',{name:'新建并启动 Agent 创作'}).click();
  await creator.getByLabel('Dora Agent').locator('.badge').getByText('失败',{exact:true}).waitFor({timeout:60000});
  const ledger=openModelLedger(dbPath,{requireConfigurationVersion:true});
  try{
    const lastDispatch=ledger.audit({limit:1000}).filter(item=>item.action==='dispatch'&&item.accountId===creatorName).at(-1);
    assert.ok(lastDispatch,'rejected provider request must have a durable dispatch record');
    assert.equal(ledger.request(lastDispatch.requestId).request.state,'in-flight','provider rejection must retain uncertain funds instead of fabricating settlement');
  }finally{ledger.close();}
  await replaceSharedKey(dialog,'test-only-browser-provider-key');
  await dialog.getByRole('button',{name:'关闭共享 API 管理'}).click();

  assert.deepEqual(errors,[]);
  console.log('Gateway controls: zero balance, configuration revocation and provider rejection fail closed; administrator restoration recovers availability');
}finally{await creatorContext.close();await adminContext.close();await browser.close();}
