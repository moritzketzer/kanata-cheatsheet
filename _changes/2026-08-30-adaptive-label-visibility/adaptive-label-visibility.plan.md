# Adaptive Action-Label Visibility Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove only redundant literal action-label lines from registry-backed keyboard cells while preserving every explanatory label and the full semantic registry data.

**Architecture:** Keep `RegistryKeyboardCell.actionLabel` and `KeyboardPresentedKey.actionLabel` unchanged. Add a pure computed `displayActionLabel` to `KeyboardPresentedKey`; it recognizes a bounded set of literal SF Symbols and returns `nil` only for an exact duplicate. `KeyboardView` renders the computed display value, while the existing semantic label continues to drive occupied styling and remains available to other consumers.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Swift Testing, raw `swiftc` Makefile, Nix `fetchFromGitHub`, Crabbox Darwin builds, nix-darwin/Home Manager deployment.

---

### Task 1: Pin the display rule with failing projector tests

**Files:**
- Modify: `Tests/Unit/RegistryTests.swift`
- Read: `Sources/Registry/KeyboardLayerProjection.swift`

- [ ] **Step 1: Add a focused presented-key fixture**

Add this helper near the existing test helpers:

```swift
private func presentedKey(
    _ actionLabel: String?,
    iconKind: String? = "sf-symbol",
    iconToken: String? = nil
) -> KeyboardPresentedKey {
    KeyboardPresentedKey(
        id: "KeyW",
        width: 1.0,
        badge: "L",
        actionLabel: actionLabel,
        freeLabel: nil,
        colorHex: "#f9e2af",
        icon: iconKind.flatMap { kind in
            iconToken.map { RegistryKeyIcon(kind: kind, token: $0) }
        }
    )
}
```

- [ ] **Step 2: Add the exact-duplicate regression test**

Add inside `RegistryTests`:

```swift
@Test("hides exact literal SF Symbol labels without dropping semantic data")
func hidesExactLiteralLabels() {
    let digit = presentedKey("4", iconToken: "4.square")

    #expect(digit.actionLabel == "4")
    #expect(digit.displayActionLabel == nil)
    #expect(presentedKey("$", iconToken: "dollarsign.square").displayActionLabel == nil)
    #expect(presentedKey("−", iconToken: "minus.square").displayActionLabel == nil)
    #expect(presentedKey("-", iconToken: "minus.square").displayActionLabel == nil)
}
```

- [ ] **Step 3: Add the explanatory/default-visible regression test**

```swift
@Test("keeps labels that add meaning or lack a known literal icon")
func keepsInformativeLabels() {
    #expect(
        presentedKey("1 · Hold Command", iconToken: "1.square").displayActionLabel
            == "1 · Hold Command"
    )
    #expect(presentedKey(";", iconKind: nil).displayActionLabel == ";")
    #expect(presentedKey("Copy", iconToken: "doc.on.doc").displayActionLabel == "Copy")
    #expect(
        presentedKey("Finder", iconKind: "app-font", iconToken: ":finder:")
            .displayActionLabel == "Finder"
    )
    #expect(
        presentedKey("Future", iconToken: "future.literal.symbol").displayActionLabel
            == "Future"
    )
}
```

- [ ] **Step 4: Run the tests and verify RED**

Run:

```bash
make test
```

Expected: compile failure because `KeyboardPresentedKey` has no member
`displayActionLabel`. This proves the tests exercise the missing production
behavior rather than current behavior.

### Task 2: Implement the bounded presentation rule

**Files:**
- Modify: `Sources/Registry/KeyboardLayerProjection.swift`
- Modify: `Sources/Overlay/KeyboardView.swift`
- Test: `Tests/Unit/RegistryTests.swift`

- [ ] **Step 1: Add the pure computed display label**

Add to `KeyboardPresentedKey`:

```swift
var displayActionLabel: String? {
    guard let actionLabel,
          let icon,
          icon.kind == "sf-symbol",
          let literalGlyph = Self.literalGlyph(for: icon.token),
          Self.label(actionLabel, matches: literalGlyph)
    else {
        return actionLabel
    }
    return nil
}

private static func literalGlyph(for token: String) -> String? {
    let squareSuffix = ".square"
    if token.hasSuffix(squareSuffix) {
        let stem = String(token.dropLast(squareSuffix.count))
        if stem.count == 1, stem.first?.isNumber == true {
            return stem
        }
    }

    switch token {
    case "plus.square": return "+"
    case "minus.square": return "−"
    case "eurosign.square": return "€"
    case "dollarsign.square": return "$"
    default: return nil
    }
}

private static func label(_ label: String, matches literalGlyph: String) -> Bool {
    if literalGlyph == "−" {
        return label == "−" || label == "-"
    }
    return label == literalGlyph
}
```

- [ ] **Step 2: Render only the computed display label**

In `KeyCell.registryContent`, replace:

```swift
if let actionLabel = key.actionLabel {
```

with:

```swift
if let actionLabel = key.displayActionLabel {
```

Do not change `isOccupied`; it intentionally continues to use the full
semantic `actionLabel`, preserving cell color and occupied styling.

- [ ] **Step 3: Run the complete suite and verify GREEN**

Run:

```bash
make test
```

Expected: 74 tests in 8 suites pass with no warnings or failures.

- [ ] **Step 4: Build the production binary**

Run:

```bash
make all
```

Expected: `.build/kanata-cheatsheet` builds successfully.

- [ ] **Step 5: Commit the app behavior**

```bash
git add -- Sources/Registry/KeyboardLayerProjection.swift \
  Sources/Overlay/KeyboardView.swift Tests/Unit/RegistryTests.swift
git commit -m 'fix(overlay): 🐛 suppress redundant literal labels'
```

Verify the signature, exact changed paths, and a clean worktree.

### Task 3: Verify the visual delta, review, and publish the app commit

**Files:**
- Read: `/tmp/kanata-layer-snapshot.swift`
- Modify: `_changes/2026-08-30-adaptive-label-visibility/change.yaml`
- Review: the complete app diff from `origin/main` through the feature head

- [ ] **Step 1: Build before and after offscreen snapshot harnesses**

Use the existing focus-preserving `/tmp/kanata-layer-snapshot.swift`. Compile
one binary from the clean primary checkout and one from this worktree, excluding
`Sources/App/main.swift` in both cases. Capture Apps, Mine, Nav, and Yabai with
the current installed config and registry into separate `mktemp -d` output
directories. Record the frontmost application before and after each run.

Expected: the frontmost application does not change.

- [ ] **Step 2: Compare and inspect all four layers**

Require byte-identical Apps, Mine, and Yabai screenshots. Nav must differ.
Inspect the Nav before/after images with `view_image` and verify:

- small labels below `0`, `4`, `5`, `6`, `7`, `8`, `9`, `+`, both `−`, `€`,
  and `$` are gone;
- the literal icons remain colored and occupied;
- `1 · Hold Command`, `2 · Hold Shift`, and `3 · Hold Option` remain;
- `:`, `, · Hold Control`, `;`, and `.` remain visible;
- no clipping or unrelated geometry change appears.

- [ ] **Step 3: Request independent app review**

Use `reviewing-code` Request mode with the spec, plan, base/head SHAs, complete
diff, RED/GREEN output, build output, and visual evidence. Critical or Important
findings block publication and return to the same reviewer after focused fixes.

- [ ] **Step 4: Record the required intermediate publication**

Append to `change.yaml`:

```yaml
  - date: 2026-08-30
    event: implementation-published
    session: 01a04859-33bf-76e3-85ef-39cad30fa0ce
    tool: codex
    publication: intermediate
    reason: the immutable app commit must be visible to fetchFromGitHub before the Nix pin can build
```

Commit only `change.yaml` with:

```bash
git commit -m 'docs(changes): 📝 record app publication boundary' -- \
  _changes/2026-08-30-adaptive-label-visibility/change.yaml
```

- [ ] **Step 5: Publish while retaining the app worktree**

Run:

```bash
git wt-publish adaptive-label-visibility
```

Expected: the app commits reach `origin/main`; the worktree and branch remain.

### Task 4: Pin and build the reviewed app in nix-config

**Files:**
- Modify: `/Users/moritz/para/0-System/nix-config/overlays/kanata-cheatsheet.nix`
- Worktree: `/Users/moritz/para/0-System/nix-config/.worktrees/adaptive-label-visibility-pin`

- [ ] **Step 1: Load the Nix and worktree owners**

Use `configuring-systems-with-nix`, `operating-nix-config-pipeline`,
`using-git-worktrees`, and `using-git`. Read the current overlay and its caller
before editing.

- [ ] **Step 2: Create an isolated nix-config worktree**

From the nix-config primary checkout:

```bash
git wt-add adaptive-label-visibility-pin
```

Verify the new worktree is clean and based on current `origin/main`. Do not
touch unrelated primary-checkout state.

- [ ] **Step 3: Update the immutable source pin**

In the Nix worktree, replace the app `rev` with the published app feature SHA
and temporarily set:

```nix
hash = final.lib.fakeHash;
```

- [ ] **Step 4: Obtain and install the source hash**

Run:

```bash
nix-config-crabbox --reason implementation build darwin \
  .#darwinConfigurations.macbook.pkgs.kanata-cheatsheet
```

Expected first result: fixed-output hash mismatch showing the actual SHA-256.
Replace `fakeHash` with that exact hash.

- [ ] **Step 5: Verify the focused Darwin package**

Run the same Crabbox build again. Expected: exit 0 and a successfully built
`kanata-cheatsheet` package. Run `nixfmt --check overlays/kanata-cheatsheet.nix`
and `git diff --check`.

- [ ] **Step 6: Commit the Nix pin**

```bash
git add -- overlays/kanata-cheatsheet.nix
git commit -m 'build(kanata-cheatsheet): 📦 pin adaptive label visibility'
```

Verify the signed commit and clean worktree.

### Task 5: Review, publish, deploy, and verify live behavior

**Files:**
- Review: Nix pin diff from `origin/main` through the Nix worktree head
- Runtime: `~/.config/kanata-cheatsheet/registry.json`, LaunchAgent

- [ ] **Step 1: Request independent Nix pin review**

Use `reviewing-code` Request mode with exact SHAs, pin diff, app review verdict,
package build output, and source-hash evidence. Resolve all blocking findings.

- [ ] **Step 2: Publish and clean the Nix worktree**

Run:

```bash
git wt-finish adaptive-label-visibility-pin
```

Expected: signed Nix commit reaches `origin/main`, Nix worktree and branch are
removed, and a clean primary checkout fast-forwards without touching foreign
state.

- [ ] **Step 3: Deploy from the nix-config primary checkout**

Run:

```bash
just switch
```

Expected: Macserver prewarm succeeds, the exact signed Nix revision activates
on the MacBook, and post-activation Attic replication verifies.

- [ ] **Step 4: Verify the live service and exact binary**

Check `/run/current-system/darwin-version.json`,
`launchctl print gui/$(id -u)/local.kanata-cheatsheet`, and the running process.
Require the deployed configuration revision to contain the Nix pin commit and
the process path to use the newly built app store path.

- [ ] **Step 5: Verify the installed visual result**

Capture the four offscreen layers with the installed registry and the published
app source. Require each live image to match its reviewed candidate image and
confirm foreground focus is unchanged.

### Task 6: Reconcile and archive the as-built app change

**Files:**
- Modify: `_changes/2026-08-30-adaptive-label-visibility/adaptive-label-visibility.spec.md`
- Modify: `_changes/2026-08-30-adaptive-label-visibility/change.yaml`
- Move: `_changes/2026-08-30-adaptive-label-visibility/` to `_changes/_archive/2026-08-30-adaptive-label-visibility/`

- [ ] **Step 1: Reconcile the specification as built**

Append an `As Built` section naming the final app and Nix SHAs, exact files,
RED/GREEN counts, build results, visual delta, review verdicts, deployed system
revision, live binary path, and any unresolved warning. Do not claim evidence
that was not observed.

- [ ] **Step 2: Close the lifecycle record**

Set `status: archived` and append `completed` and `archived` history entries
with this session and tool. Move the folder with `git mv` into `_changes/_archive/`.

- [ ] **Step 3: Commit and finish the app worktree**

Commit the as-built archive, then run:

```bash
git wt-finish adaptive-label-visibility
```

Expected: the archive commit reaches app `origin/main`; the app worktree and
branch are removed; the primary app checkout is clean and current.

- [ ] **Step 4: Run loop-closure verification**

Use `closing-loops` to verify both repositories contain their expected commits,
the app change is archived and retrievable, the deployed service uses the new
binary, and no unrelated source-owner state was changed.
