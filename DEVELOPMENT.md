# Development Plan

Rekora should start as a mobile app.

The first target is iPhone. The first technical goal is not a polished app. The
first goal is proving that we can request Apple Music access, read library
data, and save a local backup file.

## First Build Milestone

Build a tiny SwiftUI iPhone app that can:

- Open to one simple screen.
- Ask for Apple Music permission.
- Show whether permission was granted.
- Fetch the user's Apple Music playlists.
- Save a local JSON snapshot.
- Show the date of the latest snapshot.

This milestone proves the core product is possible.

## Current Checkpoint

The first iPhone scaffold now exists in `Rekora.xcodeproj`.

- `Rekora` is a SwiftUI app target with a simple first screen.
- `RekoraTests` is an XCTest target for lightweight project checks.
- The current app screen can request Apple Music permission and show whether
  access is granted, denied, restricted, or not requested yet.
- The current app screen checks Apple Music subscription and Sync Library
  readiness before requesting playlist metadata.
- Real-device validation on the connected physical iPhone found 19 Apple Music
  playlists, matching the user's expected playlist count.
- The debug-only `Check Playlists` tool maps common MusicKit token,
  subscription, library, and request failures into actionable setup messages
  instead of showing a bare `Unknown error`.
- The successful debug playlist check shows only the playlist count on screen,
  avoiding previewing personal playlist names.
- The current app screen can save a real backup snapshot from Apple Music data:
  songs, albums, playlists, and ordered playlist tracks.
- Playlist track entries keep both MusicKit's reported `position` and Rekora's
  observed `snapshotOrder` so backups remain useful when MusicKit reports
  duplicated or all-zero positions.
- Saved backup manifests include `playlistOrderWarningCount`, a small count of
  playlists whose MusicKit-reported positions do not look like contiguous
  zero-based order. The home screen uses that count to tell users Rekora saved
  observed order too in a distinct inline warning note under the latest-backup
  summary.
- The bundle identifier is currently `app.rekora.ios` and must match the
  Apple Developer portal App ID before MusicKit work begins.
- Signing currently uses a personal Apple Developer team in Xcode.
- The app launches in the iPhone Simulator.
- The app can save a first local JSON snapshot with real playlist metadata.
- The app can export the latest snapshot through an iOS Files save flow.
- The app reads a small local latest-backup manifest on launch so the first
  screen can show the latest saved backup without decoding a full snapshot.
- The backup detail screen compares the selected backup with the previous
  local backup and shows a read-only Changes summary for basic library and
  playlist differences.
- The backup detail screen can run a read-only Restore preview match check
  against Apple Music. This uses MusicKit lookup/search only and does not
  create, edit, reorder, or delete Apple Music playlists.
- After a live match check, the backup detail screen can prepare a
  confirmation-gated one-playlist rebuild. The rebuild path creates a new
  Apple Music playlist only, adds confident matched tracks in backup order,
  and skips tracks that need review. Metadata-only search matches are not
  automatically rebuilt.
- Real-device provisioning works for the connected iPhone after enabling
  Developer Mode and trusting the local development profile.
- Xcode automatic signing created an `iOS Team Provisioning Profile` for
  `app.rekora.ios`.
- MusicKit App ID setup is sufficient for the current real-device playlist and
  track metadata checks. Playlist mutation and recreation are implemented
  behind confirmation, and a disposable one-playlist rebuild was validated on
  the physical iPhone on June 19, 2026.

## Release Tagging Note

The current `main` branch is a reasonable candidate for an annotated `v0.1.0`
proof-of-concept tag because it includes the iOS scaffold, MusicKit permission
flow, real-device playlist track backup, latest backup status, tests, and
visual docs.

Do not treat this as a functional MVP release yet. The first checkpoint now has
real-device MusicKit playlist track backup, a first user-controlled export
flow, a basic read-only snapshot change view, and a read-only Restore preview
with simulator-tested Apple Music match checking and a confirmation-gated
new-playlist rebuild path. Real-device validation on June 19, 2026 confirmed
the app can create a new Apple Music playlist from a disposable backup
playlist without changing existing playlists.

Suggested tag when ready:

```sh
git tag -a v0.1.0 -m "Initial iOS proof-of-concept"
git push origin v0.1.0
```

## First-Time Local Setup

Use these steps when setting up Rekora on a new Mac or when a new developer
needs to run the app for the first time.

### 1. Install Xcode

Install the current Xcode from the Mac App Store or Apple Developer downloads,
then open it once so it can finish installing platform support.

Rekora is an iPhone-first SwiftUI app. The project is opened from:

```sh
open Rekora.xcodeproj
```

In Xcode, select the `Rekora` scheme. Use an iPhone Simulator for basic UI and
unit-test work. Use a real iPhone for Apple Music library access and real
backup validation.

### 2. Keep Command-Line Builds Project-Local

Command-line Xcode may still point at the standalone Command Line Tools after
installing Xcode. Keep this project-specific by setting `DEVELOPER_DIR` on
Rekora commands instead of changing the global `xcode-select` setting:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme Rekora \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath /private/tmp/RekoraSimulatorDerivedData
```

Run the test suite with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -scheme Rekora \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath /private/tmp/RekoraTestDerivedData
```

If that simulator name is not installed, choose an available iPhone simulator
from Xcode's device picker or run `xcrun simctl list devices available`.

### 3. Set Signing and Bundle ID

The current bundle identifier is:

```text
app.rekora.ios
```

For local development, select the `Rekora` target in Xcode, open `Signing &
Capabilities`, and choose your Apple Developer team. If your team does not
appear, sign in from Xcode's Accounts settings first. The account needs to be
able to create or use an explicit App ID with MusicKit enabled. If
`app.rekora.ios` is not available in your Apple Developer account, use your own
reverse-DNS bundle ID, then make the same change in the Apple Developer portal.

The important rule is that Xcode and the Apple Developer portal must agree on
the exact same bundle identifier.

### 4. Enable MusicKit

Rekora reads Apple Music library data through MusicKit. Before real-device
MusicKit testing, create or update the matching App ID in the Apple Developer
portal:

- Use an explicit App ID, not a wildcard App ID.
- Make sure the App ID bundle identifier matches Xcode.
- Enable the MusicKit app service for that App ID.
- Let Xcode refresh signing, or regenerate the provisioning profile if needed.

The app already includes the Apple Music privacy message:

```text
Rekora needs access to your Apple Music library so it can back up your songs, albums, and playlists.
```

If MusicKit setup is wrong, Rekora may build but fail when checking playlists
or creating a real backup.

### 5. Run on a Real iPhone

Use a real iPhone when testing Apple Music permission, playlist reading, and
backup creation.

In Xcode, plug in the iPhone, choose it from the run destination picker, then
press Run.

On the iPhone:

- Sign in to Apple Music with an account that has an active subscription.
- Turn on Sync Library if you expect cloud library data to appear.
- Enable Developer Mode if iOS asks for it, then restart the phone.
- Unlock the phone before running from Xcode.
- Trust the Mac/development profile if prompted.
- Allow Apple Music access when Rekora asks.

Hardware note: during real-device testing, plugging the iPhone directly into
the Mac was more reliable than using the available Anker hub. If Xcode does not
see the phone, try a direct cable first.

### 6. Real-Device Smoke Test

After the app launches on the phone:

1. Tap `Allow Apple Music Access`.
2. Confirm the app shows that Apple Music is ready.
3. Tap `Create Backup`.
4. Confirm the latest-backup summary appears.
5. Open `View Backup`.
6. Use `Check Apple Music Matches` in Restore preview to check the backup
   against Apple Music without changing playlists.
7. If a tiny test playlist is ready to verify, use the rebuild action only
   after confirming Rekora will create a new playlist. Confirm that existing
   playlists were not edited, reordered, or deleted.
8. Use `Save Copy to Files` if you want a visible exported backup.
9. Use `Check backup` to confirm Rekora can read a selected backup file.

Backup, backup-check, change-summary, and match-check flows are read-only with
respect to Apple Music. The rebuild action is the only current Apple Music
write path; it is confirmation-gated and creates a new playlist instead of
editing an existing one. The match check and rebuild path are implemented,
simulator-tested, and validated on a physical iPhone with a disposable
30-track playlist.

For a generic device build-for-testing check, use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Rekora.xcodeproj \
  -scheme Rekora \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/RekoraDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

## Permissions We Need

We should be able to build this as a mobile app, but Apple requires a few
things:

- An Apple Developer account.
- An explicit App ID for Rekora.
- The MusicKit app service enabled for that App ID.
- The same bundle identifier in Xcode and the Apple Developer portal.
- A clear `NSAppleMusicUsageDescription` message in the app.
- User permission through MusicKit before reading Apple Music data.

In plain English: Apple needs to know the app is allowed to use MusicKit, and
the user needs to say yes before Rekora can see their Apple Music data.

Rekora now checks MusicKit authorization on launch and requests access only
after the user taps `Allow Apple Music Access`. After access is granted, the app
checks Apple Music subscription and Sync Library readiness before it asks for
library data. Rekora can save songs, albums, playlists, and ordered playlist
tracks into a local backup snapshot. Current backup and validation code is
read-only with respect to Apple Music; it does not create, edit, reorder, or
delete songs or playlists. The current rebuild code is the exception: after a
live match check and explicit confirmation, it can create a new playlist with
confident matched tracks only. It does not edit or delete existing Apple Music
playlists.

Current live validation finding: the permission flow can be completed, and
Rekora now avoids surfacing a bare `Unknown error`. Real-device testing on the
connected iPhone successfully exported a schema v1 backup with 9,453 songs, 93
albums, 19 playlists, and 10,654 playlist-track entries. The exported file
saved through Files matched the private app snapshot byte-for-byte. The
temporary `Check Playlists` and Developer Validation sections are hidden from
the main home screen by default and are not available in release builds. In
debug builds, they require the `-RekoraDeveloperValidation` launch argument. If
MusicKit fails in another environment, the app should name the likely setup
area: Apple Developer/MusicKit setup, Apple Music sign-in, privacy
acknowledgement, subscription status, Sync Library status, or simulator/device
conditions.

## First Permission Message Draft

Rekora needs access to your Apple Music library so it can save backups of your
songs, albums, and playlists.

## What We Should Test First

- Large backup/export stress testing for issue `#19`.
- Larger playlist rebuild stress testing for issue `#18`, preferably with
  disposable playlists or a separate Apple Music account.
- Error-handling sweeps for issue `#20`: permission denial, no subscription,
  no network, empty library, huge library, export failure, corrupt backup
  files, and playlist creation failure.
- Final MVP validation for issue `#21` after the remaining hardening issues
  are complete.

## Things We Should Not Build First

- Accounts.
- Payments.
- Cloud sync.
- A web dashboard.
- Fancy restore screens.
- Automatic scheduled backups.

Those can wait until the basic MusicKit flow works.

## Questions To Ask Before Each Build Step

- What is the smallest thing we need to prove next?
- Does this require a real Apple device, or can it run in the simulator?
- Does this require Apple Developer portal setup?
- Are we reading user data, writing user data, or both?
- What should happen if Apple Music permission is denied?
- What should happen if the user does not have an active Apple Music
  subscription?
- Can this feature work without storing anything on our servers?

## Backup Schema

The current backup schema is versioned JSON and is documented in
`BACKUP_SCHEMA.md`.

The schema is the portable backup contract, not necessarily the app's local
database. The first implementation can store snapshots as JSON files; a later
database can index those snapshots for faster browsing, diffing, or restore
planning.

## Local Snapshot Storage

Rekora currently saves schema v1 snapshots as JSON files in the app's private
Documents directory under `Snapshots/`. The current real backup scope is songs,
albums, playlist metadata, and ordered playlist track entries. Playlist track
`addedAt` dates are stored when MusicKit exposes them, but most entries may not
include that value. Playlist track `position` keeps MusicKit's reported value,
and `snapshotOrder` keeps Rekora's observed entry order as a fallback for
duplicated, all-zero, sparse, or otherwise invalid positions.

The snapshot song count is intentionally broader than the top-level Apple Music
saved-song count. It includes saved library songs plus songs Rekora discovers
inside playlists, so it may be much larger than the `MusicLibraryRequest<Song>`
count shown by the temporary validation probe.

Rekora also writes `latest-backup.json`, a small manifest with the latest
snapshot filename, date, schema version, song count, album count, playlist
count, and playlist-track count. The home screen uses that manifest so it can
show backup status quickly even when snapshots contain large libraries.

Snapshot and manifest files are written with iOS file protection set to
`complete`. Rekora does not upload backups to a Rekora server. Because the
files stay in the app sandbox and are not excluded from OS backups, they may be
included in the user's normal iPhone or iCloud device backups depending on iOS
settings.

Export is separate from local storage. A locally saved snapshot stays inside
Rekora's app sandbox. The backup detail screen now offers `Save Copy to Files`,
which asks iOS to let the user choose where to keep a visible copy outside
Rekora. Exported files use friendly local-time names such as
`Rekora Backup - 2026-06-06 at 8-44 PM.json`, while internal snapshot files
keep UTC-safe technical names such as
`rekora-snapshot-2026-06-07T004450Z.json`.

While a backup is running, the UI reminds users that Rekora can only save the
playlist order Apple Music provides. That is intentionally honest: if Apple
returns playlist entries in the wrong order and Rekora has no previous trusted
snapshot to compare against, the hidden true order is not knowable without
guessing.

After a backup finishes, Rekora gives a visible inline validation note when one
or more playlists had unusual Apple-reported positions. This keeps the warning
efficient: the app stores a count in `latest-backup.json` instead of adding a
new screen or heavy validation workflow.

During real-device testing, plugging the iPhone directly into the Mac exposed
the device in Xcode more reliably than using the available Anker hub.

The current UI uses a Sanzo Wada-inspired light/dark theme. The home screen
uses friendly backup language and avoids raw filenames, raw timestamps, and
JSON terminology for non-technical users.
