import SwiftUI

@MainActor
@Observable
final class MatchModel {
    enum Kind: Equatable { case ghost(Ghost), faceToFace, solo }
    enum Phase { case intro, watch, ready, go, reveal, over }

    let kind: Kind
    let moves: [Move]
    let seed: UInt64
    private(set) var round = 0
    var phase: Phase = .intro
    var demoStart = Date()
    var goDate = Date()
    /// index 0 = bottom player (you), 1 = top player / ghost
    var results: [RoundResult?] = [nil, nil]
    var wins = [0, 0]
    var total = 0
    var records: [RoundRecord] = []
    var roundWinner: Int?
    var ghostPlan: RoundResult?
    private var decided = false
    private var rng: SeededGenerator
    private var flow: Task<Void, Never>?
    private var resolving = false
    var onRound: ((RoundResult) -> Void)?
    var hudTotal = true

    init(kind: Kind, seed: UInt64 = UInt64.random(in: 1...UInt64(Int32.max)), tiers: [Int] = [0, 0, 1, 1, 2], moves override: [Move]? = nil) {
        self.kind = kind
        self.seed = seed
        self.moves = override ?? MoveFactory.set(seed: seed, tiers: tiers)
        self.rng = SeededGenerator(seed: seed ^ 0xABCD_1234)
    }

    var currentMove: Move { moves[min(round, moves.count - 1)] }
    var isDuel: Bool { kind != .solo }
    var roundNumber: Int { min(round + 1, moves.count) }

    func begin() {
        flow?.cancel()
        flow = Task { [weak self] in await self?.run() }
    }

    func cancel() { flow?.cancel() }

    private func pause(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    private func run() async {
        while round < moves.count && !decided {
            results = [nil, nil]
            roundWinner = nil
            ghostPlan = nil
            resolving = false
            phase = .intro
            await pause(0.9)
            if Task.isCancelled { return }
            let m = moves[round]
            demoStart = Date().addingTimeInterval(0.35)
            phase = .watch
            await pause(0.35 + m.duration + 0.55)
            if Task.isCancelled { return }
            phase = .ready
            await pause(0.65 + Double.random(in: 0.1...0.6))
            if Task.isCancelled { return }
            if case .ghost(let g) = kind { ghostPlan = g.perform(m, using: &rng) }
            goDate = Date()
            phase = .go
            Haptics.heavy()
            while phase == .go && !Task.isCancelled { await pause(0.05) }
            if Task.isCancelled { return }
            await pause(isDuel ? 2.6 : 2.1)
            if decided { break }
            round += 1
        }
        if Task.isCancelled { return }
        phase = .over
        Haptics.success()
    }

    func submit(player: Int, input: PadInput) {
        guard phase == .go, results[player] == nil else { return }
        let r = Scoring.evaluate(move: currentMove, input: input)
        results[player] = r
        if player == 0 { onRound?(r) }
        switch kind {
        case .solo:
            resolve()
        case .faceToFace:
            if results[0] != nil && results[1] != nil { resolve() }
        case .ghost:
            guard !resolving, let plan = ghostPlan else { return }
            resolving = true
            let wait = max(0, plan.time - r.time) + 0.25
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                guard let self, !Task.isCancelled else { return }
                self.results[1] = plan
                self.resolve()
            }
        }
    }

    private func resolve() {
        guard phase == .go else { return }
        let a = results[0] ?? .empty
        records.append(RoundRecord(move: currentMove, results: isDuel ? [a, results[1] ?? .empty] : [a]))
        if isDuel {
            let b = results[1] ?? .empty
            if a.score != b.score { roundWinner = a.score > b.score ? 0 : 1 }
            else if abs(a.time - b.time) > 0.01 { roundWinner = a.time < b.time ? 0 : 1 }
            else { roundWinner = nil }
            if let w = roundWinner { wins[w] += 1 }
            decided = wins[0] >= 3 || wins[1] >= 3 || round == moves.count - 1
            if roundWinner == 0 { Haptics.success() } else if roundWinner == 1 { Haptics.error() }
        } else {
            total += a.score
            decided = round == moves.count - 1
            if a.score >= 70 { Haptics.success() } else { Haptics.medium() }
        }
        phase = .reveal
    }

    var youWon: Bool { wins[0] > wins[1] }
}
