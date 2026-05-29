const https = require('https');
const fs = require('fs');

const apiKey = 'AIzaSyAhAxhNSn-bAAGWr0J235FXKz7sFHtEeUE';
const output = process.argv[2] || 'C:/Users/mejohnc/Downloads/unhobble-ai-header.png';
const promptArg = process.argv[3] || `Hand-drawn Excalidraw-style editorial illustration on dark background #0a0a0f. A stylized AI robot or digital brain breaking free from chains and constraints, with energy radiating outward in a dramatic 10x burst pattern. The AI figure has a friendly but powerful presence, captured mid-motion as if just unleashed and reaching its full potential. Style: Gestural hand-drawn lines with slightly imperfect quality, sketch-like but professional. Organic Excalidraw whiteboard aesthetic with variable line weight. Composition: Subject fills the frame, minimalist design, dramatic but clean. Colors: Dark charcoal background, white and light gray for line work, bright blue (#4a90d9) for the AI core and energy burst accents, electric cyan (#22d3ee) for secondary glow effects radiating outward. Professional editorial quality suitable for a tech blog header about AI optimization.`;

console.log('Using model: gemini-2.0-flash-exp-image-generation');
console.log('Output:', output);
console.log('');

const requestBody = JSON.stringify({
  contents: [{
    parts: [{ text: promptArg }]
  }],
  generationConfig: {
    responseModalities: ["image", "text"]
  }
});

const options = {
  hostname: 'generativelanguage.googleapis.com',
  path: `/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent?key=${apiKey}`,
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
        console.log('API Error:', response.error.message);
        process.exit(1);
      }

      if (response.candidates && response.candidates[0] && response.candidates[0].content) {
        const parts = response.candidates[0].content.parts || [];

        for (const part of parts) {
          if (part.inlineData && part.inlineData.mimeType && part.inlineData.data) {
            const imageBuffer = Buffer.from(part.inlineData.data, 'base64');
            fs.writeFileSync(output, imageBuffer);
            console.log('SUCCESS! Image saved to:', output);
            console.log('Size:', Math.round(imageBuffer.length / 1024), 'KB');
            return;
          }
          if (part.text) {
            console.log('Model text:', part.text);
          }
        }
        console.log('No image data found in response parts');
        console.log('Parts received:', parts.map(p => Object.keys(p)));
      } else {
        console.log('Unexpected response structure');
        console.log(JSON.stringify(response, null, 2).substring(0, 1500));
      }
    } catch (e) {
      console.log('JSON parse error:', e.message);
      console.log('Raw response:', data.substring(0, 500));
    }
  });
});

req.on('error', (e) => {
  console.log('Request failed:', e.message);
  process.exit(1);
});

req.write(requestBody);
req.end();
