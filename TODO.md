# TODO

1. [x] The app's memory usage grows over time. Investigate and fix the memory leak.

2. [ ] Add version based on yyyymmdd-commithash

3. [ ] Link song to Apple Music in the Activity Details
   - Use `Discord_Activity_SetDetailsUrl()` to make song title clickable
   - Options: `apple-music://` deep links or Apple Music web URLs
   - Could also use `Discord_Activity_SetStateUrl()` for artist links

4. [ ] Show song or album cover in the Activity Details
   - Use `Discord_ActivityAssets` with `SetLargeImage()` and `SetLargeUrl()`
   - Need to fetch album artwork from Apple Music.app ScriptingBridge
   - Challenges: Requires image hosting/CDN or Apple Music artwork URLs
   - Assets also support `SetSmallImage()` for secondary artwork

5. [ ] Figure out requirements (signing, etc) to be able to build a **static** binary that can be
       distributed to users (doesn't have to be in the App Store), just enough to not trigger macOS's
       security popups. Also check Discord requirements if any for statically linking the SDK and
       distributing the binary.
   - Need Apple Developer ID certificate for code signing (`codesign`)
   - Sign both the main binary and Discord Social SDK library (`libdiscord_partner_sdk.dylib`)
   - Consider notarization for macOS 10.15+ to avoid "unidentified developer" warnings
   - May need entitlements for ScriptingBridge access to Apple Music.app
   - Current manual approval required: System Settings → Privacy & Security → "Allow Anyway"
   - Alternative: Distribute via Homebrew or package managers that handle signing
