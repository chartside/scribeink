#!/usr/bin/env bash
# ScribeInk identity check: fails while upstream identity (bundle IDs, product
# name, updater keys, user-facing "VoiceInk" strings) is still present.
# Run from anywhere; it changes to the repo root. Exit 0 = pass, 1 = fail.
# Allow-list: scripts/scribeink-identity.allow (see its header for the format).
set -euo pipefail
export LC_ALL=C

cd "$(git rev-parse --show-toplevel)"

ALLOW_FILE="scripts/scribeink-identity.allow"
PBXPROJ="VoiceInk.xcodeproj/project.pbxproj"
INFO_PLIST="VoiceInk/Info.plist"

FAILED=0
fail() { echo "FAIL: $*"; FAILED=1; }

if [ ! -f "$ALLOW_FILE" ]; then
    fail "allow-list: $ALLOW_FILE: allow-list missing"
fi

# is_allowed <file> <line text>: 0 if the allow-list suppresses this hit.
is_allowed() {
    local file="$1" text="$2" glob lit
    [ -f "$ALLOW_FILE" ] || return 1
    while IFS=$'\t' read -r glob lit || [ -n "$glob" ]; do
        case "$glob" in ''|'#'*) continue ;; esac
        # shellcheck disable=SC2254
        case "$file" in
            $glob)
                if [ -z "$lit" ]; then return 0; fi
                case "$text" in *"$lit"*) return 0 ;; esac
                ;;
        esac
    done < "$ALLOW_FILE"
    return 1
}

# ---- Check 1: upstream bundle ID namespace ---------------------------------
FILES1="$( { [ -f "$PBXPROJ" ] && echo "$PBXPROJ"; [ -f Makefile ] && echo Makefile
    find . \( -path ./.git -o -path ./.build -o -path ./DerivedData -o -path ./.superpowers \) -prune -o \
        -type f \( -name '*.plist' -o -name '*.entitlements' -o -name '*.xcconfig' -o -name '*.swift' \) -print \
        | sed 's#^\./##'; } | sort -u )"
while IFS= read -r f; do
    [ -n "$f" ] || continue
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        n="${hit%%:*}"; text="${hit#*:}"
        if ! is_allowed "$f" "$text"; then
            fail "id: $f:$n: com.prakashjoshipax found:$(printf '%s' "$text" | sed -e 's/^[[:space:]]*/ /' -e 's/[[:space:]]*$//')"
        fi
    done <<< "$(grep -n 'com\.prakashjoshipax' "$f" || true)"
done <<< "$FILES1"

# ---- Check 3: upstream updater keys ----------------------------------------
if [ -f "$INFO_PLIST" ]; then
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        n="${hit%%:*}"; text="${hit#*:}"
        if ! is_allowed "$INFO_PLIST" "$text"; then
            fail "updater: $INFO_PLIST:$n: upstream updater key present:$(printf '%s' "$text" | sed -e 's/^[[:space:]]*/ /' -e 's/[[:space:]]*$//')"
        fi
    done <<< "$(grep -nE 'SUFeedURL|SUPublicEDKey' "$INFO_PLIST" || true)"
else
    fail "updater: $INFO_PLIST: file missing"
fi

# ---- Checks 2 and 4 need real parsing: python3 -------------------------------
set +e
python3 -I - "$ALLOW_FILE" "$PBXPROJ" <<'PY'
import fnmatch, json, os, re, sys

allow_path, pbxproj = sys.argv[1], sys.argv[2]
failed = False

# Allow-list: (glob, literal-or-None). Mirrors the bash `case` semantics:
# fnmatch's `*` also crosses `/`.
rules = []
if os.path.isfile(allow_path):
    with open(allow_path, encoding="utf-8") as fh:
        for raw in fh:
            raw = raw.rstrip("\n")
            if not raw.strip() or raw.lstrip().startswith("#"):
                continue
            glob, _, lit = raw.partition("\t")
            rules.append((glob, lit or None))

def allowed(path, text):
    for glob, lit in rules:
        if fnmatch.fnmatchcase(path, glob) and (lit is None or lit in text):
            return True
    return False

def fail(check, where, detail):
    global failed
    failed = True
    print("FAIL: %s: %s: %s" % (check, where, detail))

SKIP_DIRS = {".git", ".build", "DerivedData", ".superpowers", "node_modules"}
def walk(exts):
    for root, dirs, files in os.walk("."):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for name in sorted(files):
            if name.endswith(exts):
                yield os.path.relpath(os.path.join(root, name), ".")

# ---- Check 2: app target PRODUCT_NAME ---------------------------------------
APP_PAIRS = [
    ("com.prakashjoshipax.VoiceInk", "com.prakashjoshipax.VoiceInk.dev"),
    ("com.chartside.ScribeInk", "com.chartside.ScribeInk.dev"),
]
app_ids = {i for pair in APP_PAIRS for i in pair}
if not os.path.isfile(pbxproj):
    fail("product-name", pbxproj, "file missing")
else:
    with open(pbxproj, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    blocks, cur = [], None
    for i, line in enumerate(lines, 1):
        if re.search(r"/\* (Debug|Release) \*/ = \{", line):
            cur = {"bid": None, "name": None, "name_line": None, "bid_line": None}
        elif cur is not None:
            m = re.match(r"\s*PRODUCT_BUNDLE_IDENTIFIER = (.+?);", line)
            if m:
                cur["bid"], cur["bid_line"] = m.group(1).strip('"'), i
            m = re.match(r"\s*PRODUCT_NAME = (.+?);", line)
            if m:
                cur["name"], cur["name_line"] = m.group(1), i
            if re.match(r"\t\t\};", line):
                blocks.append(cur)
                cur = None
    app = [b for b in blocks if b["bid"] in app_ids]
    if len(app) != 2:
        fail("product-name", pbxproj, "expected 2 app build configurations, found %d" % len(app))
    for b in app:
        is_dev = b["bid"].endswith(".dev")
        want = '"ScribeInk Dev"' if is_dev else "ScribeInk"
        if b["name"] != want:
            where = "%s:%s" % (pbxproj, b["name_line"] or b["bid_line"])
            fail("product-name", where,
                 "%s PRODUCT_NAME is %s, want %s (bundle id %s)" %
                 ("Debug" if is_dev else "Release", b["name"], want, b["bid"]))

# ---- Check 4: user-facing "VoiceInk" -----------------------------------------
NEEDLE = "VoiceInk"

def snippet(s):
    s = " ".join(s.split())
    return s if len(s) <= 90 else s[:87] + "..."

# xcstrings: every key (source text) and every stringUnit.value
def find_line(text_lines, s):
    for needle in (json.dumps(s, ensure_ascii=False)[1:-1], json.dumps(s)[1:-1]):
        for i, l in enumerate(text_lines, 1):
            if needle in l:
                return i
    return None

def walk_units(node, trail, out):
    if isinstance(node, dict):
        su = node.get("stringUnit")
        if isinstance(su, dict) and isinstance(su.get("value"), str):
            out.append((".".join(trail), su["value"]))
        for k, v in node.items():
            walk_units(v, trail + [k], out)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk_units(v, trail + [str(i)], out)

for path in walk((".xcstrings",)):
    try:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
        data = json.loads(raw)
    except Exception as e:
        fail("string", path, "cannot parse JSON: %s" % e)
        continue
    tl = raw.split("\n")
    for key, entry in (data.get("strings") or {}).items():
        if NEEDLE in key and not allowed(path, key):
            n = find_line(tl, key)
            fail("string", path + (":%d" % n if n else ""), "source key contains VoiceInk: " + snippet(key))
        units = []
        walk_units(entry, [], units)
        for trail, val in units:
            if NEEDLE in val and not allowed(path, val) and not allowed(path, key):
                n = find_line(tl, val)
                loc = trail.replace("localizations.", "").replace(".stringUnit", "")
                fail("string", path + (":%d" % n if n else ""), "value [%s] contains VoiceInk: %s" % (loc, snippet(val)))

# plist: *UsageDescription, CFBundleDisplayName, CFBundleName values
KEY_RE = re.compile(r"<key>(\w*UsageDescription|CFBundleDisplayName|CFBundleName)</key>")
for path in walk((".plist",)):
    with open(path, encoding="utf-8", errors="replace") as fh:
        pl = fh.read().split("\n")
    for i, line in enumerate(pl):
        m = KEY_RE.search(line)
        if not m:
            continue
        rest = line[m.end():]
        j, val_line = i, rest
        if "<string>" not in rest and i + 1 < len(pl):
            j, val_line = i + 1, pl[i + 1]
        vm = re.search(r"<string>(.*?)</string>", val_line)
        if vm and NEEDLE in vm.group(1) and not allowed(path, val_line):
            fail("string", "%s:%d" % (path, j + 1), "%s contains VoiceInk: %s" % (m.group(1), snippet(vm.group(1))))

# Swift: user-facing literals. Whole-file regex so a literal on the line after
# `String(localized:` is caught. Comment lines are skipped.
LIT = r'"((?:[^"\\\n]|\\.)*)"'
CALL_RE = re.compile(
    r'(?:String\(\s*localized:\s*|\bText\(\s*|\bButton\(\s*|\bLabel\(\s*|\.navigationTitle\(\s*|'
    r'\.help\(\s*|\bToggle\(\s*|\bSection\(\s*|\b(?:messageText|informativeText)\s*=\s*)' + LIT)
for path in walk((".swift",)):
    with open(path, encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    sl = src.split("\n")
    seen = set()
    for m in CALL_RE.finditer(src):
        lit = m.group(1)
        if NEEDLE not in lit:
            continue
        n = src.count("\n", 0, m.start()) + 1
        if sl[n - 1].lstrip().startswith("//"):
            continue
        if allowed(path, sl[n - 1]) or allowed(path, lit):
            continue
        if (n, lit) in seen:
            continue
        seen.add((n, lit))
        fail("string", "%s:%d" % (path, n), "Swift literal contains VoiceInk: " + snippet(lit))

sys.exit(1 if failed else 0)
PY
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
echo "OK: ScribeInk identity checks passed"
