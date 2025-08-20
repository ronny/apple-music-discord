# Apple Music → Discord Rich Presence

A macOS application that listens to Apple Music.app and updates the user's rich presence in
Discord.app running locally.

## Development Requirements

- **macOS** (tested on macOS 15.6+)
- **Zig compiler** (tested with 0.14.1) https://ziglang.org
- **Discord Social SDK** see below

Optional:
- **Xcode** (full version, not just Command Line Tools, only when you need to regenerate `Music.h`)

### Discord Social SDK (Required)

Download the Discord Social SDK 1.5 from:
https://discord.com/developers/applications/YOUR_APP_ID/social-sdk/downloads

Extract to `$HOME/src/discord_social_sdk` or specify a custom path during build.

**⚠️ The Discord Social SDK is required - the build will fail if not found.**

**🔐 macOS Security Note**: On first run, macOS will show a security popup for
`libdiscord_partner_sdk.dylib`. You must manually allow it in **System Settings → Privacy & Security
→ Security → libdiscord_partner_sdk.dylib "Allow Anyway"**.

## Building

### Building the Application

```sh
# Build with Discord Social SDK (default location: $HOME/src/discord_social_sdk)
zig build

# Build with custom Discord Social SDK location
zig build -Ddiscord-social-sdk=/path/to/discord_social_sdk
```

`Music.h` is generated based on the currently present `Apple Music.app`, so it's probably version specific.
If it's out of sync, you can regenerate it by running `zig build Music.h`.

```sh
# Generate Music.h header (requires full Xcode installation)
zig build Music.h
```

### Running the Application
```sh
# Run with default settings
zig build run

# Run with custom polling interval
./zig-out/bin/apple-music-discord-presence --interval 1000

# Show help
./zig-out/bin/apple-music-discord-presence --help
```

## Development

### Testing
```sh
# Run all tests
zig build test-all

# Run specific test suites
zig build test-config
zig build test-music
zig build test-integration
```

### Project Structure
- `main.zig` - Main application with polling-based track detection
- `MusicScriptingBridge.{m,h}` - Objective-C bridge to Apple Music
- `Music.h` - Generated header from Apple Music app
- `tests/` - Comprehensive test suite

## Configuration

### Command Line Options
- `--interval, -i <ms>` - Polling interval in milliseconds (default: 500ms, minimum: 100ms)
- `--help, -h` - Show help message

### Build Options
- `-Ddiscord-social-sdk=<path>` - Specify Discord Social SDK location
- `-Dtarget=<target>` - Cross-compilation target
- `-Doptimize=<mode>` - Optimization mode (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall)

## Troubleshooting

### Common Issues

**"Apple Music is not running"**
- Ensure Apple Music.app is launched and playing music

**"Discord Social SDK not found" (Build failure)**
- Download Discord Social SDK from Discord Developer Portal
- Extract to `$HOME/src/discord_social_sdk`
- Or specify custom path with `-Ddiscord-social-sdk=/path/to/social-sdk`
- **Build will not proceed without Discord Social SDK**

**Build errors with Music.h**
- Run `zig build Music.h` to regenerate the header
- Requires full Xcode installation (not just Command Line Tools)

**No track changes detected**
- Default polling interval is 500ms
- Try lower interval: `--interval 200`
- Ensure Apple Music is actively playing different tracks

**macOS Security popup for Discord Social SDK library**
- macOS will block unsigned libraries on first run
- Go to **System Settings → Privacy & Security → Security**
- Find `libdiscord_partner_sdk.dylib` and click **"Allow Anyway"**
- Restart the application after allowing the library

## Architecture

This application uses **polling-based track detection** via Apple Music's ScriptingBridge API. The notification-based approach was found to be non-functional on modern macOS versions and has been deprecated.

**Data Flow:**
```
main.zig → MusicScriptingBridge → Apple Music ScriptingBridge → Discord Social SDK
```
