import SwiftUI

/// All medals, earned or not, with their Research Point rewards.
struct MedalsView: View {
    let onBack: () -> Void

    private let earned = PlayerProgress.earnedMedals

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
                PixelText("MEDALS \(earned.count)/\(Medal.allCases.count)", pixel: 3, color: Theme.highlight)
                Spacer()
                Color.clear.frame(width: 90, height: 1)
            }
            .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 10)], spacing: 10) {
                    ForEach(Medal.allCases) { medal in
                        row(medal, isEarned: earned.contains(medal.id))
                    }
                }
                .padding(16)
            }
        }
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
    }

    private func row(_ medal: Medal, isEarned: Bool) -> some View {
        HStack(spacing: 12) {
            PixelIcon(icon: isEarned ? .medal : .lock, scale: 3)
                .opacity(isEarned ? 1 : 0.6)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(medal.title.uppercased())
                    .font(Theme.body(12))
                    .foregroundStyle(isEarned ? Theme.highlight : Theme.text)
                Text(medal.detail)
                    .font(Theme.body(10, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                PixelIcon(icon: isEarned ? .check : .flask, scale: isEarned ? 2 : 1, outlined: !isEarned)
                if !isEarned { PixelText("+\(medal.reward)", pixel: 2, color: Color(pixel: Pal.cyan)) }
            }
        }
        .padding(12)
        .pixelPanel(fill: isEarned ? Color(pixel: Pal.plum) : Theme.panel)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medal.title). \(medal.detail). \(isEarned ? "Earned" : "Reward \(medal.reward) research points")")
    }
}
