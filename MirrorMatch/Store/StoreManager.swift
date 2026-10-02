import StoreKit
import SwiftUI

enum ProductID {
    static let weekly = "ch.connexa.mirrormatch.pro.weekly"
    static let yearly = "ch.connexa.mirrormatch.pro.yearly"
    static let tickets20 = "ch.connexa.mirrormatch.tickets.20"
    static let tickets75 = "ch.connexa.mirrormatch.tickets.75"
    static let skins = "ch.connexa.mirrormatch.skins.all"

    static let all = [yearly, weekly, tickets20, tickets75, skins]
    static let ticketAmount: [String: Int] = [tickets20: 20, tickets75: 75]
}

@MainActor
@Observable
final class StoreManager {
    var products: [String: Product] = [:]
    var isPro: Bool { didSet { UserDefaults.standard.set(isPro, forKey: "mm.isPro") } }
    var hasSkinPack: Bool { didSet { UserDefaults.standard.set(hasSkinPack, forKey: "mm.skinPack") } }
    var loading = false
    var busy = false
    var message: String?

    private var updatesTask: Task<Void, Never>?
    private weak var game: GameStore?

    init() {
        isPro = UserDefaults.standard.bool(forKey: "mm.isPro")
        hasSkinPack = UserDefaults.standard.bool(forKey: "mm.skinPack")
    }

    func start(game: GameStore) {
        self.game = game
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await load()
            await refreshEntitlements()
        }
    }

    func load() async {
        loading = true
        defer { loading = false }
        do {
            let list = try await Product.products(for: ProductID.all)
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        } catch {
            message = "Couldn't load prices. Check your connection."
        }
    }

    func refreshEntitlements() async {
        var pro = false
        var pack = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            switch t.productID {
            case ProductID.weekly, ProductID.yearly:
                if let exp = t.expirationDate { if exp > Date() { pro = true } } else { pro = true }
            case ProductID.skins: pack = true
            default: break
            }
        }
        isPro = pro
        hasSkinPack = pack
    }

    @discardableResult
    func purchase(_ id: String) async -> Bool {
        guard let product = products[id] else {
            message = "This item isn't available right now."
            await load()
            return false
        }
        busy = true
        defer { busy = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
                return true
            case .pending:
                message = "Purchase pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            message = "Purchase failed. Please try again."
            return false
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPro || hasSkinPack ? "Purchases restored." : "No purchases to restore."
        } catch {
            message = "Couldn't restore purchases."
        }
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result else { return }
        if let amount = ProductID.ticketAmount[t.productID] {
            let key = "mm.tx.\(t.id)"
            if !UserDefaults.standard.bool(forKey: key) {
                UserDefaults.standard.set(true, forKey: key)
                game?.addTickets(amount)
                Haptics.success()
            }
        }
        await t.finish()
        await refreshEntitlements()
    }

    // MARK: display helpers
    func price(_ id: String) -> String { products[id]?.displayPrice ?? "—" }

    var yearlyHasTrial: Bool { products[ProductID.yearly]?.subscription?.introductoryOffer?.paymentMode == .freeTrial }

    var yearlyPerWeek: String? {
        guard let p = products[ProductID.yearly] else { return nil }
        return (p.price / 52).formatted(p.priceFormatStyle)
    }

    var yearlySavings: Int? {
        guard let y = products[ProductID.yearly], let w = products[ProductID.weekly] else { return nil }
        let yearlyIfWeekly = w.price * 52
        guard yearlyIfWeekly > 0 else { return nil }
        let pct = (1 - (y.price / yearlyIfWeekly)) * 100
        return Int(NSDecimalNumber(decimal: pct).doubleValue.rounded())
    }
}
