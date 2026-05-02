# No-Mac iOS physical test path

Use this when you do not have a Mac but need to install the app on a real iPhone.

## Recommended path

The practical chain is:

1. GitHub Actions macOS runner compiles the Flutter source into an unsigned IPA.
2. Download the IPA artifact.
3. Transfer the IPA to the iPhone.
4. Sign and install it with QuanNengQian.
5. Launch the app and run the real-device checklist.

This avoids owning a Mac, but it does not remove Apple's signing requirement. QuanNengQian must still provide a certificate/profile that can install on your phone.

## Prepare the GitHub repository

Create a private GitHub repository and upload the `reader-rebuild` project directory.

Do not upload local secret files such as:

- `.codex-ops/`
- API token text files
- existing IPA patch folders

The workflow file is already included:

- `.github/workflows/ios-unsigned-ipa.yml`

## Build the IPA in GitHub Actions

Open your GitHub repository:

1. Go to `Actions`.
2. Select `Build unsigned iOS IPA`.
3. Click `Run workflow`.
4. Keep the default app name, or set your own.
5. Set a stable bundle id, for example `com.yourname.readerrebuild`.
6. Wait for the workflow to finish.
7. Download the `unsigned-ios-ipa` artifact.

The artifact contains:

```text
LeonBooks-unsigned.ipa
```

## Sign and install with QuanNengQian

On the iPhone:

1. Import the unsigned IPA into QuanNengQian.
2. Choose a certificate/profile that supports your device.
3. Sign the IPA.
4. Install it.
5. If iOS asks you to trust the developer certificate, trust it in Settings.

Common installation failures:

- Bundle id conflicts with an already installed app.
- Certificate expired or revoked.
- Provisioning profile does not include your iPhone UDID.
- Entitlements do not match the certificate/profile.
- The signing tool cannot resign Flutter frameworks correctly.

If installation fails, rebuild with a new bundle id first. If it still fails, replace the certificate/profile in QuanNengQian.

## First launch setup

Use these values on the setup screen:

```text
API URL:
http://47.251.109.233/reader-rebuild-1961c0e97312/api

Device token:
Paste the server token manually. Do not store it in GitHub.
```

## Real-device validation checklist

1. App launches without crash.
2. Backend URL and token connect successfully.
3. Bookshelf loads.
4. Search returns text, comic, and audio category labels.
5. Text book opens chapter list and chapter content.
6. Reader supports immersive mode, dark mode, font size, line height, progress slider, and directory.
7. TTS can play, pause, change speed, and continue to the next chapter.
8. Comic reader scrolls smoothly, lazy-loads images, and prefetches adjacent content.
9. Offline chapter download works, then opens with network disabled.
10. Keep the app open for at least 10 minutes and confirm no crash.

## When you need automated real-device testing

For automation without a physical Mac, use a cloud device provider such as BrowserStack, Sauce Labs, Kobiton, or AWS Device Farm.

That path usually requires:

- A signed installable IPA.
- A test script, normally Appium/XCUITest.
- Paid cloud-device minutes.

For the current first-version validation, manual real-device testing through QuanNengQian is faster and cheaper.
