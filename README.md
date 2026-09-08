# kanata-cheatsheet

Floating keyboard overlays for Kanata, with registry-backed MacBook and Dygma
Defy layouts. The panel shows the active layer without taking keyboard focus.

## Pomodoro Status

The Pomodoro header shows the timer phase, remaining time, and today's
dissertation minutes toward a 30-minute target. In the Pomodoro layer, Mine D
selects dissertation work from that moment. P and Space start, pause, or resume
the timer; N advances the phase, S stops, and R/E adjust the duration.

The existing `pomodoro.sh` plugin in `nix-config` owns commands and accounting.
Only running work explicitly selected as dissertation counts. Pauses, breaks,
general work, and overtime add no progress. Stopping retains elapsed progress;
the total resets on the local calendar day and may exceed 30 minutes. This
measures selected timer time. Sleep does not automatically pause the timer.

The app reads `$XDG_STATE_HOME/pomodoro/status.json`, falling back to
`~/.local/state/pomodoro/status.json`. The version 1 JSON snapshot contains
`schema_version`, Unix `observed_at`, `state`, `mode`, `context`,
`remaining_seconds`, local `date` (`YYYY-MM-DD`), and `dissertation_seconds`.
The header displays completed whole minutes.

Reading starts immediately before showing Pomodoro and repeats once per second
while that panel is visible. Hiding or replacing it stops the reads. Updates
reuse the panel and its position. Missing, malformed, future-dated, or more than
five-seconds-old snapshots show an unavailable message and the daily target.
The app reads the snapshot without writing timer state or issuing commands.

## Build and Verify

The Makefile uses the Xcode Swift compiler and Swift Testing framework.

```sh
make all
make test
make render-contact-sheets REGISTRY=/path/to/registry.json OUTPUT=/tmp/keyboard-review
```

The renderer writes offscreen PNGs and a manifest with verified image hashes.
Both geometries include fixed Pomodoro examples for ready, running, paused,
break, expired, unavailable, and a daily total above the target.
