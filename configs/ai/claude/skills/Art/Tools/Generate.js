#!/usr/bin/env node
/**
 * Kai Art Generator - Node.js version
 * Generates images using Google Gemini's Imagen model
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// Parse arguments
const args = process.argv.slice(2);
const getArg = (name) => {
  const idx = args.indexOf(name);
  return idx !== -1 ? args[idx + 1] : null;
};

const prompt = getArg('--prompt');
const output = getArg('--output') || path.join(process.env.HOME || process.env.USERPROFILE, 'Downloads', 'generated.png');
const aspectRatio = getArg('--aspect-ratio') || '16:9';

if (!prompt) {
  console.error('Usage: node Generate.js --prompt "your prompt" [--output path.png] [--aspect-ratio 16:9]');
  process.exit(1);
}

// Load API key from .env
const envPath = path.join(process.env.HOME || process.env.USERPROFILE, '.claude', '.env');
let apiKey = process.env.GOOGLE_API_KEY;

if (!apiKey && fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf8');
  const match = envContent.match(/^GOOGLE_API_KEY=(.+)$/m);
  if (match) apiKey = match[1].trim();
}

if (!apiKey) {
  console.error('Error: GOOGLE_API_KEY not found in environment or ~/.claude/.env');
  process.exit(1);
}

console.log('Generating image with Gemini Imagen...');
console.log('Prompt:', prompt.substring(0, 100) + (prompt.length > 100 ? '...' : ''));
console.log('Output:', output);

// Use Gemini's image generation endpoint
const requestBody = JSON.stringify({
  instances: [{ prompt }],
  parameters: {
    sampleCount: 1,
    aspectRatio: aspectRatio.replace(':', ':')
  }
});

const options = {
  hostname: 'generativelanguage.googleapis.com',
  path: `/v1beta/models/imagen-3.0-generate-002:predict?key=${apiKey}`,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(requestBody)
  }
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const response = JSON.parse(data);

      if (response.error) {
        console.error('API Error:', response.error.message);
        process.exit(1);
      }

      if (response.predictions && response.predictions[0]) {
        const imageData = response.predictions[0].bytesBase64Encoded;
        const outputDir = path.dirname(output);
        if (!fs.existsSync(outputDir)) {
          fs.mkdirSync(outputDir, { recursive: true });
        }
        fs.writeFileSync(output, Buffer.from(imageData, 'base64'));
        console.log('Image saved to:', output);
      } else {
        console.error('No image in response:', JSON.stringify(response, null, 2));
        process.exit(1);
      }
    } catch (e) {
      console.error('Failed to parse response:', e.message);
      console.error('Raw response:', data.substring(0, 500));
      process.exit(1);
    }
  });
});

req.on('error', (e) => {
  console.error('Request failed:', e.message);
  process.exit(1);
});

req.write(requestBody);
req.end();
