import SwiftUI
import UserNotifications
import AppKit

@main
struct StreakByteApp: App {
    @StateObject private var model = StreakModel()

    var body: some Scene {
        WindowGroup("StreakByte") {
            StreakPopover()
                .environmentObject(model)
                .frame(width: 340)
                .padding(.vertical, 4)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra {
            StreakPopover()
                .environmentObject(model)
                .frame(width: 340)
        } label: {
            Label("StreakByte", systemImage: model.didCompleteToday ? "flame.fill" : "flame")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 430, height: 300)
        }
    }
}

@MainActor
final class StreakModel: ObservableObject {
    private enum Keys {
        static let solvedDates = "solvedDates"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let remindersEnabled = "remindersEnabled"
    }

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @Published private(set) var solvedDates: Set<String> = []
    @Published var reminderHour: Int {
        didSet { defaults.set(reminderHour, forKey: Keys.reminderHour) }
    }
    @Published var reminderMinute: Int {
        didSet { defaults.set(reminderMinute, forKey: Keys.reminderMinute) }
    }
    @Published var remindersEnabled: Bool {
        didSet {
            defaults.set(remindersEnabled, forKey: Keys.remindersEnabled)
            Task { await refreshReminder() }
        }
    }

    init() {
        solvedDates = Set(defaults.stringArray(forKey: Keys.solvedDates) ?? [])
        reminderHour = defaults.object(forKey: Keys.reminderHour) == nil ? 20 : defaults.integer(forKey: Keys.reminderHour)
        reminderMinute = defaults.object(forKey: Keys.reminderMinute) == nil ? 0 : defaults.integer(forKey: Keys.reminderMinute)
        remindersEnabled = defaults.object(forKey: Keys.remindersEnabled) == nil ? true : defaults.bool(forKey: Keys.remindersEnabled)
        Task { await refreshReminder() }
    }

    var didCompleteToday: Bool { solved(on: Date()) }

    var currentStreak: Int {
        var streak = 0
        var date = Date()
        if !solved(on: date), let yesterday = calendar.date(byAdding: .day, value: -1, to: date) { date = yesterday }
        while solved(on: date) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return streak
    }

    var longestStreak: Int {
        let dates = solvedDates.compactMap(formatter.date).sorted()
        guard !dates.isEmpty else { return 0 }
        var best = 1
        var run = 1
        for index in 1..<dates.count {
            if calendar.dateComponents([.day], from: dates[index - 1], to: dates[index]).day == 1 {
                run += 1
                best = max(best, run)
            } else if !calendar.isDate(dates[index - 1], inSameDayAs: dates[index]) {
                run = 1
            }
        }
        return best
    }

    var lastSevenDays: [Date] {
        (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
    }

    var mascotMessage: String {
        if didCompleteToday { return currentStreak >= 7 ? "Absolutely cracked. See you tomorrow." : "Streak protected. I can relax now." }
        let hour = calendar.component(.hour, from: Date())
        if hour >= 22 { return "Your streak is in the danger zone. One Easy. Now." }
        if hour >= 18 { return "LeetCode is still waiting. Suspiciously patiently." }
        return currentStreak > 0 ? "Day \(currentStreak + 1) is yours for the taking." : "One question. Tiny commitment. Big main-character energy." 
    }

    func solved(on date: Date) -> Bool { solvedDates.contains(formatter.string(from: date)) }

    func toggleToday() {
        let key = formatter.string(from: Date())
        if solvedDates.contains(key) { solvedDates.remove(key) } else { solvedDates.insert(key) }
        defaults.set(Array(solvedDates), forKey: Keys.solvedDates)
        objectWillChange.send()
        Task { await refreshReminder() }
    }

    func openLeetCode() {
        NSWorkspace.shared.open(URL(string: "https://leetcode.com/problemset/?difficulty=EASY&page=1")!)
    }

    func updateReminder(date: Date) {
        reminderHour = calendar.component(.hour, from: date)
        reminderMinute = calendar.component(.minute, from: date)
        Task { await refreshReminder() }
    }

    var reminderDate: Date {
        calendar.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
    }

    private func refreshReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-leetcode"])
        guard remindersEnabled, !didCompleteToday else { return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = currentStreak > 0 ? "Protect your \(currentStreak)-day streak 🔥" : "Your first streak starts today"
            content.body = "One LeetCode question. Open StreakByte when you’re done."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: reminderHour, minute: reminderMinute), repeats: true)
            try await center.add(UNNotificationRequest(identifier: "daily-leetcode", content: content, trigger: trigger))
        } catch {
            // The app remains fully usable if notification permission is declined.
        }
    }
}

struct StreakPopover: View {
    @EnvironmentObject private var model: StreakModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("STREAKBYTE")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(model.didCompleteToday ? "Nice work!" : "Code something.")
                        .font(.title2.bold())
                }
                Spacer()
                Text(model.didCompleteToday ? "😌" : model.currentStreak > 0 ? "👀" : "🫵")
                    .font(.system(size: 40))
            }

            HStack(spacing: 10) {
                StatCard(value: "\(model.currentStreak)", label: "day streak", color: .orange)
                StatCard(value: "\(model.longestStreak)", label: "personal best", color: .purple)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(model.mascotMessage)
                    .font(.callout.weight(.medium))
                HStack(spacing: 7) {
                    ForEach(model.lastSevenDays, id: \.self) { date in
                        DayDot(date: date, isSolved: model.solved(on: date), isToday: Calendar.current.isDateInToday(date))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))

            if model.didCompleteToday {
                Button(action: model.toggleToday) {
                    Label("Done for today", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
            } else {
                Button(action: model.openLeetCode) {
                    Label("Open an Easy question", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)

                Button(action: model.toggleToday) {
                    Label("I solved one!", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Settings") { openSettings() }.buttonStyle(.plain)
                Spacer()
                Button("Hide") { NSApplication.shared.hide(nil) }.buttonStyle(.plain)
                Text("·")
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct DayDot: View {
    let date: Date
    let isSolved: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(date, format: .dateTime.weekday(.narrow)).font(.caption2).foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 6)
                .fill(isSolved ? Color.green : Color.secondary.opacity(0.14))
                .overlay(isToday ? RoundedRectangle(cornerRadius: 6).stroke(Color.orange, lineWidth: 2) : nil)
                .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: StreakModel

    var body: some View {
        Form {
            Section("Daily reminder") {
                Toggle("Remind me every day", isOn: $model.remindersEnabled)
                DatePicker("Reminder time", selection: Binding(get: { model.reminderDate }, set: model.updateReminder), displayedComponents: .hourAndMinute)
                    .disabled(!model.remindersEnabled)
            }
            Section("How it works") {
                Text("Solve anywhere on LeetCode, then tap “I solved one!” in the menu bar. Your history stays privately on this Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
