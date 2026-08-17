# TCP Reconnect: Recover from `.waiting` State

## Problem

`KanataTCPClient` strands itself permanently when a reconnect attempt hits a
down server. Observed live on 2026-08-17: kanata was stopped during a stack
rollout, the client's single reconnect attempt got `Connection refused`,
Network.framework put the new `NWConnection` into `.waiting`, and the client
never retried. The process stays healthy-looking under launchd with no TCP
socket until its LaunchAgent is manually restarted.

Root cause (diagnosed upstream, confirmed against source): the
`stateUpdateHandler` in `Sources/TCP/KanataTCPClient.swift` handles `.ready`,
`.failed`, and `.cancelled`; its `default` branch silently ignores `.waiting`.
Reconnect scheduling only runs after `.failed` or a receive completion/error.
A connection that enters `.waiting` (e.g. `POSIXErrorCode.ECONNREFUSED` on
loopback) never reaches either path: Network.framework waits for a network
path change that never comes on localhost.

## Design

Client-local fix in `Sources/TCP/KanataTCPClient.swift`, following the repo's
pure-logic-seam testing philosophy:

1. **Pure decision seam.** Add an equatable enum and a pure static mapping:

   ```swift
   enum TCPStateAction: Equatable { case connected, retry, ignore }

   static func action(for state: NWConnection.State) -> TCPStateAction
   ```

   Mapping: `.ready → .connected`; `.failed → .retry`; `.waiting → .retry`;
   `.setup`, `.preparing`, `.cancelled` (and unknown future states) →
   `.ignore`.

2. **State handler uses the seam.** The `stateUpdateHandler` switches on
   `action(for: state)`:
   - `.connected`: current `.ready` behavior (log, `didConnect`, start
     receive loop).
   - `.retry`: log the error, `conn.cancel()` the stalled connection so it
     cannot fire further transitions, then on main:
     `didDisconnect` + `scheduleReconnect()`.
   - `.ignore`: no action.

3. **Stale-handler guard.** The state handler ignores events from a
   connection that is no longer `self.connection` (same identity check the
   receive loop already uses). This prevents a superseded connection's
   `.failed`/`.waiting` from cancelling or rescheduling over a healthy one.

Reconnect cadence stays the configured `reconnect_interval_ms` (default
3000 ms). `scheduleReconnect()` already invalidates any pending timer, and
`connect()` already cancels any lingering connection, so the fix introduces no
second timer and no duplicate connection or event delivery path. Overlay code
is untouched; the non-activating, focus-free overlay behavior is unchanged.

## Regression Test (RED first)

New tests in `Tests/Unit/` against the pure seam:

- `.waiting(ECONNREFUSED) → .retry` — the exact stranded state from the
  incident; fails to compile/pass against current code (RED), passes after.
- `.ready → .connected`, `.failed → .retry`, `.setup`/`.preparing`/
  `.cancelled → .ignore` — pin the full mapping so retry paths stay covered.

Then the complete suite (`make test`, 62 existing tests) must pass.

## Deployment

1. Merge worktree to `main`, push to `github.com/moritzketzer/kanata-cheatsheet`.
2. `nix-config/overlays/kanata-cheatsheet.nix`: bump `version` 0.2.0 → 0.2.1,
   set `rev` to the pushed commit, update `hash`.
3. Build through the documented Macserver Darwin path; never build Nix
   automatically on the MacBook. Deploy via the normal nix-config pipeline.
4. Live verification: cheatsheet connects to kanata TCP (port 7070); stop
   kanata longer than one reconnect interval so a retry hits
   `Connection refused` (the previously stranding state); restart kanata;
   verify the cheatsheet reconnects without a LaunchAgent restart and
   `appfocusd` stays connected. Report separately whether the physical
   overlay display was visually confirmed.

## Non-Scope

Kanata hotplug/BLE/USB behavior, DriverKit, TCC, layouts, keybindings,
appfocus, port changes, new daemons/watchers/pollers, UI changes, refactors
beyond this reconnect path, GitHub releases.

## As Built (2026-08-17)

Implemented exactly as designed; no design deviations.

- `Sources/TCP/KanataTCPClient.swift`: added `TCPStateAction` enum and pure
  `static func action(for: NWConnection.State) -> TCPStateAction`
  (`.ready → .connected`; `.failed`/`.waiting` → `.retry`; `.setup`/
  `.preparing`/`.cancelled`/`@unknown` → `.ignore`); `stateUpdateHandler`
  switches on the mapping, `.retry` cancels the stalled connection and
  schedules the single reconnect timer on main; identity guard
  `self.connection === conn` drops superseded connections' events.
- `Tests/Unit/TCPReconnectTests.swift`: 4 new tests; the `.waiting
  (ECONNREFUSED) → .retry` regression test was verified RED at base
  (`action(for:)` did not compile) before implementation.
- Verification: `make test` 66 tests / 7 suites pass (baseline 62/6);
  `make all` builds. Commits `05bf098` (test+seam), `ab7b8ab` (handler).
- Independent review (fresh-context reviewer): approve-with-minors; reran
  the suite independently. Three Minor, non-blocking findings, none fixed
  pre-merge by reviewer recommendation: (1) pre-existing unsynchronized
  cross-thread access to `connection` (follow-up: queue-confine mutations),
  (2) narrow TOCTOU in the identity guard sharing the same root cause,
  self-healing, strictly narrower than base, (3) base-identical benign
  double-reschedule after receive-error + `.failed`. Also noted adjacent
  pre-existing: stale `buffer` not cleared on reconnect (dropped, not
  duplicated, first line); `stop()` currently has no caller.
- Unresolved at archive time: nix pin (0.2.1), Macserver build, deployment,
  and live reconnect verification continue in `nix-config` per the
  Direct-Ship handoff; results reported in the worker session.
