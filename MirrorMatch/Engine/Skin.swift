import SwiftUI

enum SkinStyle { case plain, sparkle, rainbow, dots }

struct Skin: Identifiable, Hashable {
    enum Unlock: Hashable { case free, streak(Int), rank(Int), premium }
    let id: String
    let name: String
    let colors: [Color]
    let style: SkinStyle
    let unlock: Unlock

    var head: Color { colors.first ?? .white }
    var gradient: LinearGradient { LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing) }

    static let all: [Skin] = [
        Skin(id: "neon", name: "Neon", colors: [Theme.cyan, Theme.magenta], style: .plain, unlock: .free),
        Skin(id: "sunset", name: "Sunset", colors: [Color(red: 1, green: 0.62, blue: 0.2), Color(red: 1, green: 0.25, blue: 0.5)], style: .plain, unlock: .free),
        Skin(id: "flame", name: "Flame", colors: [Color(red: 1, green: 0.85, blue: 0.2), Color(red: 1, green: 0.3, blue: 0.1)], style: .sparkle, unlock: .streak(7)),
        Skin(id: "mint", name: "Mint Dots", colors: [Color(red: 0.4, green: 1, blue: 0.75), Color(red: 0.2, green: 0.7, blue: 1)], style: .dots, unlock: .rank(2)),
        Skin(id: "aurora", name: "Aurora", colors: [Color(red: 0.4, green: 1, blue: 0.7), Color(red: 0.55, green: 0.4, blue: 1)], style: .sparkle, unlock: .premium),
        Skin(id: "prism", name: "Prism", colors: [.red, .orange, .yellow, .green, .cyan, .purple], style: .rainbow, unlock: .premium),
        Skin(id: "gold", name: "Gold Rush", colors: [Color(red: 1, green: 0.9, blue: 0.5), Color(red: 0.9, green: 0.62, blue: 0.1)], style: .sparkle, unlock: .premium),
        Skin(id: "glitch", name: "Glitch", colors: [Color(red: 0.2, green: 1, blue: 0.3), Color(red: 0.1, green: 0.5, blue: 0.2)], style: .dots, unlock: .premium),
        Skin(id: "candy", name: "Candy", colors: [Color(red: 1, green: 0.6, blue: 0.85), Color(red: 0.6, green: 0.8, blue: 1)], style: .sparkle, unlock: .premium),
        Skin(id: "ice", name: "Ice", colors: [.white, Color(red: 0.5, green: 0.85, blue: 1)], style: .sparkle, unlock: .premium)
    ]

    static func byID(_ id: String) -> Skin { all.first { $0.id == id } ?? all[0] }

    func color(at t: Double) -> Color {
        guard colors.count > 1 else { return head }
        let x = max(0, min(0.9999, t)) * Double(colors.count - 1)
        let i = Int(x)
        let f = x - Double(i)
        return Color.mix(colors[i], colors[i + 1], f)
    }
}

extension Color {
    static func mix(_ a: Color, _ b: Color, _ f: Double) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: r1 + (r2 - r1) * f, green: g1 + (g2 - g1) * f, blue: b1 + (b2 - b1) * f)
    }
}

enum Rank {
    static let names = ["Rookie", "Copycat", "Mimic", "Mirror", "Phantom", "Legend"]
    static let thresholds = [0, 100, 250, 500, 900, 1500]
    static let icons = ["circle.dotted", "square.on.square", "person.2.fill", "sparkles", "bolt.fill", "crown.fill"]

    static func index(for mp: Int) -> Int {
        var idx = 0
        for (i, t) in thresholds.enumerated() where mp >= t { idx = i }
        return idx
    }
    static func progress(for mp: Int) -> Double {
        let i = index(for: mp)
        guard i < thresholds.count - 1 else { return 1 }
        return Double(mp - thresholds[i]) / Double(thresholds[i + 1] - thresholds[i])
    }
    static func toNext(_ mp: Int) -> Int? {
        let i = index(for: mp)
        return i < thresholds.count - 1 ? thresholds[i + 1] - mp : nil
    }
}
