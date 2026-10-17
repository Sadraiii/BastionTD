import SwiftUI

/// Between-match progression: spend Research Points to unlock upgrade tiers.
struct ResearchLabView: View {
    let onBack: () -> Void

    @State private var points = PlayerProgress.researchPoints
    @State private var research = PlayerProgress.research
    @State private var commander = PlayerProgress.commander
    @State private var skin = PlayerProgress.commanderSkin(PlayerProgress.commander.selected)
    @State private var selection: Selection?
    @State private var celebrate: Medal?

    struct Selection: Equatable {
        let kind: TowerKind
        let path: Int
        let tier: Int
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    CommanderResearchCard(progress: commander, skin: skin, points: points, onSelect: selectCommander,
                                          onSkin: selectSkin, onUpgrade: upgradeSkill)
                    PerksCard(research: research, points: points, onBuy: buyPerk)
                    ForEach(TowerKind.allCases) { kind in
                        HeroResearchCard(kind: kind, research: research, points: points, selection: $selection) {
                            recruit(kind)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            detailPanel
        }
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
        .overlay {
            if let celebrate {
                MedalToast(medal: celebrate)
                    .transition(.scale.combined(with: .opacity))
                    .onTapGesture { self.celebrate = nil }
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                playTap()
                onBack()
            } label: {
                PixelText("< BACK", pixel: 2, shadow: nil)
            }
            .buttonStyle(PixelButtonStyle.neutral)
            Spacer()
            PixelText("RESEARCH LAB", pixel: 3, color: Theme.highlight)
            Spacer()
            HStack(spacing: 6) {
                PixelIcon(icon: .flask, scale: 2)
                PixelText("\(points)", pixel: 2, color: Color(pixel: Pal.cyan))
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 40)
            .pixelPanel(shadow: false)
            .accessibilityElement()
            .accessibilityLabel("\(points) research points")
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var detailPanel: some View {
        Group {
            if let selection {
                let tier = selection.kind.paths[selection.path].tiers[selection.tier - 1]
                let unlocked = research.isUnlocked(selection.kind, path: selection.path, tier: selection.tier)
                let isNext = research.nextResearchable(selection.kind, path: selection.path) == selection.tier
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if tier.power != nil { PixelIcon(icon: .bolt, scale: 2) }
                            Text("\(selection.kind.name.uppercased()) · TIER \(selection.tier): \(tier.name.uppercased())")
                                .font(Theme.body(12))
                                .foregroundStyle(Theme.tower(selection.kind))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Text(tier.power.map { "\($0.name.uppercased()) - \($0.detail)" } ?? tier.detail)
                            .font(Theme.body(11, weight: .regular))
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("IN-MATCH PRICE: \(tier.cost) GOLD")
                            .font(Theme.body(10, weight: .regular))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if unlocked {
                        PixelText("UNLOCKED", pixel: 2, color: Theme.accent)
                    } else if isNext {
                        Button {
                            research(selection)
                        } label: {
                            HStack(spacing: 6) {
                                PixelIcon(icon: .flask, scale: 2, outlined: false)
                                PixelText("\(tier.research)", pixel: 2, shadow: nil)
                            }
                        }
                        .buttonStyle(points >= tier.research ? PixelButtonStyle.blue : PixelButtonStyle.neutral)
                        .accessibilityLabel("Research for \(tier.research) points")
                    } else {
                        Text("RESEARCH TIER \(selection.tier - 1) FIRST")
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                }
            } else {
                Text("Win matches to earn research points. Tap a tier to see what it does.")
                    .font(Theme.body(11, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78)
        .pixelPanel()
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func recruit(_ kind: TowerKind) {
        guard PlayerProgress.unlockHero(kind) else {
            SoundEngine.shared.play(.error)
            Haptics.notify(.warning)
            return
        }
        SoundEngine.shared.play(.medal)
        Haptics.notify(.success)
        let medals = PlayerProgress.awardMedals(for: nil)
        research = PlayerProgress.research
        points = PlayerProgress.researchPoints
        if let medal = medals.first {
            withAnimation(.spring(duration: 0.3)) { celebrate = medal }
        }
    }

    private func selectCommander(_ kind: CommanderKind) {
        playTap()
        commander.selected = kind
        PlayerProgress.commander = commander
        skin = PlayerProgress.commanderSkin(kind)
    }

    private func selectSkin(_ choice: CommanderSkin) {
        guard PlayerProgress.earnedMedals.count >= choice.medalsNeeded else {
            SoundEngine.shared.play(.error)
            return
        }
        playTap()
        PlayerProgress.setCommanderSkin(choice, for: commander.selected)
        skin = choice
    }

    private func buyPerk(_ perk: Perk) {
        guard PlayerProgress.buyPerk(perk) else {
            SoundEngine.shared.play(.error)
            Haptics.notify(.warning)
            return
        }
        SoundEngine.shared.play(.research)
        Haptics.notify(.success)
        research = PlayerProgress.research
        points = PlayerProgress.researchPoints
    }

    private func upgradeSkill(_ kind: CommanderKind, _ skill: Int) {
        guard PlayerProgress.upgradeSkill(kind, skill: skill) else {
            SoundEngine.shared.play(.error)
            Haptics.notify(.warning)
            return
        }
        SoundEngine.shared.play(.research)
        Haptics.notify(.success)
        commander = PlayerProgress.commander
        points = PlayerProgress.researchPoints
    }

    private func research(_ selection: Selection) {
        guard PlayerProgress.research(selection.kind, path: selection.path) else {
            SoundEngine.shared.play(.error)
            Haptics.notify(.warning)
            return
        }
        SoundEngine.shared.play(.research)
        Haptics.notify(.success)
        let medals = PlayerProgress.awardMedals(for: nil)
        research = PlayerProgress.research
        points = PlayerProgress.researchPoints
        if let medal = medals.first {
            SoundEngine.shared.play(.medal)
            withAnimation(.spring(duration: 0.3)) { celebrate = medal }
        }
    }
}

/// Permanent bonuses for every match.
private struct PerksCard: View {
    let research: ResearchState
    let points: Int
    let onBuy: (Perk) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelText("PERKS", pixel: 2, color: Theme.highlight)
            ForEach(Perk.allCases) { perk in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(perk.title.uppercased())
                            .font(Theme.body(11))
                            .foregroundStyle(research.has(perk) ? Theme.accent : Theme.text)
                        Text(perk.detail)
                            .font(Theme.body(10, weight: .regular))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer(minLength: 0)
                    if research.has(perk) {
                        PixelText("OWNED", pixel: 1, color: Theme.accent)
                    } else {
                        Button {
                            onBuy(perk)
                        } label: {
                            HStack(spacing: 4) {
                                PixelIcon(icon: .flask, scale: 1)
                                PixelText("\(perk.cost)", pixel: 1, shadow: nil)
                            }
                        }
                        .buttonStyle(points >= perk.cost ? PixelButtonStyle.blue : PixelButtonStyle.neutral)
                        .accessibilityLabel("Buy \(perk.title) for \(perk.cost) points")
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }
}

/// Pick the commander for your matches and research its skills.
private struct CommanderResearchCard: View {
    let progress: CommanderProgress
    let skin: CommanderSkin
    let points: Int
    let onSelect: (CommanderKind) -> Void
    let onSkin: (CommanderSkin) -> Void
    let onUpgrade: (CommanderKind, Int) -> Void

    var body: some View {
        let kind = progress.selected
        let levels = progress.skillLevels(kind)
        VStack(alignment: .leading, spacing: 8) {
            PixelText("COMMANDER", pixel: 2, color: Theme.highlight)
            HStack(spacing: 8) {
                ForEach(CommanderKind.allCases) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        VStack(spacing: 2) {
                            PixelImage(image: Art.commanderIcon(option, skin: option == kind ? skin : .classic), scale: 2)
                            Text(option.name.uppercased()).font(Theme.body(10))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(option == kind ? PixelButtonStyle.gold
                                 : PixelButtonStyle(color: Theme.panel, highlight: Theme.panelLight, shade: Theme.border, minHeight: 44))
                    .accessibilityLabel("\(option.name)\(option == kind ? ", selected" : "")")
                }
            }
            let medals = PlayerProgress.earnedMedals.count
            HStack(spacing: 6) {
                ForEach(CommanderSkin.allCases, id: \.self) { option in
                    let unlocked = medals >= option.medalsNeeded
                    Button {
                        onSkin(option)
                    } label: {
                        VStack(spacing: 2) {
                            PixelImage(image: Art.commanderIcon(kind, skin: option), scale: 1)
                                .opacity(unlocked ? 1 : 0.35)
                            Text(unlocked ? option.name.uppercased() : "\(option.medalsNeeded) MEDALS")
                                .font(Theme.body(8))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(option == skin ? PixelButtonStyle.gold
                                 : PixelButtonStyle(color: Theme.panel, highlight: Theme.panelLight, shade: Theme.border, minHeight: 36))
                    .accessibilityLabel(unlocked ? "\(option.name) skin" : "\(option.name) skin, needs \(option.medalsNeeded) medals")
                }
            }
            let xp = PlayerProgress.commanderXP(kind)
            let rank = CommanderKind.rank(forXP: xp)
            Text(rank < CommanderKind.maxRank
                 ? "RANK \(rank) · \(xp)/\(CommanderKind.xpForRank(rank + 1)) XP · +\(rank * 2)% POWER"
                 : "RANK \(rank) (MAX) · +\(rank * 2)% POWER")
                .font(Theme.body(10))
                .foregroundStyle(Color(pixel: Pal.commander(kind)))
            Text(kind.role + " Levels up from kills during a match, and its XP adds to its rank.")
                .font(Theme.body(11, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(kind.skills.prefix(CommanderKind.researchableSkills).enumerated()), id: \.offset) { index, skill in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(skill.name.uppercased())  LV \(levels[index])/\(CommanderSkill.maxLevel)")
                            .font(Theme.body(11))
                            .foregroundStyle(levels[index] > 0 ? Theme.text : Theme.secondaryText)
                        Text(skill.detail)
                            .font(Theme.body(10, weight: .regular))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if levels[index] < CommanderSkill.maxLevel {
                        let cost = CommanderSkill.cost(level: levels[index] + 1)
                        Button {
                            onUpgrade(kind, index)
                        } label: {
                            HStack(spacing: 4) {
                                PixelIcon(icon: .flask, scale: 1)
                                PixelText("\(cost)", pixel: 1, shadow: nil)
                            }
                        }
                        .buttonStyle(points >= cost ? PixelButtonStyle.blue : PixelButtonStyle.neutral)
                        .accessibilityLabel("\(levels[index] == 0 ? "Unlock" : "Upgrade") \(skill.name) for \(cost) points")
                    } else {
                        PixelText("MAX", pixel: 1, color: Theme.highlight)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }
}

/// A hero with both upgrade paths shown as rows of tier nodes.
private struct HeroResearchCard: View {
    let kind: TowerKind
    let research: ResearchState
    let points: Int
    @Binding var selection: ResearchLabView.Selection?
    let onRecruit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PixelImage(image: Art.towerIcon(kind, tiers: [UpgradeRules.maxTier, 2]), scale: 3)
                    .opacity(research.isHeroUnlocked(kind) ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 3) {
                    PixelText(kind.name.uppercased(), pixel: 2, color: Theme.tower(kind))
                    Text("\(kind.archetype.uppercased()) · \(kind.baseStats.damageType.title.uppercased()) · \(kind.role)")
                        .font(Theme.body(10, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if !research.isHeroUnlocked(kind) {
                    Button(action: onRecruit) {
                        VStack(spacing: 3) {
                            PixelText("RECRUIT", pixel: 1, shadow: nil)
                            HStack(spacing: 3) {
                                PixelIcon(icon: .flask, scale: 1, outlined: false)
                                PixelText("\(kind.unlockCost)", pixel: 2, shadow: nil)
                            }
                        }
                    }
                    .buttonStyle(points >= kind.unlockCost ? PixelButtonStyle.blue : PixelButtonStyle.neutral)
                    .accessibilityLabel("Recruit \(kind.name) for \(kind.unlockCost) research points")
                }
            }
            ForEach(Array(kind.paths.enumerated()), id: \.offset) { index, path in
                HStack(spacing: 8) {
                    Text(path.name.uppercased())
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.text)
                        .frame(width: 80, alignment: .leading)
                    ForEach(1...UpgradeRules.maxTier, id: \.self) { tier in
                        node(path: index, tier: tier, upgrade: path.tiers[tier - 1])
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity)
        .pixelPanel()
    }

    private func node(path: Int, tier: Int, upgrade: UpgradeTier) -> some View {
        let unlocked = research.isUnlocked(kind, path: path, tier: tier)
        let isNext = research.nextResearchable(kind, path: path) == tier
        let isSelected = selection == ResearchLabView.Selection(kind: kind, path: path, tier: tier)
        let accent = path == 0 ? Pal.amber : Pal.cyan
        return Button {
            playTap()
            selection = ResearchLabView.Selection(kind: kind, path: path, tier: tier)
        } label: {
            VStack(spacing: 2) {
                if unlocked {
                    PixelText("\(tier)", pixel: 2, color: Theme.border, shadow: nil)
                } else if isNext {
                    PixelText("\(upgrade.research)", pixel: 2, color: Color(pixel: Pal.cyan), shadow: nil)
                } else {
                    PixelIcon(icon: .lock, scale: 1)
                }
                if upgrade.power != nil { PixelIcon(icon: .bolt, scale: 1) }
            }
            .frame(width: 44, height: 44)
            .background(unlocked ? Color(pixel: accent) : Color(pixel: Pal.ink))
            .overlay(Rectangle().strokeBorder(isSelected ? Theme.text : (isNext ? Color(pixel: Pal.yellow) : Theme.panelLight), lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.name) \(kind.paths[path].name) tier \(tier), \(upgrade.name). " +
                            (unlocked ? "Unlocked" : isNext ? "Research for \(upgrade.research) points" : "Locked"))
    }
}

/// Pop-up shown when a medal is earned.
struct MedalToast: View {
    let medal: Medal

    var body: some View {
        VStack(spacing: 8) {
            PixelIcon(icon: .medal, scale: 4)
            PixelText("MEDAL EARNED!", pixel: 3, color: Theme.highlight)
            PixelText(medal.title.uppercased(), pixel: 2)
            Text(medal.detail)
                .font(Theme.body(11, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
            HStack(spacing: 6) {
                PixelIcon(icon: .flask, scale: 2)
                PixelText("+\(medal.reward)", pixel: 2, color: Color(pixel: Pal.cyan))
            }
        }
        .padding(20)
        .pixelPanel()
        .accessibilityElement(children: .combine)
    }
}
