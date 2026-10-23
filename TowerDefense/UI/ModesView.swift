import SwiftUI

/// The modes besides the campaign, each with its best result.
struct ModesView: View {
    let onDaily: () -> Void
    let onBossRush: () -> Void
    let onExpedition: () -> Void
    let onLone: () -> Void
    let onBack: () -> Void

    private let daily = MatchSetup.daily(for: Date())

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    playTap()
                    onBack()
                } label: {
                    PixelText("< BACK", pixel: 2, shadow: nil)
                }
                .buttonStyle(PixelButtonStyle.neutral)
                Spacer()
                PixelText("MODES", pixel: 3, color: Theme.highlight)
                Spacer()
                Color.clear.frame(width: 90, height: 1)
            }
            .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    let bestDaily = PlayerProgress.bestDaily(daily.setup.day ?? 0)
                    let bestRush = PlayerProgress.bestBossRush
                    let bestExpedition = PlayerProgress.bestExpedition
                    let commander = PlayerProgress.commander.selected
                    let bestLone = PlayerProgress.bestLone(commander)
                    mode("DAILY: \(daily.map.name)", best: bestDaily > 0 ? "BEST TODAY: WAVE \(bestDaily)" : nil,
                         detail: "The same map, rules and heroes for everyone today.", style: .gold, action: onDaily)
                    mode("BOSS RUSH", best: bestRush > 0 ? "BEST: WAVE \(bestRush)/\(WaveLibrary.bossRush.count)" : nil,
                         detail: "Ten waves of tougher bosses on the Arena.", style: .danger, action: onBossRush)
                    mode("EXPEDITION", best: bestExpedition > 0 ? "BEST RUN: WAVE \(bestExpedition)" : nil,
                         detail: "A random map and squad that grows with boons. The waves never end.",
                         style: .primary, action: onExpedition)
                    mode("LONE COMMANDER", best: bestLone > 0 ? "BEST AS \(commander.name.uppercased()): WAVE \(bestLone)" : nil,
                         detail: "No heroes, only your commander. Ten waves on the Courtyard for triple commander XP.",
                         style: .blue, action: onLone)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
    }

    private func mode(_ title: String, best: String?, detail: String, style: PixelButtonStyle,
                      action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button {
                playTap()
                action()
            } label: {
                VStack(spacing: 4) {
                    PixelText(title, pixel: 2)
                    if let best {
                        PixelText(best, pixel: 1, shadow: nil)
                    }
                }
                .frame(width: 236)
            }
            .buttonStyle(style)
            Text(detail)
                .font(Theme.body(11, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
