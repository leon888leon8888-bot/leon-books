# iOS physical device build and validation

This project can be edited on Windows, but iOS build, signing, simulator, and physical device validation must run on macOS with Xcode.

Official references:

- Flutter iOS setup: https://docs.flutter.dev/get-started/install/macos/mobile-ios?tab=physical
- Flutter iOS deployment: https://docs.flutter.dev/deployment/ios

## Current blocker in this workspace

The current machine is Windows 10 and does not have Flutter or Xcode installed. It cannot compile, sign, or run an iOS app on a physical iPhone.

The backend is already deployed and token-protected:

- API base URL: `http://47.251.109.233/reader-rebuild-1961c0e97312/api`
- Device token: keep it outside git and enter it in the app setup screen.

## Mac prerequisites

Install or verify these tools on the Mac:

```bash
xcodebuild -version
flutter --version
pod --version
flutter doctor -v
```

Minimum requirements:

- macOS with current Xcode installed.
- Xcode command line tools selected.
- Flutter SDK installed and on `PATH`.
- CocoaPods installed.
- Apple ID added in Xcode.
- iPhone trusted by the Mac.
- Developer Mode enabled on the iPhone.

## Bootstrap the iOS runner

From the Flutter mobile directory on the Mac:

```bash
cd /path/to/reader-rebuild/mobile
chmod +x scripts/bootstrap_ios.sh
IOS_BUNDLE_ID=com.yourname.readerrebuild \
APP_DISPLAY_NAME="Leon的书" \
./scripts/bootstrap_ios.sh
```

What the script does:

- Generates the missing `ios/` runner with `flutter create . --platforms=ios`.
- Runs `flutter pub get`.
- Sets the iOS bundle identifier.
- Adds a temporary HTTP App Transport Security allowance for the current self-hosted backend.
- Runs `pod install`.
- Builds a debug iOS app with `--no-codesign` as a compile preflight.

## Sign in Xcode

Open:

```bash
open ios/Runner.xcworkspace
```

Then:

1. Select `Runner`.
2. Open `Signing & Capabilities`.
3. Enable `Automatically manage signing`.
4. Select your Team.
5. Keep the bundle identifier unique.
6. Select the connected iPhone as the run target.
7. Press Run once from Xcode if provisioning needs to be created.

If signing fails, change `IOS_BUNDLE_ID` to a globally unique value and rerun the bootstrap script.

## Run on a physical iPhone

List devices:

```bash
flutter devices
```

Run after Xcode signing is configured:

```bash
IOS_DEVICE_ID=<device-id-from-flutter-devices> ./scripts/bootstrap_ios.sh --run
```

Or run directly:

```bash
flutter run -d <device-id-from-flutter-devices>
```

## If you sign with QuanNengQian on iPhone

QuanNengQian can help with the last mile: signing and installing an IPA on the phone. It does not compile Flutter/Dart source into an iOS binary.

Use this route when you want to avoid connecting the iPhone to Xcode every time:

```bash
cd /path/to/reader-rebuild/mobile
chmod +x scripts/bootstrap_ios.sh scripts/package_unsigned_ipa.sh
./scripts/bootstrap_ios.sh
./scripts/package_unsigned_ipa.sh
```

The unsigned IPA will be created at:

```bash
build/ios/unsigned/LeonBooks-unsigned.ipa
```

Then transfer this IPA to the iPhone and sign/install it with QuanNengQian.

Important limits:

- The IPA still must be compiled on macOS or cloud macOS first.
- The certificate and provisioning profile used by QuanNengQian must match the device and bundle id.
- If installation fails, first check bundle id, certificate expiry, UDID inclusion, and entitlements.
- This route validates install and manual runtime behavior, but it does not give the same debug logs as `flutter run` or Xcode.

## App setup values

On first launch:

- API URL: `http://47.251.109.233/reader-rebuild-1961c0e97312/api`
- Device token: paste the server token from your secure local note.

Do not commit the token into the repo.

## Validation checklist

Run these checks on the physical iPhone:

1. App installs and launches without crash.
2. Setup screen accepts backend URL and device token.
3. Bookshelf loads.
4. Search for a known book, such as `三体`, returns grouped results.
5. Open one text result and load chapter list.
6. Open a chapter and verify text rendering, dark mode, font size, line height, progress slider, and directory navigation.
7. Start TTS playback and verify audio output, speed control, and sleep timer.
8. Search/open a comic result and verify long-scroll image loading, prefetch, and error fallback.
9. Download one text chapter for offline reading and reopen it with network disabled.
10. Leave the app in reading mode for at least 10 minutes and verify no crash or audio interruption.

## Known iOS issues and fixes

- Network request fails immediately: ATS is blocking plain HTTP. Rerun the script with `IOS_ALLOW_HTTP=1`, or preferably deploy HTTPS on the backend.
- `pod install` fails: run `sudo gem install cocoapods`, then `pod repo update`.
- Physical device does not appear: reconnect USB, trust the Mac, enable Developer Mode, then rerun `flutter devices`.
- Signing fails: use a unique bundle id and configure a Team in Xcode.
- Audio does not play: confirm silent mode, volume, and that `just_audio` pods were installed.

## Production recommendation

The current backend is HTTP. For long-term iOS stability, put the backend behind HTTPS and remove the broad ATS allowance before distributing beyond personal testing.
