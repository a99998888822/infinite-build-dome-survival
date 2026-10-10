const {chromium}=require('C:/Users/mi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const url=JSON.parse(fs.readFileSync(path.join(__dirname,'server.json'),'utf8')).url;
  const page=await browser.newPage({viewport:{width:1500,height:1050}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(url);
  await page.waitForFunction(()=>images.length===2&&!loading);
  await page.locator('#play').click();
  const count=await page.locator('nav button').count();
  if(count!==6)throw Error('Missing review clips');
  for(let i=0;i<count;i++){
   await page.locator('nav button').nth(i).click();
   await page.waitForFunction(()=>images.length===2&&!loading);
   const max=Number(await page.locator('#scrub').getAttribute('max'));
   for(const at of [0,23,24,max]){
    await page.locator('#scrub').fill(String(at));
    const valid=await page.locator('#after').evaluate(c=>c.getContext('2d').getImageData(0,0,620,440).data.some((v,i)=>i%4!==3&&v>30));
    if(!valid)throw Error('Empty canvas '+i+':'+at);
   }
  }
  await page.locator('nav button').nth(1).click();
  await page.waitForFunction(()=>images.length===2&&!loading);
  await page.locator('#scrub').fill('19');
  await page.screenshot({path:path.join(__dirname,'browser_review.png'),fullPage:true});
  await page.locator('#speed').selectOption('0.5');
  await page.locator('#next').click();
  if(!((await page.locator('#counter').innerText()).startsWith('21')))throw Error('Step failed');
  await page.locator('#play').click();
  const a=await page.locator('#after').evaluate(c=>c.toDataURL());
  await page.waitForTimeout(180);
  const b=await page.locator('#after').evaluate(c=>c.toDataURL());
  if(a===b)throw Error('Animation frozen');
  await page.locator('#zoom').click();
  if(!await page.locator('body').evaluate(e=>e.classList.contains('expanded')))throw Error('Zoom failed');
  await page.locator('#zoom').click();
  await page.setViewportSize({width:620,height:980});
  await page.screenshot({path:path.join(__dirname,'browser_narrow.png'),fullPage:true});
  if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Narrow overflow');
  const retry=await browser.newPage();let attempts=0;
  retry.on('pageerror',e=>errors.push(e.message));
  await retry.route('**/renders/dagger_r02_0.webp',async route=>{attempts++;if(attempts===1)await route.abort('failed');else await route.continue()});
  await retry.goto(url);
  await retry.locator('#retry').waitFor({state:'visible'});
  await retry.locator('#retry').click();
  await retry.waitForFunction(()=>images.length===2&&!loading);
  if(attempts<2||errors.length)throw Error(errors.join('\n')||'Retry failed');
  fs.writeFileSync(path.join(__dirname,'validation/browser.json'),JSON.stringify({clips:count,all_chunks:true,controls:true,animation:true,zoom:true,narrow:true,image_failure_retry:true,page_errors:errors},null,2));
  console.log('R02_BROWSER_PASS',count);
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
