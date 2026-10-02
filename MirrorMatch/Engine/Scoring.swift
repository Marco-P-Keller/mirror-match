import SwiftUI

struct PadInput {
    var path: [CGPoint] = []
    var taps: [CGPoint] = []
    var pinch: Double = 1
    var time: Double = 0
}

enum Scoring {
    static func length(_ pts: [CGPoint]) -> Double {
        guard pts.count > 1 else { return 0 }
        var l = 0.0
        for i in 1..<pts.count { l += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) }
        return l
    }

    static func resample(_ pts: [CGPoint], count n: Int) -> [CGPoint] {
        guard n > 1 else { return pts }
        guard pts.count > 1 else { return Array(repeating: pts.first ?? .zero, count: n) }
        var cum = [0.0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
        let total = cum[cum.count - 1]
        guard total > 1e-9 else { return Array(repeating: pts[0], count: n) }
        var out: [CGPoint] = []
        var j = 1
        for k in 0..<n {
            let d = total * Double(k) / Double(n - 1)
            while j < pts.count - 1 && cum[j] < d { j += 1 }
            let seg = cum[j] - cum[j - 1]
            let f = seg > 1e-9 ? (d - cum[j - 1]) / seg : 0
            out.append(CGPoint(x: pts[j - 1].x + (pts[j].x - pts[j - 1].x) * f, y: pts[j - 1].y + (pts[j].y - pts[j - 1].y) * f))
        }
        return out
    }

    private static func centroid(_ p: [CGPoint]) -> CGPoint {
        guard !p.isEmpty else { return .zero }
        return CGPoint(x: p.reduce(0) { $0 + $1.x } / Double(p.count), y: p.reduce(0) { $0 + $1.y } / Double(p.count))
    }

    private static func clamp01(_ v: Double) -> Double { max(0, min(1, v)) }

    static func evaluate(move: Move, input: PadInput) -> RoundResult {
        var acc = 0.0
        var shown: [CGPoint] = []
        switch move.kind {
        case .path:
            shown = input.path
            if input.path.count >= 3, length(input.path) > 0.05 {
                let tp = resample(move.target, count: 48)
                let pp = resample(input.path, count: 48)
                let ct = centroid(tp), cp = centroid(pp)
                var d = 0.0
                for i in 0..<48 {
                    d += hypot((pp[i].x - cp.x) - (tp[i].x - ct.x), (pp[i].y - cp.y) - (tp[i].y - ct.y))
                }
                d /= 48
                let pos = hypot(cp.x - ct.x, cp.y - ct.y)
                acc = clamp01(1 - (d + 0.3 * pos) / 0.22)
                // Drawing way too little of the shape is never a good match.
                let ratio = length(input.path) / max(0.01, length(move.target))
                if ratio < 0.6 { acc *= max(0, ratio / 0.6) }
            }
        case .taps:
            shown = input.taps
            let target = move.target
            if !input.taps.isEmpty {
                var sum = 0.0
                for i in 0..<target.count {
                    if i < input.taps.count {
                        sum += clamp01(1 - hypot(input.taps[i].x - target[i].x, input.taps[i].y - target[i].y) / 0.2)
                    }
                }
                acc = sum / Double(target.count)
            }
        case .pinch:
            if input.pinch > 0, abs(input.pinch - 1) > 0.02 {
                let err = abs(log(input.pinch / move.pinchScale))
                acc = clamp01(1 - err / 0.7)
            }
        }
        let t = max(0.05, input.time)
        let speed = clamp01(1.3 - t / (move.duration + 0.6))
        let score = Int((100 * acc * (0.75 + 0.25 * speed)).rounded())
        return RoundResult(accuracy: acc, time: t, score: score, path: shown, pinchValue: input.pinch)
    }
}
