// Drive the actual Web IDE compiler page on an isolated native service port.
import {createRequire} from 'node:module';
const require=createRequire(new URL('../DoraStudio/package.json',import.meta.url));
const {chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const browser=await chromium.launch({headless:true});
let stopping=false;
try {
 const page=await browser.newPage();
 // The test opens the page before its first job, unlike the native WebView.
 // Hold its initial poll until the native compiler is actually requested.
 await page.route('**/compiler/poll',async route=>{
  while(!stopping){
   const response=await route.fetch();
   const data=await response.json();
   if(data.success){await route.fulfill({response});return;}
   await response.dispose();
   await new Promise(resolve=>setTimeout(resolve,100));
  }
  await route.abort();
 });
 const ready=page.waitForEvent('console',{predicate:msg=>msg.text()==='Dora compiler is ready',timeout:30000});
 await page.goto(process.argv[2]+'/compiler.html');
 await ready;
 console.log('COMPILER_PAGE_READY');
 await new Promise(resolve=>process.stdin.once('data',resolve));
 stopping=true;
 await page.unrouteAll({behavior:'ignoreErrors'});
}finally{await browser.close();}
