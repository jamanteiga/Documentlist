// Service worker minimo: cachea el "shell" para instalacion como PWA.
// Los datos siempre se piden en vivo a Supabase (no se cachean).
const CACHE = 'gesdoc-shell-v1';
const SHELL = [
  './index.html',
  './dashboard.html',
  './proyecto.html',
  './admin.html',
  './css/styles.css',
  './manifest.json'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)));
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
  // No cachear llamadas a Supabase ni a CDNs externas.
  if (url.origin !== self.location.origin) return;
  e.respondWith(
    caches.match(e.request).then((cached) => cached || fetch(e.request))
  );
});
