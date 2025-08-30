# TODO

1. [x] The app's memory usage grows over time. Investigate and fix the memory leak.

2. [x] Add version based on yyyymmdd-commithash

3. [x] Link song to Apple Music in the Activity Details (hacky version, via search)

4. [ ] Create an AppKit GUI app wrapper around the CLI
    - Create a new Xcode project for the GUI app
    - Use the CLI app as a dependency
    - Implement the GUI using AppKit
    - Add necessary UI elements for user interaction
    - Handle user input and update the CLI app accordingly
    - Stretch goal 1: automatically run the app at startup
    - Stretch goal 2: menu bar item
    - Stretch goal 3: hide app icon in Dock
    - Stretch goal 4: show album cover like Sleeve.app

5. [ ] Show song or album cover in the Activity Details
   - Use `Discord_ActivityAssets` with `SetLargeImage()` and `SetLargeUrl()`
   - Need to fetch album artwork from Apple Music.app ScriptingBridge
   - Challenges: Requires image hosting/CDN or Apple Music artwork URLs
   - Assets also support `SetSmallImage()` for secondary artwork

6. [ ] Figure out requirements (signing, etc) to be able to build a **static** binary that can be
       distributed to users (doesn't have to be in the App Store), just enough to not trigger macOS's
       security popups. Also check Discord requirements if any for statically linking the SDK and
       distributing the binary.
   - Need Apple Developer ID certificate for code signing (`codesign`)
   - Sign both the main binary and Discord Social SDK library (`libdiscord_partner_sdk.dylib`)
   - Consider notarization for macOS 10.15+ to avoid "unidentified developer" warnings
   - May need entitlements for ScriptingBridge access to Apple Music.app
   - Current manual approval required: System Settings → Privacy & Security → "Allow Anyway"
   - Alternative: Distribute via Homebrew or package managers that handle signing
