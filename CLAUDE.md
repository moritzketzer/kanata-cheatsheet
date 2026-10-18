# kanata-cheatsheet

Floating keyboard cheatsheet overlay for kanata layers.

## Build

Requires Xcode toolchain (`/usr/bin/swiftc`). Raw swiftc via Makefile — no SPM;
new Swift files under `Sources/` are picked up automatically.

```
make all       # Build kanata-cheatsheet binary
make test      # Build and run unit tests (headless — see Testing)
make clean     # Remove .build/
make render-contact-sheets REGISTRY=… OUTPUT=…   # offscreen PNG review sheets
```

## Project Structure

```
Sources/
  App/        — Entry point: NSApplication, wires TCP + overlay + browser
  TCP/        — NWConnection client for kanata events (LayerChange,
                MessagePush), pure drain/parse, auto-reconnect
  Config/     — Codable config model; defaults single-sourced from the
                memberwise inits
  Registry/   — Keybinding registry model, search/query, and
                KeyboardLayerProjector: registry → KeyboardLayerPresentation
                via RegistryLayerProjectionBuilder (geometry profiles:
                macbook, defy, legacy)
  Browser/    — Registry browser window (SwiftUI list + modifier-space grid)
  Overlay/    — OverlayPanel (floating, non-activating), OverlayController
                (delay/show/hide state machine around pure OverlayLogic),
                and one file per view type: KeyboardView assembly, geometry
                views (MacBook/Defy/Legacy), KeyCell, ModifierChip, input
                path, thumb fan/geometry data, Pomodoro header, footer,
                legends, KeyboardGeometryMetrics (all sizing math, pure)
  Palette.swift — Catppuccin Mocha color constants + Color(hex:)
  Log.swift     — os_log wrapper
Tests/
  Unit/       — Swift Testing suites (13), one per subsystem; TestRunner
  Visual/     — contact-sheet renderer behind make render-contact-sheets
```

## Architecture

TCP listener → event dispatch → delay logic → SwiftUI overlay

- `KanataTCPClient` connects to kanata TCP (default port 7070); the pure
  `KanataEvent.drainEvents` turns buffered lines into events
- `OverlayLogic` (pure, testable) decides: start delay, show, hide, or ignore;
  messages dispatch to named handlers
- `OverlayController` manages the NSPanel lifecycle and SwiftUI hosting
- `KeyboardLayerProjector` projects registry layers into presentations;
  geometry views render them per profile kind
- Config at `~/.config/kanata-cheatsheet/config.json`; registry at
  `~/.config/kanata-cheatsheet/registry.json`

## Testing

Swift Testing framework; `make test` runs every suite headless.

- Tests construct `OverlayController(presentsPanels: false)`: panels are
  created and sized but never ordered front or animated, so test runs put
  NOTHING on screen. Keep it that way — a test that needs a visible window
  is wrong here, and "headless controller never puts a panel on screen"
  pins the contract.
- Pure layers (OverlayLogic, projection, metrics, config, TCP parsing) are
  tested directly; `KeyboardGeometryMetrics` sizing is characterization-
  pinned in the Keyboard Sizing suite.
- View rendering is verified via `make render-contact-sheets` (deterministic
  offscreen PNGs + hash manifest). For pixel-preserving refactors, render
  before/after from the same display configuration and byte-compare; sheet
  dimensions depend on `NSScreen.main`, so re-render the baseline rather
  than comparing against sheets from another display setup.
