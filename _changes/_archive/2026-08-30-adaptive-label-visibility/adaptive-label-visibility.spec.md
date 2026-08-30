# Adaptive Action-Label Visibility

## Problem

Registry-backed keyboard cells always render both their center icon and their
action label. That is useful when the label explains an action, but noisy when
an icon already contains the exact literal output: for example, `4.square`
above `4` or `dollarsign.square` above `$`.

The registry must retain the complete action label because the browser, search,
and inspection views use it as semantic data. This change therefore belongs to
the overlay presentation, not the registry schema or keybinding providers.

## Design

`kanata-cheatsheet` owns the display rule in
`Sources/Registry/KeyboardLayerProjection.swift`. `KeyboardPresentedKey` will
retain its full `actionLabel` and expose a pure computed `displayActionLabel`
derived from the icon and full label. `KeyboardView` will render that computed
value. Keeping the semantic label on the presented key also preserves occupied
cell styling for an icon-only display.

The rule is deliberately narrow:

1. An iconless cell keeps its label. This leaves `:`, `;`, and `.` visible as
   the single central glyph and preserves `, · Hold Control`.
2. App-font icons keep their labels.
3. Action-oriented SF Symbols keep their labels, including Copy, Paste, Cut,
   Browser Back, Quit App, Return, modifiers, and navigation actions.
4. A known literal SF Symbol suppresses the label only when the label contains
   exactly the same literal and no additional explanation. The supported
   literals are `0.square` through `9.square`, `plus.square`, `minus.square`,
   `eurosign.square`, and `dollarsign.square`. ASCII hyphen (`-`) and
   mathematical minus (`−`) are equivalent for this comparison.
5. Any extra wording makes the label visible. Therefore `1.square` with
   `1 · Hold Command`, `2.square` with `2 · Hold Shift`, and `3.square` with
   `3 · Hold Option` keep their explanations.
6. Unknown or future icon tokens keep their labels by default.

The pure rule stays inside the existing projection model so `KeyboardView`
remains a renderer and the registry remains the source of the full semantic
label. No new component, schema field, provider override, or external
dependency is introduced.

## Expected Current Result

On the Nav layer, the small duplicate labels disappear below these icons:

- `0`, `4`, `5`, `6`, `7`, `8`, `9`
- `+`, both `−` cells, `€`, `$`

The modifier-bearing labels for `1`, `2`, and `3` remain. Iconless punctuation
still shows one literal glyph. Apps, Mine, and Yabai retain all explanatory
labels because none of their current action labels exactly duplicates a known
literal icon. Icon-only cells keep their current color and occupied styling;
their literal icon may recenter vertically within the unchanged key and panel
geometry when the redundant lower line disappears.

## Tests and Verification

Use TDD in `Tests/Unit/RegistryTests.swift` against the projector. The RED test
must cover:

- an exact digit duplicate is hidden;
- an exact currency duplicate is hidden;
- typographic minus is recognized as the `minus.square` literal;
- the full semantic `actionLabel` remains available when its display is hidden;
- a digit label with hold-modifier explanation remains;
- an iconless punctuation label remains;
- an action SF Symbol label remains;
- an app-font label remains;
- an unknown SF Symbol label remains.

Then run `make test` and `make all` in `kanata-cheatsheet`.

For delivery, publish the app commit, update only the source revision and hash
in `nix-config/overlays/kanata-cheatsheet.nix`, build the focused Darwin package
on the Macserver, and deploy through `just switch`. Capture focus-preserving
offscreen screenshots before and after for Apps, Mine, Nav, and Yabai. The
passing visual result has only the listed duplicate Nav labels removed; all
other content and geometry remain unchanged. Verify the running LaunchAgent
uses the newly pinned binary.

## Non-Scope

Key assignments, Kanata aliases or tokens, registry action labels, registry
schema, browser/search presentation, icon choice, colors, keyboard geometry,
font sizes, spacing, layer triggers, Yabai behavior, and label wording.

## Failure Mode and Reversal

The principal risk is suppressing a label that adds meaning. Exact literal
matching plus default-visible handling for unknown tokens prevents that. If the
rule still removes useful text, revert the app projection change and restore
the previous Nix app pin; no registry or keybinding migration is involved.

## Approval Scope

Approval authorizes implementation in the app worktree, tests and visual
verification, the corresponding Nix pin update in an isolated nix-config
worktree, independent review, commits, publication to both `main` branches,
MacBook deployment, live LaunchAgent verification, and archiving this change.

## As Built

The app implementation landed in `23a9946abe6f34cafcc47a96a9b077ab3de5c7d4`.
It added the pure `KeyboardPresentedKey.displayActionLabel` rule in
`Sources/Registry/KeyboardLayerProjection.swift`, switched only registry-backed
label rendering in `Sources/Overlay/KeyboardView.swift`, and added regression
coverage in `Tests/Unit/RegistryTests.swift`. The final rule uses an explicit
ASCII allowlist for `0.square` through `9.square`; a review-found fullwidth
numeric counterexample remains visible by default.

The initial RED run failed to compile because `displayActionLabel` did not yet
exist. The review-fix RED run failed one assertion because `４.square` was
incorrectly suppressed. After both production changes, `make test` passed 74
tests in 8 suites, `make all` built the optimized binary, and `git diff --check`
was clean. Independent app review closed its one Important allowlist finding
and approved exact head `23a9946` with no remaining findings.

The Nix pin landed in
`9b53a5cb778e52bab8501f7f375a6ce5e5c09858`, changing only
`overlays/kanata-cheatsheet.nix`. The measured source hash is
`sha256-Tu1DQhb7NKF88Aa2jLHP34doQfwLp3QuqDcyC5N/vew=`. The focused Macserver
Crabbox build produced
`/nix/store/6ck452rfzs0wpcybdx04fdacskihzhvg-kanata-cheatsheet-0.2.1`, and an
independent Nix review repeated the build and approved the exact pin without
findings. `nixfmt --check`, the commit-hook formatter, and diff hygiene passed.

Before/after captures kept Apps, Mine, and Yabai byte-identical. Nav removed
only the duplicate lower labels for `0`, `4`, `5`, `6`, `7`, `8`, `9`, `+`,
both minus cells, `€`, and `$`; modifier explanations and iconless punctuation
remained visible. After `just switch`, `/run/current-system/darwin-version.json`
reported configuration revision `9b53a5cb`, LaunchAgent PID 77333 ran the exact
new store binary, and all four live captures matched the reviewed candidate
byte-for-byte while `cmux` remained frontmost.

The only actionable unresolved output was the repository's existing Nix
evaluation deprecation warnings for `stdenv.isLinux` and `stdenv.isDarwin`;
this change did not touch those call sites.
