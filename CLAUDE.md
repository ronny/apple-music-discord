# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Build Commands

- `zig build` - Build the main executable
- `zig build run` - Build and run the application
- `make presence` - Alternative build using Makefile (uses zig build, preferred)
- `make presence_c` - Build C version using clang directly (just for testing)
- `make Music.h` - Generate Music.h header from Apple Music app (requires Xcode)

The main executable is built as `apple-music-discord-presence` and outputs to `zig-out/bin/`.

## Project Architecture

This is a macOS-only application that listens to Apple Music playback and updates the user's rich
presence in Discord.app using [Discord Social SDK (Standalone
C++)](https://discord.com/developers/docs/discord-social-sdk/getting-started/using-c++).

Zig is used as a build tool as well as the main compiler for all Objective-C, C, and C++ code.
Clang, GCC, and other compilers should be avoided unless absolutely necessary.

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

**Notification Approach (notif.zig)**:
```
Apple Music → NSDistributedNotificationCenter → MusicPlayerBridge → notif.zig → Display info
```

### Key Dependencies

- **macOS Frameworks**: Foundation, ScriptingBridge, Cocoa
- **Build System**: Zig with C interop for Objective-C bridges
- **Runtime**: Requires Music.app and potentially Discord.app to be running

### Attic Directory

Contains legacy implementations and experiments that are no longer used. They're kept here for
reference only.

### Discord Integration

The `discord/` directory contains vendored Discord Rich Presence SDK (Standalone C++) files.

Reference: https://discord.com/developers/docs/social-sdk/index.html

## Development Notes

- The project requires macOS and XCode to build, and Music.app and Discord.app to run
- Music.h generation requires full Xcode installation (not just CommandLineTools)
- Both polling (ScriptingBridge) and event-driven (notifications) approaches are implemented
- Memory management is handled carefully with proper string cleanup in C bridges
