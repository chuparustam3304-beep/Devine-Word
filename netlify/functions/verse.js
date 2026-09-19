const { getToken } = require('./tokenClient');

/**
 * verse.js — Netlify function proxy.
 * Behavior:
 * - If RAPIDAPI_KEY is present in env, call RapidAPI host using that key.
 * - Otherwise fall back to Quran Foundation PRELIVE OAuth token flow (getToken()).
 */

exports.handler = async function handler(event) {
  try {
    const params = event.queryStringParameters || {};
    const reference = params.reference; // e.g. "2:255"
    const random = params.random === 'true' || params.random === true;

    // Prefer RapidAPI when key is available
    const rapidKey = process.env.RAPIDAPI_KEY;
    const rapidHost = process.env.RAPIDAPI_HOST;

    if (rapidKey) {
      if (!rapidHost) {
        return { statusCode: 500, body: JSON.stringify({ error: 'RAPIDAPI_HOST not configured' }) };
      }

      // Try a list of candidate paths for RapidAPI providers (some hosts use different routes).
      const headers = {
        'X-RapidAPI-Key': rapidKey,
        'X-RapidAPI-Host': rapidHost,
      };

      const candidates = [];
      if (reference) {
        const encoded = encodeURIComponent(reference);
        candidates.push(`/ayahs/${encoded}`);
        candidates.push(`/verses/by_key/${encoded}`);
        candidates.push(`/verse/by_key/${encoded}`);
        candidates.push(`/ayah/${encoded}`);
        candidates.push(`/quran/verses/by_key/${encoded}`);
        candidates.push(`/quran/verses/${encoded}`);
      } else if (random) {
        candidates.push(`/ayahs/random`);
        candidates.push(`/verses/random`);
        candidates.push(`/random`);
      } else {
        return { statusCode: 400, body: JSON.stringify({ error: 'missing reference or random=true' }) };
      }

      // Try candidates and capture the first 2xx or 4xx (non-404) response.
      let baseData = null;
      for (const p of candidates) {
        const url = `https://${rapidHost}${p}`;
        try {
          console.log('RapidAPI probe:', url);
          const res = await fetch(url, { headers });
          console.log(' -> status', res.status);
          if (res.status === 404) continue;
          const ct = res.headers.get('content-type') || '';
          const text = await res.text();
          console.log(' -> body preview:', (text || '').slice(0, 1000));
          const parsed = ct.includes('application/json') ? JSON.parse(text) : null;
          if (res.ok && parsed) {
            baseData = parsed;
            break;
          }
          // keep first non-404 response if JSON
          if (!baseData && parsed) baseData = parsed;
        } catch (err) {
          console.log('RapidAPI probe error', url, err && err.message);
          // ignore and continue
        }
      }

      // If we found something, attempt to enrich it with Arabic text, translations, and audio
      const normalized = { reference: reference || null };
      // initialize translation placeholders so enrichment code can safely assign to them
      normalized.translations = { english: null, urdu: null };
      normalized.surah_name = null;
      normalized.arabic = null;
      normalized.audio_url = null;
      if (baseData) {
        // helper to dig common places
        const get = (obj, ...keys) => {
          let cur = obj;
          for (const k of keys) {
            if (!cur) return null;
            cur = cur[k];
          }
          return cur;
        };

        // Common shapes: { verse: {...} }, { data: {...} }, or root object
        const root = baseData.data || baseData.verse || baseData;

        // If basic fields are missing, try targeted enrichment using id or reference
        async function tryEnrich(obj) {
          const id = obj.id || obj.verse_id || obj.verseId || null;
          const ref = reference || obj.verse_key || obj.verseKey || obj.verseKeyString || null;
          const enrichCandidates = [];
          if (id) {
            enrichCandidates.push(`/verses/${id}`);
            enrichCandidates.push(`/verses/${id}/translations`);
            enrichCandidates.push(`/verses/${id}/audio`);
            enrichCandidates.push(`/verses/${id}/text`);
          }
          if (ref) {
            enrichCandidates.push(`/ayahs/${encodeURIComponent(ref)}`);
            enrichCandidates.push(`/verses/by_key/${encodeURIComponent(ref)}`);
            enrichCandidates.push(`/quran/verses/by_key/${encodeURIComponent(ref)}`);
          }

          for (const p of enrichCandidates) {
            const url = `https://${rapidHost}${p}`;
            try {
                console.log('RapidAPI enrich attempt:', url);
                const res = await fetch(url, { headers });
                console.log(' -> status', res.status);
                if (!res.ok) continue;
                const ct = res.headers.get('content-type') || '';
                const text = await res.text();
                console.log(' -> enrich body preview:', (text || '').slice(0, 1000));
                const parsed = ct.includes('application/json') ? JSON.parse(text) : null;
                if (!parsed) continue;

                // merge likely fields
                const r = parsed.data || parsed.verse || parsed || {};
                if (!normalized.surah_name) normalized.surah_name = r.chapter?.name || r.surah_name || r.surah || normalized.surah_name;
                if (!normalized.arabic) normalized.arabic = r.text_uthmani || r.text || r.arabic_text || r.ayah?.text || normalized.arabic;
                if (r.translations) {
                  const t = r.translations;
                  if (Array.isArray(t)) {
                    if (!normalized.translations.english && t[0]) normalized.translations.english = t[0].text || normalized.translations.english;
                  } else if (typeof t === 'object') {
                    normalized.translations.english = normalized.translations.english || t.en || t['english'] || t['en_us'] || normalized.translations.english;
                    normalized.translations.urdu = normalized.translations.urdu || t.ur || t['urdu'] || normalized.translations.urdu;
                  }
                }
                if (!normalized.audio_url) normalized.audio_url = r.audio?.url || r.audio_url || r.audio_url_64 || normalized.audio_url;
                // stop early if we have core fields
                if (normalized.arabic && (normalized.translations.english || normalized.translations.urdu)) return;
              } catch (e) {
                console.log('RapidAPI enrich error', url, e && e.message);
                // ignore errors and continue
              }
          }
        }
        // perform enrichment synchronously (await)
        await tryEnrich(root);

        // If enrichment still lacks Arabic/translations, try public alquran.cloud as a fallback
        if ((!normalized.arabic || !(normalized.translations.english || normalized.translations.urdu)) && normalized.reference) {
          // alquran.cloud expects the reference with colon (e.g. 2:255). Don't percent-encode the colon.
          const refRaw = normalized.reference;
          const publicFallbacks = [
            { url: `https://api.alquran.cloud/v1/ayah/${refRaw}/quran-uthmani`, type: 'arabic' },
            { url: `https://api.alquran.cloud/v1/ayah/${refRaw}/en.sahih`, type: 'english' },
            { url: `https://api.alquran.cloud/v1/ayah/${refRaw}/ur.jalandhry`, type: 'urdu' },
          ];

          for (const f of publicFallbacks) {
            try {
              console.log('Public fallback probe:', f.url);
              const res = await fetch(f.url);
              if (!res.ok) {
                console.log(' -> fallback status', res.status);
                continue;
              }
              const data = await res.json();
              const d = data && data.data ? data.data : data;
              if (f.type === 'arabic' && d && d.text) normalized.arabic = normalized.arabic || d.text;
              if (f.type === 'english' && d && d.text) normalized.translations.english = normalized.translations.english || d.text;
              if (f.type === 'urdu' && d && d.text) normalized.translations.urdu = normalized.translations.urdu || d.text;
              // attempt to capture surah name and any audio URL from public fallback
              if (d && d.surah) {
                normalized.surah_name = normalized.surah_name || d.surah.englishName || d.surah.name || null;
              }
              if (!normalized.audio_url && d) {
                // api.alquran.cloud sometimes contains audio info; try common fields safely
                if (typeof d.audio === 'string') normalized.audio_url = d.audio;
                else if (d.audio && typeof d.audio === 'object') {
                  normalized.audio_url = normalized.audio_url || d.audio.primary || d.audio.url || null;
                }
              }
              // continue probing all fallbacks so we gather arabic + both translations
            } catch (e) {
              console.log('Public fallback error', f.url, e && e.message);
            }
          }
        }

        // reference
        normalized.reference = normalized.reference || root.verse_key || root.verseKey || get(root, 'id') || normalized.reference;

        // surah name (don't overwrite value gathered from fallbacks)
        normalized.surah_name = normalized.surah_name || get(root, 'chapter', 'name') || get(root, 'surah_name') || root.surah || null;

        // arabic text candidates (preserve previously-enriched arabic)
        normalized.arabic = normalized.arabic || get(root, 'text_uthmani') || get(root, 'text') || get(root, 'arabic_text') || get(root, 'ayah', 'text') || null;

        // translations: try arrays or translation objects — merge into any existing values
        const translations = normalized.translations || { english: null, urdu: null };
        translations.english = translations.english || get(root, 'translation', 'text') || get(root, 'translations', 0, 'text') || get(root, 'translation_en') || null;
        translations.urdu = translations.urdu || get(root, 'translations', 0, 'text') || get(root, 'translation_ur') || null;
        normalized.translations = translations;

        // audio heuristics (preserve any previously-enriched audio)
        normalized.audio_url = normalized.audio_url || get(root, 'audio', 'url') || get(root, 'audio_url') || get(root, 'audio', 0, 'audio_url') || null;
      }

      return { statusCode: 200, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(normalized) };
    }

    // Fallback: Quran Foundation PRELIVE OAuth flow
    const token = await getToken();
    const headers = { Authorization: `Bearer ${token}` };

    let url;
    if (reference) {
      url = `https://apis-prelive.quran.foundation/ayahs/${encodeURIComponent(reference)}`;
    } else if (random) {
      url = `https://apis-prelive.quran.foundation/ayahs/random`;
    } else {
      return { statusCode: 400, body: JSON.stringify({ error: 'missing reference or random=true' }) };
    }

    const res = await fetch(url, { headers });
    const body = await res.text();
    const contentType = res.headers.get('content-type') || 'application/json';

    return {
      statusCode: res.status,
      headers: { 'Content-Type': contentType },
      body,
    };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
