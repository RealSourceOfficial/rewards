# Rewards ledger

Loyalty points, expiration dates and birthday perks for every rewards app you actually use.
Installs to your Android home screen as a real app.

**No build step. No npm, no Node, no bundler.** Five files. Nothing to compile, ever.

Screenshots of your rewards apps can be read automatically — OCR runs in the browser, on the
device.

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

**Share screenshots in.** Once installed, the app shows up in Android's share sheet. Select any
number of screenshots in your gallery, Share, pick Rewards ledger, and they go straight into the
review screen. This is the fastest path and needs nothing else installed.

**Scan screenshots.** Button at the bottom of the points list. Screenshot the offers or rewards
tab in any of these apps, load the images, and it reads the text on your phone — balance, cheapest
reward threshold, and every dated offer. It guesses the brand from the text and you can correct it
with a dropdown. Nothing applies until you review it, because OCR misreads dates and digits often
enough that a glance is cheaper than driving somewhere for a dead coupon.

First use downloads the OCR engine (tesseract.js, about 5 MB) from a CDN and caches it, so it works
offline after that. No key, no account, and no image ever leaves the device.

What it reads well: "0 POINTS", "YOU'VE GOT 0 POINTS", "0 STARS EARNED", "11888 pts",
"0/10 POINTS", "No points yet", "0 Shore Points", "Current Points 250", and for dates
"Expires in 6 days", "Valid thru 10/13", "Offer expires 10/27/26", "Expires Sep 26, 2026".

Earn-rate copy is ignored on purpose: "$1 = 10 Points" and "10 PTS/$1" read exactly like a
10-point reward, and used to wreck the threshold.

What it won't guess: bare numbers with no unit beside them, like IHOP's Stack Market prices. It
leaves those blank rather than inventing a value.

**Screenshot quality matters more than anything else here.** Set Settings > Advanced features >
Screenshots and screen recorder > Screenshot format to **PNG**. JPEG ringing around thin light-grey
text is exactly what breaks OCR, and these apps are full of thin light-grey text. Prefer several
normal full-resolution screenshots over one long scroll capture.

**Paste text is the accurate path.** Android's built-in OCR is ML Kit and is markedly better than
tesseract on app UI. Open a screenshot, long-press the text, Select all, Copy, then paste into the
box on the scan screen. Separate multiple screens with a blank line.

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

Screenshot reading uses tesseract.js, pinned to v5 and pulled from jsDelivr. It's the only
third-party code the app loads, it loads lazily, and everything works without it. If the pinned
version ever breaks, change `TESSERACT_SRC` near the top of the script.

Offers are stored per brand as a list, so one screenshot of an offers tab can add half a dozen at
once. Expired ones stop counting automatically but stay visible in the edit sheet until you remove
them.


---

## Capturing the screenshots automatically

`capture.sh` drives your phone from your computer over adb and walks through the apps for you.
Nothing is installed on the phone, nothing is rooted.

Pair once (Android 11+, no cable needed):

```
Settings > Developer options > Wireless debugging > Pair device with code
adb pair <phone-ip>:<pair-port>
adb connect <phone-ip>:<port>
```

Then:

```bash
./capture.sh discover     # which rewards apps are installed, and their package names
./capture.sh init         # writes a starter apps.conf from what it found
./capture.sh run          # launch each app, tap through to the tabs, screenshot
./capture.sh push         # copy the PNGs back into the phone's gallery
```

Finish on the phone: Gallery, select the new shots, Share, Rewards ledger.

`apps.conf` is tab-separated — slug, package, then the tab labels to visit:

```
wendys      com.wendys.nutritiontool      Rewards,Offers
jackbox     com.jackinthebox.ordering     Rewards,Offers
starbucks   com.starbucks.mobilecard      Rewards
```

Labels are matched against on-screen text via `uiautomator dump`, so they follow the app's own
wording rather than fixed coordinates — which means a layout change usually costs you one label
edit instead of a rewrite. Use `-` to just screenshot whatever opens.

### Why this beats Samsung's scroll capture

A scroll capture stitches everything into one enormous image, and past a certain
length One UI downscales the result. A whole phone screen squeezed to 720px wide
leaves body text around 8-10 pixels tall; OCR wants roughly 30.

`screencap` sidesteps that entirely — every shot is native resolution, 1440px
wide on an S25+, no stitching and no downscale. For long rewards catalogues put a
page count in the fourth column of `apps.conf`:

```
mcd     com.mcdonalds.app    Rewards,Deals    4
```

That captures four screens per tab, scrolling between each. Overlap is harmless:
offers are deduplicated by title and date on import, so the same deal appearing
in two shots lands once.

### What this won't do

It can't log in for you, dismiss a promo interstitial it has never seen, or know that an app buried
its points behind two more taps. Expect to run `./capture.sh run <slug>` on one app at a time while
watching the phone, and to fix labels as you go. Once an app's line is right it stays right until
that app redesigns.

Worth knowing: some app terms of service prohibit accessing them by automated means. This is your
device, your accounts, and your own data on your own screen, which is a long way from scraping
someone's servers — but it is your call to make, and it is why nothing here touches a network API.

### Alternatives if you'd rather stay on the phone

MacroDroid, Tasker with AutoInput, or Automate can do the same walk using Android's accessibility
service. Screenshots without root work through `AccessibilityService#takeScreenshot` — the usual
route is the open-source Screenshot Tile (No Root), which exposes a broadcast intent those apps can
fire. On Android 13+ some manufacturers grey out the accessibility toggle until you allow
"restricted settings" for the app.

These are fiddlier to set up than the adb script but survive not having a computer nearby.
