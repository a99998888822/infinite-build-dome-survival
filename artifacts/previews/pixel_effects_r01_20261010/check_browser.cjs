const {chromium}=require('C:/Users/mi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'), path=require('path');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1100},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(JSON.parse(fs.readFileSync(path.join(__dirname,'server.json'),'utf8')).url);
  await page.waitForFunction(()=>document.getElementById('loading').textContent.includes('短暂停顿'));
  await page.getByRole('button',{name:'暂停',exact:true}).click();
  const selectors=await page.locator('nav button').count();
  for(let i=0;i<selectors;i++){
   await page.locator('nav button').nth(i).click();
   await page.waitForFunction(()=>!document.getElementById('loading').textContent.includes('载入'));
   const label=await page.locator('#loading').innerText();
   if(/失败|无法/.test(label))throw Error(label);
   await page.locator('#scrub').fill('3');
   await page.getByRole('button',{name:'下一帧',exact:true}).click();
   if(!((await page.locator('#counter').innerText()).startsWith('05')))throw Error('scrubbing failed');
  }
  await page.locator('nav button').first().click();
  await page.waitForFunction(()=>document.getElementById('loading').textContent.includes('短暂停顿'));
  await page.locator('#speed').selectOption('0.5');
  await page.locator('#scrub').fill('2');
  await page.getByRole('button',{name:'放大 2×',exact:true}).click();
  await page.screenshot({path:path.join(__dirname,'browser_review.png'),fullPage:true});
  await page.getByRole('button',{name:'恢复 1×',exact:true}).click();
  await page.getByRole('button',{name:'播放',exact:true}).click();
  const a=await page.locator('#after').evaluate(c=>c.toDataURL());
  await page.waitForTimeout(125);
  const b=await page.locator('#after').evaluate(c=>c.toDataURL());
  if(a===b)throw Error('animation did not advance');
  await page.setViewportSize({width:620,height:950});
  await page.screenshot({path:path.join(__dirname,'browser_narrow.png'),fullPage:true});
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
  if(overflow)throw Error('horizontal overflow');
  if(errors.length)throw Error(errors.join('\n'));
  const recovery=await browser.newPage();
  const retries={};
  recovery.on('pageerror',e=>errors.push(e.message));
  await recovery.route(/renders\/(dash_circle_candidate\.webp|background\.png)/,async route=>{
   const url=route.request().url();retries[url]=(retries[url]||0)+1;
   if(retries[url]===1)await route.abort('failed');else await route.continue();
  });
  await recovery.goto(JSON.parse(fs.readFileSync(path.join(__dirname,'server.json'),'utf8')).url);
  await recovery.getByRole('button',{name:'重新加载画面',exact:true}).waitFor({state:'visible'});
  await recovery.getByRole('button',{name:'重新加载画面',exact:true}).click();
  await recovery.waitForFunction(()=>document.getElementById('loading').textContent.includes('短暂停顿'));
  if(Object.values(retries).some(count=>count<2))throw Error('failed image was not retried');
  if(errors.length)throw Error(errors.join('\n'));
  fs.writeFileSync(path.join(__dirname,'browser_validation.json'),JSON.stringify({effects:selectors,controls:true,animation_advances:true,narrow_layout:true,image_failure_retry:true,background_failure_retry:true,page_errors:errors},null,2),'utf8');
  console.log('BROWSER_REVIEW_PASS',selectors);
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
