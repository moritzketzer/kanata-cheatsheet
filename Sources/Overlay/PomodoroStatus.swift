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

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.isLenient = false
        guard schemaVersion == 1,
              dissertationSeconds >= 0,
              state == .expired || remainingSeconds >= 0,
              date.count == 10,
              let parsedDate = dateFormatter.date(from: date),
              dateFormatter.string(from: parsedDate) == date
        else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid Pomodoro status snapshot"
            ))
        }
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
        "Heute Dissertation: \(dissertationSeconds / 60) / 30 Minuten"
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
        return (0...5).contains(age) ? status : nil
    }
}
