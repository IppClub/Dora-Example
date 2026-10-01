import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const root = fileURLToPath(new URL('../apps/web/dist/', import.meta.url));
const artifacts = fileURLToPath(new URL('../apps/web/artifacts/', import.meta.url));
await mkdir(artifacts, { recursive: true });
const server = createServer(async (req, res) => {
  try {
    const path = resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
    if (path !== root.slice(0, -1) && !path.startsWith(root)) { res.writeHead(403); res.end(); return; }
    const target = path === root.slice(0, -1) ? resolve(root, 'index.html') : path;
    const bytes = await readFile(target);
    res.setHeader('content-type', ({ '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml' })[extname(target)] || 'text/plain');
    res.end(bytes);
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ headless: true, ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}) });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  const page = await context.newPage(); const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  const url = `http://127.0.0.1:${server.address().port}`;
  await page.goto(url);
  await page.getByText('本地存储可用', { exact: false }).waitFor();
  assert.equal(await page.locator('.topbar .session-status').count(),1,'Account controls and workspace status share one top bar');
  assert.equal(await page.getByLabel('项目名称',{exact:true}).count(),0,'The project form stays collapsed until requested');
  await page.getByRole('button',{name:/新建 \/ 导入/}).click();
  await page.getByRole('dialog',{name:'新建或导入项目'}).waitFor();
  await page.getByRole('button',{name:'关闭新建或导入面板'}).click();
  const archive=await page.evaluate(async()=>{
    await import('/web-package.js');
    return [...globalThis.DoraWebPackage.createArchive([{path:'download/repo/source/init.ts',data:new TextEncoder().encode('export const imported = 7;')},{path:'download/repo/source/data.bin',data:new Uint8Array([0,255,128])}])];
  });
  await page.getByLabel('导入 Dora 游戏包',{exact:true}).setInputFiles({name:'普通源码.zip',mimeType:'application/zip',buffer:Buffer.from(archive)});
  await page.getByRole('heading',{name:'普通源码',exact:true}).waitFor();assert.equal(await page.getByRole('button',{name:'Dora Agent',exact:true}).getAttribute('aria-pressed'),'true');await page.getByRole('button',{name:'资源',exact:true}).click();assert.equal(await page.getByLabel('项目代码',{exact:true}).inputValue(),'export const imported = 7;');
  await page.getByRole('button',{name:'项目信息',exact:true}).click();
  await page.locator('.project-compatibility summary').click();await page.getByText('入口：init.ts。当前编译链支持该入口类型，但不代表代码已编译或运行成功。',{exact:true}).waitFor();
  await page.setViewportSize({width:320,height:900});assert.equal(await page.locator('.project-compatibility').evaluate(el=>el.scrollWidth<=el.clientWidth+1),true);await page.locator('.project-info-drawer').screenshot({path:resolve(artifacts,'project-compatibility-320.png')});await page.getByRole('button',{name:'关闭项目信息'}).click();await page.setViewportSize({width:1440,height:1000});
  await page.reload();await page.getByRole('button',{name:/普通源码/}).click();assert.equal(await page.getByLabel('项目代码',{exact:true}).inputValue(),'export const imported = 7;');
  const projectCount=await page.locator('nav[aria-label="项目列表"] button').count();
  const damaged=Buffer.from(archive);const payload=damaged.indexOf(Buffer.from('export const imported = 7;'));assert.ok(payload>=0);damaged[payload]^=1;
  await page.getByLabel('导入 Dora 游戏包',{exact:true}).setInputFiles({name:'损坏源码.zip',mimeType:'application/zip',buffer:damaged});
  await page.getByRole('alert').filter({hasText:'CRC mismatch'}).waitFor();assert.equal(await page.locator('nav[aria-label="项目列表"] button').count(),projectCount);
  assert.equal(await page.getByRole('button',{name:'保留本次上传',exact:true}).count(),0);
  assert.equal(await page.getByLabel('项目代码',{exact:true}).inputValue(),'export const imported = 7;');await page.getByRole('heading',{name:'普通源码',exact:true}).waitFor();
  await page.reload();await page.getByRole('button',{name:/普通源码/}).click();assert.equal(await page.locator('nav[aria-label="项目列表"] button').count(),projectCount);assert.equal(await page.getByLabel('项目代码',{exact:true}).inputValue(),'export const imported = 7;');
  const wasmArchive=await page.evaluate(async()=>{await import('/web-package.js');return [...globalThis.DoraWebPackage.createArchive([{path:'original/init.wasm',data:new Uint8Array([0,97,115,109,1,0,0,0])}])];});
  await page.getByLabel('导入 Dora 游戏包',{exact:true}).setInputFiles({name:'仅Wasm.dora',mimeType:'application/zip',buffer:Buffer.from(wasmArchive)});
  await page.getByRole('alert').filter({hasText:'未找到明确的源码入口，请检查游戏包目录结构'}).waitFor();
  assert.equal(await page.locator('.archive-library').count(),0,'The sidebar no longer exposes a separate pending archive area');
  assert.equal(await page.locator('nav[aria-label="项目列表"] button').count(),projectCount,'An unrecognized package does not create a project');
  const sidebarScrolling=await page.evaluate(()=>{
    const sidebar=document.querySelector('.sidebar'),projects=document.querySelector('nav[aria-label="项目列表"]');
    return {sidebar:getComputedStyle(sidebar).overflowY,projects:getComputedStyle(projects).overflowY};
  });
  assert.equal(sidebarScrolling.sidebar,'hidden','The whole sidebar stays fixed');
  assert.equal(sidebarScrolling.projects,'auto','Only the project list scrolls vertically');
  const sourceBytes=Buffer.from('\ufeffprint "保留原文"\r\n');
  const yueArchive=await page.evaluate(async source=>{await import('/web-package.js');return [...globalThis.DoraWebPackage.createArchive([{path:'init.yue',data:new Uint8Array(source)},{path:'asset.bin',data:new Uint8Array([0,255])}])];},[...sourceBytes]);
  await page.getByLabel('导入 Dora 游戏包',{exact:true}).setInputFiles({name:'待适配.dora',mimeType:'application/zip',buffer:Buffer.from(yueArchive)});
  await page.getByRole('heading',{name:'待适配',exact:true}).waitFor();await page.getByRole('button',{name:'项目信息',exact:true}).click();await page.locator('.project-compatibility summary').click();await page.getByText('当前入口 init.yue 的编译尚未接通，源码仍可编辑和导出。',{exact:true}).waitFor();await page.getByRole('button',{name:'关闭项目信息'}).click();
  const downloading=page.waitForEvent('download');await page.getByRole('button',{name:'下载 ZIP',exact:true}).click();const download=await downloading;const backup=await readFile(await download.path());
  const preserved=await page.evaluate(async bytes=>{const archive=await globalThis.DoraWebPackage.inspectArchive(new Uint8Array(bytes),{projectBackup:true});return archive.files.map(file=>({path:file.path,bytes:[...file.data]}));},[...backup]);
  assert.deepEqual(preserved.find(file=>file.path==='init.yue').bytes,[...sourceBytes]);assert.deepEqual(preserved.find(file=>file.path==='asset.bin').bytes,[0,255]);
  await page.getByRole('button',{name:/新建 \/ 导入/}).click();
  await page.getByRole('button',{name:/新建空白项目/}).click();
  await page.getByLabel('项目名称',{exact:true}).fill('星光花园');
  await page.getByRole('button', { name: '创建并进入 Studio' }).click();
  const editor = page.getByLabel('项目代码', { exact: true });
  assert.equal(await page.getByRole('button',{name:'Dora Agent',exact:true}).getAttribute('aria-pressed'),'true','A project opens on Dora Agent before a per-project preference exists');
  const previewToolbar=page.locator('.runtime-toolbar'),workspaceToolbar=page.locator('.workspace-heading');
  assert.equal(Math.round((await previewToolbar.boundingBox()).height),Math.round((await workspaceToolbar.boundingBox()).height),'Preview and workspace toolbars share one height');
  const divider=page.getByRole('separator',{name:'调整试玩与工作区宽度'}),beforeWidth=(await page.locator('.preview-pane').boundingBox()).width;
  await divider.hover();
  const dividerBox=await divider.boundingBox();await page.mouse.move(dividerBox.x+3,dividerBox.y+20);await page.mouse.down();await page.mouse.move(dividerBox.x+83,dividerBox.y+20);await page.mouse.up();
  const afterWidth=(await page.locator('.preview-pane').boundingBox()).width;
  assert.ok(afterWidth>beforeWidth+50,`Dragging the divider resizes the preview (${beforeWidth} -> ${afterWidth})`);
  const rememberedSplit=await page.evaluate(()=>localStorage.getItem('dora-studio:workbench-split'));assert.ok(Number(rememberedSplit)>.45,'Divider position is persisted');
  await page.getByRole('button',{name:'资源',exact:true}).click();
  await editor.waitFor();
  await page.getByLabel('上传资源',{exact:true}).setInputFiles({name:'delete-me.bin',mimeType:'application/octet-stream',buffer:Buffer.from([1,2,3])});
  await page.getByRole('button',{name:'Resources/delete-me.bin',exact:true}).click();await page.getByRole('button',{name:'删除',exact:true}).click();await page.getByRole('dialog',{name:'删除 Resources/delete-me.bin？'}).getByRole('button',{name:'删除资源',exact:true}).click();
  assert.equal(await page.getByRole('button',{name:'Resources/delete-me.bin',exact:true}).count(),0,'Deleting a resource removes it from the draft');await page.getByRole('button',{name:'删除',exact:true}).click();await page.getByRole('alert').filter({hasText:'入口文件是项目最后一个可编辑资源'}).waitFor();await page.getByRole('button',{name:'关闭错误提示'}).click();await page.getByRole('button',{name:'保存项目',exact:true}).click();await page.locator('.project-header [role="status"]').filter({hasText:'更新于'}).waitFor();
  assert.equal(await page.locator('.project-agent-spinner').count(),0,'Ordinary project work must not show the Agent connection spinner');
  await page.getByRole('link',{name:'返回首页'}).click();
  await page.getByRole('heading',{name:/从一个想法/}).waitFor();
  for(const viewport of [{width:1440,height:680},{width:1024,height:768},{width:800,height:700},{width:390,height:700}]){
    await page.setViewportSize(viewport);
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,`Home must not overflow horizontally at ${viewport.width}x${viewport.height}`);
    const submit=page.getByRole('button',{name:'新建并启动 Agent 创作'});
    if(viewport.width>800){
      const box=await submit.boundingBox();assert.ok(box&&box.y>=0&&box.y+box.height<=viewport.height,`Core creation form must fit at ${viewport.width}x${viewport.height}`);
    }else{
      await submit.scrollIntoViewIfNeeded();assert.equal(await submit.isVisible(),true,`Creation action must remain reachable at ${viewport.width}x${viewport.height}`);
    }
  }
  await page.setViewportSize({width:1440,height:1000});
  await page.getByRole('button',{name:/星光花园/}).click();
  await editor.fill('export const answer: number = "wrong";');
  await page.getByRole('button', { name: '编译项目' }).click();
  await page.getByText('编译失败，请查看问题列表', { exact: true }).waitFor();
  const problem = page.locator('.diagnostics button').first(); await problem.click();
  await page.waitForFunction(() => { const el = document.querySelector('textarea[aria-label="项目代码"]'); return el.selectionEnd > el.selectionStart; });
  await page.getByRole('button', { name: '保存项目', exact: true }).click();
  await page.locator('.project-header [role="status"]').filter({hasText:'更新于'}).waitFor();
  await page.reload();
  await page.getByRole('button', { name: /星光花园/ }).click();
  assert.equal(await page.getByRole('button',{name:'资源',exact:true}).getAttribute('aria-pressed'),'true','Each project restores its last resource or Agent view');
  assert.equal(await page.evaluate(()=>localStorage.getItem('dora-studio:workbench-split')),rememberedSplit,'Divider preference survives reload');
  assert.equal(await editor.inputValue(), 'export const answer: number = "wrong";');
  await editor.fill('export const answer = 42;');
  await page.getByRole('button', { name: '编译项目' }).click();
  await page.getByText(/编译成功 · \d+ 个产物文件/).waitFor();
  await editor.fill('export function normalize(value: number) { if (value) return 1; return 0; }');
  await page.getByRole('button', { name: '编译项目' }).click();
  await page.getByText(/编译成功 · \d+ 个产物文件 · 1 条警告/).waitFor();
  await page.getByText('0 错误 · 1 警告',{exact:true}).waitFor();
  assert.equal(await page.locator('.diagnostic-kind.warning').filter({hasText:'警告'}).count(),1);
  await editor.fill('export const answer = 42;');
  await page.getByRole('button', { name: '编译项目' }).click();
  await page.getByText('0 错误 · 0 警告',{exact:true}).waitFor();
  await page.getByRole('button', { name: '保存项目', exact: true }).click();
  await page.locator('.project-header [role="status"]').filter({hasText:'更新于'}).waitFor();
  await page.screenshot({ path: resolve(artifacts, 'workbench-desktop.png'), fullPage: true });

  const other = await context.newPage(); await other.goto(url);
  await other.getByRole('button', { name: /星光花园/ }).click();
  await other.getByLabel('项目代码').fill('export const answer = 200;');
  await page.getByLabel('项目代码').fill('export const answer = 100;');
  assert.match(await page.locator('.build-status').innerText(),/^有未编译更改/);
  assert.equal(await page.getByText(/SHA-256 [0-9a-f]{10}…/).count(),1,'Editing must retain the last successful runtime artifact');
  await page.getByRole('button', { name: '保存项目', exact: true }).click();
  await page.locator('.project-header [role="status"]').filter({hasText:'更新于'}).waitFor();
  await other.getByRole('button', { name: '保存项目', exact: true }).click();
  await other.getByRole('alert').filter({ hasText: '其他标签页已修改' }).waitFor();
  assert.equal(await other.getByLabel('项目代码').inputValue(), 'export const answer = 200;');
  await other.getByRole('alert').getByRole('button', { name: '另存副本' }).click();
  await other.getByRole('heading', { name: '星光花园 · 副本', exact: true }).waitFor();
  assert.equal(await other.getByRole('button', { name: 'Dora Agent', exact: true }).getAttribute('aria-pressed'),'true','A copied project should use the new-project Agent default');
  await other.getByRole('button', { name: '资源', exact: true }).click();
  await other.getByLabel('项目代码').fill('export const unsaved = 300;');
  await other.locator('.project-link').filter({ hasText: '星光花园', hasNotText: '副本' }).click();
  await other.getByRole('dialog',{name:'放弃未保存修改？'}).getByRole('button',{name:'取消'}).click();
  assert.equal(await other.getByLabel('项目代码').inputValue(), 'export const unsaved = 300;');
  await other.close({ runBeforeUnload: false });

  await page.getByRole('button',{name:'项目信息',exact:true}).click();
  await page.getByLabel('修改项目名称',{exact:true}).fill('星光花园 · 新名称');
  await page.getByRole('button',{name:'保存名称',exact:true}).click();
  await page.locator('.project-header h1').getByText('星光花园 · 新名称',{exact:true}).waitFor();
  await page.getByRole('button',{name:'关闭项目信息'}).click();
  await page.locator('.project-link').filter({hasText:'星光花园 · 新名称'}).waitFor();

  for (const width of [1024, 736, 390, 320]) {
    await page.setViewportSize({ width, height: 900 });
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);
    assert.equal(overflow, false, `overflow at ${width}`);
    if (width <= 800) {
      await page.getByRole('button', { name: 'Dora Agent', exact: true }).click();
      await page.getByText('和你的想法一起成长', { exact: true }).waitFor();
      assert.equal(await page.getByLabel('Agent 描述').isDisabled(), true);
      assert.equal(await page.locator('.runtime-preview').isVisible(), true);
      await page.getByRole('button', { name: '资源', exact: true }).click();
    }
  }
  await page.setViewportSize({ width: 390, height: 900 });
  await page.screenshot({ path: resolve(artifacts, 'workbench-mobile.png'), fullPage: true });
  // This static-build test deliberately has no independent runtime service.
  // Actual game execution is covered by runtime-host.browser.mjs with TEST_APP.
  const runButton=page.getByRole('button', {name:'运行游戏',exact:true});
  assert.equal(await runButton.isDisabled(),false);
  await runButton.click();
  await page.getByRole('status').filter({hasText:'独立试玩 Player 尚未就绪'}).waitFor();
  assert.equal(await page.getByText('尚未配置独立来源运行服务。请先完成运行环境配置。', {exact:true}).count(),0);
  assert.equal(await page.getByText('Agent 工具试玩采样结束会停止游戏；切换项目也会停止当前实例。', {exact:true}).count(),0);
  await page.setViewportSize({width:1024,height:900});
  const deletionArchive=await page.evaluate(async()=>{await import('/web-package.js');return [...globalThis.DoraWebPackage.createArchive([
    {path:'init.ts',data:new TextEncoder().encode('export const removeMe = true;')},
    {path:'init.lua',data:new TextEncoder().encode('return { removeMe = true }')},
    {path:'keep.ts',data:new TextEncoder().encode('export const keepMe = true;')},
  ])];});
  await page.getByLabel('导入 Dora 游戏包',{exact:true}).setInputFiles({name:'删除资源验收.zip',mimeType:'application/zip',buffer:Buffer.from(deletionArchive)});
  await page.getByRole('heading',{name:'删除资源验收',exact:true}).waitFor();await page.getByRole('button',{name:'资源',exact:true}).click();
  assert.equal(await page.getByRole('button',{name:'init.lua',exact:true}).count(),0,'Generated Lua stays hidden from authored resources');
  await page.getByRole('button',{name:'init.ts',exact:true}).click();await page.getByRole('button',{name:'删除',exact:true}).click();
  await page.getByRole('dialog',{name:'删除 init.ts？'}).getByText('同时会删除它生成的 init.lua',{exact:false}).waitFor();
  await page.getByRole('dialog',{name:'删除 init.ts？'}).getByRole('button',{name:'删除资源',exact:true}).click();
  await page.getByRole('button',{name:'保存项目',exact:true}).click();await page.locator('.project-header [role="status"]').filter({hasText:'更新于'}).waitFor();
  const deletionDownloadEvent=page.waitForEvent('download');await page.getByRole('button',{name:'下载 ZIP',exact:true}).click();const deletionDownload=await deletionDownloadEvent;
  const deletionBytes=await readFile(await deletionDownload.path());
  const deletionPaths=await page.evaluate(async bytes=>(await globalThis.DoraWebPackage.inspectArchive(new Uint8Array(bytes),{projectBackup:true})).files.map(file=>file.path),[...deletionBytes]);
  assert.equal(deletionPaths.includes('init.ts'),false);assert.equal(deletionPaths.includes('init.lua'),false,'Deleting authored code also deletes its generated Lua sibling');assert.equal(deletionPaths.includes('keep.ts'),true);
  await page.getByRole('button',{name:'项目信息',exact:true}).click();await page.locator('.project-danger-zone').getByRole('button',{name:'删除项目',exact:true}).click();
  await page.getByRole('dialog',{name:'删除项目“删除资源验收”？'}).getByRole('button',{name:'删除项目',exact:true}).click();
  await page.getByRole('heading',{name:/从一个想法/}).waitFor();assert.equal(await page.getByRole('button',{name:/删除资源验收/}).count(),0);
  await page.reload();await page.getByText('本地存储可用',{exact:false}).waitFor();assert.equal(await page.getByRole('button',{name:/删除资源验收/}).count(),0,'Deleted project remains absent after reload');
  assert.deepEqual(errors, []);
  console.log(`PASS Chrome ${browser.version()}: real create/edit/save/reload/compile/diagnostic selection, two-tab conflict with copy recovery, unsaved navigation guard, 1024/736/390/320 layouts. Screenshots: ${artifacts}`);
} finally { await browser?.close(); await new Promise(resolve => server.close(resolve)); }
