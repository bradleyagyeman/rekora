# Backup Schema

Rekora backups use a versioned JSON snapshot format.

The schema is not the app database. It is the portable backup contract that
Rekora writes, exports, imports, compares, and eventually uses to rebuild what
Apple Music allows.

## Version 1

Version 1 stores a complete library snapshot with:

- `format`: the backup format marker. New exports write
  `rekora.backup.snapshot`; older v1 backups may omit this marker.
- `schemaVersion`: the backup format version. The first version is `1`.
- `snapshotID`: a unique ID for this backup.
- `createdAt`: the ISO 8601 snapshot creation date.
- `source`: app and platform metadata for the backup.
- `songs`: song records Rekora knows about from saved library songs and
  playlist entries.
- `albums`: saved album records.
- `playlists`: saved playlist records with ordered track entries.

Song, album, and playlist records each keep Apple identifiers where available:

- `libraryID`: Apple Music library identifier.
- `catalogID`: Apple Music catalog identifier.
- `appleMusicID`: Apple Music item identifier when distinct from catalog ID.
- `isrc`: International Standard Recording Code, mainly useful for songs.

Every song also keeps plain metadata fallbacks:

- library status: `saved`, `playlistOnly`, or `unknown`
- title
- artist name
- album title
- album artist name
- duration
- track number
- disc number

These fallbacks matter because Apple identifiers may be missing, unavailable,
or later point to catalog items that changed.

`saved` means the song came from the user's Apple Music library song list.
`playlistOnly` means Rekora saw the song inside a playlist even if it did not
appear in the top-level saved songs list. This lets playlist backups remain
useful when Apple Music exposes more playlist entries than saved library songs.
Because of this, a backup's total song count can be much larger than the
top-level saved-song count returned by Apple Music.

## Playlist Order

Playlist order is stored on playlist track entries, not inferred from the
global song list.

Each playlist track stores:

- `playlistID`
- `songID`
- `position`: the playlist entry position reported by MusicKit.
- optional `snapshotOrder`: the order Rekora observed while reading the
  playlist entries.
- optional `addedAt`

This lets Rekora preserve the order of each playlist even when the same song
appears in multiple playlists or when the global song array is sorted
differently.

MusicKit does not always expose playlist track added dates. Rekora stores
`addedAt` when it is available.

MusicKit may also report unhelpful playlist positions, such as every track in a
playlist having `position: 0`. Rekora keeps `position` as the raw MusicKit value
and stores `snapshotOrder` as a separate observed-order fallback. Current diff
code and future restore code should prefer `snapshotOrder` when positions are
duplicated, all zero, sparse, or otherwise invalid for a playlist. This is an
additive schema v1 field, so older backups may omit `snapshotOrder`.

## Local Storage

The first implementation saves snapshots as JSON files in Rekora's private app
storage. It also writes a small `latest-backup.json` manifest next to the
snapshots so the app can show the newest backup date, song count, album count,
playlist count, playlist-track count, and playlist order warning count without
decoding the full backup file.

The manifest's `playlistOrderWarningCount` is the number of playlists whose
MusicKit-reported positions do not look like contiguous zero-based order.
Rekora uses this as a small post-backup summary so users know observed order
was saved too. Older manifests may omit this field, and Rekora treats the count
as zero when it is missing.

Later, Rekora may also use SwiftData or SQLite for local browsing, indexing, or
diffing.

Even if a database is added later, exported backups should continue to use this
versioned JSON format so users can keep their own portable data.

## Import Validation

Rekora validates imported backups by reading the selected file contents, not by
trusting the filename or extension. A renamed file such as `My Music Backup`
should still validate if its JSON contains a supported Rekora schema version,
uses the Rekora format marker when one is present, and decodes as a complete
backup snapshot.

The `format` marker is an identification hint, not a tamper-proof signature.
A technical user can edit JSON by hand, so Rekora still treats imported files
as untrusted input and validates the full schema before showing a summary.
Current schema-v1 backups created before the marker was added remain valid if
their contents otherwise decode as complete Rekora snapshots.

The current import flow is read-only. It reports the schema version, backup
date, source app metadata, song count, album count, playlist count, and
playlist-track count, but it does not restore playlists or change Apple Music.

## Restore Preview

The current Restore preview is also read-only. It reads a saved backup and
summarizes how many playlists and playlist entries Rekora can prepare, how many
tracks look ready for automatic matching, and how many may need review before
rebuilding. Internally, the plan still uses identifiers such as catalog IDs,
Apple Music IDs, ISRC, and title/artist metadata, but the user-facing copy
keeps that detail out of the main screen. The preview can now run a read-only
Apple Music match check and merge those temporary results into the on-screen
summary. The live match results are not written into the backup schema. This
preview does not create, edit, or delete playlists.

## Playlist Rebuild

Playlist rebuild uses the backup schema as the source of truth for playlist
membership and order. After a live Apple Music match check, Rekora can prepare
a one-playlist rebuild request from confident matched tracks only. The request
uses `snapshotOrder` where available, falls back to trustworthy contiguous
`position` values for older backups, and keeps duplicate song references in
their playlist order.

The rebuild request is not written into the backup JSON. It is temporary app
state derived from the backup plus live Apple Music matches. The current MVP
path creates a new Apple Music playlist after explicit confirmation. It skips
unmatched, metadata-only, or uncertain tracks instead of guessing, and it does
not edit, replace, reorder, or delete existing Apple Music playlists.
