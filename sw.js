// Service worker minimo: cachea solo lo estatico (css/manifest) para
// instalacion como PWA. Las paginas HTML se piden siempre a la red primero
// (network-first) para que un cambio en el codigo se vea de inmediato;
// solo se usa la copia en cache si no hay conexion. Los datos siempre se
// piden en vivo a Supabase (no se cachean).
const CACHE = 'gesdoc-shell-v2';
const STATIC = ['./css/styles.css', './manifest.json'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(STATIC)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.origin !== self.location.origin) return;

  const isPage = e.request.mode === 'navigate' || e.request.destination === 'document';
  if (isPage) {
    // Network-first: siempre la version mas reciente si hay conexion.
    e.respondWith(
      fetch(e.request).catch(() => caches.match(e.request))
    );
    return;
  }

  // Estaticos: cache-first.
  e.respondWith(
    caches.match(e.request).then((cached) => cached || fetch(e.request))
  );
});
