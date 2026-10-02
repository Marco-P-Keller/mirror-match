import SwiftUI

/// AI opponents. They are always labelled as AI in the UI.
struct Ghost: Hashable, Codable {
    var name: String
    var skill: Double   // 0...1
    var tint: Int       // index for avatar color

    static let roster: [Ghost] = [
        Ghost(name: "Echo", skill: 0.50, tint: 0),
        Ghost(name: "Glitch", skill: 0.62, tint: 1),
        Ghost(name: "Shade", skill: 0.72, tint: 2),
        Ghost(name: "Prism", skill: 0.80, tint: 3),
        Ghost(name: "Nova", skill: 0.88, tint: 4),
        Ghost(name: "Zero", skill: 0.95, tint: 5)
    ]

    static func opponent(forRank rank: Int) -> Ghost {
        let idx = max(0, min(roster.count - 1, rank + Int.random(in: -1...1)))
        return roster[idx]
    }

    /// Simulates a performance on a move: returns a result + the time the ghost needs.
    func perform<G: RandomNumberGenerator>(_ move: Move, using g: inout G) -> RoundResult {
        let sloppy = (1 - skill) * 0.10 + 0.012
        let jitter = Double.random(in: -0.12...0.12, using: &g)
        let pace = max(0.45, 0.62 + (1 - skill) * 0.9 + jitter)
        let t = move.duration * pace + Double.random(in: 0.25...0.55, using: &g)
        var input = PadInput(time: t)
        switch move.kind {
        case .path:
            let a1 = Double.random(in: 0..<(2 * .pi), using: &g), a2 = Double.random(in: 0..<(2 * .pi), using: &g)
            let off = CGPoint(x: Double.random(in: -sloppy...sloppy, using: &g), y: Double.random(in: -sloppy...sloppy, using: &g))
            let base = move.target
            let n = Double(base.count)
            input.path = base.enumerated().map { i, p in
                let u = Double(i) / n * 2 * .pi
                let wob = sin(u * 3 + a1) * sloppy * 0.8 + sin(u * 7 + a2) * sloppy * 0.4
                return CGPoint(x: p.x + off.x + wob, y: p.y + off.y + cos(u * 3 + a2) * sloppy * 0.8)
            }
        case .taps:
            input.taps = move.target.map { p in
                CGPoint(x: p.x + Double.random(in: -sloppy...sloppy, using: &g) * 1.6, y: p.y + Double.random(in: -sloppy...sloppy, using: &g) * 1.6)
            }
        case .pinch:
            input.pinch = move.pinchScale * exp(Double.random(in: -sloppy...sloppy, using: &g) * 3.2)
        }
        return Scoring.evaluate(move: move, input: input)
    }
}
