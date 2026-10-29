// The owner explicitly supplied these demo-only values for this acceptance check.
// Never print cookies, tokens, successful identity details, or response bodies.
const base = process.env.VENTUREPLUS_API_URL || 'https://ventureplus123.vercel.app/api';
const accounts = [
  ['Admin', 'your-email@example.com', 'Dealatecorp1234'],
  ['Employee', 'employee.demo@estatehub.com', 'EmployeeDemo123!'],
  ['Customer', 'customer.demo@estatehub.com', 'CustomerDemo123!'],
];
for (const [role, email, password] of accounts) {
  try {
    const cookies = new Map();
    const request = async (path, options = {}) => {
      const response = await fetch(`${base}${path}`, {
        ...options,
        redirect: 'error',
        signal: AbortSignal.timeout(20000),
        headers: { 'Content-Type': 'application/json', Cookie: [...cookies].map(([k,v]) => `${k}=${v}`).join('; '), ...options.headers },
      });
      for (const cookie of response.headers.getSetCookie()) {
        const pair = cookie.split(';')[0];
        const split = pair.indexOf('=');
        cookies.set(pair.slice(0, split), pair.slice(split + 1));
      }
      return response;
    };
    const csrf = await request('/auth/csrf');
    if (!csrf.ok) { console.log(JSON.stringify({ role, step: 'csrf', status: csrf.status })); continue; }
    const token = (await csrf.json()).data.token;
    const login = await request('/auth/login', { method: 'POST', headers: { 'X-CSRF-Token': token }, body: JSON.stringify({ email, password }) });
    console.log(JSON.stringify({ role, step: 'login', status: login.status, authenticated: login.ok }));
    if (login.ok) {
      const me = await request('/auth/me');
      const identity = await me.json();
      console.log(JSON.stringify({ role, step: 'identity', status: me.status, serverRole: identity.data?.user?.role }));
      await request('/auth/logout', { method: 'POST', headers: { 'X-CSRF-Token': cookies.get('estatehub_csrf') || token }, body: '{}' });
    }
  } catch (error) { console.log(JSON.stringify({ role, error: error.name, code: error.cause?.code || 'request failed' })); }
}
