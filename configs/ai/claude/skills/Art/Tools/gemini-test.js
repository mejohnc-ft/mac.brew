const https = require('https');
const fs = require('fs');

const apiKey = 'AIzaSyAhAxhNSn-bAAGWr0J235FXKz7sFHtEeUE';
const output = process.argv[2] || 'C:/Users/mejohnc/Downloads/unhobble-ai-header.png';

const prompt = `Hand-drawn Excalidraw-style editorial illustration on dark background. A stylized AI robot breaking free from chains, with energy radiating outward in a 10x burst pattern. Friendly but powerful presence, mid-motion as if just unleashed. Gestural hand-drawn lines, slightly imperfect, sketch-like but professional. Dark background, white line work, blue accents for the AI and energy burst, cyan for secondary glow. Minimalist, dramatic, clean composition.`;

// List available models first
console.log('Checking available models...\n');

https.get(
  `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`,
  (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      const response = JSON.parse(data);
      if (response.models) {
        const models = response.models.map(m => ({
          name: m.name,
          methods: m.supportedGenerationMethods || []
        }));

        console.log('All models with image capabilities:');
        models.forEach(m => {
          if (m.methods.some(method => method.toLowerCase().includes('image'))) {
            console.log(`  ${m.name}: ${m.methods.join(', ')}`);
          }
        });

        console.log('\nAll available models:');
        models.slice(0, 15).forEach(m => {
          console.log(`  ${m.name}`);
        });
        if (models.length > 15) console.log(`  ... and ${models.length - 15} more`);
      } else {
        console.log('Response:', JSON.stringify(response, null, 2));
      }
    });
  }
);
