const { getToken } = require('./tokenClient');

exports.handler = async function handler(event) {
  try {
    const token = await getToken();
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ access_token: token }),
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message }),
    };
  }
};
