## iPhone Cleanup Guide

Use this after development testing on your real iPhone when you want to put it
back to a normal state until you need it again.

### Clean Up The Test Install

1. Remove the Rekora app from the iPhone.
   - Press and hold the app icon.
   - Tap **Remove App**.
   - Tap **Delete App** if you want the app and its local data, including local
     Rekora backup snapshots, fully removed.
2. If Rekora still appears in iOS settings with Apple Music access, revoke that
   permission.
   - On some iOS versions this is under **Settings > Privacy & Security >
     Media & Apple Music**.
   - On other versions it may appear on the app’s own settings page.
3. Optional: turn off **Developer Mode** if you do not plan to install more
   development builds soon.
   - Check **Settings > Privacy & Security > Developer Mode**.

### Delete Versus Reinstall

- Use **reinstall over the existing app** when you are still actively testing
  and want to keep the current on-device app state.
- Use **delete first, then reinstall** when you need a clean slate, want to
  clear local app data and permissions, or run into an install conflict with an
  older build.

### What Not To Worry About

- Rekora does not modify your Apple Music playlists in the current app.
- Deleting Rekora does not delete songs, albums, or playlists from Apple
  Music.
- Your Apple Music library stays in Apple Music; Rekora only reads it during
  testing and backup work.
- Turning off Developer Mode does not remove your Apple Music library or change
  Apple Music settings. It only affects whether development apps can be
  installed and run.

### Reclaim Mac Disk Space Later

If you want to free up Mac storage after iPhone testing, you can delete
Xcode's copied device-support and debug-symbol cache later.

- During testing, `~/Library/Developer/Xcode/iOS DeviceSupport` was about
  4.3 GB.
- During testing, `~/Library/Developer/Xcode/DerivedData` was about 440 MB.
- The copied symbol data can make `iOS DeviceSupport` grow even larger over
  time.

This is Mac-side Xcode cache and debug support data. It is not Apple Music
data, and it is not content downloaded to the iPhone.

### Coming Back Later

When you need Rekora again, just install it from Xcode or TestFlight as
usual. If Apple Music access was revoked, iOS will ask for permission again
the next time the app needs it.
