/* NXT Step USA – service worker: makes the app installable and opens fast.
   App files: network first, cache as fallback. Supabase and config.js are never cached. */
const CACHE = 'nxt-v2';
// Relative paths, so the app also works in a sub-folder (GitHub Pages: name.github.io/repo/)
const SHELL = ['./', 'index.html', 'manifest.webmanifest', 'icons/icon-192.png', 'img/liberty.jpg', 'img/yale.jpg', 'img/oculus.jpg', 'img/street.jpg', 'img/night.jpg', 'img/action.jpg'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if(e.request.method !== 'GET' || u.origin !== location.origin || u.pathname.endsWith('/config.js')) return;
  e.respondWith(fetch(e.request).then(r => { if(r.ok){ const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); } return r; })
    .catch(() => caches.match(e.request).then(r => r || caches.match(new URL('index.html', self.registration.scope)))));
});
