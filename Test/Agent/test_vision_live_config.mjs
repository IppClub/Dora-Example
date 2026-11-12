// Opt-in paid provider test. Uses a saved profile's URL/key without changing it.
// Required: DORA_SSR_ROOT, DORA_CLI, DORA_LLM_CONFIG_ID, DORA_VISION_MODEL,
// DORA_VISION_IMAGE (a screenshot of the model configuration dialog).
import assert from 'node:assert/strict';
import {readFile,writeFile,mkdir,copyFile,rm} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {join,resolve} from 'node:path';
const env=process.env,root=env.DORA_SSR_ROOT,cli=env.DORA_CLI,id=Number(env.DORA_LLM_CONFIG_ID),model=env.DORA_VISION_MODEL,source=env.DORA_VISION_IMAGE;
assert.ok(root&&cli&&Number.isInteger(id)&&id>0&&model&&source,'Set the five required environment variables described above.');
const output=resolve(root,'build/vision-live-config');await mkdir(join(output,'art'),{recursive:true});await copyFile(source,join(output,'art/config.png'));
const resultPath=join(output,'result.json');await rm(resultPath,{force:true});
let code=await readFile(new URL('./Fixtures/vision_live_config.lua',import.meta.url),'utf8');
code=code.replaceAll('@WORK_DIR@',output.replaceAll('\\','/').replaceAll("'","\\'")).replaceAll('@CONFIG_ID@',String(id)).replaceAll('@VISION_MODEL@',JSON.stringify(model));
const command=join(output,'command.json');await writeFile(command,JSON.stringify({mode:'lua',code,timeoutSeconds:30}));
const {stdout}=await promisify(execFile)(cli,['--asset',join(root,'Assets'),'cli','agent','command','-p',output,'--input',command]);assert.equal(JSON.parse(stdout).success,true,stdout);
let result;
for(let i=0;i<180;i++){try{result=JSON.parse(await readFile(resultPath,'utf8'));break;}catch{}await new Promise(done=>setTimeout(done,1000));}
assert.ok(result,'Provider timed out without a saved result');assert.equal(result.error,undefined);assert.equal(result.result.output.success,true,JSON.stringify(result));assert.equal(result.result.output.model,model);assert.equal(result.sameEndpoint,true);assert.equal(result.textOptionsIsolated,true);
console.log(JSON.stringify({success:true,model:result.result.output.model,responseModel:result.result.output.responseModel,usage:result.result.output.usage,report:result.result.output.report,resultPath},null,2));
