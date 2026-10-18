import Foundation

struct PomodoroStatus: Codable, Equatable {
    enum State: String, Codable {
        case idle, running, paused, expired
    }

    enum Mode: String, Codable {
        case work, `break`
    }

    enum Context: String, Codable {
        case general, dissertation
    }

    let schemaVersion: Int
    let observedAt: Int
    let state: State
    let mode: Mode
    let context: Context
    let remainingSeconds: Int
    let date: String
    let dissertationSeconds: Int

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case observedAt = "observed_at"
        case state, mode, context, date
        case remainingSeconds = "remaining_seconds"
        case dissertationSeconds = "dissertation_seconds"
    }

    /// Minutes of dissertation work the Pomodoro day aims for.
    private static let dailyGoalMinutes = 30

    /// A snapshot older than this is treated as stale and discarded.
    private static let maxSnapshotAgeSeconds: Double = 5

    /// Fixed locale and calendar so a snapshot date round-trips identically
    /// regardless of the user's regional settings.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        observedAt = try values.decode(Int.self, forKey: .observedAt)
        state = try values.decode(State.self, forKey: .state)
        mode = try values.decode(Mode.self, forKey: .mode)
        context = try values.decode(Context.self, forKey: .context)
        remainingSeconds = try values.decode(Int.self, forKey: .remainingSeconds)
        date = try values.decode(String.self, forKey: .date)
        dissertationSeconds = try values.decode(Int.self, forKey: .dissertationSeconds)

        guard isSelfConsistent else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid Pomodoro status snapshot"
            ))
        }
    }

    /// A snapshot is only usable when the writer's schema matches, the
    /// counters are non-negative, and `date` is a real calendar day.
    private var isSelfConsistent: Bool {
        guard schemaVersion == 1,
              dissertationSeconds >= 0,
              state == .expired || remainingSeconds >= 0,
              date.count == 10,
              let parsedDate = Self.dateFormatter.date(from: date),
              Self.dateFormatter.string(from: parsedDate) == date
        else { return false }
        return true
    }

    var statusLine: String {
        let category = mode == .break ? "Pause"
            : (context == .dissertation ? "Dissertation" : "Allgemein")
        switch state {
        case .idle:
            return "Bereit · \(remainingTime) · D: Dissertation"
        case .running:
            return "Läuft · \(remainingTime) übrig · \(category)"
        case .paused:
            return "Pausiert · \(remainingTime) übrig · \(category)"
        case .expired:
            return "Abgelaufen · \(category)"
        }
    }

    var progressLine: String {
        "Heute Dissertation: \(dissertationSeconds / 60) / \(Self.dailyGoalMinutes) Minuten"
    }

    private var remainingTime: String {
        let seconds = max(0, remainingSeconds)
        return String(format: "%02ld:%02ld", seconds / 60, seconds % 60)
    }

    static func defaultURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let stateHome: URL
        if let path = environment["XDG_STATE_HOME"], !path.isEmpty {
            stateHome = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            stateHome = homeDirectory.appendingPathComponent(".local/state", isDirectory: true)
        }
        return stateHome.appendingPathComponent("pomodoro/status.json")
    }

    static func read(
        from url: URL = defaultURL(),
        now: Date = Date()
    ) -> PomodoroStatus? {
        guard let data = try? Data(contentsOf: url),
              let status = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }
        let age = now.timeIntervalSince1970 - Double(status.observedAt)
        return (0...maxSnapshotAgeSeconds).contains(age) ? status : nil
    }
}
