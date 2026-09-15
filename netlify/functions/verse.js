const { getToken } = require('./tokenClient');

exports.handler = async function handler(event) {
  try {
    const params = event.queryStringParameters || {};
    const reference = params.reference; // expect e.g. "2:255" or "2:255-2:257"
    const random = params.random === 'true' || params.random === true;

    const token = await getToken();
    const headers = { Authorization: `Bearer ${token}` };

    let url;
    if (reference) {
      // call Quran Foundation API for a specific ayah
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
