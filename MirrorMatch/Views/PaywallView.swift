import SwiftUI
import StoreKit

struct PaywallView: View {
    let reason: PaywallReason
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @State private var selected = ProductID.yearly
    @State private var appear = false

    private var headline: String {
        switch reason {
        case .generic: return "Play without limits"
        case .tickets: return "Out of tickets?"
        case .skins: return "Make your trail legendary"
        case .custom: return "Invent unlimited moves"
        case .streak: return "Never lose a streak again"
        }
    }

    private var sub: String {
        switch reason {
        case .tickets: return "Pro gives you unlimited rematches, retries and streak repairs."
        case .skins: return "Pro unlocks every trail skin, now and in every future update."
        case .custom: return "Free players can create one custom move per day. Pro removes the limit."
        case .streak: return "Pro repairs broken streaks for free."
        case .generic: return "Everything unlocked. Cancel anytime."
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(Theme.gold.opacity(0.18)).frame(width: 110, height: 110).blur(radius: 14)
                        Image(systemName: "crown.fill").font(.system(size: 52)).foregroundStyle(LinearGradient(colors: [Theme.gold, .orange], startPoint: .top, endPoint: .bottom))
                            .scaleEffect(appear ? 1 : 0.6).rotationEffect(.degrees(appear ? 0 : -12))
                    }
                    .padding(.top, 30)
                    Text(headline).font(Theme.font(30)).multilineTextAlignment(.center)
                    Text(sub).font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            feature("ticket.fill", "Unlimited tickets", "Rematches, retries, streak repairs", Theme.gold)
                            feature("paintbrush.pointed.fill", "All 10 trail skins", "Aurora, Prism, Gold Rush and more", Theme.magenta)
                            feature("scribble.variable", "Unlimited custom moves", "Invent moves and challenge anyone", Theme.lime)
                            feature("flame.fill", "Free streak repair", "A missed day never ends your streak", .orange)
                        }
                    }

                    if !store.loaded {
                        if store.loading { ProgressView().padding() } else {
                            Button("Couldn't load prices · Retry") { Task { await store.load() } }.buttonStyle(SecondaryButtonStyle())
                        }
                    } else {
                        VStack(spacing: 10) {
                            planCard(ProductID.yearly)
                            planCard(ProductID.weekly)
                        }
                    }

                    Button {
                        Task { if await store.purchase(selected) , store.isPro { dismiss() } }
                    } label: {
                        if store.busy { ProgressView().tint(.black) } else { Text(ctaTitle) }
                    }
                    .buttonStyle(PrimaryButtonStyle(colors: [Theme.gold, .orange]))
                    .disabled(!store.has(selected) || store.busy)
                    .opacity(store.has(selected) ? 1 : 0.5)

                    Text(legal).font(Theme.font(11, .medium)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)

                    HStack(spacing: 18) {
                        Button("Restore") { Task { await store.restore(); if store.isPro { dismiss() } } }
                        Link("Terms", destination: Links.terms)
                        Link("Privacy", destination: Links.privacy)
                    }
                    .font(Theme.font(13, .bold)).foregroundStyle(.white.opacity(0.75))

                    Button("Just need tickets or skins? Visit the shop") {
                        dismiss()
                        Task { try? await Task.sleep(for: .seconds(0.5)); router.shop = true }
                    }
                    .font(Theme.font(13, .semibold)).foregroundStyle(Theme.cyan)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 34, height: 34).background(.ultraThinMaterial, in: Circle())
                    }
                    .foregroundStyle(.white.opacity(0.8)).accessibilityLabel("Close")
                }
                .padding(16)
                Spacer()
            }
        }
        .onAppear { withAnimation(.spring(duration: 0.7, bounce: 0.4)) { appear = true } }
        .alert("Mirror Match", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.message ?? "") }
        .presentationDragIndicator(.visible)
    }

    private var ctaTitle: String {
        if selected == ProductID.yearly, store.yearlyHasTrial { return "Try 3 Days Free" }
        return "Continue"
    }

    private var legal: String {
        let y = store.price(ProductID.yearly), w = store.price(ProductID.weekly)
        let trial = store.yearlyHasTrial ? "Yearly starts with a 3-day free trial, then \(y)/year. " : "Yearly: \(y)/year. "
        return trial + "Weekly: \(w)/week. Payment is charged to your Apple ID at confirmation of purchase (after the trial, if any). Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your Apple ID settings."
    }

    private func feature(_ icon: String, _ title: String, _ sub: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(tint)
                .frame(width: 36, height: 36).background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.font(16))
                Text(sub).font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private func planCard(_ id: String) -> some View {
        let isYear = id == ProductID.yearly
        let on = selected == id
        return Button { selected = id; Haptics.select() } label: {
            HStack {
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(on ? Theme.gold : .white.opacity(0.35))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(isYear ? "Yearly" : "Weekly").font(Theme.font(18))
                        if isYear, let s = store.yearlySavings, s > 0 { Pill(text: "SAVE \(s)%", tint: Theme.lime) }
                    }
                    Text(isYear ? (store.yearlyHasTrial ? "3 days free, then \(store.price(id))/year" : "\(store.price(id))/year") : "\(store.price(id))/week")
                        .font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if isYear, let pw = store.yearlyPerWeek {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(pw).font(Theme.font(17))
                        Text("per week").font(Theme.font(11, .semibold)).foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .padding(14)
            .background(on ? Theme.gold.opacity(0.12) : Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? Theme.gold : Theme.stroke, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel("\(isYear ? "Yearly" : "Weekly") plan, \(store.price(id))")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Shop

struct ShopView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameStore.self) private var game
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "ticket.fill").foregroundStyle(Theme.gold)
                            Text(store.isPro ? "Unlimited tickets with Pro" : "You have \(game.p.tickets) tickets").font(Theme.font(18))
                            Spacer()
                        }
                        Text("Tickets power rematches, daily retries and streak repairs. You get 3 free every day.")
                            .font(Theme.font(13, .semibold)).foregroundStyle(.white.opacity(0.65)).frame(maxWidth: .infinity, alignment: .leading)

                        item(id: ProductID.tickets20, icon: "ticket.fill", tint: Theme.gold, title: "20 Tickets", sub: "Handy refill")
                        item(id: ProductID.tickets75, icon: "ticket.fill", tint: Theme.gold, title: "75 Tickets", sub: "Best value · 35% more per $", badge: "BEST VALUE")
                        item(id: ProductID.skins, icon: "paintbrush.pointed.fill", tint: Theme.magenta, title: "All Skins", sub: "Unlock all 10 trail skins forever", owned: store.hasSkinPack || store.isPro)

                        if !store.isPro {
                            Button { dismiss(); Task { try? await Task.sleep(for: .seconds(0.5)); router.paywall = .generic } } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "crown.fill").foregroundStyle(Theme.gold)
                                    VStack(alignment: .leading) {
                                        Text("Get everything with Pro").font(Theme.font(17))
                                        Text("Unlimited tickets · all skins · custom moves").font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.65))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding(14)
                                .background(Theme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.gold.opacity(0.4)))
                            }.buttonStyle(.plain).foregroundStyle(.white)
                        }
                        Button("Restore Purchases") { Task { await store.restore() } }.font(Theme.font(14, .bold)).foregroundStyle(.white.opacity(0.7)).padding(.top, 6)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("Mirror Match", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(store.message ?? "") }
        }
        .task { if store.products.isEmpty { await store.load() } }
    }

    private func item(id: String, icon: String, tint: Color, title: String, sub: String, badge: String? = nil, owned: Bool = false) -> some View {
        Button {
            Task { await store.purchase(id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(tint)
                    .frame(width: 46, height: 46).background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text(title).font(Theme.font(17)); if let badge { Pill(text: badge, tint: Theme.lime) } }
                    Text(sub).font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if owned { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.lime) }
                else { Text(store.price(id)).font(Theme.font(16)).padding(.horizontal, 14).padding(.vertical, 8).background(Theme.cyan, in: Capsule()).foregroundStyle(.black) }
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke))
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .disabled(owned || !store.has(id) || store.busy)
    }
}
