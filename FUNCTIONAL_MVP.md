# Functional MVP Criteria

This document defines when Rekora can be called functionally complete, with
only UI polish and small bug fixes remaining.

Rekora is functionally complete when a user can grant Apple Music access,
create a real local backup, export it, inspect what changed, and rebuild at
least supported playlists from that backup without needing to understand the
underlying JSON format.

## Completion Checklist

- [x] Apple Music access
  - [x] The app requests Apple Music permission.
  - [x] The app clearly handles granted, denied, restricted, and unavailable states.
  - [x] The app can detect when MusicKit setup, subscription, or device conditions
    block access.

- [x] Real library backup
  - [x] The app fetches real user Apple Music library data.
  - [x] At minimum, backups include playlists, playlist order, songs, albums, and
    useful identifiers.
  - [x] Snapshots use the versioned backup schema instead of ad hoc data.

- [ ] Local-first storage
  - [x] The user can create a backup on-device.
  - [x] Latest backup status loads correctly after app restart.
  - [ ] Large libraries are handled without obvious freezing or memory blowups.
    Tracked by issue `#19`.

- [x] User-owned export
  - [x] The user can export a backup file outside the app sandbox.
  - [x] Exported backups are valid versioned JSON.
  - [x] The export flow does not require the user to understand JSON.

- [x] Backup inspection
  - [x] The user can see what was backed up in human terms.
  - [x] Counts, backup date, and high-level contents are visible.
  - [x] The app does not imply that audio files are backed up.

- [x] Diff and change awareness
  - [x] The user can compare two backups.
  - [x] The app shows added and removed songs.
  - [x] The app shows useful basic playlist changes.

- [x] Restore and rebuild planning
  - [x] The app can create a readable local Restore preview from a backup.
  - [x] The plan distinguishes live matched, missing, unavailable, and
    uncertain tracks after checking Apple Music availability. The read-only
    matching path is implemented, simulator-tested, and validated on a physical
    iPhone through the disposable playlist rebuild smoke test.
  - [x] The app asks before making any Apple Music changes.

- [x] Playlist rebuild MVP
  - [x] The app has a confirmation-gated one-playlist rebuild path that creates
    a new Apple Music playlist only.
  - [x] The app preserves order for matched tracks in the planned rebuild
    request.
  - [x] The app reports skipped tracks clearly before and after rebuild.
  - [x] Real-iPhone validation proves Rekora can recreate at least a test
    playlist from a backup where Apple allows it.

- [ ] Error handling
  - [ ] Permission denial, no subscription, no network, empty library, huge
    library, export failure, and corrupt backup files fail gracefully.
    Tracked by issue `#20`.
  - [ ] Expected user flows do not crash. Tracked by issue `#20`.

- [x] Privacy and trust
  - [x] Apple Music library data stays on-device unless the user explicitly exports
    it.
  - [x] Docs and in-app language are honest about recovery limits.
  - [x] The app does not collect hidden analytics about library contents.

- [ ] Validation
  - [x] Unit tests cover schema, snapshot saving/loading, manifest behavior, and
    diff logic.
  - [ ] A simulator or manual checklist covers permission, backup, export,
    import, latest status, Restore preview, and safe one-playlist rebuild.
    Tracked by issue `#21`.
  - [ ] A bastion pass is complete before treating real user data flows as
    complete. Tracked by issue `#21`.
  - [ ] A kensa pass is complete before calling the MVP functionally complete.
    Tracked by issue `#21`.

## Not Required For Functional Completion

- Beautiful final UI.
- Monetization.
- Cloud sync.
- Accounts.
- Automated scheduled backups.
- Perfect restoration of every track.
- Mac app.
- Web dashboard.
- Public App Store readiness.
- Full accessibility pass, though the app should still avoid obvious
  accessibility problems as we build.

## Suggested Milestone

Functional MVP gaps are now tracked as GitHub issues:

- `#19`: large backup/export stress testing.
- `#20`: MVP error-handling hardening.
- `#21`: final MVP validation pass.

Issue `#18` tracks larger playlist rebuild stress testing. Issue `#11` tracks
app icon and visual identity work, which is useful polish but not required for
functional completion.
