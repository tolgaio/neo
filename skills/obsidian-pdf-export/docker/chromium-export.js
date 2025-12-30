#!/usr/bin/env node
/**
 * Chromium PDF Export
 * Converts markdown to PDF via HTML using Puppeteer
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const MarkdownIt = require('markdown-it');
const anchor = require('markdown-it-anchor');

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
  input: null,
  output: null,
  title: 'Document',
  pageSize: 'A4',
  margin: '1in',
  toc: true,
  tocDepth: 3
};

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--title' && args[i + 1]) {
    options.title = args[++i];
  } else if (arg === '--page-size' && args[i + 1]) {
    options.pageSize = args[++i];
  } else if (arg === '--margin' && args[i + 1]) {
    options.margin = args[++i];
  } else if (arg === '--no-toc') {
    options.toc = false;
  } else if (arg === '--toc-depth' && args[i + 1]) {
    options.tocDepth = parseInt(args[++i], 10);
  } else if (arg === '-o' && args[i + 1]) {
    options.output = args[++i];
  } else if (!arg.startsWith('-')) {
    options.input = arg;
  }
}

if (!options.input) {
  console.error('Usage: chromium-export.js <input.md> -o <output.pdf> [options]');
  console.error('Options:');
  console.error('  --title TEXT      Document title');
  console.error('  --page-size SIZE  Page size (A4, Letter, or WxH like 6in x 9in)');
  console.error('  --margin SIZE     Page margin (e.g., 1in, 2cm)');
  console.error('  --no-toc          Disable table of contents');
  console.error('  --toc-depth N     TOC depth (default: 3)');
  process.exit(1);
}

// Initialize markdown-it with anchor plugin for heading IDs
const md = new MarkdownIt({
  html: true,
  linkify: true,
  typographer: true
}).use(anchor, {
  permalink: false,
  slugify: (s) => s.toLowerCase().replace(/[^\w]+/g, '-').replace(/^-+|-+$/g, '')
});

// Parse page size
function parsePageSize(size) {
  const standardSizes = {
    'a4': { width: '210mm', height: '297mm' },
    'letter': { width: '8.5in', height: '11in' },
    'legal': { width: '8.5in', height: '14in' },
    'a5': { width: '148mm', height: '210mm' }
  };

  const lower = size.toLowerCase();
  if (standardSizes[lower]) {
    return standardSizes[lower];
  }

  // Parse WxH format (e.g., "6x9" or "6in x 9in")
  const match = size.match(/^([\d.]+)\s*(in|cm|mm)?\s*x\s*([\d.]+)\s*(in|cm|mm)?$/i);
  if (match) {
    const unit = match[2] || match[4] || 'in';
    return {
      width: `${match[1]}${unit}`,
      height: `${match[3]}${unit}`
    };
  }

  // Simple WxH without units (assume inches)
  const simpleMatch = size.match(/^([\d.]+)x([\d.]+)$/);
  if (simpleMatch) {
    return {
      width: `${simpleMatch[1]}in`,
      height: `${simpleMatch[2]}in`
    };
  }

  // Fallback to A4
  console.error(`Unknown page size: ${size}, using A4`);
  return standardSizes.a4;
}

// Generate TOC from headings
function generateToc(html, maxDepth) {
  const headingRegex = /<h([1-6])[^>]*id="([^"]*)"[^>]*>([^<]*)<\/h[1-6]>/gi;
  const toc = [];
  let match;

  while ((match = headingRegex.exec(html)) !== null) {
    const level = parseInt(match[1], 10);
    if (level <= maxDepth) {
      toc.push({
        level,
        id: match[2],
        text: match[3].replace(/<[^>]*>/g, '').trim()
      });
    }
  }

  if (toc.length === 0) return '';

  let tocHtml = '<ul>';
  for (const item of toc) {
    tocHtml += `<li class="toc-h${item.level}"><a href="#${item.id}">${item.text}</a></li>`;
  }
  tocHtml += '</ul>';

  return tocHtml;
}

// Read template
function getTemplate() {
  const templatePath = '/app/templates/obsidian.html';
  if (fs.existsSync(templatePath)) {
    return fs.readFileSync(templatePath, 'utf-8');
  }

  // Fallback minimal template
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>{{title}}</title>
  <style>
    body { font-family: sans-serif; padding: 2em; line-height: 1.6; }
    a { color: #7c3aed; }
    code { background: #f3f4f6; padding: 0.2em 0.4em; border-radius: 3px; }
    pre { background: #f3f4f6; padding: 1em; overflow-x: auto; }
  </style>
</head>
<body>{{{content}}}</body>
</html>`;
}

// Simple template rendering
function render(template, data) {
  let result = template;

  // Handle conditionals {{#if var}}...{{/if}}
  result = result.replace(/\{\{#if\s+(\w+)\}\}([\s\S]*?)\{\{\/if\}\}/g, (match, key, content) => {
    return data[key] ? content : '';
  });

  // Handle raw HTML {{{var}}}
  result = result.replace(/\{\{\{(\w+)\}\}\}/g, (match, key) => {
    return data[key] !== undefined ? data[key] : '';
  });

  // Handle escaped {{var}}
  result = result.replace(/\{\{(\w+)\}\}/g, (match, key) => {
    const val = data[key] !== undefined ? data[key] : '';
    return String(val).replace(/[&<>"']/g, (c) => {
      const entities = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
      return entities[c];
    });
  });

  return result;
}

async function main() {
  try {
    // Read markdown
    const markdown = fs.readFileSync(options.input, 'utf-8');

    // Convert to HTML
    const contentHtml = md.render(markdown);

    // Generate TOC
    const tocHtml = options.toc ? generateToc(contentHtml, options.tocDepth) : '';

    // Parse page size
    const pageSize = parsePageSize(options.pageSize);

    // Render template
    const template = getTemplate();
    const html = render(template, {
      title: options.title,
      content: contentHtml,
      toc: options.toc && tocHtml,
      tocHtml: tocHtml,
      showHeader: true,
      date: new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }),
      pageSize: `${pageSize.width} ${pageSize.height}`,
      margin: options.margin
    });

    // Launch browser
    const browser = await puppeteer.launch({
      headless: 'new',
      executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium-browser',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu'
      ]
    });

    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });

    // Generate PDF
    const pdfOptions = {
      path: options.output,
      format: undefined,
      width: pageSize.width,
      height: pageSize.height,
      margin: {
        top: options.margin,
        right: options.margin,
        bottom: options.margin,
        left: options.margin
      },
      printBackground: true,
      displayHeaderFooter: true,
      headerTemplate: '<div></div>',
      footerTemplate: '<div style="font-size: 10px; text-align: center; width: 100%;"><span class="pageNumber"></span></div>'
    };

    await page.pdf(pdfOptions);
    await browser.close();

    console.log(`PDF created: ${options.output}`);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
