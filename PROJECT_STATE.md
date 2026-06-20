# Project State

## Current status
Public-ready snapshot of `rekora`, an iPhone-first, local-first Apple Music
backup and restore-preview app.

## Last completed
- Scrubbed legacy local workspace references from copied documentation.
- Preserved the current Swift project, tests, documentation, and design handoff
  files in a fresh-history public snapshot.

## In progress
- Fresh public repository preparation.

## Next action
Run simulator tests on an available iOS Simulator destination.

## Blockers / questions
- None in the source tree.

## Important decisions
- Publish from a fresh git history.
- Keep Apple Music user data, exports, signing assets, and local simulator
  artifacts outside git.

## How to run / verify
```bash
xcodebuild -project Rekora.xcodeproj -scheme Rekora \
  -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO build-for-testing
```

## Notes for future sessions
- Use `xcodebuild -list -project Rekora.xcodeproj` to confirm schemes.
