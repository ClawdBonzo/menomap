import SwiftUI
import StoreKit

/// "See the month, not just the day." Close button always visible. No countdowns, no data threats.
/// Prices come only from StoreKit; a skeleton shows while products load.
struct PaywallView: View {
    let trigger: PaywallTrigger

    @Environment(SubscriptionManager.self) private var subscription
    @Environment(\.dismiss) private var dismiss
    @State private var selected = ProductID.yearly
    @State private var showRedeem = false

    private var headline: LocalizedStringKey {
        switch trigger {
        case .pdf, .appointment: "Walk in with notes."
        case .experiment: "Test it on your own data."
        default: "See the month, not just the day."
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingHero().frame(height: 120)
                    Text("MenoMap Pro").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(MenoTheme.teal)
                    Text(headline).font(MenoTheme.headline(.largeTitle)).foregroundStyle(MenoTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 14) {
                        benefit("square.grid.3x3.middle.filled", "30, 90 and 365-day heat maps and stats")
                        benefit("sparkle.magnifyingglass", "Patterns in your own entries, with the numbers")
                        benefit("doc.richtext", "Clinician notes as a PDF, in any language we support")
                        benefit("flask", "Two-week experiments: before vs during")
                        benefit("calendar.badge.clock", "The full monthly Heat Report")
                        benefit("bell", "Medication reminders")
                    }

                    plans
                    if let err = subscription.lastError {
                        Text(err).font(.footnote).foregroundStyle(MenoTheme.danger)
                    }

                    Button {
                        Task {
                            guard let p = subscription.product(selected) else { return }
                            if await subscription.purchase(p) { dismiss() }
                        }
                    } label: {
                        if subscription.purchasing != nil { ProgressView().tint(MenoTheme.onTeal) } else { Text(ctaTitle) }
                    }
                    .buttonStyle(.menoPrimary)
                    .disabled(subscription.product(selected) == nil || subscription.purchasing != nil)

                    if trigger == .pdf || trigger == .appointment, let visit = subscription.product(ProductID.visitReport) {
                        Button {
                            Task { if await subscription.purchase(visit) { dismiss() } }
                        } label: {
                            VStack(spacing: 2) {
                                Text("Just this visit: \(visit.displayPrice)")
                                Text("One full PDF of up to 90 days. No subscription.").font(.caption)
                            }
                        }
                        .buttonStyle(.menoSecondary)
                    }

                    Button("Have a code from your clinic or a friend?") { showRedeem = true }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: MenoTheme.minHit)

                    HStack(spacing: 18) {
                        Button("Restore") { Task { await subscription.restore(); if subscription.isPro { dismiss() } } }
                        Link("Terms", destination: LegalLinks.terms)
                        Link("Privacy", destination: LegalLinks.privacy)
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)

                    Text("Subscriptions renew automatically until cancelled in Settings → Apple Account → Subscriptions. The free trial applies to the yearly plan for new subscribers. Your data stays on your iPhone either way, and everything you've logged stays yours on the free plan.")
                        .font(.caption2).foregroundStyle(MenoTheme.inkSecondary)
                }
                .padding(24)
                .padding(.top, 20)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(MenoTheme.inkSecondary)
                    .frame(width: MenoTheme.minHit, height: MenoTheme.minHit)
                    .background(MenoTheme.surface, in: Circle())
            }
            .padding(12)
            .accessibilityLabel(Text("Close"))
        }
        .background(MenoTheme.ground.ignoresSafeArea())
        .offerCodeRedemption(isPresented: $showRedeem) { result in
            Task {
                await subscription.refreshEntitlements()
                if subscription.isPro { dismiss() }
            }
        }
        .task { if subscription.products.isEmpty { await subscription.loadProducts() } }
    }

    private var ctaTitle: String {
        guard let p = subscription.product(selected) else { return String(localized: "Continue") }
        if let intro = p.subscription?.introductoryOffer, intro.paymentMode == .freeTrial {
            return String(localized: "Start free trial")
        }
        return String(localized: "Continue with \(p.displayPrice)")
    }

    @ViewBuilder private var plans: some View {
        if subscription.products.isEmpty {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16).fill(MenoTheme.hairline).frame(height: 68)
                }
                if subscription.productsFailed {
                    Button("Couldn't reach the App Store. Try again") { Task { await subscription.loadProducts() } }
                        .font(.footnote)
                }
            }
            .redacted(reason: .placeholder)
        } else {
            VStack(spacing: 10) {
                ForEach([ProductID.yearly, ProductID.monthly, ProductID.lifetime], id: \.self) { id in
                    if let p = subscription.product(id) { planRow(p) }
                }
            }
        }
    }

    private func planRow(_ p: Product) -> some View {
        let on = selected == p.id
        return Button { selected = p.id } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.title3).foregroundStyle(on ? MenoTheme.teal : MenoTheme.inkSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planName(p)).font(.headline).foregroundStyle(MenoTheme.ink)
                        if p.id == ProductID.yearly {
                            Text("Best value").font(.caption2.weight(.bold)).foregroundStyle(MenoTheme.onTeal)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(MenoTheme.teal, in: Capsule())
                        }
                    }
                    Text(planDetail(p)).font(.caption).foregroundStyle(MenoTheme.inkSecondary)
                }
                Spacer()
                Text(p.displayPrice).font(.system(.headline, design: .serif).monospacedDigit()).foregroundStyle(MenoTheme.ink)
            }
            .padding(16)
            .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? MenoTheme.teal : MenoTheme.hairline, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func planName(_ p: Product) -> String {
        switch p.id {
        case ProductID.yearly: String(localized: "Yearly")
        case ProductID.monthly: String(localized: "Monthly")
        case ProductID.lifetime: String(localized: "Lifetime")
        default: p.displayName
        }
    }

    private func planDetail(_ p: Product) -> String {
        switch p.id {
        case ProductID.yearly:
            let monthly = (p.price / 12).formatted(p.priceFormatStyle)
            if let intro = p.subscription?.introductoryOffer, intro.paymentMode == .freeTrial {
                let days = intro.period.unit == .week ? intro.period.value * 7 : intro.period.value
                return String(localized: "\(days)-day free trial, then \(p.displayPrice)/year (\(monthly)/month)")
            }
            return String(localized: "\(monthly)/month, billed yearly")
        case ProductID.monthly: return String(localized: "Billed monthly. Cancel any time.")
        case ProductID.lifetime: return String(localized: "Pay once. Family Sharing included.")
        default: return p.description
        }
    }

    private func benefit(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(MenoTheme.teal).frame(width: 28)
            Text(text).font(.body).foregroundStyle(MenoTheme.ink)
        }
    }
}
