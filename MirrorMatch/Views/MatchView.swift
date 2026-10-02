import SwiftUI

/// Shared gameplay screen for ghost duels, face-to-face and solo runs.
struct MatchView<Result: View>: View {
    @Environment(GameStore.self) private var game
    let model: MatchModel
    var title: String = ""
    var opponentName: String = ""
    var onClose: () -> Void
    @ViewBuilder var result: () -> Result

    var body: some View {
        ZStack {
            AppBackground()
            switch model.kind {
            case .faceToFace: FaceToFaceLayout(model: model, skin: game.skin)
            default: SingleLayout(model: model, skin: game.skin, title: title, opponentName: opponentName)
            }
            VStack {
                HStack {
                    Button { onClose() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                            .frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                    }
                    .foregroundStyle(.white)
                    .accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 6)
                Spacer()
            }
            .opacity(model.kind == .faceToFace ? 0 : 1)
            .allowsHitTesting(model.kind != .faceToFace)

            if model.kind == .faceToFace {
                HStack {
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                            .frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                    }
                    .foregroundStyle(.white)
                    .accessibilityLabel("Close")
                    Spacer()
                }
            }
            if model.phase == .over {
                result().transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(duration: 0.4), value: model.phase == .over)
        .task { model.begin() }
        .onDisappear { model.cancel() }
        .statusBarHidden(false)
    }
}

// MARK: - helpers

@MainActor func padMode(_ m: MatchModel) -> PadMode {
    switch m.phase {
    case .intro, .ready: return .idle
    case .watch: return .demo(m.demoStart)
    case .go: return .live(m.goDate)
    case .reveal, .over: return .reveal
    }
}

struct PhaseBanner: View {
    let model: MatchModel
    var body: some View {
        VStack(spacing: 4) {
            Group {
                switch model.phase {
                case .intro: Text("ROUND \(model.roundNumber)").foregroundStyle(Theme.brand)
                case .watch: Text("WATCH").foregroundStyle(Theme.cyan)
                case .ready: Text("GET READY…").foregroundStyle(Theme.gold)
                case .go: Text("GO!").foregroundStyle(Theme.lime)
                default: Text(" ")
                }
            }
            .font(Theme.font(34))
            .contentTransition(.opacity)
            Text(model.phase == .intro || model.phase == .watch || model.phase == .ready || model.phase == .go ? model.currentMove.instruction : " ")
                .font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.75))
            if model.currentMove.mirrored && (model.phase == .watch || model.phase == .ready || model.phase == .go) {
                Pill(text: "MIRROR ROUND · flip left ⇄ right", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", tint: Theme.magenta)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.phase)
    }
}

struct ScoreBadge: View {
    let r: RoundResult
    var won: Bool = false
    var body: some View {
        HStack(spacing: 10) {
            Text("\(r.score)").font(Theme.font(44)).foregroundStyle(won ? Theme.lime : .white)
                .contentTransition(.numericText())
            VStack(alignment: .leading, spacing: 2) {
                Text("Accuracy \(Int(r.accuracy * 100))%").font(Theme.font(13, .semibold))
                Text(String(format: "Time %.1fs", r.time)).font(Theme.font(13, .semibold)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct Pips: View {
    let wins: Int
    var tint: Color = Theme.lime
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(i < wins ? tint : Color.white.opacity(0.15)).frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.2)))
                    .scaleEffect(i < wins ? 1.1 : 1)
            }
        }
        .animation(.spring(duration: 0.35), value: wins)
        .accessibilityLabel("\(wins) round wins")
    }
}

// MARK: - single player screen (ghost duel + solo)

struct SingleLayout: View {
    let model: MatchModel
    let skin: Skin
    let title: String
    let opponentName: String
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(spacing: 10) {
            header.padding(.top, 44)
            Spacer(minLength: 0)
            PhaseBanner(model: model).frame(height: 96)
            PlayPad(move: model.currentMove, mode: padMode(model), skin: skin,
                    revealResult: model.results[0], rival: model.results[1],
                    onFinish: { model.submit(player: 0, input: $0) })
                .id("pad-\(model.round)")
                .padding(.horizontal, 18)
                .overlay(alignment: .bottom) {
                    if model.phase == .reveal, let r = model.results[0] {
                        ScoreBadge(r: r, won: model.roundWinner == 0 || !model.isDuel).padding(.bottom, 14)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            footer.padding(.bottom, 14)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 0)
        .animation(.spring(duration: 0.35), value: model.phase)
    }

    @ViewBuilder private var header: some View {
        if case .ghost(let g) = model.kind {
            HStack(spacing: 12) {
                GhostAvatar(ghost: g, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.name).font(Theme.font(20))
                    Text("AI GHOST").font(Theme.font(11, .bold)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Pips(wins: model.wins[1], tint: Theme.magenta)
                GhostPeek(model: model).frame(width: 64, height: 64)
            }
            .padding(.horizontal, 20)
        } else {
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Text(title).font(Theme.font(18))
                    Text("Round \(model.roundNumber) of \(model.moves.count)").font(Theme.font(13, .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
            .overlay(alignment: .trailing) {
                if model.hudTotal { Text("\(model.total)").font(Theme.font(26)).foregroundStyle(Theme.cyan).padding(.trailing, 20).contentTransition(.numericText()) }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        if model.isDuel {
            HStack {
                Text(game.displayName).font(Theme.font(20))
                Spacer()
                Pips(wins: model.wins[0])
            }
            .padding(.horizontal, 24)
        } else {
            HStack(spacing: 6) {
                ForEach(0..<model.moves.count, id: \.self) { i in
                    Capsule().fill(i < model.records.count ? scoreColor(model.records[i].results[0].score) : Color.white.opacity(i == model.round ? 0.4 : 0.15))
                        .frame(height: 8)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

func scoreColor(_ s: Int) -> Color {
    s >= 80 ? Theme.lime : s >= 55 ? Theme.gold : s >= 30 ? Color.orange : Color.red
}

struct GhostAvatar: View {
    let ghost: Ghost
    var size: CGFloat = 44
    static let tints: [[Color]] = [
        [Color(red: 0.5, green: 0.8, blue: 1), Color(red: 0.3, green: 0.4, blue: 1)],
        [Color(red: 0.4, green: 1, blue: 0.5), Color(red: 0.1, green: 0.5, blue: 0.3)],
        [Color(red: 0.7, green: 0.6, blue: 1), Color(red: 0.3, green: 0.2, blue: 0.7)],
        [Color(red: 1, green: 0.8, blue: 0.4), Color(red: 1, green: 0.4, blue: 0.4)],
        [Color(red: 1, green: 0.5, blue: 0.8), Color(red: 0.6, green: 0.2, blue: 0.9)],
        [Color(red: 1, green: 1, blue: 1), Color(red: 0.4, green: 0.4, blue: 0.5)]
    ]
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: GhostAvatar.tints[ghost.tint % 6], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "eye.trianglebadge.exclamationmark.fill").opacity(0)
            Text("👻").font(.system(size: size * 0.55))
        }
        .frame(width: size, height: size)
    }
}

/// Small live view of what the ghost is drawing.
struct GhostPeek: View {
    let model: MatchModel
    var body: some View {
        TimelineView(.animation(paused: model.phase != .go)) { tl in
            Canvas { ctx, size in
                guard let plan = model.ghostPlan, model.phase == .go || model.phase == .reveal || model.phase == .over else { return }
                let side = size.width
                let el = model.phase == .go ? tl.date.timeIntervalSince(model.goDate) : 99
                let p = min(1, max(0, (el - 0.2) / max(0.3, plan.time - 0.2)))
                switch model.currentMove.kind {
                case .path:
                    let n = max(0, Int(p * Double(plan.path.count)))
                    if n > 1 { TrailDrawer.draw(&ctx, pts: Array(plan.path.prefix(n)), side: side, skin: Skin.byID("ice"), width: 3, head: p < 1) }
                case .taps:
                    let n = Int(p * Double(plan.path.count))
                    for (i, pt) in plan.path.prefix(n).enumerated() {
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x * side - 4, y: pt.y * side - 4, width: 8, height: 8)), with: .color(.white.opacity(0.8 - Double(i) * 0.05)))
                    }
                case .pinch:
                    let v = 1 + (plan.pinchValue - 1) * p
                    let d = side * 0.12 * max(0.3, min(3, v))
                    for s in [-1.0, 1.0] {
                        ctx.fill(Path(ellipseIn: CGRect(x: side / 2 + s * d * 0.7 - 4, y: side / 2 - s * d * 0.7 - 4, width: 8, height: 8)), with: .color(.white))
                    }
                }
            }
        }
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.stroke))
        .accessibilityHidden(true)
    }
}

// MARK: - face to face

struct FaceToFaceLayout: View {
    let model: MatchModel
    let skin: Skin

    var body: some View {
        VStack(spacing: 0) {
            half(player: 1).rotationEffect(.degrees(180))
            Rectangle().fill(Theme.brand).frame(height: 3).opacity(0.8)
            half(player: 0)
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay {
            Text(centerText).font(Theme.font(15)).padding(.horizontal, 14).padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule()).offset(x: 60)
                .opacity(0)
        }
    }

    private var centerText: String { "R\(model.roundNumber)" }

    private func half(player: Int) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(player == 0 ? "PLAYER 1" : "PLAYER 2").font(Theme.font(14)).foregroundStyle(.white.opacity(0.7))
                Pips(wins: model.wins[player], tint: player == 0 ? Theme.lime : Theme.magenta)
                Spacer()
                Text("Round \(model.roundNumber)/\(model.moves.count)").font(Theme.font(13, .semibold)).foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 22).padding(.top, player == 0 ? 6 : 4)
            PhaseBanner(model: model).scaleEffect(0.78).frame(height: 78)
            PlayPad(move: model.currentMove, mode: padMode(model), skin: player == 0 ? skin : Skin.byID("sunset"),
                    revealResult: model.results[player], rival: model.results[1 - player],
                    onFinish: { model.submit(player: player, input: $0) })
                .id("pad-\(model.round)-\(player)")
                .padding(.horizontal, 22)
                .overlay(alignment: .bottom) {
                    if model.phase == .reveal, let r = model.results[player] {
                        ScoreBadge(r: r, won: model.roundWinner == player).scaleEffect(0.85).padding(.bottom, 8)
                    }
                }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
