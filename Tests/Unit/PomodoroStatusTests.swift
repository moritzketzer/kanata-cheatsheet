import Testing
import Foundation

@Suite("Pomodoro status")
struct PomodoroStatusTests {
    @Test("paused dissertation snapshot produces the requested header")
    func pausedHeader() throws {
        let status = try JSONDecoder().decode(
            PomodoroStatus.self,
            from: Data(pomodoroFixture().utf8)
        )

        #expect(status.statusLine == "Pausiert · 03:42 übrig · Dissertation")
        #expect(status.progressLine == "Heute Dissertation: 12 / 30 Minuten")
        #expect(try JSONDecoder().decode(
            PomodoroStatus.self,
            from: JSONEncoder().encode(status)
        ) == status)
    }

    @Test("phase and attribution labels remain distinct", arguments: [
        ("idle", "work", "general", 1500, "Bereit · 25:00 · D: Dissertation"),
        ("running", "work", "general", 222, "Läuft · 03:42 übrig · Allgemein"),
        ("running", "work", "dissertation", 222, "Läuft · 03:42 übrig · Dissertation"),
        ("paused", "work", "general", 222, "Pausiert · 03:42 übrig · Allgemein"),
        ("running", "break", "dissertation", 222, "Läuft · 03:42 übrig · Pause"),
        ("paused", "break", "dissertation", 222, "Pausiert · 03:42 übrig · Pause"),
        ("expired", "work", "dissertation", -222, "Abgelaufen · Dissertation"),
        ("expired", "break", "general", 0, "Abgelaufen · Pause"),
    ])
    func phaseLabels(
        state: String, mode: String, context: String, remaining: Int, expected: String
    ) throws {
        let status = try JSONDecoder().decode(
            PomodoroStatus.self,
            from: Data(pomodoroFixture(
                state: state, mode: mode, context: context, remaining: remaining
            ).utf8)
        )
        #expect(status.statusLine == expected)
    }

    @Test("progress uses whole minutes without capping the goal", arguments: [
        (59, "Heute Dissertation: 0 / 30 Minuten"),
        (1799, "Heute Dissertation: 29 / 30 Minuten"),
        (1800, "Heute Dissertation: 30 / 30 Minuten"),
        (2461, "Heute Dissertation: 41 / 30 Minuten"),
    ])
    func completedMinutes(seconds: Int, expected: String) throws {
        let status = try JSONDecoder().decode(
            PomodoroStatus.self,
            from: Data(pomodoroFixture(progress: seconds).utf8)
        )
        #expect(status.progressLine == expected)
    }

    @Test("malformed and unsupported snapshots are rejected", arguments: [
        "{}", "not json",
        pomodoroFixture().replacingOccurrences(of: "\"schema_version\":1", with: "\"schema_version\":2"),
        pomodoroFixture(state: "unknown"),
        pomodoroFixture(mode: "unknown"),
        pomodoroFixture(context: "unknown"),
        pomodoroFixture(remaining: -1),
        pomodoroFixture(progress: -1),
        pomodoroFixture(date: "2026-02-30"),
        pomodoroFixture(date: "2026-9-8"),
        pomodoroFixture().replacingOccurrences(of: "\"observed_at\":1000", with: "\"observed_at\":1.5"),
    ])
    func rejectsInvalidSnapshots(json: String) {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PomodoroStatus.self, from: Data(json.utf8))
        }
    }

    @Test("reader accepts fresh snapshots and rejects future or stale observations")
    func readerFreshness() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PomodoroStatusTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("status.json")

        #expect(PomodoroStatus.read(from: path, now: Date(timeIntervalSince1970: 1000)) == nil)
        try Data(pomodoroFixture().utf8).write(to: path)
        #expect(PomodoroStatus.read(from: path, now: Date(timeIntervalSince1970: 1000)) != nil)
        #expect(PomodoroStatus.read(from: path, now: Date(timeIntervalSince1970: 1005)) != nil)
        #expect(PomodoroStatus.read(from: path, now: Date(timeIntervalSince1970: 1005.01)) == nil)
        #expect(PomodoroStatus.read(from: path, now: Date(timeIntervalSince1970: 999.99)) == nil)
        try Data("invalid".utf8).write(to: path)
        #expect(PomodoroStatus.read(from: path, now: Date(timeIntervalSince1970: 1000)) == nil)
    }

    @Test("snapshot location follows XDG state home with the home fallback")
    func snapshotLocation() {
        let home = URL(fileURLWithPath: "/example/home")
        #expect(PomodoroStatus.defaultURL(environment: [:], homeDirectory: home).path
            == "/example/home/.local/state/pomodoro/status.json")
        #expect(PomodoroStatus.defaultURL(environment: ["XDG_STATE_HOME": ""], homeDirectory: home).path
            == "/example/home/.local/state/pomodoro/status.json")
        #expect(PomodoroStatus.defaultURL(environment: ["XDG_STATE_HOME": "/example/state"], homeDirectory: home).path
            == "/example/state/pomodoro/status.json")
    }
}

func pomodoroFixture(
    state: String = "paused",
    mode: String = "work",
    context: String = "dissertation",
    remaining: Int = 222,
    progress: Int = 720,
    date: String = "2026-09-08"
) -> String {
    """
    {"schema_version":1,"observed_at":1000,"state":"\(state)","mode":"\(mode)","context":"\(context)","remaining_seconds":\(remaining),"date":"\(date)","dissertation_seconds":\(progress)}
    """
}
