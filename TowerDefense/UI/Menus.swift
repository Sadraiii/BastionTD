import SwiftUI

/// Dimmed full-screen backdrop for menus.
private struct MenuBackdrop<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color(pixel: Pal.ink).opacity(0.78)
                .ignoresSafeArea()
                .contentShape(Rectangle())
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .padding(20)
                    .frame(maxWidth: 380)
                    .pixelPanel()
                    .padding(16)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
    }
}

struct PauseMenuView: View {
    let boons: [Boon]
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHowToPlay: () -> Void
    let onQuit: () -> Void

    @AppStorage(StorageKey.soundEnabled) private var soundOn = true
    @AppStorage(StorageKey.hapticsEnabled) private var hapticsOn = true

    var body: some View {
        MenuBackdrop {
            VStack(spacing: 12) {
                PixelText("PAUSED", pixel: 4, color: Theme.highlight)
                    .padding(.bottom, 6)
                if !boons.isEmpty {
                    boonList
                }
                menuButton("RESUME", style: .primary, action: onResume)
                menuButton("RESTART", style: .neutral, action: onRestart)
                menuButton("HOW TO PLAY", style: .neutral, action: onHowToPlay)
                HStack(spacing: 10) {
                    Button {
                        soundOn.toggle()
                        playTap()
                    } label: {
                        HStack(spacing: 6) {
                            PixelIcon(icon: soundOn ? .speaker : .speakerOff, scale: 2, outlined: false)
                            PixelText(soundOn ? "ON" : "OFF", pixel: 2, shadow: nil)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle.blue)
                    .accessibilityLabel(soundOn ? "Sound on" : "Sound off")

                    Button {
                        hapticsOn.toggle()
                        playTap()
                    } label: {
                        PixelText(hapticsOn ? "BUZZ ON" : "BUZZ OFF", pixel: 2, shadow: nil)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle.blue)
                    .accessibilityLabel(hapticsOn ? "Haptics on" : "Haptics off")
                }
                menuButton("QUIT TO MENU", style: .danger, action: onQuit)
            }
        }
    }

    /// Each boon taken once, in the order first picked, with how many times it was taken.
    private var boonList: some View {
        let distinct = boons.reduce(into: [Boon]()) { list, boon in
            if !list.contains(boon) { list.append(boon) }
        }
        return VStack(spacing: 4) {
            PixelText("BOONS", pixel: 2, color: Theme.secondaryText)
            ForEach(distinct, id: \.title) { boon in
                HStack {
                    Text(boon.title.uppercased()).foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("X\(boons.filter { $0 == boon }.count)").foregroundStyle(Theme.text)
                }
                .font(Theme.body(12))
            }
        }
        .padding(10)
        .background(Color(pixel: Pal.ink).opacity(0.5))
    }

    private func menuButton(_ title: String, style: PixelButtonStyle, action: @escaping () -> Void) -> some View {
        Button {
            playTap()
            action()
        } label: {
            PixelText(title, pixel: 2, shadow: nil).frame(maxWidth: .infinity)
        }
        .buttonStyle(style)
    }
}

struct GameOverView: View {
    let outcome: GameOutcome
    let session: GameSession
    let onRestart: () -> Void
    let nextMap: MapDefinition?
    let onNextMap: (MapDefinition) -> Void
    let onQuit: () -> Void
    let onResearch: () -> Void

    var body: some View {
        MenuBackdrop {
            VStack(spacing: 12) {
                switch outcome {
                case let .victory(stars):
                    PixelText("VICTORY!", pixel: 5, color: Theme.highlight)
                    StarRow(earned: stars, scale: 4)
                    Text("THE BASTION STANDS.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.secondaryText)
                case .defeat:
                    if session.isEndless {
                        PixelText("ENDLESS OVER", pixel: 4, color: Theme.highlight)
                        Text("YOU HELD OUT UNTIL WAVE \(session.waveNumber).")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        PixelText("DEFEAT", pixel: 5, color: Theme.danger)
                        PixelImage(image: Art.coreImage, scale: 3)
                            .colorMultiply(Color(pixel: Pal.red))
                        Text("THE CRYSTAL FELL ON WAVE \(session.waveNumber) OF \(session.totalWaves).")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }

                rewardsBlock

                VStack(spacing: 4) {
                    statRow("VILLAINS DEFEATED", "\(session.stats.enemiesDefeated)")
                    statRow("POWERS USED", "\(session.stats.powersUsed)")
                    statRow("GOLD EARNED", "\(session.stats.goldEarned)")
                    statRow("LIVES LEFT", "\(session.lives)/\(session.engine.startingLives)")
                }
                .padding(10)
                .background(Color(pixel: Pal.ink).opacity(0.5))

                if case .victory = outcome {
                    // Lone Commander is a short mode, and most Endless boons only help heroes.
                    if !session.isLone {
                        button("ENDLESS MODE", style: .gold, action: session.continueEndless)
                    }
                    // The Highlands open by stars, so beating Deep Core may not open the next map.
                    if let next = nextMap, PlayerProgress.isUnlocked(next) {
                        button("NEXT MAP", style: .primary) { onNextMap(next) }
                    }
                } else {
                    button("TRY AGAIN", style: .primary, action: onRestart)
                }
                HStack(spacing: 10) {
                    button("LAB", style: .blue, action: onResearch)
                    button("MENU", style: .neutral, action: onQuit)
                }
            }
        }
    }

    @ViewBuilder
    private var rewardsBlock: some View {
        let rewards = session.rewards
        if rewards.researchPoints > 0 || !rewards.medals.isEmpty || !rewards.stars.isEmpty {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    PixelIcon(icon: .flask, scale: 2)
                    PixelText("+\(rewards.researchPoints) RESEARCH", pixel: 2, color: Color(pixel: Pal.cyan))
                }
                ForEach(rewards.medals) { medal in
                    HStack(spacing: 6) {
                        PixelIcon(icon: .medal, scale: 1)
                        Text("MEDAL: \(medal.title.uppercased())")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.highlight)
                    }
                }
                ForEach(rewards.stars, id: \.self) { line in
                    HStack(spacing: 6) {
                        PixelIcon(icon: .star, scale: 1)
                        Text(line)
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.gold)
                    }
                }
                ForEach(rewards.badges, id: \.self) { line in
                    HStack(spacing: 6) {
                        PixelIcon(icon: .skull, scale: 1)
                        Text(line)
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.text)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(pixel: Pal.ocean).opacity(0.35))
            .accessibilityElement(children: .combine)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value).foregroundStyle(Theme.text)
        }
        .font(Theme.body(12))
    }

    private func button(_ title: String, style: PixelButtonStyle, action: @escaping () -> Void) -> some View {
        Button {
            playTap()
            action()
        } label: {
            PixelText(title, pixel: 2, shadow: nil).frame(maxWidth: .infinity)
        }
        .buttonStyle(style)
    }
}
