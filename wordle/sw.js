// Word Master Wordle — service worker
// Bump this whenever a deploy should force-refresh installed copies.
const CACHE = "wmw-v1";

const CORE = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./favicon.svg",
  "./apple-touch-icon.png",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-maskable-512.png",
  "./words/answers-5.js", "./words/answers-6.js", "./words/answers-7.js", "./words/answers-8.js",
  "./words/valid-5.js", "./words/valid-6.js", "./words/valid-7.js", "./words/valid-8.js",
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Never touch the live leaderboard traffic — Firebase manages its own transport/offline cache.
const isLive = (url) => /firebasedatabase\.app|firebaseio\.com/.test(url);

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET" || isLive(req.url)) return;

  // The app shell: always prefer the network so a fresh deploy shows up
  // immediately; fall back to the cached copy only when offline.
  if (req.mode === "navigate" || req.url.endsWith("/index.html")) {
    e.respondWith(
      fetch(req)
        .then((res) => { caches.open(CACHE).then((c) => c.put(req, res.clone())); return res; })
        .catch(() => caches.match(req).then((res) => res || caches.match("./index.html")))
    );
    return;
  }

  // Everything else (word lists, icons, fonts): serve from cache instantly,
  // refresh the cache in the background (stale-while-revalidate).
  e.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const cached = await cache.match(req);
      const network = fetch(req)
        .then((res) => { if (res && res.ok) cache.put(req, res.clone()); return res; })
        .catch(() => cached);
      return cached || network;
    })
  );
});
