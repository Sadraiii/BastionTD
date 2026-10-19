import SwiftUI

/// The selected hero: two upgrade paths, its power, targeting and selling.
struct TowerInfoPanel: View {
    let session: GameSession
    let tower: TowerSnapshot
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            header
            if !compact {
                Text(statsLine)
                    .font(Theme.body(10, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(tower.paths, id: \.index) { path in
                PathRow(kind: tower.kind, path: path, compact: compact) {
                    session.upgradeSelected(path: path.index)
                }
            }
            if compact {
                HStack(spacing: 6) {
                    powerButton
                    targetingMenu
                }
            } else {
                powerButton
                HStack(spacing: 6) {
                    targetingMenu
                    sellButton
                }
            }
        }
    }

    private var statsLine: String {
        let s = tower.stats
        if s.income > 0 {
            var parts = ["+\(s.income) GOLD PER WAVE"]
            if s.buffDamage > 0 { parts.append("+\(Int(s.buffDamage * 100))% DMG NEARBY") }
            if s.buffRate > 0 { parts.append("+\(Int(s.buffRate * 100))% SPEED NEARBY") }
            return parts.joined(separator: " · ")
        }
        let reach = tower.kind.attackStyle == .cross ? "ROW + COLUMN" : "RNG \(format(s.range))"
        var parts = [s.damageType.title.uppercased(), "DMG \(format(s.damage))", reach, "\(format(s.shotsPerSecond))/S"]
        if s.detectsCamo { parts.append("SEES CLOAKED") }
        if !s.hitsAir { parts.append("GROUND ONLY") }
        return parts.joined(separator: " · ")
    }

    private var subtitle: String {
        if tower.isDisabled { return "EMP: OFFLINE!" }
        if let combo = tower.combos.first {
            return "COMBO: \(combo.uppercased())" + (tower.combos.count > 1 ? " +\(tower.combos.count - 1)" : "")
        }
        if tower.stats.growth > 0 {
            return "\(tower.stats.damageType.title.uppercased()) · GROWN +\(tower.growth)% · \(tower.kills) KO"
        }
        return "\(tower.stats.damageType.title.uppercased()) · \(tower.kind.archetype.uppercased()) · \(tower.kills) KO"
    }

    private var header: some View {
        HStack(spacing: 8) {
            PixelImage(image: Art.towerIcon(tower.kind, tiers: tower.tiers), scale: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(tower.kind.name.uppercased())
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.tower(tower.kind))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(Theme.body(9, weight: .regular))
                    .foregroundStyle(tower.isDisabled ? Theme.danger : tower.combos.isEmpty ? Theme.secondaryText : Theme.highlight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            if compact { sellButton }
            Button(action: session.deselectTower) {
                PixelIcon(icon: .close, scale: 2, outlined: false)
            }
            .buttonStyle(PixelButtonStyle(color: Theme.panel, highlight: Theme.panelLight, shade: Theme.border, minHeight: 32))
            .accessibilityLabel("Close hero panel")
        }
    }

    private var sellButton: some View {
        Button(action: session.sellSelected) {
            HStack(spacing: 4) {
                Text("SELL").font(Theme.body(10))
                GoldLabel(amount: tower.sellValue, pixel: 1, color: Theme.text)
            }
            .frame(maxWidth: compact ? nil : .infinity)
        }
        .buttonStyle(PixelButtonStyle(color: Color(pixel: Pal.amber), highlight: Color(pixel: Pal.yellow), shade: Color(pixel: Pal.rust), minHeight: 32))
        .accessibilityLabel("Sell for \(tower.sellValue) gold")
    }

    @ViewBuilder
    private var powerButton: some View {
        if let power = tower.power {
            Button {
                session.activatePower(towerID: tower.id)
            } label: {
                HStack(spacing: 6) {
                    PixelIcon(icon: .bolt, scale: 2)
                    Text(power.name.uppercased())
                        .font(Theme.body(10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !power.isReady {
                        Text("\(power.secondsLeft)S").font(Theme.body(10, weight: .regular))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(power.isReady ? PixelButtonStyle.gold : PixelButtonStyle(color: Theme.panelLight, highlight: Color(pixel: Pal.steel), shade: Theme.border, minHeight: 36))
            .overlay(alignment: .bottomLeading) {
                if !power.isReady {
                    GeometryReader { geo in
                        Rectangle().fill(Color(pixel: Pal.amber))
                            .frame(width: geo.size.width * power.charge, height: 3)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                    .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(power.isReady ? "Activate \(power.name). \(power.detail)" : "\(power.name) recharging, \(power.secondsLeft) seconds")
        } else {
            HStack(spacing: 6) {
                PixelIcon(icon: .bolt, scale: 1)
                Text("TIER 3 UNLOCKS A POWER")
                    .font(Theme.body(9))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(Color(pixel: Pal.ink).opacity(0.45))
        }
    }

    @ViewBuilder
    private var targetingMenu: some View {
        if tower.kind.usesTargeting {
            Menu {
                ForEach(TargetingMode.allCases) { mode in
                    Button {
                        session.setTargeting(mode)
                    } label: {
                        Label(mode.title, systemImage: mode == tower.targeting ? "checkmark" : mode.symbol)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    PixelIcon(icon: .target, scale: 2, outlined: false)
                    Text(tower.targeting.title.uppercased())
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: 36)
                .pixelPanel(fill: Theme.panelLight, bevel: Color(pixel: Pal.steel), shadow: false)
            }
            .accessibilityLabel("Targeting: \(tower.targeting.title)")
        } else {
            Text("AURA")
                .font(Theme.body(10))
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 10)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: 36)
                .pixelPanel(fill: Theme.panelLight, bevel: Color(pixel: Pal.steel), shadow: false)
        }
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

/// One upgrade path: name, tier pips and the button for the next tier.
private struct PathRow: View {
    let kind: TowerKind
    let path: PathSnapshot
    let compact: Bool
    let onUpgrade: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(path.name.uppercased())
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                TierPips(tier: path.tier, color: Color(pixel: path.index == 0 ? Pal.amber : Pal.cyan))
            }
            .frame(width: compact ? 82 : 66, alignment: .leading)

            Button(action: onUpgrade) {
                label
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(style)
            .disabled(path.status == .maxed || path.status == .blocked)
            .accessibilityLabel(accessibility)
        }
    }

    @ViewBuilder
    private var label: some View {
        switch path.status {
        case let .available(cost), let .unaffordable(cost):
            HStack(spacing: 5) {
                Text((path.nextName ?? "").uppercased())
                    .font(Theme.body(9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                GoldLabel(amount: cost, pixel: 1, color: path.status == .available(cost: cost) ? Theme.text : Color(pixel: Pal.pink))
            }
        case let .needsResearch(points):
            HStack(spacing: 5) {
                PixelIcon(icon: .lock, scale: 1)
                Text("RESEARCH \(points)").font(Theme.body(9)).lineLimit(1).minimumScaleFactor(0.7)
                PixelIcon(icon: .flask, scale: 1)
            }
            .foregroundStyle(Theme.secondaryText)
        case .blocked:
            Text("OTHER PATH CHOSEN").font(Theme.body(9)).foregroundStyle(Theme.secondaryText).lineLimit(1).minimumScaleFactor(0.6)
        case .maxed:
            Text("MAXED").font(Theme.body(10)).foregroundStyle(Theme.gold)
        }
    }

    private var style: PixelButtonStyle {
        if case .available = path.status {
            return PixelButtonStyle(color: Color(pixel: Pal.green), highlight: Color(pixel: Pal.lime), shade: Color(pixel: Pal.forest), minHeight: 36)
        }
        return PixelButtonStyle(color: Theme.panelLight, highlight: Color(pixel: Pal.steel), shade: Theme.border, minHeight: 36)
    }

    private var accessibility: String {
        let name = path.nextName ?? ""
        switch path.status {
        case let .available(cost): return "Upgrade \(path.name) to \(name) for \(cost) gold. \(path.nextDetail ?? "")"
        case let .unaffordable(cost): return "\(name) costs \(cost) gold"
        case let .needsResearch(points): return "\(name) needs \(points) research points in the Research Lab"
        case .blocked: return "\(path.name) is locked because the other path is past tier 2"
        case .maxed: return "\(path.name) fully upgraded"
        }
    }
}

/// Four little squares showing how far a path is upgraded.
struct TierPips: View {
    let tier: Int
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<UpgradeRules.maxTier, id: \.self) { index in
                Rectangle()
                    .fill(index < tier ? color : Theme.panelLight)
                    .frame(width: size, height: size)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            }
        }
        .accessibilityHidden(true)
    }
}
