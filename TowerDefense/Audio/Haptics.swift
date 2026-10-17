import UIKit

/// Light haptic feedback for key moments, respecting the player's setting.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notifier = UINotificationFeedbackGenerator()

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard PlayerProgress.hapticsEnabled else { return }
        switch style {
        case .heavy, .rigid: heavy.impactOccurred()
        case .medium: medium.impactOccurred()
        default: light.impactOccurred()
        }
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard PlayerProgress.hapticsEnabled else { return }
        notifier.notificationOccurred(type)
    }
}
