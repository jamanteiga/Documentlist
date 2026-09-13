-- ============================================================
-- MIGRACION: renombrar gesdoc.profiles -> gesdoc.usuarios_gesdoc
-- y quitar las cuentas prestadas de ESTRUCTURA.
-- Ejecutar UNA VEZ en SQL Editor sobre tu base de datos actual
-- (no hace falta volver a correr schema.sql entero).
-- ============================================================

-- 1) Renombrar la tabla (conserva datos, FKs, RLS y triggers ya asociados)
alter table gesdoc.profiles rename to usuarios_gesdoc;

-- 2) Quitar las cuentas de ESTRUCTURA que usaste solo para probar
delete from gesdoc.usuarios_gesdoc
where email in ('jamanteiga@estructura.app.invalid','jmanteiga@estructura.app.invalid');

-- 3) Recrear las funciones para que apunten al nuevo nombre de tabla
--    (los triggers ya definidos siguen usando estas mismas funciones,
--    no hace falta volver a crearlos)
create or replace function gesdoc.handle_new_user()
returns trigger as $$
begin
  insert into gesdoc.usuarios_gesdoc (id, email, role)
  values (new.id, new.email, 'VIEWER')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create or replace function gesdoc.is_admin()
returns boolean as $$
  select exists (select 1 from gesdoc.usuarios_gesdoc where id = auth.uid() and role = 'ADMIN');
$$ language sql stable security definer;

create or replace function gesdoc.can_edit()
returns boolean as $$
  select exists (select 1 from gesdoc.usuarios_gesdoc where id = auth.uid() and role in ('ADMIN','EDITOR'));
$$ language sql stable security definer;

create or replace function gesdoc.protect_profile_role()
returns trigger as $$
begin
  if auth.uid() is not null and not gesdoc.is_admin() and new.role is distinct from old.role then
    new.role := old.role;
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- 4) Comprobacion final: deberia salir vacio (0 filas)
select * from gesdoc.usuarios_gesdoc;
