import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../config.js';

// GESDOC vive en su propio esquema Postgres ("gesdoc"), no en "public",
// para poder compartir el mismo proyecto Supabase que otras apps (p.ej.
// ESTRUCTURA) sin chocar con sus tablas. Por eso se fija aqui el esquema:
// todas las llamadas .from('tabla') de la app apuntan a gesdoc.tabla.
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  db: { schema: 'gesdoc' }
});
