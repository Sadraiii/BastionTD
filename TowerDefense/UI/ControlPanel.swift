import SwiftUI

/// The panel beside (landscape) or below (portrait) the battlefield. It shows
/// either the build options or the selected tower's details.
struct ControlPanel: View {
    let session: GameSession
    let landscape: Bool

    var body: some View {
        Group {
            if landscape {
                VStack(spacing: 10) {
                    SideStats(session: session)
                    if let tower = session.selectedTower {
                        TowerInfoPanel(session: session, tower: tower, compact: false)
                        Spacer(minLength: 0)
                    } else {
                        BuildGrid(session: session)
                        Spacer(minLength: 0)
                        ActionBar(session: session)
                    }
                }
                .padding(10)
            } else {
                VStack(spacing: 8) {
                    if let tower = session.selectedTower {
                        TowerInfoPanel(session: session, tower: tower, compact: true)
                    } else {
                        ActionBar(session: session)
                        BuildRow(session: session)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            Color(pixel: Pal.navy)
                .overlay(alignment: landscape ? .leading : .top) {
                    Rectangle().fill(Theme.border)
                        .frame(width: landscape ? 3 : nil, height: landscape ? nil : 3)
                }
                .ignoresSafeArea()
        }
    }
}

/// A hero button in the build panel. Locked heroes show their Research cost.
struct TowerCard: View {
    let kind: TowerKind
    let selected: Bool
    let affordable: Bool
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                PixelImage(image: Art.towerIcon(kind), scale: 2)
                    .opacity(unlocked ? 1 : 0.35)
                    .overlay {
                        if !unlocked { PixelIcon(icon: .lock, scale: 2) }
                    }
                Text(kind.shortName.uppercased())
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if unlocked {
                    GoldLabel(amount: kind.cost, pixel: 1, color: affordable ? Theme.gold : Theme.danger)
                } else {
                    HStack(spacing: 2) {
                        PixelIcon(icon: .flask, scale: 1)
                        PixelText("\(kind.unlockCost)", pixel: 1, color: Color(pixel: Pal.cyan))
                    }
                }
            }
            .frame(minWidth: 56, maxWidth: .infinity, minHeight: 70)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .pixelPanel(
                fill: selected ? Color(pixel: Pal.ocean) : Theme.panel,
                bevel: selected ? Color(pixel: Pal.cyan) : Theme.panelLight,
                shadow: !selected
            )
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(pixel: Pal.damage(kind.baseStats.damageType)))
                    .frame(width: 6, height: 6)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                    .padding(6)
            }
            .offset(y: selected ? 3 : 0)
            .opacity(!unlocked || affordable || selected ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlocked
            ? "\(kind.name), \(kind.cost) gold, \(kind.baseStats.damageType.title) damage. \(kind.role)"
            : "\(kind.name), locked. Recruit for \(kind.unlockCost) research points in the Research Lab")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct BuildRow: View {
    let session: GameSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TowerKind.allCases) { kind in
                    card(kind).frame(width: 68)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }

    private func card(_ kind: TowerKind) -> some View {
        TowerCard(kind: kind, selected: session.buildKind == kind, affordable: session.gold >= kind.cost,
                  unlocked: session.isHeroUnlocked(kind)) {
            session.chooseBuild(kind)
        }
    }
}

struct BuildGrid: View {
    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(TowerKind.allCases) { kind in
                        TowerCard(kind: kind, selected: session.buildKind == kind, affordable: session.gold >= kind.cost,
                                  unlocked: session.isHeroUnlocked(kind)) {
                            session.chooseBuild(kind)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            if let kind = session.buildKind {
                Text("\(kind.baseStats.damageType.title.uppercased()) · \(kind.role)")
                    .font(Theme.body(10, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Context action: confirm a placement, start the next wave, or show wave status.
/// Hero powers that are unlocked appear here as quick-cast buttons.
struct ActionBar: View {
    let session: GameSession

    var body: some View {
        Group {
            if let kind = session.buildKind {
                placementControls(kind)
            } else {
                HStack(spacing: 6) {
                    ForEach(session.powers.prefix(4)) { item in
                        PowerChip(item: item) { session.activatePower(towerID: item.id) }
                    }
                    waveControl
                }
            }
        }
    }

    @ViewBuilder
    private var waveControl: some View {
        if session.canStartWave {
            Button(action: session.startWave) {
                HStack(spacing: 6) {
                    PixelIcon(icon: .play, scale: 2, outlined: false)
                    if session.phase == .preparing {
                        PixelText(session.powers.isEmpty ? "START WAVE" : "START", pixel: 2, shadow: nil)
                    } else {
                        PixelText("NEXT \(session.intermissionSeconds)S", pixel: 2, shadow: nil)
                        if session.earlyBonus > 0 {
                            GoldLabel(amount: session.earlyBonus, pixel: 1, color: Theme.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelButtonStyle.primary)
            .accessibilityLabel(session.phase == .preparing ? "Start wave" : "Call next wave early for \(session.earlyBonus) bonus gold")
        } else {
            HStack(spacing: 6) {
                PixelIcon(icon: .skull, scale: 2)
                Text("\(session.enemiesRemaining) LEFT")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    @ViewBuilder
    private func placementControls(_ kind: TowerKind) -> some View {
        HStack(spacing: 8) {
            Button(action: session.cancelBuild) {
                PixelIcon(icon: .close, scale: 2, outlined: false)
            }
            .buttonStyle(PixelButtonStyle.danger)
            .accessibilityLabel("Cancel building")

            if let result = session.pendingResult, session.pendingCell != nil {
                if result == .ok {
                    Button(action: session.confirmBuild) {
                        HStack(spacing: 6) {
                            PixelIcon(icon: .check, scale: 2, outlined: false)
                            PixelText("BUILD", pixel: 2, shadow: nil)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle.primary)
                } else {
                    Text(result.message.uppercased())
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else {
                Text("TAP A TILE TO PLACE \(kind.shortName.uppercased())")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
}

/// Quick-cast button for one hero's power, with a charge meter.
struct PowerChip: View {
    let item: PowerBarItem
    let action: () -> Void
    @State private var blink = false

    var body: some View {
        Button(action: action) {
            PixelImage(image: Art.towerIcon(item.kind), scale: 2)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(pixel: Pal.ink).opacity(0.65))
                        .frame(height: 32 * (1 - item.charge))
                }
                .overlay(alignment: .topTrailing) {
                    if item.isReady { PixelIcon(icon: .bolt, scale: 1).offset(x: 3, y: -3) }
                }
                .padding(4)
                .pixelPanel(
                    fill: item.isReady ? Color(pixel: Pal.rust) : Theme.panel,
                    bevel: item.isReady ? Color(pixel: blink ? Pal.yellow : Pal.amber) : Theme.panelLight,
                    shadow: item.isReady
                )
        }
        .buttonStyle(.plain)
        .onAppear { blink = true }
        .animation(item.isReady ? .easeInOut(duration: 0.4).repeatForever() : .default, value: blink)
        .accessibilityLabel(item.isReady ? "Activate \(item.name)" : "\(item.name) recharging")
    }
}
