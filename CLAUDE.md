# kanata-cheatsheet

Floating keyboard cheatsheet overlay for kanata layers.

## Build

Requires Xcode toolchain (`/usr/bin/swiftc`). Raw swiftc via Makefile — no SPM.

```
make all       # Build kanata-cheatsheet binary
make test      # Build and run unit tests
make clean     # Remove .build/
```

## Project Structure

```
Sources/
  App/
    main.swift                — Entry point: NSApplication, wires TCP + overlay + config
  TCP/
    KanataTCPClient.swift     — NWConnection TCP client, JSON parsing, auto-reconnect
  Config/
    Config.swift              — Codable config model, defaults, file loading
  Overlay/
    OverlayPanel.swift        — NSPanel: floating, non-activating, click-through
    OverlayController.swift   — Show/hide logic with delay timer + pure OverlayLogic
    KeyboardView.swift        — SwiftUI: ANSI keyboard grid, key cells, color legend
  Log.swift                   — os_log wrapper
Tests/
  Unit/
    ConfigTests.swift
    TCPParsingTests.swift
    OverlayControllerTests.swift
    TestRunner.swift
```

## Architecture

TCP listener → event dispatch → delay logic → SwiftUI overlay

- `KanataTCPClient` connects to kanata TCP (default port 7070), parses `LayerChange` JSON events
- `OverlayLogic` (pure, testable) decides: start delay, show, hide, or ignore
- `OverlayController` manages the NSPanel lifecycle and SwiftUI hosting
- `KeyboardView` renders an ANSI keyboard grid with color-coded active keys

Config at `~/.config/kanata-cheatsheet/config.json` — all behavior is config-driven.

## Testing

Uses Swift Testing framework. Mocks test the pure logic layer without UI:
- Config parsing and defaults
- TCP message parsing (LayerChange extraction)
- Overlay show/hide state machine (delay, cancellation, stale timers)
