import SwiftUI

struct HomeView: View {
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @State private var sheet: HomeSheet?
    @State private var pasteAlert = false

    enum HomeSheet: String, Identifiable { case skins, stats, settings, friends; var id: String { rawValue } }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    topBar
                    logo
                    rankCard
                    quickDuel
                    tiles
                    if game.canRepairStreak { repairBanner }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .skins: SkinsView()
            case .stats: StatsView()
            case .settings: SettingsView()
            case .friends: FriendsSheet()
            }
        }
        .onAppear { game.refreshDay() }
        #if DEBUG
        .task {
            try? await Task.sleep(for: .seconds(1.0))
            switch Autoplay.route {
            case "skins": sheet = .skins
            case "stats": sheet = .stats
            case "friends": sheet = .friends
            case "settings": sheet = .settings
            default: break
            }
        }
        #endif
    }

    private var topBar: some View {
        HStack {
            Button { router.shop = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ticket.fill").foregroundStyle(Theme.gold)
                    Text(store.isPro ? "∞" : "\(game.p.tickets)").font(Theme.font(17))
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.cyan).font(.system(size: 15))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.stroke))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tickets: \(store.isPro ? "unlimited" : String(game.p.tickets)). Open shop")
            Spacer()
            if store.isPro {
                Pill(text: "PRO", icon: "crown.fill", tint: Theme.gold)
            } else {
                Button { router.paywall = .generic } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                        Text("Go Pro").font(Theme.font(15))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(LinearGradient(colors: [Theme.gold, Color.orange], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }
                .accessibilityLabel("Go Pro")
            }
        }
        .padding(.top, 8)
    }

    private var logo: some View {
        VStack(spacing: 0) {
            Text("MIRROR").font(Theme.font(44)).foregroundStyle(Theme.brand)
            Text("MATCH").font(Theme.font(44)).foregroundStyle(Theme.brand)
                .scaleEffect(y: -1).mask(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                .frame(height: 30).offset(y: -2).accessibilityHidden(true)
            Text("Copy it better. Win it faster.").font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.6)).padding(.top, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mirror Match")
    }

    private var rankCard: some View {
        Button { sheet = .stats } label: {
            GlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Theme.brandDiag).frame(width: 50, height: 50)
                        Image(systemName: Rank.icons[game.rankIndex]).font(.system(size: 22, weight: .bold)).foregroundStyle(.black)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(game.rankName).font(Theme.font(20))
                            Spacer()
                            Text("\(game.p.mp) MP").font(Theme.font(14)).foregroundStyle(.white.opacity(0.6))
                        }
                        ProgressView(value: Rank.progress(for: game.p.mp)).tint(Theme.cyan)
                        if let n = Rank.toNext(game.p.mp) {
                            Text("\(n) MP to \(Rank.names[min(5, game.rankIndex + 1)])").font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rank \(game.rankName), \(game.p.mp) mirror points. Open stats")
    }

    private var quickDuel: some View {
        Button { router.start(.ghost) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Quick Duel").font(Theme.font(26))
                    Text("Best of 5 vs an AI ghost").font(Theme.font(14, .semibold)).opacity(0.7)
                }
                Spacer()
                Image(systemName: "bolt.fill").font(.system(size: 30, weight: .bold))
            }
            .padding(.horizontal, 22)
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(height: 84)
        .accessibilityHint("Starts a best of five match against an AI opponent")
    }

    private var tiles: some View {
        let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: cols, spacing: 14) {
            tile(title: "Daily Challenge", subtitle: dailySubtitle, icon: "flame.fill", tint: .orange, badge: game.dailyDone ? nil : "NEW") { router.start(.daily) }
            tile(title: "Challenge a Friend", subtitle: "Send a link, beat their score", icon: "paperplane.fill", tint: Theme.cyan, badge: nil) { sheet = .friends }
            tile(title: "Face to Face", subtitle: "2 players, 1 phone", icon: "person.2.fill", tint: Theme.magenta, badge: nil) { router.start(.faceToFace) }
            tile(title: "Custom Move", subtitle: "Invent a move to share", icon: "scribble.variable", tint: Theme.lime, badge: store.isPro ? nil : "PRO") {
                if store.isPro || game.customAvailableForFree { router.start(.customCreate) } else { router.paywall = .custom }
            }
        }
    }

    private var dailySubtitle: String {
        if let s = game.todayScore { return "Today: \(s)/500 · 🔥 \(game.currentStreak)" }
        return game.currentStreak > 0 ? "🔥 \(game.currentStreak)-day streak" : "Same 5 moves for everyone"
    }

    private func tile(title: String, subtitle: String, icon: String, tint: Color, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlassCard(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                            .frame(width: 42, height: 42).background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 13))
                        Spacer()
                        if let badge { Pill(text: badge, tint: badge == "PRO" ? Theme.gold : Theme.lime) }
                    }
                    Text(title).font(Theme.font(17)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                    Text(subtitle).font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(2).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var repairBanner: some View {
        GlassCard {
            HStack(spacing: 12) {
                Text("🔥").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your \(game.p.brokenStreak)-day streak just broke").font(Theme.font(15))
                    Text("Repair it for 3 tickets").font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button("Repair") {
                    if store.isPro {
                        game.addTickets(3); _ = game.repairStreak()
                    } else if !game.repairStreak() { router.paywall = .streak }
                }
                .buttonStyle(.borderedProminent).tint(.orange).foregroundStyle(.black).font(Theme.font(14))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            footerButton("Skins", icon: "paintbrush.pointed.fill") { sheet = .skins }
            footerButton("Stats", icon: "chart.bar.fill") { sheet = .stats }
            footerButton("Settings", icon: "gearshape.fill") { sheet = .settings }
        }
    }

    private func footerButton(_ t: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold))
                Text(t).font(Theme.font(12, .bold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke))
        }
    }
}
