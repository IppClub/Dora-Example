import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {DatabaseSync} from 'node:sqlite';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_REAL_MODEL_URL,dbPath=process.env.STUDIO_REAL_MODEL_DB;
const adminName=process.env.STUDIO_REAL_MODEL_ADMIN??'studio-real-admin';
const adminPassword=process.env.STUDIO_REAL_MODEL_ADMIN_PASSWORD??'studio-real-admin-password-123';
const creatorName=process.env.STUDIO_REAL_MODEL_ACCOUNT??'studio-real-creator';
const creatorPassword=process.env.STUDIO_REAL_MODEL_PASSWORD??'studio-real-creator-password-123';
const outsiderName=process.env.STUDIO_REAL_MODEL_OUTSIDER??'studio-real-outsider';
const outsiderPassword=process.env.STUDIO_REAL_MODEL_OUTSIDER_PASSWORD??'studio-real-outsider-password-123';
if(!origin||!dbPath)throw new Error('Set the HTTPS Studio URL and isolated database path');
const database=new DatabaseSync(dbPath,{readOnly:true});
const row=database.prepare('SELECT project AS projectId FROM studio_projects WHERE owner=? ORDER BY revision DESC LIMIT 1').get(creatorName);
database.close();
assert.equal(typeof row?.projectId,'string','creator must have a cloud project from the real-model journey');

const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const errors=[];
const login=async(page,account,password)=>{
  page.on('pageerror',error=>errors.push(error.message));
  await page.goto(origin);await page.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  await page.getByLabel('账号名').fill(account);await page.getByLabel('密码').fill(password);
  await page.getByRole('button',{name:'登录账号'}).click();await page.getByText('账号已连接').waitFor();
};
let adminContext,creatorContext,outsiderContext;
try{
  adminContext=await browser.newContext({ignoreHTTPSErrors:true});const admin=await adminContext.newPage();await login(admin,adminName,adminPassword);
  await admin.getByRole('button',{name:'账号管理'}).click();await admin.getByRole('button',{name:'邀请新账号'}).click();
  await admin.getByRole('button',{name:'生成邀请码'}).click();const invite=await admin.locator('.admin-invitation code').innerText();
  await admin.getByRole('button',{name:'关闭账号管理'}).click();

  creatorContext=await browser.newContext({ignoreHTTPSErrors:true});const creator=await creatorContext.newPage();await login(creator,creatorName,creatorPassword);
  assert.equal((await creator.request.get(`${origin}/api/projects/${encodeURIComponent(row.projectId)}`)).status(),200);

  outsiderContext=await browser.newContext({ignoreHTTPSErrors:true});const outsider=await outsiderContext.newPage();outsider.on('pageerror',error=>errors.push(error.message));
  await outsider.goto(origin);await outsider.getByRole('button',{name:'登录 / 邀请码注册'}).click();await outsider.getByRole('button',{name:'邀请码注册',exact:true}).click();
  await outsider.getByLabel('邀请码').fill(invite);await outsider.getByLabel('账号名').fill(outsiderName);await outsider.getByLabel('密码').fill(outsiderPassword);
  await outsider.getByRole('button',{name:'创建账号并登录'}).click();await outsider.getByText('账号已连接').waitFor();
  assert.equal((await outsider.request.get(`${origin}/api/projects/${encodeURIComponent(row.projectId)}`)).status(),404,'another invited account must not read creator source');
  const list=await (await outsider.request.get(`${origin}/api/projects`)).json();assert.deepEqual(list,{version:1,items:[],nextCursor:null});
  assert.deepEqual(errors,[]);
  console.log(JSON.stringify({result:'passed',creatorCanRead:true,outsiderDenied:true,outsiderCloudProjects:0}));
}finally{
  await outsiderContext?.close();await creatorContext?.close();await adminContext?.close();await browser.close();
}
