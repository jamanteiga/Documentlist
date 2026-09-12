# GESDOC — Control documental multiproyecto

App para llevar el control de la documentación (vendor document index / document list) de varios proyectos a la vez: listado de documentos por proyecto, historial de revisiones, generación de transmittals y alertas de documentos pendientes o retrasados.

Arquitectura: HTML/CSS/JS puro (sin build) + Supabase (base de datos, autenticación y permisos por rol) + despliegue en GitHub Pages. Mismo esquema que ESTRUCTURA/REGHOR.

Roles: **ADMIN** (todo, incluye borrar y administración), **EDITOR** (crear/editar documentos y transmittals), **VIEWER** (solo lectura).

---

## 1. Usar el mismo proyecto Supabase que ESTRUCTURA

Si ya tienes tus dos proyectos gratuitos de Supabase ocupados (REGHOR y ESTRUCTURA), GESDOC no necesita uno nuevo: sus tablas viven en su **propio esquema de Postgres** llamado `gesdoc` (no `public`), así que conviven en el mismo proyecto que ESTRUCTURA sin tocar ni una tabla suya.

1. Entra en tu proyecto Supabase de **ESTRUCTURA**.
2. Menú lateral → **SQL Editor** → **New query**.
3. Pega el contenido completo de `schema.sql` (incluido en esta carpeta) y pulsa **Run**.
   - Crea el esquema `gesdoc` con sus propias tablas, vista y políticas de seguridad (RLS), separado de las de ESTRUCTURA, y precarga los códigos de estado habituales (A, B, C, R, I, PC, PR).
4. **Imprescindible** — Menú lateral → **Project Settings** (icono de engranaje) → **Data API** → busca **"Exposed schemas"** → añade `gesdoc` a la lista (junto a `public`) → guarda.
   - Sin este paso la app no podrá leer ni escribir nada: por defecto Supabase solo expone el esquema `public` a través de la API.

## 2. Conectar la app a tu proyecto

1. En el mismo sitio (**Project Settings** → **Data API**), copia la **Project URL** y la clave **anon public** (en "API Keys") — son las mismas que usa ESTRUCTURA, no hace falta buscar otras.
2. Abre `config.js` en esta carpeta y sustituye:
   ```js
   export const SUPABASE_URL = 'https://TU-PROYECTO.supabase.co';
   export const SUPABASE_ANON_KEY = 'TU-CLAVE-ANON-PUBLICA';
   ```
   (`js/db.js` ya está configurado para que todas las consultas de GESDOC apunten al esquema `gesdoc`, así que no hace falta tocar nada más.)

## 3. Crear el primer usuario (ADMIN)

Como GESDOC comparte proyecto Supabase con ESTRUCTURA, **comparte también sus usuarios** (la tabla `auth.users` es una sola por proyecto): al ejecutar `schema.sql` ya se ha creado automáticamente un perfil de GESDOC (rol `VIEWER`) para cada usuario que ya existía en ESTRUCTURA. Es decir, cualquiera que ya tenga cuenta en ESTRUCTURA puede entrar en GESDOC con el mismo email y contraseña. Si no quieres eso, solo hay dos vías: usar un proyecto Supabase distinto (no es tu caso ahora), o simplemente no subir el rol de esas cuentas más allá de `VIEWER` y no añadirlas como miembros de ningún proyecto (así entran pero no ven nada).

1. Si tu propio email ya existe en ESTRUCTURA, ya tienes perfil en GESDOC (rol `VIEWER`); solo falta subirlo a ADMIN — ver paso 2. Si es un email nuevo: menú lateral → **Authentication** → **Users** → **Add user** → **Create new user** (marca "Auto Confirm User" para que pueda entrar sin verificar el email).
2. Menú lateral → **Table Editor** → arriba a la izquierda, el desplegable de esquema (pone `public`) → cámbialo a **`gesdoc`** → tabla `profiles` → busca la fila con tu email → columna `role` → cámbiala a `ADMIN`.
   - Alternativa por SQL (SQL Editor): `update gesdoc.profiles set role = 'ADMIN' where email = 'tu-email@dominio.com';`
3. Los siguientes usuarios nuevos los das de alta igual (Authentication → Users → Add user); entrarán con rol `VIEWER` por defecto y tú les subes el rol desde la pestaña **Administración** de la app.

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
