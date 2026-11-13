#!/usr/bin/env bash
# Prepares the android/ folder: generates it with `flutter create` when it is
# missing, then applies Tally's app name and launcher icon, and checks the
# package id. Safe to run any number of times, locally or in CI.
set -euo pipefail

ORG="com.tallyapp"
NAME="tally"
LABEL="Tally"
APP_ID="$ORG.$NAME"

cd "$(dirname "$0")/.."

MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "Generating android/ with flutter create ($APP_ID)..."
  tmp="$(mktemp -d)"
  # Generated in a temp folder so nothing in this project is overwritten.
  flutter create --no-pub --platforms=android \
    --org "$ORG" --project-name "$NAME" "$tmp/$NAME" > /dev/null
  rm -rf android
  cp -R "$tmp/$NAME/android" android
  rm -rf "$tmp"
fi

# App name shown under the launcher icon.
sed -i.bak -E "s/android:label=\"[^\"]*\"/android:label=\"$LABEL\"/" "$MANIFEST"
rm -f "$MANIFEST.bak"

# Launcher icon: adaptive icon (Android 8+) plus PNGs for older versions.
cp -R android_overlay/res/. android/app/src/main/res/

# Checks. These fail loudly instead of shipping the wrong name or id.
if ! grep -q "android:label=\"$LABEL\"" "$MANIFEST"; then
  echo "ERROR: could not set the app label in $MANIFEST" >&2
  exit 1
fi
if ! grep -q 'android:icon="@mipmap/ic_launcher"' "$MANIFEST"; then
  echo "ERROR: $MANIFEST does not use @mipmap/ic_launcher as its icon" >&2
  exit 1
fi
if ! grep -Eq "applicationId *=? *\"$APP_ID\"" android/app/build.gradle*; then
  echo "ERROR: android/app/build.gradle does not use the package id $APP_ID." >&2
  echo "Delete the android/ folder and run this script again." >&2
  exit 1
fi
if grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  echo "ERROR: the main manifest asks for internet access; Tally must not." >&2
  exit 1
fi

echo "android/ is ready: $APP_ID, label \"$LABEL\", Tally launcher icon."
