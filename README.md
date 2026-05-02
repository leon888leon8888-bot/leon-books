# Reader Rebuild

An owned, rebuildable reading app skeleton for self-hosted single-user use.

## Structure

- `backend`
  - Runnable Node.js API
- `mobile`
  - Flutter client skeleton

## V1 goals

- Single-user entry without login
- Bookshelf
- Source management
- Source auto validation
- Real upstream search
- Real chapter list + chapter content
- Real HTTP TTS proxy
- Bookshelf backup
- Source backup
- Progress sync

## Legado-inspired optimizations

This rebuild now includes three capabilities borrowed from the overall product shape of [gedoor/legado](https://github.com/gedoor/legado):

- Unified import hub
  - Supports `bookSource`, `rssSource`, `replaceRule`, `httpTTS`, `theme`, `readConfig`, `addToBookshelf`
- HTTP TTS engine management
  - Stores multiple remote TTS engines for listen mode
- Reading configuration
  - Stores font size, line height, paragraph spacing, font family, theme, page mode, immersive mode, cleanup, progress, and TTS continuity preferences

## Reading experience

- Text reader
  - Immersive mode with tap-to-toggle toolbars
  - Paper and night themes
  - Font size, line height, paragraph spacing, font family, bold, and justification controls
  - Content purification with replace rules and ad-like line filtering
  - Chapter navigation and long-form progress slider
  - Offline chapter payload cache with network fallback
  - Built-in TTS playback using the configured HTTP TTS engines, speed control, sleep timer, and auto-next-chapter
- Comic reader
  - Dedicated long-strip comic reader
  - Cached image loading, nearby chapter prefetch, and per-image failure fallback
  - Manual offline chapter download with image asset caching
  - Immersive mode, paper/night theme, chapter navigation, and long-form progress slider
  - Text fallback when a source marked as comic resolves to text content

## iOS-first track

- The mobile shell is now being tuned toward iPhone-first behavior
- See [IOS_ADAPTATION.md](C:/Users/Administrator/Documents/Playground/reader-rebuild/mobile/IOS_ADAPTATION.md)
- See [IOS_DEVICE_RUNBOOK.md](C:/Users/Administrator/Documents/Playground/reader-rebuild/mobile/IOS_DEVICE_RUNBOOK.md) for Mac-side physical iPhone build and validation
- See [CLOUD_IOS_BUILD.md](C:/Users/Administrator/Documents/Playground/reader-rebuild/CLOUD_IOS_BUILD.md) for the no-Mac cloud build plus QuanNengQian install path
- See [NO_MAC_IPA_QUICKSTART_CN.md](C:/Users/Administrator/Documents/Playground/reader-rebuild/NO_MAC_IPA_QUICKSTART_CN.md) for the Chinese no-Mac IPA quickstart
- Final iOS build and signing still require macOS + Xcode

## Local start

### Backend

```powershell
cd C:\Users\Administrator\Documents\Playground\reader-rebuild\backend
npm install
npm run dev
```

Default listen address: `http://127.0.0.1:3030`

### Backend smoke test

```powershell
cd C:\Users\Administrator\Documents\Playground\reader-rebuild\backend
npm run smoke
```

### Import filtered QRead sources

This rebuild can import the already-filtered source set exported from your live QRead backend.

```powershell
cd C:\Users\Administrator\Documents\Playground\reader-rebuild\backend
npm run import:qread-sources
```

Default import file:

- [qread-current-book-sources-2026-05-01.json](C:/Users/Administrator/Documents/Playground/.codex-ops/qread-current-book-sources-2026-05-01.json)

### Run source validation once

```powershell
cd C:\Users\Administrator\Documents\Playground\reader-rebuild\backend
npm run validate:sources
```

The validation policy is:

- Run against every imported source once per day
- Disable a source immediately when the validation URL fails
- Re-enable that same source automatically on a later successful validation

Useful environment variables:

- `SOURCE_VALIDATION_TIMEOUT_MS`
- `SOURCE_VALIDATION_CONCURRENCY`
- `SOURCE_VALIDATION_HOUR`
- `SOURCE_VALIDATION_MINUTE`
- `SOURCE_VALIDATION_SEARCH_KEY`
- `QREAD_API_BASE_URL`
- `QREAD_ACCESS_TOKEN`
- `QREAD_TIMEOUT_MS`

### QRead bridge smoke test

This verifies the new real-reading bridge against the upstream QRead engine.

```powershell
cd C:\Users\Administrator\Documents\Playground\reader-rebuild\backend
$env:QREAD_API_BASE_URL='http://47.251.109.233/api/5'
$env:QREAD_ACCESS_TOKEN='replace-with-server-token'
npm run smoke:qread
```

### Flutter client

Flutter is not installed on this machine yet, so the client is currently checked in as source only.

After Flutter is installed:

```powershell
cd C:\Users\Administrator\Documents\Playground\reader-rebuild\mobile
flutter pub get
flutter run
```

For iPhone-side signing tools, first build an unsigned IPA on macOS:

```bash
cd /path/to/reader-rebuild/mobile
./scripts/package_unsigned_ipa.sh
```

Output:

- `build/ios/unsigned/LeonBooks-unsigned.ipa`

## API endpoints

- `GET /api/bootstrap`
- `GET /api/me`
- `GET /api/library/overview`
- `POST /api/import/:pathType`
- `GET /api/bookshelf`
- `POST /api/bookshelf`
- `PATCH /api/bookshelf/:id/progress`
- `GET /api/sources`
- `POST /api/sources/import`
- `POST /api/sources/:id/check`
- `GET /api/sources/validation/state`
- `POST /api/sources/validation/run`
- `GET /api/rss-sources`
- `GET /api/replace-rules`
- `GET /api/tts-engines`
- `GET /api/tts/default`
- `GET /api/tts/stream`
- `GET /api/themes`
- `GET /api/read-config`
- `PUT /api/read-config`
- `GET /api/reading/status`
- `GET|POST /api/reading/search`
- `GET|POST /api/reading/explore`
- `GET|POST /api/reading/book/resolve`
- `GET|POST /api/reading/chapters`
- `GET|POST /api/reading/content`
- `GET /api/sync/overview`
- `POST /api/sync/bookshelf/backup`
- `POST /api/sync/sources/backup`
- `POST /api/sync/progress/push`
- `PATCH /api/sync/settings`

## Default behavior

- Single-user mode is enabled by default
- First app entry only asks for backend URL
- Backend seeds an `owner-local` founder account
- Backup and sync are enabled by default
- Backend state is stored in `backend/data/db.sqlite`
- If an old `backend/data/db.json` exists, the backend migrates it into SQLite on first start and keeps the JSON file as a rollback backup
- Source validation is scheduled automatically when the backend process starts
- When `QREAD_API_BASE_URL` and `QREAD_ACCESS_TOKEN` are set, the backend can reuse the live QRead engine for search, reading, and TTS

## Next steps

1. Deploy the backend to your cloud server
2. Install Flutter and run the mobile shell
3. Bind the mobile client to the new reading and TTS endpoints
4. Add an admin dashboard if you want multi-device management
