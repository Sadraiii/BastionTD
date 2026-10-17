import SwiftUI

/// Reference screen: every villain's traits and every hero's damage type and powers.
/// Helps players pick the right heroes for flyers, cloaked foes and immunities.
struct CodexView: View {
    let onBack: () -> Void
    @State private var showHeroes = false

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
                PixelText("CODEX", pixel: 3, color: Theme.highlight)
                Spacer()
                Button {
                    playTap()
                    showHeroes.toggle()
                } label: {
                    PixelText(showHeroes ? "VILLAINS" : "HEROES", pixel: 2, shadow: nil)
                }
                .buttonStyle(PixelButtonStyle.blue)
            }
            .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                    if showHeroes {
                        ForEach(TowerKind.allCases) { heroRow($0) }
                    } else {
                        ForEach(EnemyKind.codex, id: \.self) { villainRow($0) }
                    }
                }
                .padding(16)
            }
        }
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
    }

    private func villainRow(_ kind: EnemyKind) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PixelImage(image: Art.enemyIcon(kind), scale: 2)
                .frame(width: 48, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.name.uppercased())
                    .font(Theme.body(12))
                    .foregroundStyle(Color(pixel: Pal.enemy(kind)))
                if !kind.traitTags.isEmpty {
                    Text(kind.traitTags.joined(separator: " · "))
                        .font(Theme.body(9))
                        .foregroundStyle(Theme.highlight)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(kind.ability)
                    .font(Theme.body(10, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .pixelPanel()
        .accessibilityElement(children: .combine)
    }

    private func heroRow(_ kind: TowerKind) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PixelImage(image: Art.towerIcon(kind, tiers: [UpgradeRules.maxTier, 2]), scale: 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(kind.name.uppercased())
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.tower(kind))
                    Text(kind.baseStats.damageType.title.uppercased())
                        .font(Theme.body(9))
                        .foregroundStyle(Theme.border)
                        .padding(.horizontal, 4)
                        .background(Color(pixel: Pal.damage(kind.baseStats.damageType)))
                }
                Text(kind.role)
                    .font(Theme.body(10, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                let powers = kind.paths.compactMap { $0.tiers[2].power?.name }
                Text("POWERS: " + powers.joined(separator: " / ").uppercased())
                    .font(Theme.body(9))
                    .foregroundStyle(Theme.highlight)
                    .fixedSize(horizontal: false, vertical: true)
                if !kind.baseStats.hitsAir {
                    Text("CAN'T HIT FLYERS").font(Theme.body(9)).foregroundStyle(Theme.danger)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .pixelPanel()
        .accessibilityElement(children: .combine)
    }
}
