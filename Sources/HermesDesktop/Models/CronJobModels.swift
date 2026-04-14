import Foundation

struct CronJobListResponse: Codable {
    let ok: Bool
    let jobs: [CronJob]
}

struct CronJob: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let prompt: String
    let skills: [String]
    let model: String?
    let provider: String?
    let schedule: CronSchedule?
    let scheduleDisplay: String
    let recurrence: CronRecurrence?
    let enabled: Bool
    let state: String
    let createdAt: Date?
    let nextRunAt: Date?
    let lastRunAt: Date?
    let lastStatus: String?
    let lastError: String?
    let deliveryTarget: String?
    let origin: CronJobOrigin?
    let lastDeliveryError: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case prompt
        case skills
        case model
        case provider
        case schedule
        case scheduleDisplay = "schedule_display"
        case recurrence
        case enabled
        case state
        case createdAt = "created_at"
        case nextRunAt = "next_run_at"
        case lastRunAt = "last_run_at"
        case lastStatus = "last_status"
        case lastError = "last_error"
        case deliveryTarget = "delivery_target"
        case origin
        case lastDeliveryError = "last_delivery_error"
    }

    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? id : trimmed
    }

    var trimmedPrompt: String? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var previewPrompt: String {
        guard let trimmedPrompt else {
            return "No saved prompt payload"
        }

        let compact = trimmedPrompt.replacingOccurrences(of: "\n", with: " ")
        return compact.count > 140 ? String(compact.prefix(140)) + "…" : compact
    }

    var resolvedScheduleDisplay: String {
        if let rawScheduleText {
            return CronScheduleFormatter.humanReadableDescription(for: rawScheduleText) ?? rawScheduleText
        }

        return "No schedule metadata"
    }

    var isPaused: Bool {
        normalizedState == "paused"
    }

    var isRunning: Bool {
        normalizedState == "running"
    }

    var isActive: Bool {
        isRunning || normalizedState == "scheduled"
    }

    var displayState: String {
        switch normalizedState {
        case "scheduled":
            return "Active"
        case "":
            return enabled ? "Active" : "Paused"
        default:
            return normalizedState
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    var displayModel: String? {
        guard let model,
              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if model.count <= 34 {
            return model
        }

        let prefix = model.prefix(16)
        let suffix = model.suffix(12)
        return "\(prefix)…\(suffix)"
    }

    func matchesSearch(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        let normalizedQuery = trimmedQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let haystacks = [
            id,
            resolvedName,
            prompt,
            resolvedScheduleDisplay,
            rawScheduleText ?? "",
            model ?? "",
            provider ?? ""
        ] + skills

        return haystacks.contains { value in
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .localizedStandardContains(normalizedQuery)
        }
    }

    private var normalizedState: String {
        state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var rawScheduleText: String? {
        let display = scheduleDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        if !display.isEmpty {
            return display
        }

        let expr = schedule?.expr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return expr.isEmpty ? nil : expr
    }
}

struct CronSchedule: Codable, Hashable {
    let kind: String?
    let expr: String?
    let timezone: String?
}

struct CronRecurrence: Codable, Hashable {
    let times: Int?
    let remaining: Int?
}

struct CronJobOrigin: Codable, Hashable {
    let kind: String?
    let source: String?
    let label: String?
}

private enum CronScheduleFormatter {
    private static let weekdaySymbols = [
        "0": "Sun",
        "1": "Mon",
        "2": "Tue",
        "3": "Wed",
        "4": "Thu",
        "5": "Fri",
        "6": "Sat",
        "7": "Sun",
        "sun": "Sun",
        "mon": "Mon",
        "tue": "Tue",
        "wed": "Wed",
        "thu": "Thu",
        "fri": "Fri",
        "sat": "Sat"
    ]

    static func humanReadableDescription(for expression: String) -> String? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 5 else { return nil }

        let minute = parts[0]
        let hour = parts[1]
        let dayOfMonth = parts[2]
        let month = parts[3]
        let dayOfWeek = parts[4]

        guard let time = formattedTime(hour: hour, minute: minute) else {
            return nil
        }

        if dayOfMonth == "*", month == "*", dayOfWeek == "*" {
            return "Every day at \(time)"
        }

        if dayOfMonth == "*", month == "*", dayOfWeek == "1-5" {
            return "Every weekday at \(time)"
        }

        if dayOfMonth == "*", month == "*",
           let days = formattedWeekdays(dayOfWeek) {
            return "Every \(days) at \(time)"
        }

        if hour == "*", month == "*", dayOfMonth == "*", dayOfWeek == "*",
           let minuteValue = Int(minute) {
            return String(format: "Every hour at :%02d", minuteValue)
        }

        if month == "*", dayOfWeek == "*",
           let day = Int(dayOfMonth) {
            return "On day \(day) of every month at \(time)"
        }

        return nil
    }

    private static func formattedTime(hour: String, minute: String) -> String? {
        guard let hourValue = Int(hour), let minuteValue = Int(minute),
              (0...23).contains(hourValue), (0...59).contains(minuteValue) else {
            return nil
        }

        return String(format: "%02d:%02d", hourValue, minuteValue)
    }

    private static func formattedWeekdays(_ rawValue: String) -> String? {
        let values = rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard !values.isEmpty else { return nil }

        let resolved = values.compactMap { weekdaySymbols[$0] }
        guard resolved.count == values.count else { return nil }

        return resolved.joined(separator: ", ")
    }
}
