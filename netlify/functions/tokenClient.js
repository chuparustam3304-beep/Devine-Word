let cached = null;
let expiresAt = 0;

async function fetchToken() {
  const clientId = process.env.QF_CLIENT_ID;
  const clientSecret = process.env.QF_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new Error('Missing QF_CLIENT_ID or QF_CLIENT_SECRET environment variables');
  }

  const body = new URLSearchParams();
  body.append('grant_type', 'client_credentials');
  body.append('client_id', clientId);
  body.append('client_secret', clientSecret);

  const res = await fetch('https://prelive-oauth2.quran.foundation/oauth2/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Token request failed: ${res.status} ${text}`);
  }

  const data = await res.json();
  if (!data.access_token) throw new Error('No access_token in token response');

  const now = Date.now();
  const ttl = (data.expires_in || 3600) * 1000;
  // expire 60s early
  expiresAt = now + Math.max(0, ttl - 60000);
  cached = data.access_token;
  return cached;
}

module.exports.getToken = async function getToken() {
  if (cached && Date.now() < expiresAt) return cached;
  return fetchToken();
};
