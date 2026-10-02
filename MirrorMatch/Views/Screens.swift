import SwiftUI
import StoreKit

// MARK: - Ghost duel

struct GhostScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @State private var model: MatchModel?
    @State private var ghost = Ghost.roster[0]
    @State private var recorded = false
    @State private var delta = 0
    @State private var rankBefore = 0

    var body: some View {
        ZStack {
            AppBackground()
            if let model {
                MatchView(model: model, opponentName: ghost.name, onClose: close) {
                    DuelResultView(
                        won: model.youWon,
                        score: (model.wins[0], model.wins[1]),
                        opponent: ghost.name, avatar: AnyView(GhostAvatar(ghost: ghost, size: 64)),
                        delta: delta, rankUp: game.rankIndex > rankBefore,
                        records: model.records, names: [game.displayName, ghost.name],
                        rematchCost: store.isPro ? 0 : 1,
                        onRematch: rematch, onNew: { newMatch() }, onHome: close
                    )
                }
                .id(model.seed)
                .onChange(of: model.phase) { _, p in if p == .over { finish(model) } }
            }
        }
        .onAppear { if model == nil { newMatch() } }
    }

    private func newMatch(seed: UInt64? = nil, keepGhost: Bool = false) {
        recorded = false; delta = 0
        rankBefore = game.rankIndex
        if !keepGhost { ghost = Ghost.opponent(forRank: game.rankIndex) }
        let tiers = game.rankIndex >= 2 ? [0, 1, 1, 2, 2] : [0, 0, 1, 1, 2]
        let m = MatchModel(kind: .ghost(ghost), seed: seed ?? UInt64.random(in: 1...UInt64(Int32.max)), tiers: tiers)
        m.onRound = { game.recordRound($0) }
        model = m
    }

    private func rematch() {
        guard let model else { return }
        if game.spendTickets(1, isPro: store.isPro) {
            newMatch(seed: model.seed &+ 1, keepGhost: true)
        } else {
            router.paywall = .tickets
        }
    }

    private func finish(_ m: MatchModel) {
        guard !recorded else { return }
        recorded = true
        delta = game.recordGhostMatch(won: m.youWon)
        if m.youWon, game.p.wins == 3, !game.p.reviewAsked {
            game.p.reviewAsked = true
            Task { try? await Task.sleep(for: .seconds(2.5)); requestReview() }
        }
    }

    private func close() {
        let showPay = !store.isPro && game.p.matches >= 2 && game.p.matches - game.p.lastPaywallMatch >= 4
        dismiss()
        if showPay {
            game.p.lastPaywallMatch = game.p.matches
            Task { try? await Task.sleep(for: .seconds(0.7)); router.paywall = .generic }
        }
    }
}

struct DuelResultView: View {
    let won: Bool
    let score: (Int, Int)
    let opponent: String
    let avatar: AnyView
    let delta: Int
    let rankUp: Bool
    let records: [RoundRecord]
    let names: [String]
    let rematchCost: Int
    var onRematch: () -> Void
    var onNew: () -> Void
    var onHome: () -> Void
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            Color.black.opacity(0.93).ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer(minLength: 20)
                avatar
                Text(won ? "VICTORY" : "DEFEAT").font(Theme.font(48))
                    .foregroundStyle(won ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.white.opacity(0.85)))
                Text("\(score.0) – \(score.1) vs \(opponent)").font(Theme.font(20, .bold)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 10) {
                    Pill(text: "\(delta >= 0 ? "+" : "")\(delta) MP", icon: "sparkles", tint: delta >= 0 ? Theme.lime : .red)
                    if rankUp { Pill(text: "RANK UP · \(game.rankName)", icon: "arrow.up.circle.fill", tint: Theme.gold) }
                }
                if !won { Text("So close. Run it back?").font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.6)) }
                Spacer(minLength: 10)
                VStack(spacing: 10) {
                    ReplayShareButton(records: records, names: names,
                                      headline: won ? "I WON \(score.0)–\(score.1)" : "SO CLOSE \(score.0)–\(score.1)",
                                      subline: "\(names[0]) vs \(opponent)",
                                      text: "🪞 Mirror Match \(score.0)–\(score.1) vs \(opponent). Think you can copy better? \(Challenge.appStoreURL)")
                    Button { onRematch() } label: {
                        HStack {
                            Text(won ? "Run it back" : "Revenge")
                            if rematchCost > 0 { Label("\(rematchCost)", systemImage: "ticket.fill").font(Theme.font(15)).foregroundStyle(Theme.gold) }
                        }
                    }.buttonStyle(SecondaryButtonStyle())
                    HStack(spacing: 10) {
                        Button("New Opponent") { onNew() }.buttonStyle(SecondaryButtonStyle())
                        Button("Home") { onHome() }.buttonStyle(SecondaryButtonStyle())
                    }
                    if !store.isPro { ProUpsell() }
                }
                .padding(.horizontal, 22).padding(.bottom, 14)
            }
        }
    }
}

struct ProUpsell: View {
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.paywall = .generic } label: {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill").foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Unlimited tickets · all skins · custom moves").font(Theme.font(13, .bold))
                    Text("Try Mirror Match Pro").font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
            }
            .padding(12)
            .background(Theme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.gold.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

// MARK: - Face to face

struct FaceToFaceScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameStore.self) private var game
    @State private var model = MatchModel(kind: .faceToFace)
    @State private var counted = false

    var body: some View {
        MatchView(model: model, onClose: { dismiss() }) {
            ZStack {
                Color.black.opacity(0.93).ignoresSafeArea()
                VStack(spacing: 0) {
                    verdict(for: 1).rotationEffect(.degrees(180)).frame(maxHeight: .infinity)
                    Rectangle().fill(Theme.brand).frame(height: 3)
                    verdict(for: 0).frame(maxHeight: .infinity)
                }
                .ignoresSafeArea()
                VStack(spacing: 10) {
                    Button("Rematch") { model = MatchModel(kind: .faceToFace); counted = false }.buttonStyle(PrimaryButtonStyle()).frame(width: 190)
                    Button("Done") { dismiss() }.buttonStyle(SecondaryButtonStyle()).frame(width: 190)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            }
        }
        .id(model.seed)
        .onChange(of: model.phase) { _, p in
            if p == .over && !counted { counted = true; game.recordHeadToHead() }
        }
    }

    private func verdict(for p: Int) -> some View {
        let win = model.wins[p] > model.wins[1 - p]
        let draw = model.wins[p] == model.wins[1 - p]
        return VStack(spacing: 4) {
            Text(draw ? "DRAW" : (win ? "YOU WIN" : "YOU LOSE")).font(Theme.font(40))
                .foregroundStyle(draw ? AnyShapeStyle(.white) : win ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.white.opacity(0.6)))
            Text("\(model.wins[p]) – \(model.wins[1 - p])").font(Theme.font(26, .bold)).foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Daily + friend runs

enum RunMode: Hashable {
    case daily, friendCreate, friendAccept(Challenge)
}

struct RunScreen: View {
    let mode: RunMode
    @Environment(\.dismiss) private var dismiss
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @State private var model: MatchModel?
    @State private var started = false
    @State private var recorded = false
    @State private var friendSeed = UInt64.random(in: 1...UInt64(Int32.max))
    @State private var reminderAsked = false

    private var seed: UInt64 {
        switch mode {
        case .daily: return UInt64(DayKey.key())
        case .friendCreate: return friendSeed
        case .friendAccept(let c): return c.seed
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            if let model, started {
                MatchView(model: model, title: runTitle, onClose: { dismiss() }) {
                    RunResultView(mode: mode, total: model.total, records: model.records, seed: seed,
                                  onRetry: retry, onHome: { dismiss() })
                }
                .id(model.seed)
                .onChange(of: model.phase) { _, p in if p == .over { finish(model) } }
            } else {
                lobby
            }
        }
    }

    private var runTitle: String {
        switch mode {
        case .daily: return "Daily #\(DayKey.dailyNumber())"
        case .friendCreate: return "Your challenge"
        case .friendAccept(let c): return "vs \(c.name)"
        }
    }

    private var lobby: some View {
        VStack(spacing: 18) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle()) }
                    .foregroundStyle(.white).accessibilityLabel("Close")
                Spacer()
            }
            Spacer()
            switch mode {
            case .daily:
                Text("🔥").font(.system(size: 64))
                Text("Daily Challenge #\(DayKey.dailyNumber())").font(Theme.font(30)).multilineTextAlignment(.center)
                Text("The same 5 moves for every player today. Beat your best, keep your streak.").font(Theme.font(16, .semibold)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Pill(text: "Streak \(game.currentStreak)", icon: "flame.fill", tint: .orange)
                    if let s = game.todayScore { Pill(text: "Today \(s)/500", icon: "checkmark.circle.fill", tint: Theme.lime) }
                }
            case .friendCreate:
                Text("🎯").font(.system(size: 64))
                Text("Set the score to beat").font(Theme.font(30)).multilineTextAlignment(.center)
                Text("Play 5 moves. Then send your friend a link: they play the exact same moves against your score.").font(Theme.font(16, .semibold)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            case .friendAccept(let c):
                Text("⚔️").font(.system(size: 64))
                Text("\(c.name) challenged you").font(Theme.font(30)).multilineTextAlignment(.center)
                Text("Score to beat: \(c.score)/500").font(Theme.font(22)).foregroundStyle(Theme.cyan)
                Text("Same 5 moves. Copy them better.").font(Theme.font(16, .semibold)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button(startTitle) { begin(free: true) }.buttonStyle(PrimaryButtonStyle())
            if case .daily = mode, game.dailyDone {
                Text("Replays cost 1 ticket. Your best score counts.").font(Theme.font(13, .semibold)).foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(24)
    }

    private var startTitle: String {
        if case .daily = mode, game.dailyDone { return store.isPro ? "Play again" : "Play again · 1 🎟" }
        return "Start"
    }

    private func begin(free: Bool) {
        if case .daily = mode, game.dailyDone, !game.spendTickets(1, isPro: store.isPro) {
            router.paywall = .tickets
            return
        }
        recorded = false
        let tiers = [0, 1, 1, 2, 2]
        let m = MatchModel(kind: .solo, seed: seed, tiers: tiers)
        m.onRound = { game.recordRound($0) }
        model = m
        started = true
    }

    private func retry() {
        switch mode {
        case .daily: begin(free: false)
        case .friendCreate:
            if game.spendTickets(1, isPro: store.isPro) { friendSeed = UInt64.random(in: 1...UInt64(Int32.max)); started = false; model = nil; begin(free: true) }
            else { router.paywall = .tickets }
        case .friendAccept:
            if game.spendTickets(1, isPro: store.isPro) { started = false; model = nil; begin(free: true) } else { router.paywall = .tickets }
        }
    }

    private func finish(_ m: MatchModel) {
        guard !recorded else { return }
        recorded = true
        game.recordRun(score: m.total)
        switch mode {
        case .daily:
            game.completeDaily(score: m.total)
            if !game.p.reminders && !reminderAsked && game.currentStreak >= 2 {
                reminderAsked = true
                game.scheduleDailyReminder()
            }
        case .friendAccept(let c):
            game.recordFriendMatch(rival: c.name, won: m.total > c.score)
        case .friendCreate: break
        }
    }
}

struct RunResultView: View {
    let mode: RunMode
    let total: Int
    let records: [RoundRecord]
    let seed: UInt64
    var onRetry: () -> Void
    var onHome: () -> Void
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router

    private var challenge: Challenge { Challenge(kind: .run, seed: seed, name: game.displayName, score: total) }

    private var verdict: (String, Color)? {
        if case .friendAccept(let c) = mode {
            if total > c.score { return ("YOU BEAT \(c.name.uppercased())", Theme.lime) }
            if total == c.score { return ("DEAD EVEN", Theme.gold) }
            return ("\(c.name.uppercased()) WINS", Color.red)
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.93).ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer(minLength: 10)
                if let v = verdict { Text(v.0).font(Theme.font(30)).foregroundStyle(v.1).multilineTextAlignment(.center) }
                Text("\(total)").font(Theme.font(84)).foregroundStyle(Theme.brand)
                Text("out of 500").font(Theme.font(16, .semibold)).foregroundStyle(.white.opacity(0.6)).offset(y: -10)
                HStack(spacing: 8) {
                    ForEach(Array(records.enumerated()), id: \.offset) { _, r in
                        VStack(spacing: 4) {
                            Text("\(r.results[0].score)").font(Theme.font(16)).foregroundStyle(scoreColor(r.results[0].score))
                            Image(systemName: r.move.icon).font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 22)
                if case .daily = mode {
                    HStack(spacing: 10) {
                        Pill(text: "🔥 \(game.currentStreak)-day streak", tint: .orange)
                        Pill(text: "Best today \(game.todayScore ?? total)", icon: "star.fill", tint: Theme.gold)
                    }
                }
                Spacer(minLength: 6)
                VStack(spacing: 10) {
                    ShareLink(item: shareText) {
                        Label(shareLabel, systemImage: "paperplane.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    ReplayShareButton(records: records, names: [game.displayName], headline: "\(total)/500", subline: headline, text: shareText)
                    HStack(spacing: 10) {
                        Button { onRetry() } label: {
                            HStack { Text("Retry"); if !store.isPro { Label("1", systemImage: "ticket.fill").foregroundStyle(Theme.gold) } }
                        }.buttonStyle(SecondaryButtonStyle())
                        Button("Home") { onHome() }.buttonStyle(SecondaryButtonStyle())
                    }
                    if !store.isPro { ProUpsell() }
                }
                .padding(.horizontal, 22).padding(.bottom, 14)
            }
        }
    }

    private var headline: String {
        switch mode {
        case .daily: return "Daily Challenge #\(DayKey.dailyNumber())"
        case .friendCreate: return "Beat my score"
        case .friendAccept(let c): return "vs \(c.name) (\(c.score))"
        }
    }

    private var shareLabel: String {
        switch mode {
        case .daily: return "Share My Score"
        case .friendCreate: return "Challenge a Friend"
        case .friendAccept: return "Send Rematch Link"
        }
    }

    private var shareText: String {
        switch mode {
        case .daily:
            let grid = records.map { r -> String in
                let s = r.results[0].score
                return s >= 80 ? "🟩" : s >= 55 ? "🟨" : s >= 30 ? "🟧" : "🟥"
            }.joined()
            return "🪞 Mirror Match Daily #\(DayKey.dailyNumber()) — \(total)/500\n\(grid)\nBeat me: \(challenge.webURL.absoluteString)"
        default:
            return challenge.shareText
        }
    }
}
