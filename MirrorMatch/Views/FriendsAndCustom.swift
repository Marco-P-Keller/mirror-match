import SwiftUI

struct FriendsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameStore.self) private var game
    @Environment(Router.self) private var router
    @State private var pasteFailed = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Text("🎯").font(.system(size: 54)).padding(.top, 10)
                        Text("Challenge a friend").font(Theme.font(28))
                        Text("Play 5 moves, share the link. Your friend plays the exact same moves and tries to beat your score. No account needed.")
                            .font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                        Button("Create a Challenge") {
                            dismiss()
                            Task { try? await Task.sleep(for: .seconds(0.45)); router.start(.friendCreate) }
                        }.buttonStyle(PrimaryButtonStyle())

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Got a challenge link?").font(Theme.font(17))
                                Text("Tap the link in your chat and it opens right here. Or paste it:").font(Theme.font(13, .semibold)).foregroundStyle(.white.opacity(0.6))
                                PasteButton(payloadType: String.self) { strings in
                                    Task { @MainActor in
                                        if let s = strings.first, let c = Challenge.parse(s) {
                                            dismiss()
                                            try? await Task.sleep(for: .seconds(0.45))
                                            router.incoming(c)
                                            router.session = c.kind == .custom ? .customPlay(c) : .friendAccept(c)
                                            router.pendingChallenge = nil
                                        } else { pasteFailed = true }
                                    }
                                }
                                .buttonBorderShape(.capsule).tint(Theme.cyan)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !game.p.rivals.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Your rivals").font(Theme.font(17))
                                    ForEach(game.p.rivals.sorted { ($0.value[0] + $0.value[1]) > ($1.value[0] + $1.value[1]) }.prefix(8), id: \.key) { k, v in
                                        HStack {
                                            Text(k).font(Theme.font(16, .bold))
                                            Spacer()
                                            Text("\(v[0]) – \(v[1])").font(Theme.font(16)).foregroundStyle(v[0] >= v[1] ? Theme.lime : .red)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("That doesn't look like a Mirror Match link", isPresented: $pasteFailed) { Button("OK", role: .cancel) {} }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Custom move creation

struct CustomCreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @State private var pts: [CGPoint] = []
    @State private var move: Move?
    @State private var demoStart = Date()
    @State private var counted = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle()) }
                        .foregroundStyle(.white).accessibilityLabel("Close")
                    Spacer()
                    if !store.isPro { Pill(text: "1 free per day", icon: "gift.fill", tint: Theme.lime) }
                }
                Text(move == nil ? "Draw your move" : "Looks great!").font(Theme.font(30))
                Text(move == nil ? "One stroke. Make it tricky, make it fun." : "Your friends will have to copy this. Send it over.")
                    .font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                Group {
                    if let move {
                        PlayPad(move: move, mode: .demo(demoStart), skin: game.skin).id(demoStart)
                    } else {
                        drawPad
                    }
                }
                .padding(.horizontal, 6)
                Spacer(minLength: 0)
                if let move {
                    let ch = Challenge(kind: .custom, name: game.displayName, customPoints: move.points)
                    ShareLink(item: ch.shareText) { Label("Send to a Friend", systemImage: "paperplane.fill") }.buttonStyle(PrimaryButtonStyle())
                    HStack(spacing: 10) {
                        Button("Replay") { demoStart = Date() }.buttonStyle(SecondaryButtonStyle())
                        Button("Redraw") { self.move = nil; pts = [] }.buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
            .padding(20)
        }
    }

    private var drawPad: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.055))
                RoundedRectangle(cornerRadius: 30).strokeBorder(Theme.stroke, lineWidth: 2)
                if pts.isEmpty { Label("Draw here", systemImage: "hand.draw.fill").font(Theme.font(18)).foregroundStyle(.white.opacity(0.4)) }
                Canvas { ctx, _ in TrailDrawer.draw(&ctx, pts: pts, side: side, skin: game.skin) }
                    .allowsHitTesting(false)
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let p = CGPoint(x: min(1, max(0, v.location.x / side)), y: min(1, max(0, v.location.y / side)))
                            if let l = pts.last, hypot(l.x - p.x, l.y - p.y) < 0.004 { return }
                            pts.append(p)
                        }
                        .onEnded { _ in
                            if Scoring.length(pts) < 0.5 { pts = []; Haptics.error(); return }
                            move = MoveFactory.custom(from: pts)
                            demoStart = Date()
                            Haptics.success()
                            if !counted { counted = true; game.noteCustomCreated() }
                        })
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Play someone's custom move

struct CustomPlayScreen: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    @Environment(GameStore.self) private var game
    @Environment(Router.self) private var router
    @State private var model: MatchModel?

    var body: some View {
        ZStack {
            AppBackground()
            if let model {
                MatchView(model: model, title: "\(challenge.name)'s move", onClose: { dismiss() }) {
                    let best = model.records.map { $0.results[0].score }.max() ?? 0
                    ZStack {
                        Color.black.opacity(0.93).ignoresSafeArea()
                        VStack(spacing: 14) {
                            Text("BEST OF 3").font(Theme.font(16)).foregroundStyle(.white.opacity(0.6))
                            Text("\(best)").font(Theme.font(90)).foregroundStyle(Theme.brand)
                            Text(best >= 85 ? "Basically a mirror 🪞" : best >= 60 ? "Pretty close!" : "Tricky one. Try again!").font(Theme.font(18, .bold))
                            ShareLink(item: "🪞 I got \(best)/100 copying \(challenge.name)'s move in Mirror Match! \(challenge.webURL.absoluteString)") {
                                Label("Share My Score", systemImage: "paperplane.fill")
                            }.buttonStyle(PrimaryButtonStyle())
                            Button("Make my own move") { dismiss(); Task { try? await Task.sleep(for: .seconds(0.5)); router.start(.customCreate) } }.buttonStyle(SecondaryButtonStyle())
                            Button("Try again") { start() }.buttonStyle(SecondaryButtonStyle())
                            Button("Home") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(24)
                    }
                }
                .id(model.seed)
            }
        }
        .onAppear { if model == nil { start() } }
    }

    private func start() {
        let m = MoveFactory.custom(from: challenge.customPoints)
        let mm = MatchModel(kind: .solo, moves: [m, m, m])
        mm.hudTotal = false
        mm.onRound = { game.recordRound($0) }
        model = mm
    }
}
