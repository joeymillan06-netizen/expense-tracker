const cloudConfig = window.OURS_CONFIG || {};
const cloudReady = Boolean(cloudConfig.supabaseUrl && cloudConfig.supabaseAnonKey);
let cloudTimer;

async function supabaseRequest(path, options = {}) {
  if (!cloudReady) return null;
  const response = await fetch(`${cloudConfig.supabaseUrl}${path}`, {
    ...options,
    headers: {
      apikey: cloudConfig.supabaseAnonKey,
      Authorization: `Bearer ${localStorage.getItem('ours-access-token') || cloudConfig.supabaseAnonKey}`,
      'Content-Type': 'application/json',
      Prefer: options.prefer || 'return=representation',
      ...(options.headers || {})
    }
  });
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).message || 'Cloud request failed');
  return response.status === 204 ? null : response.json();
}

async function signInWithSupabase(email, password) {
  if (!cloudReady) throw new Error('Add your Supabase URL, anon key and workspace ID in config.js.');
  const response = await fetch(`${cloudConfig.supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: 'POST', headers: { apikey: cloudConfig.supabaseAnonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  const session = await response.json();
  if (!response.ok) throw new Error(session.error_description || session.msg || 'Sign in failed');
  localStorage.setItem('ours-access-token', session.access_token);
  localStorage.setItem('ours-refresh-token', session.refresh_token);
  return session.user;
}

async function loadCloudWorkspace(displayName = 'Member') {
  if (!cloudConfig.workspaceId) {
    let memberships = await supabaseRequest('/rest/v1/workspace_members?select=workspace_id&limit=1');
    if (!memberships?.length) {
      const created = await supabaseRequest('/rest/v1/rpc/bootstrap_finance_workspace', {
        method: 'POST', body: JSON.stringify({ member_name: displayName })
      });
      cloudConfig.workspaceId = typeof created === 'string' ? created : created?.workspace_id || created;
    } else cloudConfig.workspaceId = memberships[0].workspace_id;
  }
  const rows = await supabaseRequest(`/rest/v1/workspace_state?workspace_id=eq.${cloudConfig.workspaceId}&select=payload&limit=1`);
  return rows?.[0]?.payload || null;
}

async function persistCloudWorkspace(payload) {
  const currentRows = await supabaseRequest(`/rest/v1/workspace_state?workspace_id=eq.${cloudConfig.workspaceId}&select=payload&limit=1`);
  const merged = window.mergeWorkspaceData ? window.mergeWorkspaceData(payload, currentRows?.[0]?.payload || {}) : payload;
  if (typeof data !== 'undefined') data = merged;
  localStorage.setItem('ours-data-v2', JSON.stringify(merged));
  return supabaseRequest('/rest/v1/workspace_state?on_conflict=workspace_id', {
    method: 'POST', prefer: 'resolution=merge-duplicates,return=minimal',
    body: JSON.stringify({ workspace_id: cloudConfig.workspaceId, payload: merged, updated_at: new Date().toISOString() })
  });
}

function queueCloudSync() {
  if (!cloudReady || !localStorage.getItem('ours-access-token')) return;
  clearTimeout(cloudTimer);
  cloudTimer = setTimeout(() => persistCloudWorkspace(data).catch(console.error), 500);
}

window.cloudReady = cloudReady;
window.signInWithSupabase = signInWithSupabase;
window.loadCloudWorkspace = loadCloudWorkspace;
window.queueCloudSync = queueCloudSync;
