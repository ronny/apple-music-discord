# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Build Commands

### Building
- `zig build` - Build the main executable (Debug mode, uses Discord Social SDK debug library)
- `zig build -Doptimize=ReleaseFast` - Build release version (uses Discord Social SDK release library)
- `zig build run` - Build and run the application
- `zig build Music.h` - Generate Music.h header from Apple Music app (requires Xcode)

### Testing
- `zig build test-all` - Run all tests (recommended)
- `zig build test-config` - Run configuration parsing tests
- `zig build test-music` - Run Apple Music bridge tests
- `zig build test-integration` - Run integration tests
- `zig build test` - Run main application tests

The main executable is built as `apple-music-discord-presence` and outputs to `zig-out/bin/`.

## Project Architecture

This is a macOS-only application that listens to Apple Music playback and updates the user's rich
presence in Discord.app using [Discord Social SDK (Standalone
C++)](https://discord.com/developers/docs/discord-social-sdk/getting-started/using-c++).

Zig 0.14.x is used as a build tool as well as the main compiler for all Objective-C, C, and C++
code. Clang, GCC, and other compilers should be avoided unless absolutely necessary.

### Core Architecture Components

1. **Objective-C Bridges**: there is no macOS API to access Apple Music playback information directly,
  so we need to use ScriptingBridge to access it.
   - `MusicScriptingBridge.m/.h` - Direct Apple Music ScriptingBridge interface where we can query
     the currently playing track, but we won't get notified when the track changes.
   - `MusicPlayerBridge.m/.h` - Notification-based monitoring bridge, which is an attempt to get
     notification when the track changes in Apple Music.

2. **Generated Headers**:
   - `Music.h` - Auto-generated from Apple Music app using `sdef`/`sdp`

### Data Flow

**ScriptingBridge Approach (main.zig)**:
```
main.zig → MusicScriptingBridge → Apple Music ScriptingBridge → Display info
```

**Notification Approach (DEPRECATED)**:
```
Apple Music → NSDistributedNotificationCenter → MusicPlayerBridge → notif.zig → Display info
```

**Note**: The notification approach was found to be non-functional on modern macOS versions. Apple Music does not send the expected distributed notifications, making polling the only viable approach.

### Key Dependencies

- **macOS Frameworks**: Foundation, ScriptingBridge, Cocoa
- **Build System**: Zig with C interop for Objective-C bridges
- **Runtime**: Requires Music.app and potentially Discord.app to be running

### Attic Directory

Contains legacy implementations and experiments that are no longer used. They're kept here for
reference only.

- Other legacy files in various languages (C, Zig experiments)

### Discord Integration

The `discord/` directory contains vendored Discord Social SDK (Standalone C++) files.

Reference: https://discord.com/developers/docs/discord-social-sdk/index.html

## Development Notes

- The project requires macOS and XCode to build, and Music.app and Discord.app to run
- Music.h generation requires full Xcode installation (not just CommandLineTools)
- **Polling is the only working approach** - notification-based approach is deprecated
- Memory management is handled carefully with proper string cleanup in C bridges
- Application supports configurable polling intervals via `--interval` CLI flag (default 500ms)
- **macOS Security**: Discord Social SDK library requires manual approval in System Settings on first run

## Workflow

- Make small incremental changes that can be tested
- Always accompany code changes with automated tests where possible
- Prompt to create a jj/git commit when sensible
- Never run jj or git commands except for querying

## Testing

The project includes a comprehensive test suite covering:

- **Configuration management** - CLI argument parsing, validation, error handling
- **Apple Music integration** - ScriptingBridge connectivity, track info retrieval
- **Core application logic** - Track change detection, polling mechanisms
- **Memory safety** - String handling, resource cleanup, leak prevention

### Test Structure

- `tests/config_test.zig` - Configuration parsing and validation
- `tests/music_bridge_test.zig` - Objective-C bridge functionality
- `tests/integration_test.zig` - Core logic and cross-language interop
- `tests/test_helpers.zig` - Shared utilities and mock objects

### Running Tests

Always run tests before committing changes:
```bash
zig build test-all  # Run all tests (recommended)
```

Tests require Apple Music to be available for full coverage of music bridge functionality.

- Consult TODO.md for future plans
