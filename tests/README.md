# Test Suite

This directory contains comprehensive tests for the Apple Music Discord Presence application.

## Test Structure

### `test_helpers.zig`
Common utilities and mock objects used across tests:
- `Config` struct for testing configuration parsing
- `PlayerState` enum for testing state transitions
- Helper functions for validation logic

### `config_test.zig`
Unit tests for configuration management:
- Default configuration values
- CLI argument parsing logic
- Interval validation and bounds checking
- Error handling for invalid inputs

### `music_bridge_test.zig`
Tests for the Objective-C bridge functionality:
- MusicPlayerState enum value consistency
- DetailedTrackInfo structure initialization
- Apple Music app connection testing
- Memory management for track information
- String handling safety checks

### `integration_test.zig`
Integration tests for core application logic:
- PlayerState enum conversions between C and Zig
- Track change detection algorithms
- Memory management in polling loops
- Time calculations for playback position
- Polling interval validation

## Running Tests

### All Tests
```bash
zig build test-all
```

### Individual Test Suites
```bash
# Configuration tests
zig build test-config

# Music bridge tests  
zig build test-music

# Integration tests
zig build test-integration

# Main application tests
zig build test
```

## Test Coverage

The test suite covers:

✅ **Configuration Management**
- CLI argument parsing
- Default values
- Input validation
- Error handling

✅ **Apple Music Integration**
- ScriptingBridge connectivity
- Track information retrieval
- Player state detection
- Memory safety

✅ **Core Logic**
- Track change detection
- Polling mechanisms
- State transitions
- Time calculations

✅ **Memory Management**
- String allocation/deallocation
- Resource cleanup
- Memory leak prevention

## Test Dependencies

Tests require:
- macOS with ScriptingBridge framework
- Zig compiler with C interop support
- Apple Music app (for integration tests)
- Xcode Command Line Tools

## Notes

- Music bridge tests may require Apple Music to be running for full coverage
- Integration tests verify cross-language interoperability (Zig ↔ Objective-C)
- All tests are designed to run without external dependencies beyond the system frameworks