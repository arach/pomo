const puppeteer = require('puppeteer');
const fs = require('fs').promises;
const path = require('path');

const watchfaces = [
  'default',
  'neon', 
  'terminal',
  'rolodex',
  'retro-digital',
  'retro-lcd'
];

async function captureWatchfaces() {
  const browser = await puppeteer.launch({ 
    headless: false,
    defaultViewport: null 
  });
  
  // Create output directory
  const outputDir = path.join(__dirname, 'watchface-analysis', 'puppeteer-captures');
  await fs.mkdir(outputDir, { recursive: true });
  
  // Capture split view for each watchface
  for (const watchface of watchfaces) {
    console.log(`Capturing ${watchface}...`);
    
    const page = await browser.newPage();
    await page.setViewport({ width: 800, height: 400 });
    
    // Load split view
    await page.goto(`http://localhost:1421/?watchface=${watchface}&split=true`);
    
    // Wait for content to load
    await page.waitForTimeout(2000);
    
    // Take screenshot
    await page.screenshot({
      path: path.join(outputDir, `${watchface}-comparison.png`),
      fullPage: false
    });
    
    await page.close();
  }
  
  // Also capture individual v2 versions for detailed analysis
  for (const watchface of watchfaces) {
    console.log(`Capturing ${watchface} v2 only...`);
    
    const page = await browser.newPage();
    await page.setViewport({ width: 400, height: 400 });
    
    await page.goto(`http://localhost:1421/?watchface=${watchface}&version=v2`);
    await page.waitForTimeout(2000);
    
    await page.screenshot({
      path: path.join(outputDir, `${watchface}-v2-only.png`),
      fullPage: false
    });
    
    await page.close();
  }
  
  await browser.close();
  console.log('All watchfaces captured!');
}

captureWatchfaces().catch(console.error);