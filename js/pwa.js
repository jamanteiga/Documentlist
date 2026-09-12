// Registro del service worker (instalacion como PWA). Efecto lateral: solo importar.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch((err) => console.warn('SW no registrado', err));
  });
}
