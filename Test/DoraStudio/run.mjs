import {spawn} from 'node:child_process';
import {access,cp,mkdir,mkdtemp,readdir,rm,symlink} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {basename,join,resolve} from 'node:path';

const suiteRoot=import.meta.dirname;

async function isStudioRoot(path){
  try{
    await access(join(path,'Studio/package.json'));
    await access(join(path,'Studio/apps/web/src/App.tsx'));
    return true;
  }catch{return false;}
}

const candidates=[
  process.env.DORA_SSR_ROOT,
  resolve(suiteRoot,'../../../Dora-SSR'),
  resolve(suiteRoot,'../../../../Dora-SSR'),
].filter(Boolean);
let doraRoot;
for(const candidate of candidates){if(await isStudioRoot(candidate)){doraRoot=resolve(candidate);break;}}
if(!doraRoot)throw new Error('Set DORA_SSR_ROOT to the Dora-SSR checkout that contains Studio/package.json');

const studioRoot=join(doraRoot,'Studio');
const requested=[];let build=true;
for(const argument of process.argv.slice(2)){
  if(argument==='--no-build'){build=false;continue;}
  if(argument.startsWith('-'))throw new Error(`Unknown option: ${argument}`);
  const name=basename(argument);
  if(name!==argument&&argument!==`tests/${name}`)throw new Error(`Test names cannot contain directories: ${argument}`);
  requested.push(name);
}

function run(command,args,cwd){
  return new Promise((resolve,reject)=>{
    const child=spawn(command,args,{cwd,stdio:'inherit',env:{...process.env,DORA_SSR_ROOT:doraRoot,DORA_STUDIO_ROOT:studioRoot}});
    child.once('error',reject);
    child.once('exit',(code,signal)=>code===0?resolve():reject(new Error(signal?`${command} stopped by ${signal}`:`${command} exited with ${code}`)));
  });
}

const temporary=await mkdtemp(join(tmpdir(),'dora-studio-tests-'));
const mirrorRoot=join(temporary,'Dora-SSR'),mirrorStudio=join(mirrorRoot,'Studio'),mirrorTests=join(mirrorStudio,'tests');
try{
  await mkdir(mirrorStudio,{recursive:true});
  for(const entry of await readdir(doraRoot,{withFileTypes:true})){
    if(entry.name==='.git'||entry.name==='Studio')continue;
    await symlink(join(doraRoot,entry.name),join(mirrorRoot,entry.name),entry.isDirectory()?'dir':'file');
  }
  for(const entry of await readdir(studioRoot,{withFileTypes:true})){
    if(entry.name==='tests')continue;
    await symlink(join(studioRoot,entry.name),join(mirrorStudio,entry.name),entry.isDirectory()?'dir':'file');
  }
  await cp(join(suiteRoot,'tests'),mirrorTests,{recursive:true});

  if(build)await run('pnpm',['build'],studioRoot);
  const available=(await readdir(mirrorTests)).filter(name=>name.endsWith('.mjs'));
  const selected=requested.length?requested:available.filter(name=>name.endsWith('.test.mjs'));
  for(const name of selected)if(!available.includes(name))throw new Error(`Unknown Dora Studio test: ${name}`);
  const unit=selected.filter(name=>name.endsWith('.test.mjs'));
  const scripts=selected.filter(name=>!name.endsWith('.test.mjs'));
  if(unit.length)await run(process.execPath,['--test',...unit.map(name=>join(mirrorTests,name))],studioRoot);
  for(const name of scripts)await run(process.execPath,[join(mirrorTests,name)],studioRoot);
}finally{
  await rm(temporary,{recursive:true,force:true});
}
