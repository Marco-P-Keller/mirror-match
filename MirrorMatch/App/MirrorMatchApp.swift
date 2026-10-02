import SwiftUI

@main
struct MirrorMatchApp: App {
    @State private var game = GameStore()
    @State private var store = StoreManager()
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(game)
                .environment(store)
                .environment(router)
                .preferredColorScheme(.dark)
                .tint(Theme.cyan)
                .task {
                    #if DEBUG
                    if Autoplay.demo { game.applyDemoProfile() }
                    #endif
                    store.start(game: game)
                    Haptics.enabled = game.p.haptics
                }
                .onOpenURL { url in
                    if let c = Challenge.parse(url) { router.incoming(c) }
                }
        }
    }
}

enum Session: Identifiable, Hashable {
    case ghost, faceToFace, daily, friendCreate
    case friendAccept(Challenge), customCreate, customPlay(Challenge)

    var id: String {
        switch self {
        case .ghost: return "ghost"
        case .faceToFace: return "f2f"
        case .daily: return "daily"
        case .friendCreate: return "friendCreate"
        case .friendAccept(let c): return "accept-\(c.id)"
        case .customCreate: return "customCreate"
        case .customPlay(let c): return "customPlay-\(c.id)"
        }
    }
}

enum PaywallReason: String, Identifiable {
    case generic, tickets, skins, custom, streak
    var id: String { rawValue }
}

@MainActor
@Observable
final class Router {
    var session: Session?
    var paywall: PaywallReason?
    var shop = false
    var pendingChallenge: Challenge?

    func incoming(_ c: Challenge) {
        session = nil
        pendingChallenge = c
    }

    func start(_ s: Session) { session = s }
}

struct RootView: View {
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        ZStack {
            #if DEBUG
            Color.clear.task { await debugRoute() }
            #endif
            if game.p.onboarded {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: $router.session) { s in
            SessionHost(session: s)
        }
        .sheet(item: $router.paywall) { reason in
            PaywallView(reason: reason)
        }
        .sheet(isPresented: $router.shop) { ShopView() }
        .onChange(of: scenePhase) { _, p in
            if p == .active { game.refreshDay() }
        }
        .onChange(of: router.pendingChallenge) { _, c in
            guard let c, game.p.onboarded else { return }
            router.pendingChallenge = nil
            router.session = c.kind == .custom ? .customPlay(c) : .friendAccept(c)
        }
    }
}

struct SessionHost: View {
    let session: Session
    var body: some View {
        switch session {
        case .ghost: GhostScreen()
        case .faceToFace: FaceToFaceScreen()
        case .daily: RunScreen(mode: .daily)
        case .friendCreate: RunScreen(mode: .friendCreate)
        case .friendAccept(let c): RunScreen(mode: .friendAccept(c))
        case .customCreate: CustomCreateScreen()
        case .customPlay(let c): CustomPlayScreen(challenge: c)
        }
    }
}

#if DEBUG
extension RootView {
    func debugRoute() async {
        guard let r = Autoplay.route else { return }
        try? await Task.sleep(for: .seconds(1.0))
        switch r {
        case "ghost": router.start(.ghost)
        case "daily": router.start(.daily)
        case "f2f": router.start(.faceToFace)
        case "friend": router.start(.friendCreate)
        case "custom": router.start(.customCreate)
        case "paywall": router.paywall = .generic
        case "shop": router.shop = true
        case "replay":
            var g = SeededGenerator(seed: 5)
            let ghost = Ghost.roster[2]
            let recs = MoveFactory.set(seed: 11).map { m -> RoundRecord in
                RoundRecord(move: m, results: [ghost.perform(m, using: &g), ghost.perform(m, using: &g)])
            }
            if let url = try? await ReplayRenderer.render(records: recs, names: ["Marco", "Shade"], skin: Skin.byID("neon"), headline: "I WON 3–1", subline: "Marco vs Shade") {
                try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: "/tmp/mm_replay.mp4"))
                print("REPLAY", url.path)
            }
        default: break
        }
    }
}
#endif
