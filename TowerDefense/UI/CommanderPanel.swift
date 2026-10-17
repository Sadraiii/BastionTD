import SwiftUI

/// The selected commander: level, XP and its three skills.
struct CommanderPanel: View {
    let session: GameSession
    let commander: CommanderSnapshot
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            header
            let layout = compact ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout(spacing: 6))
            layout {
                ForEach(commander.skills, id: \.index) { skill in
                    skillButton(skill)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            PixelImage(image: Art.commanderIcon(commander.kind), scale: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(commander.kind.name.uppercased()) · LEVEL \(commander.level)")
                    .font(Theme.body(12))
                    .foregroundStyle(Color(pixel: Pal.commander(commander.kind)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                GeometryReader { geo in
                    Rectangle().fill(Theme.panelLight)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color(pixel: Pal.yellow)).frame(width: geo.size.width * commander.xp)
                        }
                }
                .frame(height: 4)
                Text("TAP GRASS TO MOVE")
                    .font(Theme.body(9, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 0)
            Button(action: session.deselectCommander) {
                PixelIcon(icon: .close, scale: 2, outlined: false)
            }
            .buttonStyle(PixelButtonStyle(color: Theme.panel, highlight: Theme.panelLight, shade: Theme.border, minHeight: 32))
            .accessibilityLabel("Close commander panel")
        }
    }

    private func skillButton(_ skill: SkillSnapshot) -> some View {
        Button {
            session.useSkill(skill.index)
        } label: {
            VStack(spacing: 2) {
                Text(skill.name.uppercased())
                    .font(Theme.body(10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if skill.level == 0 {
                    PixelIcon(icon: .lock, scale: 1)
                } else if skill.isReady {
                    Text("LV \(skill.level)").font(Theme.body(9, weight: .regular))
                } else {
                    Text("\(skill.secondsLeft)S").font(Theme.body(9, weight: .regular))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(skill.isReady ? PixelButtonStyle(color: Color(pixel: Pal.amber), highlight: Color(pixel: Pal.yellow), shade: Color(pixel: Pal.rust), minHeight: 40)
                     : PixelButtonStyle(color: Theme.panelLight, highlight: Color(pixel: Pal.steel), shade: Theme.border, minHeight: 40))
        .overlay(alignment: .bottomLeading) {
            if skill.level > 0 && !skill.isReady {
                GeometryReader { geo in
                    Rectangle().fill(Color(pixel: Pal.amber))
                        .frame(width: geo.size.width * skill.charge, height: 3)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
                .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(skill.level == 0 ? "\(skill.name), locked" : "\(skill.name). \(skill.detail)")
    }
}

/// Opens the commander panel from the action bar; glows when a skill is ready.
struct CommanderChip: View {
    let commander: CommanderSnapshot
    let action: () -> Void

    var body: some View {
        let ready = commander.skills.contains(where: \.isReady)
        Button(action: action) {
            PixelImage(image: Art.commanderIcon(commander.kind), scale: 2)
                .overlay(alignment: .bottomTrailing) {
                    PixelText("\(commander.level)", pixel: 1, color: Theme.gold).offset(x: 3, y: 3)
                }
                .padding(4)
                .pixelPanel(
                    fill: ready ? Color(pixel: Pal.rust) : Theme.panel,
                    bevel: ready ? Color(pixel: Pal.amber) : Theme.panelLight,
                    shadow: ready
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(commander.kind.name), level \(commander.level)")
    }
}
