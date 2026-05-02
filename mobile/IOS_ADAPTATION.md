# iOS adaptation notes

## Current direction

The mobile shell is being optimized for iPhone-first usage:

- iOS page transitions
- Cupertino color and background tuning
- tighter text scaling for smaller phone screens
- single-user entry flow without login

## Build requirements

According to Flutter's official iOS setup documentation, building and signing an iOS app requires:

- macOS
- Xcode
- CocoaPods

This Windows machine can keep evolving the Dart source, but the final iOS build, signing, simulator run, and App Store packaging must happen on a Mac.

## Immediate next steps

1. Keep evolving the app shell and reading experience here.
2. Move the project to a Mac with Flutter + Xcode installed.
3. Run `scripts/bootstrap_ios.sh` from the `mobile` directory.
4. Open `ios/Runner.xcworkspace` and configure Xcode signing.
5. Run on a physical iPhone with `flutter run -d <device-id>`.

Detailed runbook:

- [IOS_DEVICE_RUNBOOK.md](C:/Users/Administrator/Documents/Playground/reader-rebuild/mobile/IOS_DEVICE_RUNBOOK.md)

The bootstrap script also patches iOS App Transport Security for the current HTTP backend. This is acceptable for personal physical-device testing, but the production path should be HTTPS.

## iOS UX priorities

The next iOS-facing upgrades should be:

1. Cupertino-style tab and settings surfaces
2. EPUB reader page optimized for iPhone safe areas
3. Larger tap targets for chapter navigation and TTS controls
4. Dynamic type and dark mode tuning
