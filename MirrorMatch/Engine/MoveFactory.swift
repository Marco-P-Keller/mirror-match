import SwiftUI

enum MoveFactory {
    static let denseCount = 96

    /// Deterministic set of moves for a seed (daily challenge, friend challenge, duels).
    static func set(seed: UInt64, tiers: [Int] = [0, 1, 1, 2, 2]) -> [Move] {
        var g = SeededGenerator(seed: seed)
        var out: [Move] = []
        var lastID = ""
        for tier in tiers {
            var m = generate(tier: tier, using: &g)
            var guardCount = 0
            while m.id == lastID && guardCount < 6 { m = generate(tier: tier, using: &g); guardCount += 1 }
            lastID = m.id
            out.append(m)
        }
        return out
    }

    static func generate<G: RandomNumberGenerator>(tier: Int, using g: inout G) -> Move {
        let t = max(0, min(2, tier))
        let pool: [[String]] = [
            ["line", "circle", "check", "taps3", "pinchOut", "pinchIn"],
            ["zigzag", "triangle", "wave", "bolt", "taps4", "swoosh"],
            ["spiral", "infinity", "star", "heart", "taps5", "zigzag"]
        ]
        let kind = pool[t].randomElement(using: &g)!
        var m = build(kind, using: &g)
        if t >= 1, m.kind != .pinch, Int.random(in: 0..<4, using: &g) == 0 {
            m.mirrored = true
        }
        return m
    }

    static func build<G: RandomNumberGenerator>(_ kind: String, using g: inout G) -> Move {
        let c = CGPoint(x: 0.5, y: 0.5)
        func rot(_ pts: [CGPoint], _ a: Double) -> [CGPoint] {
            let ca = cos(a), sa = sin(a)
            return pts.map { p in
                let dx = p.x - c.x, dy = p.y - c.y
                return CGPoint(x: c.x + dx * ca - dy * sa, y: c.y + dx * sa + dy * ca)
            }
        }
        func flipX(_ pts: [CGPoint]) -> [CGPoint] { pts.map { CGPoint(x: 1 - $0.x, y: $0.y) } }
        func dense(_ poly: [CGPoint]) -> [CGPoint] { Scoring.resample(poly, count: denseCount) }
        func curve(_ n: Int = 120, _ f: (Double) -> CGPoint) -> [CGPoint] {
            dense((0...n).map { f(Double($0) / Double(n)) })
        }
        func mk(_ id: String, _ title: String, _ pts: [CGPoint]) -> Move {
            let len = Scoring.length(pts)
            return Move(id: id, title: title, kind: .path, points: pts, duration: min(3.4, max(1.3, 0.9 + len * 1.2)))
        }
        let flip = Bool.random(using: &g)
        let anyAngle = Double.random(in: 0..<(2 * .pi), using: &g)
        let quarter = Double(Int.random(in: 0..<4, using: &g)) * .pi / 2

        switch kind {
        case "line":
            let d = CGPoint(x: cos(anyAngle), y: sin(anyAngle))
            return mk("line", "Swipe", dense([CGPoint(x: c.x - d.x * 0.36, y: c.y - d.y * 0.36), CGPoint(x: c.x + d.x * 0.36, y: c.y + d.y * 0.36)]))
        case "circle":
            let dir: Double = flip ? 1 : -1
            let s = Double.random(in: 0..<(2 * .pi), using: &g)
            return mk("circle", "Circle", curve { t in
                let a = s + dir * 2 * .pi * t
                return CGPoint(x: c.x + 0.32 * cos(a), y: c.y + 0.32 * sin(a))
            })
        case "check":
            var p = dense([CGPoint(x: 0.2, y: 0.55), CGPoint(x: 0.4, y: 0.76), CGPoint(x: 0.82, y: 0.24)])
            if flip { p = flipX(p) }
            return mk("check", "Checkmark", p)
        case "zigzag":
            let peaks = Int.random(in: 3...4, using: &g)
            var poly: [CGPoint] = []
            for i in 0...peaks { poly.append(CGPoint(x: 0.14 + 0.72 * Double(i) / Double(peaks), y: i % 2 == 0 ? 0.3 : 0.7)) }
            return mk("zigzag", "Zigzag", dense(rot(poly, quarter)))
        case "triangle":
            let r = 0.36
            let a0 = anyAngle
            var poly = (0..<3).map { i -> CGPoint in
                let a = a0 + Double(i) * 2 * .pi / 3
                return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            }
            poly.append(poly[0])
            return mk("triangle", "Triangle", dense(poly))
        case "wave":
            let k = Double.random(in: 1.5...2.0, using: &g)
            var p = curve { t in CGPoint(x: 0.1 + 0.8 * t, y: c.y + 0.2 * sin(2 * .pi * k * t)) }
            p = rot(p, Bool.random(using: &g) ? 0 : .pi / 2)
            return mk("wave", "Wave", p)
        case "bolt":
            var p = dense([CGPoint(x: 0.58, y: 0.1), CGPoint(x: 0.3, y: 0.52), CGPoint(x: 0.62, y: 0.52), CGPoint(x: 0.4, y: 0.92)])
            if flip { p = flipX(p) }
            return mk("bolt", "Lightning", p)
        case "swoosh":
            let a0 = quarter
            return mk("swoosh", "Swoosh", dense(rot(curve { t in
                let a = (-0.25 + 0.85 * t) * .pi
                return CGPoint(x: c.x + 0.38 * cos(a) - 0.1, y: c.y + 0.38 * sin(a) + 0.12)
            }, a0)))
        case "spiral":
            let dir: Double = flip ? 1 : -1
            return mk("spiral", "Spiral", curve(160) { t in
                let r = 0.04 + 0.34 * (1 - t)
                let a = dir * 2 * .pi * 1.75 * t
                return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            })
        case "infinity":
            let p = curve(160) { t in
                let a = 2 * .pi * t
                return CGPoint(x: c.x + 0.38 * sin(a), y: c.y + 0.2 * sin(a) * cos(a) * 1.6)
            }
            return mk("infinity", "Infinity", flip ? flipX(p) : p)
        case "star":
            let order = [0, 2, 4, 1, 3, 0]
            let poly = order.map { i -> CGPoint in
                let step: Double = 2 * Double.pi / 5
                let a: Double = -Double.pi / 2 + Double(i) * step
                return CGPoint(x: c.x + 0.4 * cos(a), y: c.y + 0.4 * sin(a))
            }
            return mk("star", "Star", dense(poly))
        case "heart":
            let p = curve(160) { t in
                let a: Double = Double.pi + 2 * Double.pi * t
                let x: Double = 16 * pow(sin(a), 3)
                let y1: Double = 13 * cos(a) - 5 * cos(2 * a)
                let y2: Double = 2 * cos(3 * a) + cos(4 * a)
                let y: Double = y1 - y2
                return CGPoint(x: c.x + x * 0.024, y: c.y - y * 0.024 - 0.04)
            }
            return mk("heart", "Heart", flip ? flipX(p) : p)
        case "pinchOut", "pinchIn":
            let out = kind == "pinchOut"
            return Move(id: kind, title: out ? "Spread" : "Pinch", kind: .pinch, points: [c], pinchScale: out ? 2.1 : 0.45, duration: 1.3)
        default: // taps
            let n = Int(kind.dropFirst(4)) ?? 3
            var pts: [CGPoint] = []
            var tries = 0
            while pts.count < n && tries < 200 {
                tries += 1
                let p = CGPoint(x: Double.random(in: 0.14...0.86, using: &g), y: Double.random(in: 0.14...0.86, using: &g))
                if pts.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) > 0.26 }) { pts.append(p) }
            }
            while pts.count < n { pts.append(CGPoint(x: 0.2 + 0.15 * Double(pts.count), y: 0.5)) }
            return Move(id: kind, title: "Tap \(n)", kind: .taps, points: pts, duration: 0.55 * Double(n) + 0.4)
        }
    }

    /// Build a custom move from a freehand stroke.
    static func custom(from stroke: [CGPoint]) -> Move {
        let pts = Scoring.resample(stroke, count: denseCount)
        let len = Scoring.length(pts)
        return Move(id: "custom", title: "Custom", kind: .path, points: pts, duration: min(3.6, max(1.4, 0.9 + len * 1.2)))
    }
}
