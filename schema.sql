-- ============================================================
-- GESDOC · Control documental multiproyecto
-- Esquema Supabase (PostgreSQL) — ejecutar completo una sola vez
-- Menu: Supabase Dashboard > SQL Editor > New query > pegar y RUN
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- PERFILES / ROLES ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'VIEWER' check (role in ('ADMIN','EDITOR','VIEWER')),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email, 'VIEWER');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- PROYECTOS ----------
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client text,
  po_number text,
  plant_location text,
  project_identification text,
  model text,
  review_days integer not null default 15,
  status text not null default 'ACTIVO' check (status in ('ACTIVO','CERRADO')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.project_members (
  project_id uuid references public.projects(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  primary key (project_id, user_id)
);

-- ---------- CODIGOS DE ESTADO ----------
create table if not exists public.status_codes (
  code text primary key,
  description text not null,
  category text not null default 'OTRO' check (category in ('APROBADO','PENDIENTE','INFORMACION','RECHAZADO','OTRO')),
  color text not null default '#6b7280'
);

insert into public.status_codes (code, description, category, color) values
  ('A','Aprobado','APROBADO','#16a34a'),
  ('B','Aprobado con comentarios menores','APROBADO','#65a30d'),
  ('C','Aprobado con comentarios - reenviar','PENDIENTE','#d97706'),
  ('R','Rechazado - reenviar','RECHAZADO','#dc2626'),
  ('I','Para informacion','INFORMACION','#0284c7'),
  ('PC','Pendiente de aprobacion del cliente','PENDIENTE','#d97706'),
  ('PR','Pendiente de revision interna','PENDIENTE','#ca8a04')
on conflict (code) do nothing;

-- ---------- DOCUMENTOS ----------
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  client_doc_no text,
  vendor_doc_no text,
  title text not null,
  tag_no text,
  model text,
  delivery_date date,
  current_revision integer not null default 0,
  current_status text references public.status_codes(code),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- ---------- TRANSMITTALS ----------
create table if not exists public.transmittals (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  transmittal_no text not null,
  direction text not null check (direction in ('ENVIADO','RECIBIDO')),
  transmittal_date date not null default current_date,
  counterparty text,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (project_id, direction, transmittal_no)
);

create table if not exists public.transmittal_items (
  id uuid primary key default gen_random_uuid(),
  transmittal_id uuid not null references public.transmittals(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete cascade,
  revision integer not null,
  status text references public.status_codes(code)
);

-- ---------- HISTORIAL DE EVENTOS ----------
create table if not exists public.document_events (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  event_type text not null check (event_type in ('ENVIADO','RECIBIDO')),
  revision integer not null,
  event_date date not null default current_date,
  status text references public.status_codes(code),
  transmittal_id uuid references public.transmittals(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

-- ---------- VISTA: ultimo evento por documento (para dashboard/alertas) ----------
create or replace view public.document_status
with (security_invoker = true) as
select
  d.*,
  le.event_type as last_event_type,
  le.event_date as last_event_date,
  le.status as last_event_status
from public.documents d
left join lateral (
  select event_type, event_date, status
  from public.document_events e
  where e.document_id = d.id
  order by e.event_date desc, e.created_at desc
  limit 1
) le on true;

-- ============ ROW LEVEL SECURITY ============
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.status_codes enable row level security;
alter table public.documents enable row level security;
alter table public.transmittals enable row level security;
alter table public.transmittal_items enable row level security;
alter table public.document_events enable row level security;

create or replace function public.is_admin()
returns boolean as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN');
$$ language sql stable security definer;

create or replace function public.is_project_member(pid uuid)
returns boolean as $$
  select public.is_admin() or exists (
    select 1 from public.project_members where project_id = pid and user_id = auth.uid()
  );
$$ language sql stable security definer;

create or replace function public.can_edit()
returns boolean as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN','EDITOR'));
$$ language sql stable security definer;

-- profiles
create policy "profiles_select_own_or_admin" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles_update_admin" on public.profiles for update using (public.is_admin());
create policy "profiles_update_self" on public.profiles for update using (id = auth.uid());

-- Aunque la politica anterior permite a cualquiera actualizar su propia fila
-- (para editar full_name), este trigger impide que alguien se auto-asigne
-- un rol distinto sin ser ADMIN.
create or replace function public.protect_profile_role()
returns trigger as $$
begin
  if not public.is_admin() and new.role is distinct from old.role then
    new.role := old.role;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_protect_profile_role on public.profiles;
create trigger trg_protect_profile_role
  before update on public.profiles
  for each row execute procedure public.protect_profile_role();

-- projects
create policy "projects_select_member" on public.projects for select using (public.is_project_member(id) or created_by = auth.uid());
create policy "projects_insert_editor" on public.projects for insert with check (public.can_edit());
create policy "projects_update_editor_member" on public.projects for update using (public.is_project_member(id) and public.can_edit());
create policy "projects_delete_admin" on public.projects for delete using (public.is_admin());

-- project_members
create policy "members_select" on public.project_members for select using (public.is_project_member(project_id));
create policy "members_admin_all" on public.project_members for all using (public.is_admin());
-- quien crea un proyecto puede anadirse a si mismo como miembro (sin ser ADMIN)
create policy "members_insert_self_on_own_project" on public.project_members for insert with check (
  user_id = auth.uid() and exists (select 1 from public.projects p where p.id = project_id and p.created_by = auth.uid())
);

-- status_codes
create policy "status_select_auth" on public.status_codes for select using (auth.uid() is not null);
create policy "status_admin_write" on public.status_codes for all using (public.is_admin());

-- documents
create policy "documents_select_member" on public.documents for select using (public.is_project_member(project_id));
create policy "documents_insert_editor" on public.documents for insert with check (public.is_project_member(project_id) and public.can_edit());
create policy "documents_update_editor" on public.documents for update using (public.is_project_member(project_id) and public.can_edit());
create policy "documents_delete_admin" on public.documents for delete using (public.is_admin());

-- transmittals
create policy "transmittals_select_member" on public.transmittals for select using (public.is_project_member(project_id));
create policy "transmittals_insert_editor" on public.transmittals for insert with check (public.is_project_member(project_id) and public.can_edit());
create policy "transmittals_update_editor" on public.transmittals for update using (public.is_project_member(project_id) and public.can_edit());
create policy "transmittals_delete_admin" on public.transmittals for delete using (public.is_admin());

-- transmittal_items
create policy "titems_select_member" on public.transmittal_items for select using (
  exists (select 1 from public.transmittals t where t.id = transmittal_id and public.is_project_member(t.project_id))
);
create policy "titems_insert_editor" on public.transmittal_items for insert with check (
  exists (select 1 from public.transmittals t where t.id = transmittal_id and public.is_project_member(t.project_id) and public.can_edit())
);
create policy "titems_delete_admin" on public.transmittal_items for delete using (
  exists (select 1 from public.transmittals t where t.id = transmittal_id and public.is_admin())
);

-- document_events
create policy "events_select_member" on public.document_events for select using (
  exists (select 1 from public.documents d where d.id = document_id and public.is_project_member(d.project_id))
);
create policy "events_insert_editor" on public.document_events for insert with check (
  exists (select 1 from public.documents d where d.id = document_id and public.is_project_member(d.project_id) and public.can_edit())
);
create policy "events_delete_admin" on public.document_events for delete using (
  exists (select 1 from public.documents d where d.id = document_id and public.is_admin())
);

-- ============================================================
-- Tras ejecutar este script, conviértete en ADMIN con:
--   update public.profiles set role = 'ADMIN' where email = 'TU-EMAIL@dominio.com';
-- (Table Editor > profiles, o aquí mismo en SQL Editor)
-- ============================================================
