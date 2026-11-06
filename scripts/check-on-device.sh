#!/usr/bin/env bash
# On-device check: fails if cloud code is not gated behind #if CLOUD_PROVIDERS,
# if ungated code references cloud types, or if a new network host appears.
# Run from anywhere; it changes to the repo root. Exit 0 = pass, 1 = fail.
set -euo pipefail
export LC_ALL=C

cd "$(git rev-parse --show-toplevel)"

CLOUD_DIR="VoiceInk/Infrastructure/Providers/Transcription/Cloud"
ALLOW_FILE="scripts/on-device-hosts.allow"

EXCLUDED_NAMES="AssemblyAIProvider CartesiaProvider DeepgramProvider ElevenLabsProvider GeminiProvider GroqProvider MistralProvider OpenRouterProvider SonioxProvider SpeechmaticsProvider XAIProvider CloudTranscriptionService"

# Paths relative to VoiceInk/
GUARDED_CALL_SITES="Features/Recording/Workflows/TranscriptionServiceRegistry.swift
Features/ModelLibrary/State/TranscriptionModelManager.swift"

FAILED=0
fail() { echo "FAIL: $*"; FAILED=1; }

# First non-blank, non-comment line of a file (// comments only).
first_code_line() {
    grep -vE '^[[:space:]]*(//.*)?$' "$1" | head -n 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true
}
# Last non-blank line of a file.
last_code_line() {
    grep -vE '^[[:space:]]*$' "$1" | tail -n 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true
}

# Build the EXCLUDED list (sorted, one path per line).
EXCLUDED=""
for n in $EXCLUDED_NAMES; do
    EXCLUDED="$EXCLUDED$CLOUD_DIR/$n.swift"$'\n'
done
if [ -d "$CLOUD_DIR/Streaming" ]; then
    EXCLUDED="$EXCLUDED$(find "$CLOUD_DIR/Streaming" -type f -name '*.swift')"$'\n'
fi
EXCLUDED="$(printf '%s' "$EXCLUDED" | grep -v '^$' | sort)"

# ---- Check 1: wrapped files ------------------------------------------------
while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ ! -f "$f" ]; then
        fail "wrapped: $f: file missing"
        continue
    fi
    first="$(first_code_line "$f")"
    last="$(last_code_line "$f")"
    if [ "$first" != "#if CLOUD_PROVIDERS" ]; then
        fail "wrapped: $f: first code line is not '#if CLOUD_PROVIDERS'"
    elif [ "$last" != "#endif" ]; then
        fail "wrapped: $f: last line is not '#endif'"
    fi
done <<< "$EXCLUDED"

# ---- Check 2: no stray references -----------------------------------------
TYPES=""
while IFS= read -r f; do
    [ -f "$f" ] || continue
    TYPES="$TYPES$(grep -hoE '^(final |public |private )?(class|struct|enum|protocol|actor) [A-Za-z0-9_]+' "$f" | awk '{print $NF}' || true)"$'\n'
done <<< "$EXCLUDED"
TYPES="$(printf '%s' "$TYPES" | grep -v '^$' | sort -u || true)"

is_guarded() {
    local rel="${1#VoiceInk/}" g
    while IFS= read -r g; do
        [ "$g" = "$rel" ] && return 0
    done <<< "$GUARDED_CALL_SITES"
    return 1
}

if [ -n "$TYPES" ]; then
    TYPE_PATTERN="$(printf '%s\n' "$TYPES" | paste -sd'|' -)"
    SWIFT_OUTSIDE="$(find VoiceInk -type f -name '*.swift' -not -path "$CLOUD_DIR/*" | sort)"
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        hits="$(grep -owE "$TYPE_PATTERN" "$f" | sort -u | paste -sd',' - || true)"
        [ -n "$hits" ] || continue
        if is_guarded "$f"; then
            if ! grep -q '#if CLOUD_PROVIDERS' "$f"; then
                fail "references: $f: guarded call site lacks '#if CLOUD_PROVIDERS' (mentions $hits)"
            fi
        else
            fail "references: $f: mentions $hits"
        fi
    done <<< "$SWIFT_OUTSIDE"
fi
# Each guarded call site must exist and contain the guard.
while IFS= read -r g; do
    [ -n "$g" ] || continue
    if [ ! -f "VoiceInk/$g" ]; then
        fail "references: VoiceInk/$g: guarded call site missing"
    fi
done <<< "$GUARDED_CALL_SITES"

# ---- Check 3: no new hosts -------------------------------------------------
ALLOWED=""
if [ -f "$ALLOW_FILE" ]; then
    ALLOWED="$(grep -vE '^[[:space:]]*(#.*)?$' "$ALLOW_FILE" || true)"
else
    fail "hosts: $ALLOW_FILE: allow-list missing"
fi
while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ "$(first_code_line "$f")" = "#if CLOUD_PROVIDERS" ] && continue
    for host in $(grep -oE 'https://[A-Za-z0-9.-]+' "$f" | sed 's#^https://##' | sort -u || true); do
        if ! printf '%s\n' "$ALLOWED" | grep -qxF "$f $host"; then
            fail "hosts: $f: $host not in $ALLOW_FILE"
        fi
    done
done < <(find VoiceInk -type f -name '*.swift' | sort)

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
echo "OK: on-device checks passed"
