// Usage: node dev/get-token.js 9876500101 Miner1   (prints a Firebase ID token; needs FIREBASE_WEB_API_KEY in the shell)
const [, , phone, password, dial = '91'] = process.argv;
const key = process.env.FIREBASE_WEB_API_KEY;
if (!phone || !password || !key) {
  console.error('Usage: FIREBASE_WEB_API_KEY=... node dev/get-token.js <national phone> <password> [dialCode=91]');
  process.exit(1);
}
export async function getToken(national, pwd, dialCode = '91') {
  const email = `${dialCode}${national}@phone.mineguardian.app`;
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: pwd, returnSecureToken: true }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error(j?.error?.message || 'sign-in failed');
  return j.idToken;
}

if (import.meta.url === `file:///${process.argv[1].replace(/\\/g, '/')}` || process.argv[1].endsWith('get-token.js')) {
  getToken(phone, password, dial).then((t) => console.log(t)).catch((e) => { console.error(e.message); process.exit(1); });
}
