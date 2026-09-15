Netlify functions for Quran proxy

Setup

- Create a Netlify site from this repo (Site settings → Build & deploy → Continuous Deployment).
- Add environment variables in Site settings → Build & deploy → Environment:
  - `QF_CLIENT_ID` — your Quran Foundation client id (keep secret)
  - `QF_CLIENT_SECRET` — your Quran Foundation client secret (keep secret)

Local testing

- Install Netlify CLI: `npm i -g netlify-cli`
- Run locally: `netlify dev`
- Test endpoint: `curl 'http://localhost:8888/.netlify/functions/verse?reference=2:255'`

If you prefer RapidAPI instead, set `RAPIDAPI_KEY` and `RAPIDAPI_HOST` and modify `netlify/functions/verse.js` to call RapidAPI endpoints.
