#if DEBUG
import SwiftUI

/// Debug-only helpers used to capture App Store screenshots and run end-to-end smoke tests.
enum Autoplay {
    static let args = ProcessInfo.processInfo.arguments
    static var enabled: Bool { args.contains("-autoplay") }
    static var demo: Bool { args.contains("-demo") }
    static var route: String? {
        guard let i = args.firstIndex(of: "-route"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

extension GameStore {
    func applyDemoProfile() {
        var d = Profile()
        d.name = "Marco"
        d.mp = 310
        d.wins = 27; d.losses = 11; d.matches = 38
        d.rounds = 160; d.perfectRounds = 23
        d.bestRun = 431
        d.streak = 6; d.bestStreak = 9
        d.lastDailyKey = DayKey.key()
        d.tickets = 3; d.lastRefillKey = DayKey.key()
        d.onboarded = true
        d.reviewAsked = true
        d.lastPaywallMatch = 38
        for i in 0..<14 {
            if i % 5 != 3 { d.dailyScores[String(DayKey.offset(i - 13))] = 250 + (i * 37) % 230 }
        }
        d.dailyScores[String(DayKey.key())] = 412
        d.rivals = ["Lena": [3, 1], "Tom": [1, 2], "Mia": [2, 2]]
        p = d
    }
}

extension PlayPad {
    @MainActor func runAutoplay(go: Date, setPts: @escaping ([CGPoint]) -> Void, setPinch: @escaping (Double) -> Void, finish: @escaping (Double) -> Void) async {
        guard Autoplay.enabled else { return }
        try? await Task.sleep(for: .seconds(0.5))
        var g = SeededGenerator(seed: UInt64.random(in: 1...9999))
        let jitter = Double.random(in: 0.004...0.02, using: &g)
        switch move.kind {
        case .path:
            var acc: [CGPoint] = []
            let tgt = move.target
            for (i, p) in tgt.enumerated() {
                acc.append(CGPoint(x: p.x + sin(Double(i) * 0.5) * jitter, y: p.y + cos(Double(i) * 0.7) * jitter))
                if i % 3 == 0 { setPts(acc); try? await Task.sleep(for: .seconds(move.duration * 0.55 / Double(tgt.count) * 3)) }
            }
            setPts(acc)
            finish(Date().timeIntervalSince(go))
        case .taps:
            break // handled by the pad through finish with synthetic taps
        case .pinch:
            setPinch(move.pinchScale * 0.93)
            try? await Task.sleep(for: .seconds(0.5))
            finish(Date().timeIntervalSince(go))
        }
    }
}
#endif
