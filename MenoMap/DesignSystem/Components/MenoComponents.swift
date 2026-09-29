import SwiftUI
import MenoCore

// MARK: - Card

struct MenoCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous).strokeBorder(MenoTheme.hairline))
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var trailing: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(MenoTheme.headline(.title3))
                .foregroundStyle(MenoTheme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MenoTheme.teal)
                    .frame(minHeight: MenoTheme.minHit)
            }
        }
    }
}

// MARK: - Buttons

struct MenoButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, danger }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: MenoTheme.radiusButton, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: MenoTheme.radiusButton, style: .continuous)
                        .strokeBorder(MenoTheme.teal.opacity(0.5), lineWidth: 1.5)
                }
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: MenoTheme.onTeal
        case .secondary, .quiet: MenoTheme.teal
        case .danger: .white
        }
    }

    private var background: Color {
        switch kind {
        case .primary: MenoTheme.teal
        case .secondary: .clear
        case .quiet: MenoTheme.tealSoft
        case .danger: MenoTheme.danger
        }
    }
}

extension ButtonStyle where Self == MenoButtonStyle {
    static var menoPrimary: MenoButtonStyle { MenoButtonStyle(kind: .primary) }
    static var menoSecondary: MenoButtonStyle { MenoButtonStyle(kind: .secondary) }
    static var menoQuiet: MenoButtonStyle { MenoButtonStyle(kind: .quiet) }
}

// MARK: - Chips

struct MetricChip: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).imageScale(.small) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: MenoTheme.minHit)
            .foregroundStyle(isOn ? MenoTheme.onTeal : MenoTheme.ink)
            .background(isOn ? MenoTheme.teal : MenoTheme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? .clear : MenoTheme.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Wrapping row of chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            maxX = max(maxX, x - spacing)
            rowH = max(rowH, s.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX, x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: - Disclaimer

/// The legal posture, shown on onboarding, Learn, Settings and in the PDF footer.
enum Disclaimer {
    static var full: String {
        String(localized: "MenoMap is a wellness tracker and education tool. It does not diagnose menopause or any other condition, does not prescribe or change treatment, and does not replace care from a qualified clinician. If symptoms worry you, or if you have bleeding after menopause, chest pain, sudden severe headache, one-sided weakness, trouble breathing, or fainting, seek in-person or emergency care.")
    }

    static var short: String {
        String(localized: "Wellness tracker, not a diagnosis. Check with a clinician before making medical decisions.")
    }
}

struct DisclaimerBanner: View {
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(MenoTheme.inkSecondary)
                .accessibilityHidden(true)
            Text(compact ? Disclaimer.short : Disclaimer.full)
                .font(.footnote)
                .foregroundStyle(MenoTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MenoTheme.hairline))
        .accessibilityElement(children: .combine)
    }
}

/// Full-width safety banner (bleeding after menopause, emergency copy). The only place `danger` is used.
struct SafetyBanner: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "exclamationmark.circle.fill")
                .font(.headline)
                .foregroundStyle(MenoTheme.danger)
            Text(message)
                .font(.body)
                .foregroundStyle(MenoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MenoTheme.dangerSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(MenoTheme.teal)
                .accessibilityHidden(true)
            Text(title)
                .font(MenoTheme.headline(.headline))
                .foregroundStyle(MenoTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(MenoTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Screen background

extension View {
    func menoScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(MenoTheme.ground.ignoresSafeArea())
            .tint(MenoTheme.teal)
    }
}
