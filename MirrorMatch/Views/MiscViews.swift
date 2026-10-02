import SwiftUI
import StoreKit

// MARK: - Skins

struct SkinsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(Skin.all) { skin in card(skin) }
                    }
                    .padding(20)
                    if !(store.isPro || store.hasSkinPack) {
                        VStack(spacing: 10) {
                            Button { Task { await store.purchase(ProductID.skins) } } label: { Text("Unlock All Skins · \(store.price(ProductID.skins))") }
                                .buttonStyle(PrimaryButtonStyle(colors: [Theme.magenta, .orange]))
                            Button("Or get everything with Pro") { dismiss(); Task { try? await Task.sleep(for: .seconds(0.5)); router.paywall = .skins } }
                                .font(Theme.font(14, .bold)).foregroundStyle(Theme.gold)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Trail Skins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func card(_ skin: Skin) -> some View {
        let unlocked = game.isUnlocked(skin, isPro: store.isPro, hasPack: store.hasSkinPack)
        let selected = game.p.skin == skin.id
        return Button {
            if unlocked { game.p.skin = skin.id; Haptics.success() }
            else if case .premium = skin.unlock { Haptics.select(); Task { await store.purchase(ProductID.skins) } }
        } label: {
            VStack(spacing: 8) {
                Canvas { ctx, size in
                    let pts = (0...60).map { i -> CGPoint in
                        let t = Double(i) / 60
                        return CGPoint(x: 0.1 + 0.8 * t, y: 0.5 + 0.28 * sin(t * .pi * 2.4))
                    }
                    TrailDrawer.draw(&ctx, pts: pts, side: size.width, skin: skin, width: 7)
                }
                .frame(height: 90)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                .opacity(unlocked ? 1 : 0.55)
                HStack {
                    Text(skin.name).font(Theme.font(15))
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.lime) }
                    else if !unlocked { Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.5)) }
                }
                Text(unlockText(skin, unlocked)).font(Theme.font(11, .semibold)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selected ? Theme.lime : Theme.stroke, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .accessibilityLabel("\(skin.name) skin, \(unlocked ? (selected ? "selected" : "unlocked") : "locked")")
    }

    private func unlockText(_ s: Skin, _ unlocked: Bool) -> String {
        if unlocked { return "Unlocked" }
        switch s.unlock {
        case .free: return "Free"
        case .streak(let n): return "Reach a \(n)-day daily streak"
        case .rank(let r): return "Reach rank \(Rank.names[r])"
        case .premium: return "Premium · tap to unlock"
        }
    }
}

// MARK: - Stats

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameStore.self) private var game

    private var winRate: Int {
        let t = game.p.wins + game.p.losses
        return t == 0 ? 0 : Int((Double(game.p.wins) / Double(t) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        GlassCard {
                            VStack(spacing: 10) {
                                Image(systemName: Rank.icons[game.rankIndex]).font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.brand)
                                Text(game.rankName).font(Theme.font(30))
                                Text("\(game.p.mp) Mirror Points").font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.65))
                                ProgressView(value: Rank.progress(for: game.p.mp)).tint(Theme.cyan)
                                HStack {
                                    ForEach(0..<Rank.names.count, id: \.self) { i in
                                        Circle().fill(i <= game.rankIndex ? Theme.cyan : Color.white.opacity(0.15)).frame(width: 9, height: 9)
                                        if i < Rank.names.count - 1 { Spacer() }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        let cols = [GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: cols, spacing: 12) {
                            stat("Wins", "\(game.p.wins)", Theme.lime)
                            stat("Losses", "\(game.p.losses)", .red)
                            stat("Win rate", "\(winRate)%", Theme.cyan)
                            stat("Matches", "\(game.p.matches)", .white)
                            stat("Best run", "\(game.p.bestRun)/500", Theme.gold)
                            stat("Perfect rounds", "\(game.p.perfectRounds)", Theme.magenta)
                            stat("Daily streak", "🔥 \(game.currentStreak)", .orange)
                            stat("Best streak", "\(game.p.bestStreak)", .orange)
                        }
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Last 14 days").font(Theme.font(16))
                                HStack(alignment: .bottom, spacing: 5) {
                                    ForEach(0..<14, id: \.self) { i in
                                        let key = DayKey.offset(i - 13)
                                        let s = game.p.dailyScores[String(key)] ?? 0
                                        VStack(spacing: 4) {
                                            Capsule().fill(s == 0 ? Color.white.opacity(0.12) : scoreColor(s / 5))
                                                .frame(height: max(6, CGFloat(s) / 500 * 70))
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .frame(height: 76, alignment: .bottom)
                                Text("Daily Challenge scores").font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func stat(_ t: String, _ v: String, _ c: Color) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(v).font(Theme.font(24)).foregroundStyle(c)
                Text(t).font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store

    var body: some View {
        @Bindable var game = game
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Your name", text: $game.p.name)
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                        .onChange(of: game.p.name) { _, n in if n.count > 18 { game.p.name = String(n.prefix(18)) } }
                }
                Section("Game") {
                    Toggle("Haptics", isOn: $game.p.haptics).onChange(of: game.p.haptics) { _, v in Haptics.enabled = v }
                    Toggle("Daily reminder", isOn: Binding(get: { game.p.reminders }, set: { $0 ? game.scheduleDailyReminder() : game.cancelReminder() }))
                }
                Section("Mirror Match Pro") {
                    HStack { Text("Status"); Spacer(); Text(store.isPro ? "Active" : "Free").foregroundStyle(store.isPro ? Theme.lime : .secondary) }
                    Button("Restore Purchases") { Task { await store.restore() } }
                    Link("Manage Subscription", destination: Links.manageSubs)
                }
                Section("About") {
                    Button("Rate Mirror Match") { requestReview() }
                    Link("Support", destination: Links.support)
                    Link("Privacy Policy", destination: Links.privacy)
                    Link("Terms of Use (EULA)", destination: Links.terms)
                    HStack { Text("Version"); Spacer(); Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0").foregroundStyle(.secondary) }
                }
                Section { Text("AI Ghosts are computer-controlled opponents. Mirror Match collects no personal data.").font(.footnote).foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("Mirror Match", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(store.message ?? "") }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @Environment(GameStore.self) private var game
    @Environment(Router.self) private var router
    @State private var name = ""
    @State private var demoStart = Date()
    @FocusState private var focused: Bool
    private let demoMove: Move = {
        var g = SeededGenerator(seed: 7)
        return MoveFactory.build("circle", using: &g)
    }()

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 18) {
                Spacer(minLength: 10)
                Text("MIRROR MATCH").font(Theme.font(34)).foregroundStyle(Theme.brand)
                Text("Can you copy this better than your friends in 3 seconds?").font(Theme.font(17, .bold)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                TimelineView(.periodic(from: .now, by: 3.6)) { tl in
                    PlayPad(move: demoMove, mode: .demo(tl.date), skin: Skin.byID("neon")).id(tl.date)
                }
                .frame(maxHeight: 250).padding(.horizontal, 40)
                HStack(spacing: 10) {
                    step("1", "Watch", Theme.cyan)
                    step("2", "Copy", Theme.magenta)
                    step("3", "Win", Theme.lime)
                }
                TextField("", text: $name, prompt: Text("Your name (optional)").foregroundStyle(.white.opacity(0.4)))
                    .font(Theme.font(18, .bold)).multilineTextAlignment(.center)
                    .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stroke))
                    .focused($focused).submitLabel(.done).onSubmit { focused = false }
                    .padding(.horizontal, 20)
                Spacer(minLength: 6)
                Button("Play your first duel") {
                    game.p.name = String(name.trimmingCharacters(in: .whitespaces).prefix(18))
                    game.p.onboarded = true
                    Task { try? await Task.sleep(for: .seconds(0.3)); router.start(.ghost) }
                }
                .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 24).padding(.bottom, 20)
            }
        }
        .onTapGesture { focused = false }
    }

    private func step(_ n: String, _ t: String, _ c: Color) -> some View {
        HStack(spacing: 8) {
            Text(n).font(Theme.font(15)).foregroundStyle(.black).frame(width: 26, height: 26).background(c, in: Circle())
            Text(t).font(Theme.font(17))
        }
        .padding(.horizontal, 14).padding(.vertical, 8).background(Theme.card, in: Capsule())
    }
}
