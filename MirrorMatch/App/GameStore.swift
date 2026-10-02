import SwiftUI
import UserNotifications

enum DayKey {
    static func key(_ date: Date = Date()) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }
    static func offset(_ days: Int, from date: Date = Date()) -> Int {
        key(Calendar.current.date(byAdding: .day, value: days, to: date) ?? date)
    }
    /// Daily challenge number (day 1 = launch day).
    static func dailyNumber(_ date: Date = Date()) -> Int {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        return max(1, (Calendar.current.dateComponents([.day], from: start, to: Calendar.current.startOfDay(for: date)).day ?? 0) + 1)
    }
}

struct Profile: Codable {
    var name = ""
    var mp = 0
    var wins = 0
    var losses = 0
    var rounds = 0
    var perfectRounds = 0
    var bestRun = 0
    var streak = 0
    var brokenStreak = 0
    var bestStreak = 0
    var lastDailyKey = 0
    var dailyScores: [String: Int] = [:]
    var tickets = 3
    var lastRefillKey = 0
    var skin = "neon"
    var haptics = true
    var reminders = false
    var onboarded = false
    var customDayKey = 0
    var customCount = 0
    var rivals: [String: [Int]] = [:]
    var matches = 0
    var reviewAsked = false
    var lastPaywallMatch = 0
}

@MainActor
@Observable
final class GameStore {
    var p: Profile { didSet { save() } }
    private let storageKey = "mm.profile.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: storageKey), let prof = try? JSONDecoder().decode(Profile.self, from: d) {
            p = prof
        } else {
            p = Profile()
        }
        refreshDay()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(p) { UserDefaults.standard.set(d, forKey: storageKey) }
    }

    // MARK: derived
    var displayName: String { p.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Player" : p.name }
    var rankIndex: Int { Rank.index(for: p.mp) }
    var rankName: String { Rank.names[rankIndex] }
    var todayKey: Int { DayKey.key() }
    var dailyDone: Bool { p.dailyScores[String(todayKey)] != nil }
    var todayScore: Int? { p.dailyScores[String(todayKey)] }
    var streakAlive: Bool { p.lastDailyKey == todayKey || p.lastDailyKey == DayKey.offset(-1) }
    var currentStreak: Int { streakAlive ? p.streak : 0 }
    var canRepairStreak: Bool { p.brokenStreak >= 3 && p.lastDailyKey == DayKey.offset(-2) && !streakAlive }
    var skin: Skin { Skin.byID(p.skin) }

    // MARK: day rollover & tickets
    func refreshDay() {
        let today = todayKey
        if p.lastRefillKey != today {
            if p.tickets < 3 { p.tickets = 3 }
            p.lastRefillKey = today
        }
        if !streakAlive && p.streak > 0 {
            if p.lastDailyKey == DayKey.offset(-2) { p.brokenStreak = p.streak }
            p.streak = 0
        }
    }

    func spendTickets(_ n: Int, isPro: Bool) -> Bool {
        if isPro { return true }
        guard p.tickets >= n else { return false }
        p.tickets -= n
        return true
    }

    func addTickets(_ n: Int) { p.tickets += n }

    func repairStreak() -> Bool {
        guard canRepairStreak, p.tickets >= 3 else { return false }
        p.tickets -= 3
        p.streak = p.brokenStreak
        p.lastDailyKey = DayKey.offset(-1)
        p.brokenStreak = 0
        return true
    }

    // MARK: results
    func completeDaily(score: Int) {
        let key = String(todayKey)
        let isFirst = p.dailyScores[key] == nil
        if isFirst {
            p.streak = (p.lastDailyKey == DayKey.offset(-1)) ? p.streak + 1 : 1
            p.lastDailyKey = todayKey
            p.brokenStreak = 0
            p.bestStreak = max(p.bestStreak, p.streak)
        }
        p.dailyScores[key] = max(score, p.dailyScores[key] ?? 0)
        p.bestRun = max(p.bestRun, score)
        // keep history small
        if p.dailyScores.count > 60 {
            for k in p.dailyScores.keys.sorted().prefix(p.dailyScores.count - 60) { p.dailyScores[k] = nil }
        }
    }

    func recordRun(score: Int) { p.bestRun = max(p.bestRun, score) }

    func recordRound(_ r: RoundResult) {
        p.rounds += 1
        if r.score >= 95 { p.perfectRounds += 1 }
    }

    /// Returns the MP change.
    @discardableResult
    func recordGhostMatch(won: Bool) -> Int {
        p.matches += 1
        let base = 12 + rankIndex * 2
        let delta = won ? base + 12 : -min(p.mp, 8)
        p.mp = max(0, p.mp + delta)
        if won { p.wins += 1 } else { p.losses += 1 }
        return delta
    }

    func recordFriendMatch(rival: String, won: Bool) {
        var r = p.rivals[rival] ?? [0, 0]
        r[won ? 0 : 1] += 1
        p.rivals[rival] = r
        p.matches += 1
        if won { p.wins += 1 } else { p.losses += 1 }
    }

    func recordHeadToHead() { p.matches += 1 }

    func isUnlocked(_ skin: Skin, isPro: Bool, hasPack: Bool) -> Bool {
        if isPro || hasPack { return true }
        switch skin.unlock {
        case .free: return true
        case .streak(let n): return p.bestStreak >= n
        case .rank(let r): return rankIndex >= r
        case .premium: return false
        }
    }

    var customAvailableForFree: Bool { p.customDayKey != todayKey || p.customCount < 1 }
    func noteCustomCreated() {
        if p.customDayKey != todayKey { p.customDayKey = todayKey; p.customCount = 0 }
        p.customCount += 1
    }

    // MARK: reminders
    func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                self.p.reminders = granted
                guard granted else { return }
                center.removePendingNotificationRequests(withIdentifiers: ["daily"])
                let content = UNMutableNotificationContent()
                content.title = "Today's Daily Challenge is live 🪞"
                content.body = "Same 5 moves for everyone. Keep your streak alive!"
                content.sound = .default
                var comps = DateComponents(); comps.hour = 18; comps.minute = 30
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                center.add(UNNotificationRequest(identifier: "daily", content: content, trigger: trigger))
            }
        }
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily"])
        p.reminders = false
    }
}

