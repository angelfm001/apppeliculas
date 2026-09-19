// Helper Supabase REST (sin dependencias, funciona 100% estatico)
function supaClient() {
  const URL = window.SUPABASE_URL;
  const KEY = window.SUPABASE_ANON_KEY;
  if (!URL || URL.includes('TU_PROJECT')) {
    throw new Error('Configura SUPABASE_URL y SUPABASE_ANON_KEY en assets/js/config.js');
  }
  async function req(table, opts = {}) {
    const { method = 'GET', query = '', body = null } = opts;
    const res = await fetch(`${URL}/rest/v1/${table}${query}`, {
      method,
      headers: {
        apikey: KEY,
        Authorization: `Bearer ${KEY}`,
        'Content-Type': 'application/json',
        Prefer: method === 'POST' ? 'return=representation' : undefined,
      },
      body: body ? JSON.stringify(body) : null,
    });
    if (!res.ok) {
      const t = await res.text();
      throw new Error(`Supabase ${res.status}: ${t}`);
    }
    const text = await res.text();
    return text ? JSON.parse(text) : [];
  }
  return {
    list: (t, order = 'id') => req(t, { query: `?select=*&order=${order}.asc` }),
    insert: (t, row) => req(t, { method: 'POST', body: row }),
    update: (t, id, row) => req(t, { method: 'PATCH', query: `?id=eq.${id}`, body: row }),
    remove: (t, id) => req(t, { method: 'DELETE', query: `?id=eq.${id}` }),
    countBy: async (t, col, val) => {
      const rows = await req(t, { query: `?select=id&${col}=eq.${val}` });
      return rows.length;
    },
  };
}
function showMsg(elId, msg, isErr = false) {
  const el = document.getElementById(elId);
  if (!el) return;
  el.textContent = msg;
  el.className = isErr ? 'alert alert-danger' : 'alert alert-success';
  el.style.display = 'block';
  setTimeout(() => { el.style.display = 'none'; }, 4000);
}
function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
