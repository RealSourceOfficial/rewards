# Rewards ledger

Loyalty points, expiration dates and birthday perks for every rewards app you actually use.
Installs to your Android home screen as a real app.

**No build step. No npm, no Node, no bundler.** Five files. Nothing to compile, ever.

Everything you type stays in your phone's browser storage. Nothing is sent anywhere except the
two map lookups you trigger by hand.

---

## The one thing you can't avoid

An installable app needs an **https** address. That's a browser rule, not a choice I made.
Without it Android gives you a bookmark instead of an app, and refuses to hand over your location.

You don't need to buy a domain or run a server to get https, though. Pick whichever of these
annoys you least.

### Option 1 — GitHub Pages (recommended, all in a browser)

You already have a GitHub account, which is most of the work.

1. Create a new **public** repo, name it anything.
2. **Add file → Upload files.** Drag in `index.html`, `manifest.webmanifest`, `sw.js`, and the
   `icons` folder. Commit.
3. **Settings → Pages.** Under *Source* pick **Deploy from a branch**, branch `main`, folder
   `/ (root)`. Save.
4. Wait a minute. Your app is at `https://<username>.github.io/<repo>/`.

Free https, no domain, no server, no certificate to renew. Roughly three minutes, once, and then
you never touch it again. Updating later means replacing `index.html` through the same web UI.

If you'd rather the repo stay private, Cloudflare Pages and Netlify both do the same thing from a
private repo on their free tiers.

### Option 2 — your own box

Drop the five files in any webroot behind your existing reverse proxy. No build, no Node on the
server, nothing to keep running. One note for whatever proxy you use:

```
# Caddy
rewards.yourdomain.org {
    root * /srv/rewards
    file_server
    header /sw.js Cache-Control "no-cache"
    header /index.html Cache-Control "no-cache"
}
```

The `no-cache` on `sw.js` matters. A cached service worker means updates silently stop arriving.

### Option 3 — straight off the phone, no hosting at all

Copy the files to your phone and open `index.html` from a file manager. Be clear about what you're
giving up, because it's most of the point:

| | hosted on https | opened as a local file |
|---|---|---|
| Installs as a real app | yes | no, browser tab only |
| Works offline | yes | yes |
| Saves your data | yes | usually, but easy to lose |
| Finds your location | yes | no — type a town instead |
| Nearby restaurant scan | yes | probably, may be blocked |

The app detects this and says so in plain language rather than failing silently. It's a fine way to
kick the tires. It's a bad way to live.

---

## Installing it on the phone

Once it's on an https address:

1. Open the URL in Chrome on Android.
2. Menu → **Add to home screen** (or **Install app**).
3. Chrome quietly builds a WebAPK, so you get a real launcher icon, an entry in the task switcher,
   and no address bar. Samsung Internet works the same way.

After the first launch it opens offline. Only the nearby scan needs a connection.

---

## Using it

**Points tab.** Tap a brand to open its app, read your balance, tap the row and type it in. The
card at the top tells you where to eat next and why. Expiring points outrank a ready reward, since
a reward sitting still costs nothing while expiring points are money walking out the door.

**Birthday tab.** Counts down to your birthday, with a marker 30 days out. That marker is the real
deadline — most programs want you enrolled a week to a month ahead, and some want a purchase on
file first. The checkbox per brand is the useful part; signing up is the whole job.

**Settings → Rescan** finds the nearest location of every brand in one request. Free, keyless,
OpenStreetMap. Scan when you move, not on a timer.

Change your birthday, the search radius, or add chains from the dropdown at the bottom of the
points list.

---

## Backup and restore

Settings → **Backup and restore**. Download a JSON file, or paste one back.

The export holds only what you typed — about 500 bytes. Brand names, colours, links, OSM tags and
the shipped birthday notes all live inside `index.html` and come from whichever copy you're
running. A field is only written to the export if you actually overrode the shipped value.

That's what makes updates safe. Drop in a newer `index.html` that renames a brand, fixes a dead
link or adds thirty chains, and your balances still land in the right rows. Nothing stale gets
pinned. Old export formats are walked forward automatically.

**Merge** — rows in the file overwrite matching rows; anything the file doesn't mention is left
alone.
**Replace** — everything here is thrown out and rebuilt from the file. Use this when moving phones.

Export before you replace `index.html`, and before clearing browser data. Your data survives
updates; it does not survive "clear site data."

---

## Editing the brand list

Open `index.html` in any text editor and find `var SEED`. Add an entry:

```js
{id:"zips", name:"Zips Drive In", program:"", dot:"#C8102E",
 link:"https://zipsdrivein.com", osm:"Zips Drive In"}
```

`id` is what your saved data keys against, so never rename one — that orphans the row's numbers.
`osm` should match how the chain is tagged in OpenStreetMap's `name` or `brand` field; leave it
empty to skip the brand during scans. `EXTRAS` just below feeds the *Add a place* dropdown.

Bump `CACHE` in `sw.js` after any edit, or the old copy keeps serving.

---

## About the data

Balances, thresholds and expiration rules are typed by hand. None of these chains publish a
consumer API, and automating a login to scrape balances would violate all of their terms and break
the first time a page changes.

Seeded birthday perks come from public 2026 roundups. They vary by franchise and change often —
overwrite each one with what your app actually says.

Nearby lookups use the Overpass API and Nominatim, both volunteer-run and donation-funded. One
rescan is a single request covering every brand, cached until you scan again. Don't hammer them.
