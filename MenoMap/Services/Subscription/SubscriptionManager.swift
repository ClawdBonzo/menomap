import Foundation
import StoreKit
import RevenueCat

enum ProductID {
    static let monthly = "menomap.pro.monthly"
    static let yearly = "menomap.pro.yearly"
    static let lifetime = "menomap.pro.lifetime"
    static let visitReport = "menomap.visitreport.single"

    static let subscriptions: Set<String> = [monthly, yearly]
    static let pro: Set<String> = [monthly, yearly, lifetime]
    static let all: [String] = [yearly, monthly, lifetime, visitReport]
}

/// What an entitlement decision needs from a transaction; lets the rule be unit-tested without StoreKit.
struct EntitlementInput: Equatable {
    var productID: String
    var expirationDate: Date?
    var revocationDate: Date?
}

enum Entitlement {
    /// Lifetime OR an unexpired, unrevoked subscription → Pro. Everything else → Free.
    static func isPro(_ inputs: [EntitlementInput], now: Date = .now) -> Bool {
        inputs.contains { t in
            guard ProductID.pro.contains(t.productID), t.revocationDate == nil else { return false }
            if t.productID == ProductID.lifetime { return true }
            guard let exp = t.expirationDate else { return false }
            return exp > now
        }
    }
}

protocol SubscriptionProviding {
    var isPro: Bool { get }
    var visitReportCredits: Int { get }
}

/// StoreKit 2 purchases. RevenueCat runs in observer mode only (Apple Ads attribution, anonymous IDs);
/// it never receives health data. The app stays usable when StoreKit is down (cached entitlement, else Free).
@MainActor
@Observable
final class SubscriptionManager: SubscriptionProviding {
    private(set) var products: [Product] = []
    private(set) var productsFailed = false
    private(set) var isPro: Bool
    private(set) var visitReportCredits: Int
    private(set) var purchasing: String?
    var lastError: String?

    private static let cacheKey = "meno.entitlement.pro"
    private static let creditsKey = "meno.visitreport.credits"
    private var updatesTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: Self.cacheKey)
        visitReportCredits = UserDefaults.standard.integer(forKey: Self.creditsKey)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-MMPro") { isPro = true }
        if ProcessInfo.processInfo.arguments.contains("-MMFree") { isPro = false }
        #endif
    }

    func start() {
        configureRevenueCat()
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    private func configureRevenueCat() {
        guard !Purchases.isConfigured,
              let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String, !key.isEmpty else { return }
        Purchases.configure(with: Configuration.Builder(withAPIKey: key)
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
            .build())
        Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()
    }

    func loadProducts() async {
        productsFailed = false
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = ProductID.all.compactMap { id in loaded.first { $0.id == id } }
            productsFailed = products.isEmpty
        } catch {
            productsFailed = true
            MenoLog.commerce.error("products failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    func refreshEntitlements() async {
        var inputs: [EntitlementInput] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result {
                inputs.append(EntitlementInput(productID: t.productID, expirationDate: t.expirationDate, revocationDate: t.revocationDate))
            }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-MMPro") { return setPro(true) }
        if ProcessInfo.processInfo.arguments.contains("-MMFree") { return setPro(false) }
        #endif
        setPro(Entitlement.isPro(inputs))
    }

    private func setPro(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.cacheKey)
        guard value != isPro else { return }
        isPro = value
        AppContainer.shared.refreshSnapshot()
    }

    private func handle(_ result: StoreKit.VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result else { return }
        if t.productID == ProductID.visitReport, t.revocationDate == nil {
            addCredit()
        }
        await t.finish()
        await refreshEntitlements()
    }

    /// Returns true when the purchase completed.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchasing = product.id
        defer { purchasing = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let t) = verification else {
                    lastError = String(localized: "The App Store couldn't verify that purchase.")
                    return false
                }
                if t.productID == ProductID.visitReport { addCredit() }
                await t.finish()
                await refreshEntitlements()
                if Purchases.isConfigured { _ = try? await Purchases.shared.recordPurchase(result) }
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do { try await AppStore.sync() } catch { lastError = error.localizedDescription }
        await refreshEntitlements()
    }

    // MARK: Visit Report credits (consumable)

    private func addCredit() {
        visitReportCredits += 1
        UserDefaults.standard.set(visitReportCredits, forKey: Self.creditsKey)
    }

    /// Spends one credit for a full PDF. Pro users never spend credits.
    func consumeVisitReportCredit() -> Bool {
        guard !isPro else { return true }
        guard visitReportCredits > 0 else { return false }
        visitReportCredits -= 1
        UserDefaults.standard.set(visitReportCredits, forKey: Self.creditsKey)
        return true
    }

    var canExportFullPDF: Bool { isPro || visitReportCredits > 0 }
}
