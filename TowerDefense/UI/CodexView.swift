import SwiftUI

/// Reference screen: every villain's traits, every hero's damage type and powers, and the
/// hero combos found so far. Helps players pick the right heroes for flyers, cloaked foes and immunities.
struct CodexView: View {
    let onBack: () -> Void
    @State private var page = Page.villains

    /// The top-right button names the page it opens next.
    private enum Page: String {
        case villains = "VILLAINS", heroes = "HEROES", combos = "COMBOS"

        var next: Page { self == .villains ? .heroes : self == .heroes ? .combos : .villains }
    }

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
                    page = page.next
                } label: {
                    PixelText(page.next.rawValue, pixel: 2, shadow: nil)
                }
                .buttonStyle(PixelButtonStyle.blue)
            }
            .padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                    switch page {
                    case .villains:
                        ForEach(EnemyKind.codex, id: \.self) { villainRow($0) }
                    case .heroes:
                        ForEach(TowerKind.allCases) { heroRow($0) }
                    case .combos:
                        let found = PlayerProgress.discoveredCombos
                        ForEach(HeroCatalog.combos, id: \.name) { comboRow($0, found: found.contains($0.name)) }
                    }
                }
                .padding(16)
            }
        }
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
    }

    /// Bronze, silver and gold.
    private static let badgeColors = [Pal.copper, Pal.silver, Pal.yellow]

    /// A villain stays a dark "???" until it has been beaten.
    private func villainRow(_ kind: EnemyKind) -> some View {
        let seen = PlayerProgress.hasSeen(kind)
        let kills = PlayerProgress.kills(kind)
        let badges = PlayerProgress.badges(kind)
        let nextBadge = PlayerProgress.badgeKills(kind).first { $0 > kills }
        return HStack(alignment: .top, spacing: 12) {
            PixelImage(image: seen ? Art.enemyIcon(kind) : Art.enemySilhouette(kind), scale: 2)
                .frame(width: 48, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                if seen {
                    HStack(spacing: 6) {
                        Text(kind.name.uppercased())
                            .font(Theme.body(12))
                            .foregroundStyle(Color(pixel: Pal.enemy(kind)))
                        if badges > 0 {
                            Text(PlayerProgress.badgeNames[badges - 1])
                                .font(Theme.body(9))
                                .foregroundStyle(Theme.border)
                                .padding(.horizontal, 4)
                                .background(Color(pixel: Self.badgeColors[badges - 1]))
                        }
                    }
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
                    Text("\(kills) DEFEATED" + (nextBadge.map { " · NEXT BADGE AT \($0)" } ?? ""))
                        .font(Theme.body(9))
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    Text("???")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.secondaryText)
                    Text("NOT BEATEN YET")
                        .font(Theme.body(9))
                        .foregroundStyle(Theme.secondaryText)
                }
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

    /// A combo stays "???" until it has been formed in a match.
    private func comboRow(_ combo: HeroCombo, found: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 4) {
                PixelImage(image: Art.towerIcon(combo.first), scale: 2)
                if found { PixelImage(image: Art.towerIcon(combo.second), scale: 2) }
            }
            .frame(width: 68, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(found ? combo.name.uppercased() : "???")
                    .font(Theme.body(12))
                    .foregroundStyle(found ? Theme.highlight : Theme.secondaryText)
                Text("\(combo.first.name.uppercased()) + \(found ? combo.second.name.uppercased() : "???")")
                    .font(Theme.body(9))
                    .foregroundStyle(Theme.secondaryText)
                if found {
                    Text(combo.detail)
                        .font(Theme.body(10, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .pixelPanel()
        .accessibilityElement(children: .combine)
    }
}
