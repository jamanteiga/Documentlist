import { supabase } from './db.js';

// Redirige a index.html si no hay sesion activa. Devuelve la sesion si la hay.
export async function requireSession() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    window.location.href = 'index.html';
    return null;
  }
  return session;
}

// Devuelve el perfil (con rol) del usuario logueado.
export async function getProfile() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data, error } = await supabase
    .from('usuarios_gesdoc')
    .select('*')
    .eq('id', user.id)
    .single();
  if (error) {
    console.error('getProfile', error);
    return null;
  }
  return data;
}

export async function logout() {
  await supabase.auth.signOut();
  window.location.href = 'index.html';
}

// Pinta la barra superior comun a todas las paginas internas.
// activePage: 'dashboard' | 'admin'
export function renderTopbar(profile, activePage) {
  const el = document.getElementById('topbar');
  if (!el) return;
  const adminLink = profile && profile.role === 'ADMIN'
    ? `<a href="admin.html" class="${activePage === 'admin' ? 'active' : ''}">Administracion</a>`
    : '';
  // Mostrar solo el nombre de usuario (antes de la @), no el email completo.
  const displayName = profile
    ? (profile.full_name || (profile.email ? profile.email.split('@')[0] : ''))
    : '';
  el.innerHTML = `
    <div class="brand">GESDOC</div>
    <nav>
      <a href="dashboard.html" class="${activePage === 'dashboard' ? 'active' : ''}">Proyectos</a>
      ${adminLink}
    </nav>
    <div class="user">
      <span>${displayName}</span>
      <span class="badge outline" style="color:#6b7280;border-color:#d1d5db;">${profile ? profile.role : ''}</span>
      <button class="btn small" id="logoutBtn">Salir</button>
    </div>
  `;
  document.getElementById('logoutBtn').addEventListener('click', logout);
}
