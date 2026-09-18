import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {openLoginStore} from '../apps/server/login-store.mjs';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_REAL_MODEL_URL,dbPath=process.env.STUDIO_REAL_MODEL_DB;
const keyName=process.env.STUDIO_REAL_MODEL_KEY_NAME??'DEEPSEEK_API_KEY';
const providerKey=/^[A-Z][A-Z0-9_]{1,127}$/.test(keyName)?process.env[keyName]:undefined;
const model=process.env.STUDIO_REAL_MODEL_ID??'deepseek-flash';
const label=process.env.STUDIO_REAL_MODEL_LABEL??'DeepSeek 创作模型';
const providerId=process.env.STUDIO_REAL_MODEL_PROVIDER_ID??'deepseek';
const adminName=process.env.STUDIO_REAL_MODEL_ADMIN??'studio-real-admin';
const adminPassword=process.env.STUDIO_REAL_MODEL_ADMIN_PASSWORD??'studio-real-admin-password-123';
const creatorName=process.env.STUDIO_REAL_MODEL_ACCOUNT??'studio-real-creator';
const creatorPassword=process.env.STUDIO_REAL_MODEL_PASSWORD??'studio-real-creator-password-123';
if(!origin||!dbPath||!providerKey)throw new Error('Set the HTTPS Studio URL, database path and an authorized provider key environment variable');

const bootstrapStore=openLoginStore(dbPath),bootstrap=bootstrapStore.issueInvite({administrator:true});bootstrapStore.close();
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const adminContext=await browser.newContext({ignoreHTTPSErrors:true}),admin=await adminContext.newPage(),errors=[];
let creatorContext;
admin.on('pageerror',error=>errors.push(error.message));
try{
  await admin.goto(origin);await admin.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  await admin.getByRole('button',{name:'邀请码注册',exact:true}).click();
  await admin.getByLabel('邀请码').fill(bootstrap.code);await admin.getByLabel('账号名').fill(adminName);await admin.getByLabel('密码').fill(adminPassword);
  await admin.getByRole('button',{name:'创建账号并登录'}).click();await admin.getByText('账号已连接').waitFor();
  await admin.getByRole('button',{name:'共享 API 管理',exact:true}).click();
  const models=admin.getByRole('dialog',{name:'共享 API 管理'});await models.getByRole('button',{name:'导入共享 API 配置'}).click();
  await models.getByLabel('配置名称').fill(label);await models.getByLabel('共享供应商').selectOption(providerId);await models.getByLabel('模型标识').fill(model);
  await models.getByLabel('输入单价').fill(process.env.STUDIO_REAL_MODEL_INPUT_CNY_PER_MILLION??'2');
  await models.getByLabel('输出单价').fill(process.env.STUDIO_REAL_MODEL_OUTPUT_CNY_PER_MILLION??'8');
  await models.getByRole('button',{name:'保存配置（默认停用）'}).click();await models.getByText('尚未导入或已撤销',{exact:false}).waitFor();
  await models.getByLabel('共享 API Key').fill(providerKey);await models.getByRole('button',{name:'加密保存密钥'}).click();
  await models.getByText('已加密托管',{exact:false}).waitFor();assert.equal(await models.getByLabel('共享 API Key').inputValue(),'');
  await models.getByLabel('API 最大并发').fill('2');await models.getByRole('button',{name:'保存 API 并发'}).click();await models.getByText('0/2 正在使用',{exact:false}).waitFor();
  await models.getByRole('button',{name:'启用共享配置'}).click();await models.getByText('已启用 · 配置 v',{exact:false}).waitFor();
  await models.getByRole('button',{name:'关闭共享 API 管理'}).click();

  await admin.getByRole('button',{name:'账号管理'}).click();await admin.getByRole('button',{name:'邀请新账号'}).click();await admin.getByRole('button',{name:'生成邀请码'}).click();
  const invite=await admin.locator('.admin-invitation code').innerText();await admin.getByRole('button',{name:'关闭账号管理'}).click();
  creatorContext=await browser.newContext({ignoreHTTPSErrors:true});const creator=await creatorContext.newPage();creator.on('pageerror',error=>errors.push(error.message));
  await creator.goto(origin);await creator.getByRole('button',{name:'登录 / 邀请码注册'}).click();await creator.getByRole('button',{name:'邀请码注册',exact:true}).click();
  await creator.getByLabel('邀请码').fill(invite);await creator.getByLabel('账号名').fill(creatorName);await creator.getByLabel('密码').fill(creatorPassword);
  await creator.getByRole('button',{name:'创建账号并登录'}).click();await creator.getByText('账号已连接').waitFor();

  await admin.getByRole('button',{name:'共享 API 管理',exact:true}).click();const grants=admin.getByRole('dialog',{name:'共享 API 管理'});
  await grants.getByRole('button',{name:'账号与逐 API 授权'}).click();await grants.getByLabel('授权账号名').fill(creatorName);await grants.getByRole('button',{name:'读取账号授权'}).click();
  await grants.getByText('尚未分配账号模型额度').waitFor();await grants.getByLabel('账号金额上限').fill('10');await grants.getByLabel('账号模型并发').fill('2');
  await grants.getByRole('button',{name:'保存账号总额度'}).click();await grants.getByText('已用 ¥0',{exact:false}).waitFor();
  await grants.getByLabel('选择授权 API').selectOption({label:`${label} · 可用`});await grants.getByLabel('逐 API 金额上限').fill('5');await grants.getByLabel('逐 API 并发').fill('1');
  await grants.getByRole('button',{name:'分配逐 API 授权'}).click();await grants.getByText('已有授权',{exact:false}).waitFor();
  await grants.getByRole('button',{name:'关闭共享 API 管理'}).click();
  await creator.locator('.idea-model-select').getByRole('button',{name:'刷新'}).click();
  await creator.getByLabel('本次创作使用的共享模型').selectOption({label:`${label} · ${model}`});
  assert.deepEqual(errors,[]);
  console.log(`Real shared model setup passed: ${label} is enabled and assigned to ${creatorName}`);
}finally{
  await creatorContext?.close();await adminContext.close();await browser.close();
}
