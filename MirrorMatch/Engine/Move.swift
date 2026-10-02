import SwiftUI

enum MoveKind: String, Codable { case path, taps, pinch }

/// A single gesture the players have to copy. All coordinates are normalized to a unit square.
struct Move: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var kind: MoveKind
    var points: [CGPoint]
    var pinchScale: Double = 1
    var duration: Double
    var mirrored: Bool = false

    /// The geometry the player is actually scored against (mirrored rounds flip left/right).
    var target: [CGPoint] {
        mirrored ? points.map { CGPoint(x: 1 - $0.x, y: $0.y) } : points
    }

    var maxTime: Double { duration * 2.2 + 1.2 }

    var instruction: String {
        switch kind {
        case .path: return mirrored ? "Draw it MIRRORED" : "Draw it"
        case .taps: return mirrored ? "Tap the MIRRORED spots in order" : "Tap the spots in order"
        case .pinch: return pinchScale > 1 ? "Spread two fingers" : "Pinch two fingers"
        }
    }

    var icon: String {
        switch kind {
        case .taps: return "hand.tap.fill"
        case .pinch: return pinchScale > 1 ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left"
        case .path: return "scribble.variable"
        }
    }
}

struct RoundResult: Codable, Hashable {
    var accuracy: Double
    var time: Double
    var score: Int
    var path: [CGPoint]
    var pinchValue: Double = 1

    static let empty = RoundResult(accuracy: 0, time: 0, score: 0, path: [])
}

struct RoundRecord: Codable, Hashable {
    var move: Move
    var results: [RoundResult]
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
