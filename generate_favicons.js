const puppeteer = require('C:\\Users\\user\\.gemini\\antigravity\\scratch\\axioma-landing\\node_modules\\puppeteer-core');
const fs = require('fs');
const path = require('path');

const EDGE_PATH = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const SVG_PATH = 'C:\\Users\\user\\.gemini\\antigravity\\scratch\\axioma\\public\\brand-assets\\logo_thumbnail.svg';
const PUBLIC_DIR = 'C:\\Users\\user\\.gemini\\antigravity\\scratch\\axioma\\public';

const svgContent = fs.readFileSync(SVG_PATH, 'utf8');

// SVG with notification badge dot for badge favicons
const svgWithBadge = svgContent.replace(
  '</svg>',
  `  <!-- Notification Badge -->
  <circle cx="400" cy="110" r="90" fill="#EF4444" stroke="#FFFFFF" stroke-width="28" />
</svg>`
);

async function generateFavicons() {
  const browser = await puppeteer.launch({
    executablePath: EDGE_PATH,
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();

  const sizes = [
    { name: 'favicon-16x16.png', size: 16, badge: false },
    { name: 'favicon-32x32.png', size: 32, badge: false },
    { name: 'favicon-96x96.png', size: 96, badge: false },
    { name: 'favicon-512x512.png', size: 512, badge: false },
    { name: 'apple-icon-180x180.png', size: 180, badge: false },
    { name: 'apple-icon.png', size: 192, badge: false },
    { name: 'android-icon-192x192.png', size: 192, badge: false },
    { name: 'favicon-badge-16x16.png', size: 16, badge: true },
    { name: 'favicon-badge-32x32.png', size: 32, badge: true },
    { name: 'favicon-badge-96x96.png', size: 96, badge: true }
  ];

  for (const item of sizes) {
    const rawSvg = item.badge ? svgWithBadge : svgContent;
    const html = `<!DOCTYPE html><html><body style="margin:0;padding:0;background:transparent;overflow:hidden;display:flex;align-items:center;justify-content:center;width:${item.size}px;height:${item.size}px;">
      <div style="width:${item.size}px;height:${item.size}px;display:flex;">${rawSvg.replace(/width="512" height="512"/, `width="${item.size}" height="${item.size}"`)}</div>
    </body></html>`;

    await page.setViewport({ width: item.size, height: item.size, deviceScaleFactor: 2 });
    await page.setContent(html);
    const dest = path.join(PUBLIC_DIR, item.name);
    await page.screenshot({ path: dest, omitBackground: true });
    console.log(`Generated ${item.name} (${item.size}x${item.size})`);
  }

  // Also create favicon.ico as a copy of 32x32
  fs.copyFileSync(path.join(PUBLIC_DIR, 'favicon-32x32.png'), path.join(PUBLIC_DIR, 'favicon.ico'));
  console.log('Copied favicon.ico');

  await browser.close();
}

generateFavicons().catch(console.error);
