#!/bin/bash
# Pre-submission privacy/security checks for the App Store.
#
#   Tools/release_check.sh                 # builds an unsigned Release .app and checks it
#   Tools/release_check.sh path/to/X.xcarchive   # checks a signed archive (run before upload)
#
# Exits non-zero if any FAIL is reported. WARN items need a human decision.
# This covers what can be verified locally; App Store Connect answers
# (App Privacy, age rating, export compliance, DSA trader status) are manual —
# see Audit/APP_STORE_READINESS.md.

set -uo pipefail
cd "$(dirname "$0")/.."

fails=0
pass() { echo "PASS  $1"; }
warn() { echo "WARN  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }

target="${1:-}"
signed=false
if [[ -z "$target" ]]; then
    out="$(mktemp -d)"
    echo "Building unsigned Release into $out ..."
    xcodebuild build -project Helichopter.xcodeproj -scheme flappy-fly-bird -configuration Release \
        -destination 'generic/platform=iOS' -derivedDataPath "$out" CODE_SIGNING_ALLOWED=NO \
        > "$out/build.log" 2>&1 || { echo "Build failed; see $out/build.log"; exit 1; }
    app="$out/Build/Products/Release-iphoneos/Helichopter.app"
elif [[ "$target" == *.xcarchive ]]; then
    app="$(find "$target/Products/Applications" -maxdepth 1 -name '*.app' | head -1)"
    signed=true
else
    app="$target"
fi
[[ -d "$app" ]] || { echo "No .app found at $app"; exit 1; }
plist="$app/Info.plist"
binary="$app/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
echo "Checking $app"
echo

# --- Privacy manifest (required since May 2024) ---------------------------------
manifest="$app/PrivacyInfo.xcprivacy"
if [[ -f "$manifest" ]] && plutil -lint "$manifest" >/dev/null; then
    pass "Privacy manifest bundled and valid"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyTracking' "$manifest" 2>/dev/null)" == "false" ]] \
        && pass "Manifest declares no tracking" || fail "Manifest NSPrivacyTracking is not false"
else
    fail "PrivacyInfo.xcprivacy missing or malformed in the bundle"
fi
declared="$(plutil -convert xml1 -o - "$manifest" 2>/dev/null)"

# --- Required-reason APIs used by our binary must be declared ------------------
# Apple frameworks are exempt; only symbols/selectors referenced by our code count.
symbols="$( { nm -um "$binary" 2>/dev/null; strings -a "$binary" 2>/dev/null; } )"
check_reason() { # category, regex
    if grep -Eq "$2" <<< "$symbols"; then
        grep -q "$1" <<< "$declared" && pass "$1 used and declared" \
            || fail "$1 API referenced by the app but not declared in PrivacyInfo.xcprivacy"
    fi
}
check_reason NSPrivacyAccessedAPICategoryUserDefaults 'NSUserDefaults|UserDefaults'
check_reason NSPrivacyAccessedAPICategoryFileTimestamp '_stat\b|_fstat\b|_lstat\b|getattrlist|NSFileCreationDate|NSFileModificationDate|contentModificationDate|creationDate'
check_reason NSPrivacyAccessedAPICategorySystemBootTime 'systemUptime|_mach_absolute_time'
check_reason NSPrivacyAccessedAPICategoryDiskSpace 'statfs|statvfs|NSFileSystemFreeSize|NSFileSystemSize|volumeAvailableCapacity'
check_reason NSPrivacyAccessedAPICategoryActiveKeyboards 'activeInputModes'

# --- Export compliance -----------------------------------------------------------
[[ "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$plist" 2>/dev/null)" == "false" ]] \
    && pass "ITSAppUsesNonExemptEncryption = false (no custom encryption)" \
    || fail "ITSAppUsesNonExemptEncryption not set; App Store Connect will ask on every upload"

# --- Network security --------------------------------------------------------------
if /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity' "$plist" >/dev/null 2>&1; then
    warn "NSAppTransportSecurity exceptions present; justify each one in review notes"
else
    pass "No App Transport Security exceptions"
fi
# handleEventsForBackgroundURLSession is a UIApplicationDelegate selector name, not networking.
grep -v 'handleEventsForBackgroundURLSession' <<< "$symbols" \
    | grep -Eq 'NSURLSession|URLSession|CFNetwork|_socket\b|_connect\b' \
    && warn "Networking symbols found; confirm privacy answers ('Data Not Collected') still hold" \
    || pass "No networking APIs referenced (supports 'Data Not Collected')"

# --- Permissions: any protected API needs a purpose string ----------------------
for pair in "AVCaptureDevice:NSCameraUsageDescription" "CLLocationManager:NSLocationWhenInUseUsageDescription" \
            "PHPhotoLibrary:NSPhotoLibraryUsageDescription" "CNContactStore:NSContactsUsageDescription" \
            "AVAudioRecorder:NSMicrophoneUsageDescription" "SFSpeechRecognizer:NSSpeechRecognitionUsageDescription" \
            "ATTrackingManager:NSUserTrackingUsageDescription"; do
    api="${pair%%:*}"; key="${pair##*:}"
    if grep -q "$api" <<< "$symbols" && ! /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
        fail "$api used without $key"
    fi
done
pass "No protected-resource API used without a purpose string"

# --- Third-party code --------------------------------------------------------------
if [[ -d "$app/Frameworks" ]] && [[ -n "$(ls "$app/Frameworks")" ]]; then
    warn "Embedded frameworks: $(ls "$app/Frameworks" | tr '\n' ' ')— each needs its own privacy manifest and signature"
else
    pass "No embedded third-party frameworks or SDKs"
fi

# --- Debug leftovers ------------------------------------------------------------------
grep -Eq '/tmp/helichopter|XCTest|Testing\.framework' <<< "$(strings -a "$binary")" \
    && fail "Test-only paths or frameworks referenced by the app binary" \
    || pass "No test-only code in the app binary"
grep -rlE '\[(OWNER|MONITORED)[^]]*\]' "$app" >/dev/null 2>&1 \
    && fail "Placeholder text found inside the app bundle" || pass "No placeholder text in the bundle"

# --- Versioning -------------------------------------------------------------------------
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
minos="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$plist" 2>/dev/null)"
echo "INFO  Version $version ($build), minimum iOS $minos"
[[ "$build" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] && pass "Build number format valid" || fail "Build number '$build' is not numeric"

# --- Marketing icon must be opaque ------------------------------------------------------
icon="Helichopter/Assets/Assets.xcassets/AppIcon.appiconset/1024.png"
[[ "$(sips -g hasAlpha "$icon" 2>/dev/null | awk '/hasAlpha/ {print $2}')" == "no" ]] \
    && pass "1024 px App Store icon has no alpha channel" || fail "1024 px App Store icon has transparency"

# --- Signing (archives only) -------------------------------------------------------------
if $signed; then
    ents="$(codesign -d --entitlements - --xml "$app" 2>/dev/null)"
    grep -q '<key>get-task-allow</key><true/>' <<< "$ents" \
        && fail "get-task-allow is true: archive was signed for development, not distribution" \
        || pass "Distribution entitlements (no get-task-allow)"
    codesign --verify --deep --strict "$app" 2>/dev/null && pass "Code signature verifies" || fail "Code signature invalid"
else
    warn "Unsigned build: re-run with the .xcarchive from Product > Archive to check signing"
fi

# --- Release-document placeholders that block submission -----------------------------
if grep -rqE '\[(OWNER|MONITORED)[^]]*\]' Release/; then
    warn "Release/ docs still contain [OWNER]/[MONITORED SUPPORT EMAIL] placeholders (privacy policy not publishable yet)"
fi
grep -rq 'privacyPolicyURL\|Privacy Policy' Helichopter --include='*.swift' \
    && pass "In-app privacy policy link present" \
    || warn "No in-app privacy policy link (Guideline 5.1.1 requires one; see the release plan)"

echo
[[ $fails -eq 0 ]] && echo "No blocking failures." || echo "$fails blocking failure(s)."
exit $((fails > 0))
