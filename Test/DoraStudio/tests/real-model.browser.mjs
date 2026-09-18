import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';

const require=createRequire(import.meta.url),{chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const origin=process.env.STUDIO_REAL_MODEL_URL,dbPath=process.env.STUDIO_REAL_MODEL_DB;
const account=process.env.STUDIO_REAL_MODEL_ACCOUNT,password=process.env.STUDIO_REAL_MODEL_PASSWORD;
if(!origin||!dbPath||!account||!password)throw new Error('Set the existing HTTPS Studio URL, database path and creator login; configure the real shared model and secret through the administrator UI');
const browser=await chromium.launch({headless:true,...(process.env.STUDIO_CHROME_PATH?{executablePath:process.env.STUDIO_CHROME_PATH}:{})});
const context=await browser.newContext({ignoreHTTPSErrors:true}),page=await context.newPage(),errors=[];
page.on('pageerror',error=>errors.push(error.message));
const ledgerBefore=openModelLedger(dbPath,{requireConfigurationVersion:true});
let spentBefore,auditAfter;
try{spentBefore=ledgerBefore.scope('account',account).spent;auditAfter=ledgerBefore.audit({limit:1000}).at(-1)?.sequence??0;}
finally{ledgerBefore.close();}
try{
  await page.goto(origin);await page.getByRole('button',{name:'登录 / 邀请码注册'}).click();
  await page.getByLabel('账号名').fill(account);await page.getByLabel('密码').fill(password);
  await page.getByRole('button',{name:'登录账号'}).click();await page.getByText('账号已连接').waitFor();
  await page.locator('.idea-model-select').getByRole('button',{name:'刷新'}).click();
  const select=page.getByLabel('本次创作使用的共享模型'),options=select.locator('option:not([value=""])');
  await options.first().waitFor({state:'attached',timeout:15000});
  const requestedLabel=process.env.STUDIO_REAL_MODEL_LABEL;
  if(requestedLabel){
    const matches=options.filter({hasText:requestedLabel});assert.equal(await matches.count(),1,'requested shared model label must match exactly one option');
    await select.selectOption(await matches.first().getAttribute('value'));
  }
  else await select.selectOption(await options.first().getAttribute('value'));
  await page.getByLabel('游戏创意').fill('这是模型网关验收。请只简短回复已收到，不要修改文件，也不要调用工具。');
  await page.getByRole('button',{name:'新建并启动 Agent 创作'}).click();
  await page.locator('.agent-task').first().waitFor({timeout:60000});
  await page.getByLabel('Dora Agent').locator('.badge').getByText('已完成',{exact:true}).waitFor({timeout:180000});
  await page.getByText('修改已核对到本机',{exact:false}).waitFor({timeout:60000});

  const ledger=openModelLedger(dbPath,{requireConfigurationVersion:true});
  try{
    const events=ledger.audit({after:auditAfter,limit:1000}),finished=events.filter(item=>item.action==='finish'&&item.accountId===account).at(-1);
    assert.ok(finished,'real Agent request must have a durable finish event');
    const record=ledger.request(finished.requestId);
    assert.equal(record.request.state,'settled');assert.ok(record.receipt?.usage&&record.receipt.usage.inputTokens>0n&&record.receipt.usage.outputTokens>0n,'real provider must report non-zero usage');
    assert.ok(ledger.scope('account',account).spent>spentBefore,'real provider usage must increase the creator RMB spend');
  }finally{ledger.close();}
  assert.deepEqual(errors,[]);
  console.log('Real shared model acceptance: original Agent consumed the configured provider response, persisted non-zero usage and increased creator RMB spend');
}finally{await context.close();await browser.close();}
