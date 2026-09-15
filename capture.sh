#!/usr/bin/env bash
# capture.sh — walk your rewards apps and screenshot the useful screens.
#
# Runs on your computer, drives the phone over adb. Nothing is installed on the
# phone, nothing is rooted, and no account is touched by anything but you.
#
#   ./capture.sh discover          list installed apps that look like rewards apps
#   ./capture.sh init              write a starter apps.conf from what's installed
#   ./capture.sh run               capture every app in apps.conf
#   ./capture.sh run wendys        capture one entry
#   ./capture.sh push              copy the results back to the phone's gallery
#
# Pair the phone first (Android 11+, no cable):
#   Settings > Developer options > Wireless debugging > Pair device with code
#   adb pair <ip>:<pair-port>          then      adb connect <ip>:<port>

set -uo pipefail

OUT="${OUT:-./shots}"
CONF="${CONF:-./apps.conf}"
SETTLE="${SETTLE:-3}"        # seconds to wait after launching an app
STEP="${STEP:-2}"            # seconds to wait after a tap
PHONE_DIR="${PHONE_DIR:-/sdcard/Pictures/RewardsShots}"

die() { printf '%s\n' "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }

need_device() {
  command -v adb >/dev/null || die "adb not found. Install android-tools."
  local n
  n=$(adb devices | grep -cw "device$")
  [ "$n" -eq 0 ] && die "No device. Try: adb connect <phone-ip>:<port>"
  [ "$n" -gt 1 ] && die "More than one device attached. Set ANDROID_SERIAL."
  return 0
}

# ---------------------------------------------------------------- discover

KEYWORDS='wendy|mcdonald|tacobell|taco.?bell|jackinthebox|jack.?in|starbucks|ihop|popeyes|chipotle|dominos|pizzahut|papajohn|littlecaesars|jerseymike|jimmyjohn|krispykreme|dutchbros|7eleven|seveneleven|church|carlsjr|ckeinc|burgerking|bk\.|arbys|subway|dairyqueen|dq|walmart|gasbuddy|dennys|panera|chickfila|dunkin|kfc|pandaexpress|sonic|fiveguys|wingstop|deltaco|raisingcanes|qdoba|redrobin|applebees|olivegarden|buffalowildwings|shakeshack|baskin|coldstone|modpizza|roundtable|tacotime|jamba|cinnabon|safeway|fredmeyer|winco|costco'

cmd_discover() {
  need_device
  note "Installed packages that look like rewards apps:"
  adb shell pm list packages -3 \
    | sed 's/^package://' \
    | grep -Ei "$KEYWORDS" \
    | sort \
    || note "(none matched — try: adb shell pm list packages -3 | grep -i <name>)"
}

cmd_init() {
  need_device
  [ -f "$CONF" ] && die "$CONF already exists. Delete it first if you want a fresh one."
  {
    echo "# One line per app:  slug <TAB> package <TAB> tab labels to visit (comma separated)"
    echo "# Tab labels are matched against on-screen text, case-insensitive."
    echo "# A label of '-' means: just screenshot whatever opens."
    echo "#"
    echo "# Blank labels are fine to start with; run 'capture.sh run <slug>' and watch"
    echo "# the phone to see what the tabs are actually called."
    echo ""
    adb shell pm list packages -3 \
      | sed 's/^package://' \
      | grep -Ei "$KEYWORDS" \
      | sort \
      | while read -r pkg; do
          slug=$(printf '%s' "$pkg" | awk -F. '{print $NF}' | tr -cd 'a-z0-9')
          printf '%s\t%s\t%s\n' "$slug" "$pkg" "Rewards,Offers"
        done
  } > "$CONF"
  note "Wrote $CONF"
  note "Open it and fix the tab labels per app before running."
}

# ---------------------------------------------------------------- ui helpers

# Dump the current view hierarchy to stdout.
ui_dump() {
  adb shell uiautomator dump /sdcard/.ui.xml >/dev/null 2>&1 || return 1
  adb shell cat /sdcard/.ui.xml 2>/dev/null
}

# Find the centre of the first node whose text or content-desc matches $1.
# Prints "x y", or nothing if not found.
find_tap_point() {
  local want="$1" xml
  xml=$(ui_dump) || return 1
  # uiautomator emits the whole tree on one line, so split it into nodes first.
  # (tr can't do this — it maps character to character, never one to two.)
  printf '%s' "$xml" \
    | sed 's/></>\n</g' \
    | grep -i -- "$want" \
    | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | head -1 \
    | sed 's/[^0-9]/ /g' \
    | awk '{ if (NF>=4) printf "%d %d\n", ($1+$3)/2, ($2+$4)/2 }'
}

tap_label() {
  local label="$1" pt
  pt=$(find_tap_point "$label")
  if [ -z "$pt" ]; then
    note "could not find a control labelled '$label'"
    return 1
  fi
  # shellcheck disable=SC2086
  adb shell input tap $pt
  sleep "$STEP"
  return 0
}

shoot() {
  local name="$1"
  adb exec-out screencap -p > "$OUT/$name.png" 2>/dev/null
  if [ ! -s "$OUT/$name.png" ]; then
    rm -f "$OUT/$name.png"
    note "screenshot failed for $name"
    return 1
  fi
  note "saved $name.png"
  return 0
}

# ---------------------------------------------------------------- run

capture_app() {
  local slug="$1" pkg="$2" labels="$3"

  printf '\n%s (%s)\n' "$slug" "$pkg"
  adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
    || { note "couldn't launch $pkg"; return 1; }
  sleep "$SETTLE"

  if [ "$labels" = "-" ] || [ -z "$labels" ]; then
    shoot "${slug}-home"
    return 0
  fi

  local IFS=,
  local shot_any=0
  for label in $labels; do
    label=$(printf '%s' "$label" | sed 's/^ *//;s/ *$//')
    [ -z "$label" ] && continue
    if tap_label "$label"; then
      shoot "${slug}-$(printf '%s' "$label" | tr '[:upper:] ' '[:lower:]-')" && shot_any=1
    fi
  done

  # If no tab matched, at least grab the landing screen — often the offers page.
  [ "$shot_any" -eq 0 ] && shoot "${slug}-home"

  adb shell am force-stop "$pkg" >/dev/null 2>&1
  return 0
}

cmd_run() {
  need_device
  [ -f "$CONF" ] || die "No $CONF. Run: $0 init"
  mkdir -p "$OUT"
  local only="${1:-}"
  local count=0

  while IFS=$'\t' read -r slug pkg labels; do
    case "$slug" in ''|\#*) continue ;; esac
    [ -n "$only" ] && [ "$slug" != "$only" ] && continue
    capture_app "$slug" "$pkg" "${labels:-}"
    count=$((count + 1))
  done < "$CONF"

  adb shell rm -f /sdcard/.ui.xml >/dev/null 2>&1
  printf '\nCaptured %d app(s) into %s\n' "$count" "$OUT"
  printf 'Next: %s push     (then share them into the ledger from your gallery)\n' "$0"
}

cmd_push() {
  need_device
  [ -d "$OUT" ] || die "Nothing in $OUT yet."
  adb shell mkdir -p "$PHONE_DIR"
  local n=0
  for f in "$OUT"/*.png; do
    [ -e "$f" ] || continue
    adb push "$f" "$PHONE_DIR/" >/dev/null && n=$((n + 1))
  done
  # Make the gallery notice them.
  adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
    -d "file://$PHONE_DIR" >/dev/null 2>&1
  printf 'Pushed %d image(s) to %s\n' "$n" "$PHONE_DIR"
  printf 'On the phone: Gallery > select them > Share > Rewards ledger\n'
}

case "${1:-}" in
  discover) cmd_discover ;;
  init)     cmd_init ;;
  run)      shift; cmd_run "${1:-}" ;;
  push)     cmd_push ;;
  *)        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
