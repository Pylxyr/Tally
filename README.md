# Tally

A private expense and budget tracker for Android, built with Flutter.

- **Safe to spend today** on the home screen: (budget minus spending before today) divided by the days left in the month, minus today's spending. It turns coral when negative.
- Month progress bar with a tick for an even spending pace, spending-by-category donut, this week's spending (Sunday to Saturday), top categories, recent activity.
- Tracker with month navigation, search and filters. Budgets with optional per-category limits. Custom categories. Recurring bills. CSV export.
- All data stays on the phone, in the app's private storage. No accounts. The release app does not ask for the internet permission.

Built for Flutter 3.50 (Dart 3.14). The UI uses the standalone `material_ui` package, which replaced `package:flutter/material.dart` in this Flutter release.

## 1. Push to a new GitHub repo

1. Create an empty repository on GitHub (no README, no .gitignore). Private is fine.
2. In this folder:

   ```bash
   git init -b main
   git add .
   git commit -m "Tally 1.0.0"
   git remote add origin https://github.com/YOUR-NAME/YOUR-REPO.git
   git push -u origin main
   ```

   Replace the URL with your repo's. Make sure `.github/workflows/release.yml` was included.

3. In the repo: **Settings → Actions → General → Workflow permissions** can stay on the default. The workflow asks for exactly what it needs.

## 2. Release the APK

```bash
git tag v1.0.0 && git push --tags
```

The **Release APK** workflow runs: it sets up Java and Flutter, generates the Android project, runs `flutter pub get`, `flutter analyze` and `flutter test`, builds release APKs (one per CPU type), names them `tally-1.0.0-<cpu>.apk` and attaches it to a GitHub Release with AI-written release notes (see below).

You can also run it by hand: **Actions → Release APK → Run workflow**. Leave the tag empty to use the version in `pubspec.yaml`, or type one such as `v1.0.1`.

For the next release, use a new tag (`v1.0.1`, and so on). The Android version code comes from the workflow run number, so it always goes up.

### Release notes

The release job runs `tool/release_notes.py`. It reads the commits since the previous `v*` tag, asks Claude to turn them into short Added / Fixed / Changed / Removed notes for app users, and adds a "Full changelog" link and install instructions. If there is no API key, or the request fails, the notes fall back to a plain list of commit subjects, so a release is never blocked (a warning shows in the run). The first release has no earlier tag, so its notes summarise the app from the README and the commits.

Add one repository secret to turn the AI notes on: **`ANTHROPIC_API_KEY`**. To use a different model, set a repository variable `CHANGELOG_MODEL` (default `claude-sonnet-5-5`). Only the release job can see the key, never the build. Write clear commit messages; they are the input.

## 3. Where the APK appears

- **Releases** on the right side of your repo's front page, under **Assets**: three files, `tally-1.0.0-arm64-v8a.apk`, `tally-1.0.0-armeabi-v7a.apk` and `tally-1.0.0-x86_64.apk`. They are the same app built for different processors.
- Also on the workflow run page under **Artifacts** (`tally-apk`), together with the run's **summary** page, which lists each file's size and the biggest things inside the APK.

**Which one is mine?** `arm64-v8a` fits almost every phone made since about 2017. Use `armeabi-v7a` only for an older 32-bit phone, and `x86_64` for emulators and Chromebooks. If the app says it can't be installed, try the other file.

## 4. Install on your phone

1. On the phone, open your repo's **Releases** page in a browser and download `tally-1.0.0-arm64-v8a.apk`. (For a private repo, sign in to GitHub in that browser.)
2. Open the downloaded file. Android will ask you to allow installs from that browser ("Install unknown apps"). Allow it, then go back and tap Install.
3. If Play Protect warns about an unknown app, choose to install anyway. This is expected for an app that is not from the Play Store.

Or from a computer with USB debugging on: `adb install tally-1.0.0-arm64-v8a.apk`.

**Important:** without your own signing key (next section) every release is signed with a different throwaway debug key. Android will refuse to install a new release over an older one. Uninstall the old app first (which deletes its data, so export a CSV first), or set up your own key once and every later release will update in place.

## 5. Optional: sign releases with your own key

Do this once. Create a keystore (keep the file and passwords somewhere safe; if you lose them you can never update the app in place):

```bash
keytool -genkeypair -v -keystore tally-release.jks -alias tally \
  -keyalg RSA -keysize 2048 -validity 10000
```

Turn it into one line of base64:

```bash
base64 -w0 tally-release.jks                 # Linux
base64 -i tally-release.jks | tr -d '\n'     # macOS
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("tally-release.jks"))
```

In your repo go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the base64 text from above |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `tally` (or the alias you chose) |
| `ANDROID_KEY_PASSWORD` | the key password (optional; defaults to the keystore password) |

Repository secrets belong to one repo, so add them to Tally even if another repo of yours already has the same ones.

With the first three present, the workflow signs the APK with your key. Without them it falls back to debug signing, so the very first release needs no setup. Never commit the `.jks` file (it is in `.gitignore`).

## Running it locally

You need Flutter 3.50 or newer and JDK 17.

```bash
bash tool/prepare_android.sh     # creates android/ with the right name, id and icon
flutter pub get
flutter analyze
flutter test
flutter run
```

## How the Android project is handled

`android/` is **generated, not committed**. `tool/prepare_android.sh` runs `flutter create` for the Flutter version you have, then applies:

- package id `com.tallyapp.tally` (checked afterwards; the script stops if it is wrong),
- app label **Tally**,
- the launcher icon from `android_overlay/res` (adaptive and monochrome icons for Android 8+, PNGs for older versions),
- a check that the main manifest does not request internet access.

CI and your machine run the same script, so they produce the same result and the project never goes stale against a new Flutter. If you would rather commit `android/`, run the script, delete the `/android/` line from `.gitignore`, and commit it; the script still works on top of it.

## App size

Flutter apps carry the Flutter engine as native code, one copy per CPU type. A single "fat" APK holds three copies, which is why it was about 48 MB. The workflow now builds one APK per CPU type (`--split-per-abi`), so the file you install holds one copy. The app itself is identical, so nothing is lost. Expect roughly a third of the old size; the run summary page shows the exact numbers.

Debug symbols are also split out of the app (`--split-debug-info`) and kept as a separate `tally-symbols` artifact on each run, so crash stack traces can still be read with `flutter symbolize`.

Things deliberately not done, because each one costs something: dropping 32-bit or x86 builds (some devices could no longer install), and compressing native libraries inside the APK (smaller download, larger installed app and slower install).

## Things worth knowing

- **Recurring bills** are added when the app is opened or brought back to the foreground, not by a background service. If a due day passes while the app is closed, the expense is added with the right date the next time you open it. A bill only creates expenses dated on or after the day you created (or resumed) it. In months shorter than the due day, it lands on the last day.
- **Dashboard** always shows the current calendar month. Use the Tracker to look at other months.
- **Data file:** `tally_data.json` in the app's private storage. If it ever cannot be read, Tally keeps the old file next to it and starts fresh.
- `flutter analyze` in the workflow runs with `--no-fatal-infos`, so style suggestions do not block a release; warnings and errors still do.

## Project layout

```
lib/logic/    budget maths, recurring bills, models, CSV (pure Dart, unit tested)
lib/state/    app state and the local JSON store
lib/ui/       theme, screens, sheets, charts
test/         unit tests for the budget maths
tool/         prepare_android.sh, release_notes.py
android_overlay/res/   launcher icon resources
.github/workflows/release.yml
```
