const https = require('https');
const fs = require('fs');

const apiKey = 'AIzaSyAhAxhNSn-bAAGWr0J235FXKz7sFHtEeUE';
const output = 'C:/Users/mejohnc/Downloads/unhobble-ai-header-gemini3.png';

const prompt = `Hand-drawn Excalidraw-style editorial illustration on dark background #0a0a0f. A stylized AI robot or digital brain breaking free from chains and constraints, with energy radiating outward in a dramatic 10x burst pattern. The AI figure has a friendly but powerful presence, captured mid-motion as if just unleashed and reaching its full potential. Style: Gestural hand-drawn lines with slightly imperfect quality, sketch-like but professional. Organic Excalidraw whiteboard aesthetic with variable line weight. Composition: Subject fills the frame, minimalist design, dramatic but clean. Colors: Dark charcoal background, white and light gray for line work, bright blue (#4a90d9) for the AI core and energy burst accents, electric cyan (#22d3ee) for secondary glow effects radiating outward. Professional editorial quality suitable for a tech blog header about AI optimization.`;

console.log('Using model: gemini-3-pro-image-preview');
console.log('Output:', output);
console.log('');

const requestBody = JSON.stringify({
  contents: [{ parts: [{ text: prompt }] }],
  generationConfig: { responseModalities: ['image', 'text'] }
});

const req = https.request({
  hostname: 'generativelanguage.googleapis.com',
  path: '/v1beta/models/gemini-3-pro-image-preview:generateContent?key=' + apiKey,
  method: 'POST',
  headers: { 'Content-Type': 'application/json' }
}, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const response = JSON.parse(data);
      if (response.error) {
        console.log('API Error:', response.error.message);
        return;
      }
      const parts = response.candidates?.[0]?.content?.parts || [];
      for (const part of parts) {
        if (part.inlineData?.data) {
          const buf = Buffer.from(part.inlineData.data, 'base64');
          fs.writeFileSync(output, buf);
          console.log('SUCCESS! Image saved to:', output);
          console.log('Size:', Math.round(buf.length / 1024), 'KB');
          return;
        }
        if (part.text) console.log('Model text:', part.text);
      }
      console.log('No image in response. Full response:', JSON.stringify(response, null, 2).substring(0, 500));
    } catch (e) {
      console.log('Error:', e.message);
    }
  });
});
req.on('error', e => console.log('Request error:', e.message));
req.write(requestBody);
req.end();
