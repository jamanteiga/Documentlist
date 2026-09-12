# GESDOC — Control documental multiproyecto

App para llevar el control de la documentación (vendor document index / document list) de varios proyectos a la vez: listado de documentos por proyecto, historial de revisiones, generación de transmittals y alertas de documentos pendientes o retrasados.

Arquitectura: HTML/CSS/JS puro (sin build) + Supabase (base de datos, autenticación y permisos por rol) + despliegue en GitHub Pages. Mismo esquema que ESTRUCTURA/REGHOR.

Roles: **ADMIN** (todo, incluye borrar y administración), **EDITOR** (crear/editar documentos y transmittals), **VIEWER** (solo lectura).

---

## 1. Crear el proyecto en Supabase

1. Entra en [supabase.com](https://supabase.com) → **New project**.
2. Elige nombre, contraseña de base de datos y región (Europe recomendable). Espera a que se aprovisione (~2 min).
3. Menú lateral → **SQL Editor** → **New query**.
4. Pega el contenido completo de `schema.sql` (incluido en esta carpeta) y pulsa **Run**.
   - Esto crea las tablas, la vista de estado y las políticas de seguridad (RLS), y precarga los códigos de estado habituales (A, B, C, R, I, PC, PR).

## 2. Conectar la app a tu proyecto

1. Menú lateral → **Project Settings** (icono de engranaje) → **Data API**.
2. Copia la **Project URL** y la clave **anon public** (en "API Keys").
3. Abre `config.js` en esta carpeta y sustituye:
   ```js
   export const SUPABASE_URL = 'https://TU-PROYECTO.supabase.co';
   export const SUPABASE_ANON_KEY = 'TU-CLAVE-ANON-PUBLICA';
   ```

## 3. Crear el primer usuario (ADMIN)

1. Menú lateral → **Authentication** → **Users** → **Add user** → **Create new user**.
   - Rellena email y contraseña, y marca "Auto Confirm User" para que pueda entrar sin verificar el email.
2. Menú lateral → **Table Editor** → tabla `profiles` → busca la fila con tu email → columna `role` → cámbiala a `ADMIN`.
   - Alternativa por SQL (SQL Editor): `update public.profiles set role = 'ADMIN' where email = 'tu-email@dominio.com';`
3. Los siguientes usuarios los das de alta igual (Authentication → Users → Add user); entrarán con rol `VIEWER` por defecto y tú les subes el rol desde la pestaña **Administración** de la app.

> Nota: por defecto Supabase pide confirmar el email al darse de alta. Como los usuarios los crea el administrador manualmente (no hay registro público en la app), marca siempre "Auto Confirm User" al crearlos y no hace falta tocar nada más.

## 4. Publicar en GitHub Pages

1. Crea un repositorio nuevo en GitHub (puede ser privado), por ejemplo `GESDOC`.
2. Sube todo el contenido de esta carpeta a la raíz del repositorio (`schema.sql` y `README.md` pueden quedarse o borrarse, no afectan a la app).
3. En el repositorio: **Settings** → **Pages** → en "Build and deployment" → **Source: Deploy from a branch** → **Branch: main** / carpeta `/ (root)` → **Save**.
4. Espera 1-2 minutos; la URL aparece en esa misma página (tipo `https://jamanteiga.github.io/GESDOC/`).

---

## Uso de la app

- **Proyectos** (pantalla principal tras iniciar sesión): tarjetas con cada proyecto activo y sus contadores de documentos pendientes/retrasados, más una tabla con todos los documentos que requieren atención en cualquier proyecto. Botón **+ Nuevo proyecto** para dar de alta uno (PO, cliente, planta, plazo de revisión en días).
- **Dentro de un proyecto** → pestaña **Documentos**: alta/edición de documentos (nº doc cliente, nº doc proveedor, título, tag, modelo, fecha de entrega prevista, revisión y estado actuales). Botón **Historial** en cada fila para ver todos los envíos/recepciones registrados y añadir uno nuevo suelto.
- **Dentro de un proyecto** → pestaña **Transmittals**: **+ Nuevo transmittal** abre un formulario con el número, fecha, dirección (enviado/recibido), contraparte y una lista de todos los documentos del proyecto para marcar cuáles van incluidos con su revisión y estado; al crearlo se actualiza automáticamente el histórico y el estado de cada documento, y se abre una hoja imprimible (**Ver/Imprimir** → botón "Imprimir/Guardar PDF").
- **Administración** (solo ADMIN): asignar roles a usuarios, asignar usuarios a proyectos concretos (equipos), y editar/añadir los códigos de estado (por defecto: A=Aprobado, B=Aprobado con comentarios menores, C=Aprobado con comentarios-reenviar, R=Rechazado, I=Para información, PC=Pendiente aprobación cliente, PR=Pendiente revisión interna).

### Cómo se calculan las alertas

Para cada documento se mira su último evento (enviado/recibido) y la fecha de entrega prevista, comparado con el "plazo de revisión" del proyecto (por defecto 15 días, editable al crear el proyecto):

- 🔴 Rojo: sin enviar y ya pasada la fecha de entrega prevista / enviado hace más días que el plazo sin respuesta / estado pendiente desde hace más del plazo / rechazado.
- 🟠 Naranja: se acerca al plazo sin respuesta, o estado pendiente reciente.
- Sin marcar: al día.

### Personalización rápida

- **Cambiar el plazo de revisión** de un proyecto: edítalo al crearlo (de momento no es editable después desde la interfaz; se puede cambiar directamente en Table Editor → `projects` → columna `review_days`).
- **Solo tú vas a usar la app**: date de alta como ADMIN (paso 3) y ya tienes acceso a todos los proyectos sin tocar nada más en "Equipos".
- **Multiusuario**: crea cada usuario en Supabase, asígnale rol (VIEWER/EDITOR/ADMIN) y añádelo como miembro de los proyectos que le correspondan desde Administración → Equipos por proyecto.

### Próximos pasos posibles (no incluidos en esta versión)

- Notificaciones por email de documentos retrasados (requeriría una Edge Function + un servicio de correo, p.ej. Resend).
- Importar documentos desde un Excel existente (por ahora se dan de alta desde el formulario; puedo añadirlo si lo necesitas).
- Adjuntar el PDF del documento a cada registro (Supabase Storage).
