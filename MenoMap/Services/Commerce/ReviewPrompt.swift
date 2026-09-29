import StoreKit
import UIKit

/// Asks for a review only after a positive moment (a PDF exported, an experiment with fewer surges),
/// never after a surge, at most once per 120 days.
enum ReviewPrompt {
    private static let key = "meno.review.last"

    @MainActor
    static func recordPositiveMoment() {
        let last = UserDefaults.standard.double(forKey: key)
        guard Date.now.timeIntervalSince1970 - last > 120 * 86400 else { return }
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: key)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
