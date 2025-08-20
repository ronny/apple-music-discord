# TODO

1. [ ] Link song to Apple Music in the Activity Details
   - Use `Discord_Activity_SetDetailsUrl()` to make song title clickable
   - Options: `apple-music://` deep links or Apple Music web URLs
   - Could also use `Discord_Activity_SetStateUrl()` for artist links

2. [ ] Show song or album cover in the Activity Details
   - Use `Discord_ActivityAssets` with `SetLargeImage()` and `SetLargeUrl()`
   - Need to fetch album artwork from Apple Music ScriptingBridge
   - Challenges: Requires image hosting/CDN or Apple Music artwork URLs
   - Assets also support `SetSmallImage()` for secondary artwork
