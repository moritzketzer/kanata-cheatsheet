# TCP Reconnect `.waiting` Recovery Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `KanataTCPClient` retry when Network.framework parks a connection in `.waiting`, so the cheatsheet reconnects after a kanata outage without a LaunchAgent restart.

**Architecture:** Extract a pure `NWConnection.State → TCPStateAction` mapping as a testable seam; the `stateUpdateHandler` switches on it and treats `.waiting` like `.failed` (cancel + schedule the single existing reconnect timer). An identity guard drops events from superseded connections.

**Tech Stack:** Swift, Network.framework, Swift Testing, raw `swiftc` via Makefile (`make test`).

---

### Task 1: Pure state→action seam with RED regression test

**Files:**
- Create: `Tests/Unit/TCPReconnectTests.swift`
- Modify: `Sources/TCP/KanataTCPClient.swift` (add enum + static func near the `// MARK: - TCP Client` section)

- [ ] **Step 1: Write the failing regression test**

Create `Tests/Unit/TCPReconnectTests.swift`:

```swift
import Testing
import Network

@Suite("TCP Reconnect")
struct TCPReconnectTests {
    @Test("waiting state retries (regression: client stranded after refused reconnect)")
    func waitingRetries() {
        let refused = NWError.posix(.ECONNREFUSED)
        #expect(KanataTCPClient.action(for: .waiting(refused)) == .retry)
    }

    @Test("failed state retries")
    func failedRetries() {
        #expect(KanataTCPClient.action(for: .failed(NWError.posix(.ECONNRESET))) == .retry)
    }

    @Test("ready state connects")
    func readyConnects() {
        #expect(KanataTCPClient.action(for: .ready) == .connected)
    }

    @Test("setup, preparing, and cancelled are ignored")
    func lifecycleIgnored() {
        #expect(KanataTCPClient.action(for: .setup) == .ignore)
        #expect(KanataTCPClient.action(for: .preparing) == .ignore)
        #expect(KanataTCPClient.action(for: .cancelled) == .ignore)
    }
}
```

- [ ] **Step 2: Run tests to verify RED**

Run: `make test`
Expected: compile failure — `KanataTCPClient` has no member `action(for:)` / no `TCPStateAction`. This is the RED state: the mapping does not exist because current code ignores `.waiting`.

- [ ] **Step 3: Implement the pure mapping**

In `Sources/TCP/KanataTCPClient.swift`, insert directly above `protocol KanataTCPClientDelegate`:

```swift
enum TCPStateAction: Equatable {
    case connected
    case retry
    case ignore
}
```

And inside `final class KanataTCPClient` (below `init`), add:

```swift
    /// Pure mapping from NWConnection state to client action.
    /// `.waiting` must retry: on loopback a refused connection never gets a
    /// path-change event, so waiting strands the client forever.
    static func action(for state: NWConnection.State) -> TCPStateAction {
        switch state {
        case .ready:
            return .connected
        case .failed, .waiting:
            return .retry
        case .setup, .preparing, .cancelled:
            return .ignore
        @unknown default:
            return .ignore
        }
    }
```

- [ ] **Step 4: Run tests to verify GREEN**

Run: `make test`
Expected: all suites pass (62 existing + 4 new).

- [ ] **Step 5: Commit**

```bash
git add Tests/Unit/TCPReconnectTests.swift Sources/TCP/KanataTCPClient.swift
git commit -m "test(tcp): ✅ pin state→action mapping incl. waiting retry"
```

### Task 2: Route stateUpdateHandler through the seam

**Files:**
- Modify: `Sources/TCP/KanataTCPClient.swift:90-108` (the `conn.stateUpdateHandler` closure in `connect()`)

- [ ] **Step 1: Replace the state handler**

Replace the existing closure:

```swift
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                Log.info("Connected to kanata TCP at \(self.host):\(self.port)")
                DispatchQueue.main.async { self.delegate?.didConnect() }
                self.receive(on: conn)
            case .failed(let error):
                Log.error("TCP connection failed: \(error)")
                DispatchQueue.main.async {
                    self.delegate?.didDisconnect()
                    self.scheduleReconnect()
                }
            case .cancelled:
                break
            default:
                break
            }
        }
```

with:

```swift
        conn.stateUpdateHandler = { [weak self] state in
            // Identity guard: a superseded connection must not cancel or
            // reschedule over the current one.
            guard let self, self.connection === conn else { return }
            switch KanataTCPClient.action(for: state) {
            case .connected:
                Log.info("Connected to kanata TCP at \(self.host):\(self.port)")
                DispatchQueue.main.async { self.delegate?.didConnect() }
                self.receive(on: conn)
            case .retry:
                Log.error("TCP connection unavailable (\(state)); will retry")
                conn.cancel()
                DispatchQueue.main.async {
                    self.delegate?.didDisconnect()
                    self.scheduleReconnect()
                }
            case .ignore:
                break
            }
        }
```

- [ ] **Step 2: Full suite + app build**

Run: `make test && make all`
Expected: all tests pass; `.build/kanata-cheatsheet` builds cleanly.

- [ ] **Step 3: Commit**

```bash
git add Sources/TCP/KanataTCPClient.swift
git commit -m "fix(tcp): 🐛 retry from waiting state instead of stranding"
```

### Task 3: Review and integrate

- [ ] Independent review via @reviewing-code (verify spec acceptance: retry on `.waiting`, no duplicate timers/connections/event delivery, overlay untouched).
- [ ] Merge to `main` and push via @finishing-a-development-branch / `git wt-finish tcp-reconnect-waiting` (source push must precede the nix pin).

### Task 4: Nix pin + deploy + live verification (nix-config repo)

- [ ] In `nix-config/overlays/kanata-cheatsheet.nix`: `version = "0.2.1"`, `rev = <pushed main commit>`, refresh `hash` (build once to get the mismatch, or `nix-prefetch-github`).
- [ ] Build via the documented Macserver Darwin path; never build Nix automatically on the MacBook. Deploy through the normal nix-config pipeline (per @configuring-systems-with-nix / @operating-nix-config-pipeline).
- [ ] Live verification: confirm cheatsheet TCP connection to 127.0.0.1:7070 (`lsof`); stop kanata > 1 reconnect interval (≥10 s) so a retry hits `Connection refused`; restart kanata; confirm cheatsheet reconnects without LaunchAgent restart and `appfocusd` stays connected. Report overlay visual confirmation separately.
