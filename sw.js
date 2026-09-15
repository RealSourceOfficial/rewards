/* Rewards ledger service worker.
 *
 * Caches the app shell so it opens instantly and works offline. Cross-origin
 * calls (Overpass, Nominatim) pass straight through — a stale restaurant
 * location is worse than no location.
 *
 * Bump CACHE whenever you replace index.html, or the old copy keeps serving.
 */
var CACHE = "rewards-ledger-v2";

/* The OCR engine and its language data are big and versioned, so once they've
   been fetched we keep them. Everything else cross-origin stays uncached. */
var OCR_HOSTS = ["cdn.jsdelivr.net", "unpkg.com", "tessdata.projectnaptha.com"];

/* Screenshots handed over by the share sheet wait here until the page loads. */
var SHARE_CACHE = "rewards-ledger-shared";

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
              return k !== CACHE && k !== SHARE_CACHE;
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
  var url = new URL(req.url);

  /* Screenshots shared from the gallery arrive as a POST here. Stash the
   * blobs, then bounce the user into the app, which picks them up on load.
   * The redirect has to be returned synchronously; reading the body can
   * finish afterwards inside waitUntil. */
  if (req.method === "POST" && url.pathname.indexOf("/share-target") !== -1) {
    event.respondWith(Response.redirect("./?shared=1", 303));
    event.waitUntil(
      req.formData().then(function (form) {
        var files = form.getAll("images").filter(Boolean);
        return caches.open(SHARE_CACHE).then(function (cache) {
          // Drop anything left from a previous share that was never consumed.
          return cache.keys().then(function (old) {
            return Promise.all(old.map(function (k) { return cache.delete(k); }));
          }).then(function () {
            return Promise.all(files.map(function (f, i) {
              var key = "./shared/" + i + "-" + encodeURIComponent(f.name || ("image-" + i));
              return cache.put(key, new Response(f, {
                headers: { "Content-Type": f.type || "image/png" }
              }));
            }));
          });
        });
      }).catch(function () { /* a failed share shouldn't wedge the worker */ })
    );
    return;
  }

  if (req.method !== "GET") return;

  if (url.origin !== self.location.origin) {
    // Cache-first for the OCR engine: it's ~5 MB and never changes for a
    // pinned version, so re-downloading it on every scan would be rude.
    if (OCR_HOSTS.indexOf(url.hostname) !== -1) {
      event.respondWith(
        caches.open(CACHE).then(function (cache) {
          return cache.match(req).then(function (hit) {
            if (hit) return hit;
            return fetch(req).then(function (res) {
              if (res && (res.ok || res.type === "opaque")) cache.put(req, res.clone());
              return res;
            });
          });
        })
      );
    }
    return; // everything else cross-origin goes straight to the network
  }

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
