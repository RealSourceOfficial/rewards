/* Rewards ledger service worker.
 *
 * Caches the app shell so it opens instantly and works offline. Cross-origin
 * calls (Overpass, Nominatim) pass straight through — a stale restaurant
 * location is worse than no location.
 *
 * Bump CACHE whenever you replace index.html, or the old copy keeps serving.
 */
var CACHE = "rewards-ledger-v1";

var SHELL = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/maskable-512.png",
  "./icons/favicon.png"
];

self.addEventListener("install", function (event) {
  event.waitUntil(
    caches
      .open(CACHE)
      .then(function (c) {
        // addAll is all-or-nothing; add individually so one 404 can't
        // wreck the whole install.
        return Promise.all(
          SHELL.map(function (url) {
            return c.add(url).catch(function () {
              return null;
            });
          })
        );
      })
      .then(function () {
        return self.skipWaiting();
      })
  );
});

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches
      .keys()
      .then(function (keys) {
        return Promise.all(
          keys
            .filter(function (k) {
              return k !== CACHE;
            })
            .map(function (k) {
              return caches.delete(k);
            })
        );
      })
      .then(function () {
        return self.clients.claim();
      })
  );
});

self.addEventListener("fetch", function (event) {
  var req = event.request;
  if (req.method !== "GET") return;

  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // let the network handle it

  if (req.mode === "navigate") {
    event.respondWith(
      fetch(req).catch(function () {
        return caches.open(CACHE).then(function (cache) {
          return cache.match("./index.html").then(function (hit) {
            return hit || cache.match("./");
          });
        });
      })
    );
    return;
  }

  event.respondWith(
    caches.open(CACHE).then(function (cache) {
      return cache.match(req).then(function (cached) {
        var network = fetch(req)
          .then(function (res) {
            if (res && res.ok) cache.put(req, res.clone());
            return res;
          })
          .catch(function () {
            return cached;
          });
        return cached || network;
      });
    })
  );
});
