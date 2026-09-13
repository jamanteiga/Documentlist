// ============================================================
// Configuracion de conexion a Supabase
// Rellena estos dos valores con los de tu proyecto:
// Supabase Dashboard > Project Settings > Data API / API Keys
// ============================================================
export const SUPABASE_URL = 'https://wuarkraddnndmgvfnkmm.supabase.co';
export const SUPABASE_ANON_KEY = 'sb_publishable_qF-x44yXSydPBojMk_GOUg_TM34uXFI';

// Nombre visible de la aplicacion (barra de navegacion, PWA)
export const APP_NAME = 'GESDOC';

// Dominio que usan las cuentas de este proyecto Supabase compartido con
// ESTRUCTURA (auth.users no guarda "usuarios", guarda emails; ESTRUCTURA
// crea cuentas con este dominio ficticio). Si en el login se escribe un
// usuario sin "@", se le anade este sufijo automaticamente.
export const USERNAME_DOMAIN_SUFFIX = '@estructura.app.invalid';
