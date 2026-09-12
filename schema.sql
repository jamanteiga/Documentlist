-- ============================================================
-- GESDOC · Control documental multiproyecto
-- Esquema Supabase (PostgreSQL) — ejecutar completo una sola vez
-- Menu: Supabase Dashboard > SQL Editor > New query > pegar y RUN
--
-- IMPORTANTE: este script crea todo dentro de su PROPIO esquema
-- Postgres llamado "gesdoc" (no "public"), para poder convivir en el
-- MISMO proyecto Supabase que ya usan otras apps (p.ej. ESTRUCTURA)
-- sin chocar con sus tablas/funciones (profiles, is_admin, etc.).
-- ============================================================

create extension if not exists "pgcrypto";
create schema if not exists gesdoc;

-- ---------- PERFILES / ROLES ----------
create table if not exists gesdoc.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'VIEWER' check (role in ('ADMIN','EDITOR','VIEWER')),
  created_at timestamptz not null default now()
);

create or replace function gesdoc.handle_new_user()
returns trigger as $$
begin
  insert into gesdoc.profiles (id, email, role)
  values (new.id, new.email, 'VIEWER')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

-- Nombre de trigger UNICO (con sufijo _gesdoc) para no tocar/pisar
-- ningun trigger que ya exista en auth.users de otra app del mismo proyecto.
drop trigger if exists on_auth_user_created_gesdoc on auth.users;
create trigger on_auth_user_created_gesdoc
  after insert on auth.users
  for each row execute procedure gesdoc.handle_new_user();

-- El trigger de arriba solo dispara con usuarios NUEVOS. Como este proyecto
-- ya tenia usuarios (los de ESTRUCTURA), esto les crea su perfil de GESDOC
-- (rol VIEWER por defecto) para que puedan entrar con la misma cuenta.
insert into gesdoc.profiles (id, email, role)
select id, email, 'VIEWER' from auth.users
on conflict (id) do nothing;

-- ---------- PROYECTOS ----------
create table if not exists gesdoc.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client text,
  po_number text,
  plant_location text,
  project_identification text,
  model text,
  review_days integer not null default 15,
  status text not null default 'ACTIVO' check (status in ('ACTIVO','CERRADO')),
  created_by uuid references gesdoc.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists gesdoc.project_members (
  project_id uuid references gesdoc.projects(id) on delete cascade,
  user_id uuid references gesdoc.profiles(id) on delete cascade,
  primary key (project_id, user_id)
);

-- ---------- CODIGOS DE ESTADO ----------
create table if not exists gesdoc.status_codes (
  code text primary key,
  description text not null,
  category text not null default 'OTRO' check (category in ('APROBADO','PENDIENTE','INFORMACION','RECHAZADO','OTRO')),
  color text not null default '#6b7280'
);

insert into gesdoc.status_codes (code, description, category, color) values
  ('A','Aprobado','APROBADO','#16a34a'),
  ('B','Aprobado con comentarios menores','APROBADO','#65a30d'),
  ('C','Aprobado con comentarios - reenviar','PENDIENTE','#d97706'),
  ('R','Rechazado - reenviar','RECHAZADO','#dc2626'),
  ('I','Para informacion','INFORMACION','#0284c7'),
  ('PC','Pendiente de aprobacion del cliente','PENDIENTE','#d97706'),
  ('PR','Pendiente de revision interna','PENDIENTE','#ca8a04')
on conflict (code) do nothing;

-- ---------- DOCUMENTOS ----------
create table if not exists gesdoc.documents (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references gesdoc.projects(id) on delete cascade,
  client_doc_no text,
  vendor_doc_no text,
  title text not null,
  tag_no text,
  model text,
  delivery_date date,
  current_revision integer not null default 0,
  current_status text references gesdoc.status_codes(code),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- ---------- TRANSMITTALS ----------
create table if not exists gesdoc.transmittals (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references gesdoc.projects(id) on delete cascade,
  transmittal_no text not null,
  direction text not null check (direction in ('ENVIADO','RECIBIDO')),
  transmittal_date date not null default current_date,
  counterparty text,
  notes text,
  created_by uuid references gesdoc.profiles(id),
  created_at timestamptz not null default now(),
  unique (project_id, direction, transmittal_no)
);

create table if not exists gesdoc.transmittal_items (
  id uuid primary key default gen_random_uuid(),
  transmittal_id uuid not null references gesdoc.transmittals(id) on delete cascade,
  document_id uuid not null references gesdoc.documents(id) on delete cascade,
  revision integer not null,
  status text references gesdoc.status_codes(code)
);

-- ---------- HISTORIAL DE EVENTOS ----------
create table if not exists gesdoc.document_events (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references gesdoc.documents(id) on delete cascade,
  event_type text not null check (event_type in ('ENVIADO','RECIBIDO')),
  revision integer not null,
  event_date date not null default current_date,
  status text references gesdoc.status_codes(code),
  transmittal_id uuid references gesdoc.transmittals(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

-- ---------- VISTA: ultimo evento por documento (para dashboard/alertas) ----------
create or replace view gesdoc.document_status
with (security_invoker = true) as
select
  d.*,
  le.event_type as last_event_type,
  le.event_date as last_event_date,
  le.status as last_event_status
from gesdoc.documents d
left join lateral (
  select event_type, event_date, status
  from gesdoc.document_events e
  where e.document_id = d.id
  order by e.event_date desc, e.created_at desc
  limit 1
) le on true;

-- ============ ROW LEVEL SECURITY ============
alter table gesdoc.profiles enable row level security;
alter table gesdoc.projects enable row level security;
alter table gesdoc.project_members enable row level security;
alter table gesdoc.status_codes enable row level security;
alter table gesdoc.documents enable row level security;
alter table gesdoc.transmittals enable row level security;
alter table gesdoc.transmittal_items enable row level security;
alter table gesdoc.document_events enable row level security;

create or replace function gesdoc.is_admin()
returns boolean as $$
  select exists (select 1 from gesdoc.profiles where id = auth.uid() and role = 'ADMIN');
$$ language sql stable security definer;

create or replace function gesdoc.is_project_member(pid uuid)
returns boolean as $$
  select gesdoc.is_admin() or exists (
    select 1 from gesdoc.project_members where project_id = pid and user_id = auth.uid()
  );
$$ language sql stable security definer;

create or replace function gesdoc.can_edit()
returns boolean as $$
  select exists (select 1 from gesdoc.profiles where id = auth.uid() and role in ('ADMIN','EDITOR'));
$$ language sql stable security definer;

-- profiles
create policy "profiles_select_own_or_admin" on gesdoc.profiles for select using (id = auth.uid() or gesdoc.is_admin());
create policy "profiles_update_admin" on gesdoc.profiles for update using (gesdoc.is_admin());
create policy "profiles_update_self" on gesdoc.profiles for update using (id = auth.uid());

-- Aunque la politica anterior permite a cualquiera actualizar su propia fila
-- (para editar full_name), este trigger impide que alguien se auto-asigne
-- un rol distinto sin ser ADMIN.
create or replace function gesdoc.protect_profile_role()
returns trigger as $$
begin
  if not gesdoc.is_admin() and new.role is distinct from old.role then
    new.role := old.role;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_protect_profile_role on gesdoc.profiles;
create trigger trg_protect_profile_role
  before update on gesdoc.profiles
  for each row execute procedure gesdoc.protect_profile_role();

-- projects
create policy "projects_select_member" on gesdoc.projects for select using (gesdoc.is_project_member(id) or created_by = auth.uid());
create policy "projects_insert_editor" on gesdoc.projects for insert with check (gesdoc.can_edit());
create policy "projects_update_editor_member" on gesdoc.projects for update using (gesdoc.is_project_member(id) and gesdoc.can_edit());
create policy "projects_delete_admin" on gesdoc.projects for delete using (gesdoc.is_admin());

-- project_members
create policy "members_select" on gesdoc.project_members for select using (gesdoc.is_project_member(project_id));
create policy "members_admin_all" on gesdoc.project_members for all using (gesdoc.is_admin());
-- quien crea un proyecto puede anadirse a si mismo como miembro (sin ser ADMIN)
create policy "members_insert_self_on_own_project" on gesdoc.project_members for insert with check (
  user_id = auth.uid() and exists (select 1 from gesdoc.projects p where p.id = project_id and p.created_by = auth.uid())
);

-- status_codes
create policy "status_select_auth" on gesdoc.status_codes for select using (auth.uid() is not null);
create policy "status_admin_write" on gesdoc.status_codes for all using (gesdoc.is_admin());

-- documents
create policy "documents_select_member" on gesdoc.documents for select using (gesdoc.is_project_member(project_id));
create policy "documents_insert_editor" on gesdoc.documents for insert with check (gesdoc.is_project_member(project_id) and gesdoc.can_edit());
create policy "documents_update_editor" on gesdoc.documents for update using (gesdoc.is_project_member(project_id) and gesdoc.can_edit());
create policy "documents_delete_admin" on gesdoc.documents for delete using (gesdoc.is_admin());

-- transmittals
create policy "transmittals_select_member" on gesdoc.transmittals for select using (gesdoc.is_project_member(project_id));
create policy "transmittals_insert_editor" on gesdoc.transmittals for insert with check (gesdoc.is_project_member(project_id) and gesdoc.can_edit());
create policy "transmittals_update_editor" on gesdoc.transmittals for update using (gesdoc.is_project_member(project_id) and gesdoc.can_edit());
create policy "transmittals_delete_admin" on gesdoc.transmittals for delete using (gesdoc.is_admin());

-- transmittal_items
create policy "titems_select_member" on gesdoc.transmittal_items for select using (
  exists (select 1 from gesdoc.transmittals t where t.id = transmittal_id and gesdoc.is_project_member(t.project_id))
);
create policy "titems_insert_editor" on gesdoc.transmittal_items for insert with check (
  exists (select 1 from gesdoc.transmittals t where t.id = transmittal_id and gesdoc.is_project_member(t.project_id) and gesdoc.can_edit())
);
create policy "titems_delete_admin" on gesdoc.transmittal_items for delete using (
  exists (select 1 from gesdoc.transmittals t where t.id = transmittal_id and gesdoc.is_admin())
);

-- document_events
create policy "events_select_member" on gesdoc.document_events for select using (
  exists (select 1 from gesdoc.documents d where d.id = document_id and gesdoc.is_project_member(d.project_id))
);
create policy "events_insert_editor" on gesdoc.document_events for insert with check (
  exists (select 1 from gesdoc.documents d where d.id = document_id and gesdoc.is_project_member(d.project_id) and gesdoc.can_edit())
);
create policy "events_delete_admin" on gesdoc.document_events for delete using (
  exists (select 1 from gesdoc.documents d where d.id = document_id and gesdoc.is_admin())
);

-- ============ PERMISOS DE ESQUEMA ============
-- Necesario porque "gesdoc" no es el esquema "public": sin esto, aunque las
-- politicas RLS sean correctas, PostgREST no dejaria ni empezar a consultar.
grant usage on schema gesdoc to anon, authenticated, service_role;
grant all on all tables in schema gesdoc to anon, authenticated, service_role;
grant all on all sequences in schema gesdoc to anon, authenticated, service_role;
grant all on all routines in schema gesdoc to anon, authenticated, service_role;
alter default privileges in schema gesdoc grant all on tables to anon, authenticated, service_role;
alter default privileges in schema gesdoc grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema gesdoc grant all on routines to anon, authenticated, service_role;

-- ============================================================
-- PASOS QUE FALTAN TRAS EJECUTAR ESTE SCRIPT (fuera del SQL Editor):
--
-- 1) Project Settings > Data API > "Exposed schemas" > anade "gesdoc"
--    a la lista (junto a "public") y guarda. Sin este paso la app no
--    podra leer/escribir nada aunque el script se haya ejecutado bien.
--
-- 2) Conviertete en ADMIN (SQL Editor, nueva query):
--    update gesdoc.profiles set role = 'ADMIN' where email = 'TU-EMAIL@dominio.com';
--    (tu fila aparece automaticamente en cuanto inicias sesion una vez
--    en la app, o en cuanto se crea tu usuario en Authentication > Users)
-- ============================================================
