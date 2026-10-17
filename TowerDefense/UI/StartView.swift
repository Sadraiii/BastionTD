import SwiftUI

/// Title screen with the map picker.
struct StartView: View {
    let onPlay: (MapDefinition) -> Void
    let onHowToPlay: () -> Void
    let onResearch: () -> Void
    let onMedals: () -> Void

    @State private var showMaps = false
    @State private var researchPoints = 0
    @AppStorage(StorageKey.soundEnabled) private var soundOn = true

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                PixelBackdrop()
                if showMaps {
                    MapSelectView(landscape: landscape, onSelect: onPlay) {
                        playTap()
                        withAnimation(.easeOut(duration: 0.15)) { showMaps = false }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    title(landscape: landscape)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func title(landscape: Bool) -> some View {
        VStack(spacing: landscape ? 14 : 24) {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                PixelText("BASTION TD", pixel: 6, color: Theme.highlight)
                PixelText("PIXEL TOWER DEFENSE", pixel: 2, color: Theme.text)
            }
            HStack(spacing: 10) {
                ForEach(TowerKind.allCases) { kind in
                    PixelImage(image: Art.towerIcon(kind, tiers: [UpgradeRules.maxTier, 2]), scale: 3)
                }
            }
            .padding(.vertical, landscape ? 0 : 8)

            VStack(spacing: 12) {
                Button {
                    playTap()
                    withAnimation(.easeOut(duration: 0.15)) { showMaps = true }
                } label: {
                    PixelText("PLAY", pixel: 3).frame(width: 236)
                }
                .buttonStyle(PixelButtonStyle.primary)

                HStack(spacing: 12) {
                    Button {
                        playTap()
                        onResearch()
                    } label: {
                        HStack(spacing: 6) {
                            PixelIcon(icon: .flask, scale: 2)
                            PixelText("LAB", pixel: 2, shadow: nil)
                            if researchPoints > 0 {
                                PixelText("\(researchPoints)", pixel: 1, color: Theme.border, shadow: nil)
                                    .padding(3)
                                    .background(Color(pixel: Pal.cyan))
                            }
                        }
                        .frame(width: 100)
                    }
                    .buttonStyle(PixelButtonStyle.blue)
                    .accessibilityLabel("Research Lab, \(researchPoints) points")

                    Button {
                        playTap()
                        onMedals()
                    } label: {
                        HStack(spacing: 6) {
                            PixelIcon(icon: .medal, scale: 1)
                            PixelText("MEDALS", pixel: 2, shadow: nil)
                        }
                        .frame(width: 100)
                    }
                    .buttonStyle(PixelButtonStyle.neutral)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .onAppear { researchPoints = PlayerProgress.researchPoints }
        .overlay(alignment: .topLeading) {
            Button {
                playTap()
                onHowToPlay()
            } label: {
                PixelIcon(icon: .question, scale: 3, outlined: false)
                    .frame(width: 44, height: 40)
            }
            .buttonStyle(PixelButtonStyle(color: Theme.panel, highlight: Theme.panelLight, shade: Theme.border, minHeight: 40))
            .accessibilityLabel("How to play")
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                soundOn.toggle()
                playTap()
            } label: {
                PixelIcon(icon: soundOn ? .speaker : .speakerOff, scale: 3, outlined: false)
                    .frame(width: 44, height: 40)
            }
            .buttonStyle(PixelButtonStyle(color: Theme.panel, highlight: Theme.panelLight, shade: Theme.border, minHeight: 40))
            .accessibilityLabel(soundOn ? "Sound on" : "Sound off")
            .padding(12)
        }
    }
}

/// Animated pixel backdrop: the battlefield ground with a parade of enemies.
struct PixelBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 15)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let board = Art.boardImage(for: .circuit)
                    let scale = max(1, ceil(max(size.width / board.size.width, size.height / board.size.height)))
                    let boardSize = CGSize(width: board.size.width * scale, height: board.size.height * scale)
                    let image = context.resolve(Image(uiImage: board).interpolation(.none))
                    context.draw(image, in: CGRect(
                        x: ((size.width - boardSize.width) / 2).rounded(),
                        y: ((size.height - boardSize.height) / 2).rounded(),
                        width: boardSize.width, height: boardSize.height
                    ))
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(pixel: Pal.ink).opacity(0.62)))

                    // Enemy parade along the bottom.
                    let kinds: [EnemyKind] = [.drone, .runner, .medic, .brute, .wisp, .splitter, .drone, .titan]
                    let spacing: CGFloat = 64
                    let loop = CGFloat(kinds.count) * spacing + size.width
                    let offset = CGFloat(time * 28).truncatingRemainder(dividingBy: loop)
                    let frame = Int(time * 5) % 2
                    for (i, kind) in kinds.enumerated() {
                        let icon = Art.enemyIcon(kind, frame: frame)
                        let x = (offset - CGFloat(i) * spacing).truncatingRemainder(dividingBy: loop) - spacing
                        let w = icon.size.width * 3, h = icon.size.height * 3
                        let resolved = context.resolve(Image(uiImage: icon).interpolation(.none))
                        context.draw(resolved, in: CGRect(x: x.rounded(), y: size.height - 30 - h, width: w, height: h))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Map picker cards with a pixel preview of each battlefield.
struct MapSelectView: View {
    let landscape: Bool
    let onSelect: (MapDefinition) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: landscape ? 10 : 16) {
            HStack {
                Button(action: onBack) {
                    PixelText("< BACK", pixel: 2)
                }
                .buttonStyle(PixelButtonStyle.neutral)
                Spacer()
                PixelText("SELECT MAP", pixel: 3, color: Theme.highlight)
                Spacer()
                Color.clear.frame(width: 90, height: 1)
            }
            .padding(.horizontal, 16)

            ScrollView(landscape ? .horizontal : .vertical, showsIndicators: false) {
                let cards = ForEach(MapDefinition.all) { map in
                    MapCard(map: map) {
                        playTap()
                        onSelect(map)
                    }
                }
                if landscape {
                    HStack(spacing: 14) { cards }.padding(16)
                } else {
                    VStack(spacing: 16) { cards }.padding(16)
                }
            }
        }
        .padding(.top, 8)
    }
}

struct MapCard: View {
    let map: MapDefinition
    let action: () -> Void

    private var unlocked: Bool { PlayerProgress.isUnlocked(map) }

    var body: some View {
        Button(action: unlocked ? action : { SoundEngine.shared.play(.error) }) {
            VStack(alignment: .leading, spacing: 8) {
                PixelImage(image: Art.mapPreview(for: map), scale: 1)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 2))
                    .overlay(alignment: .topTrailing) {
                        DifficultyTag(difficulty: map.difficulty).padding(6)
                    }
                    .overlay {
                        if !unlocked {
                            ZStack {
                                Color(pixel: Pal.ink).opacity(0.7)
                                VStack(spacing: 6) {
                                    PixelIcon(icon: .lock, scale: 3)
                                    Text(lockMessage)
                                        .font(Theme.body(11))
                                        .foregroundStyle(Theme.text)
                                }
                            }
                        }
                    }
                PixelText(map.name.uppercased(), pixel: 3)
                Text(map.tagline)
                    .font(Theme.body(11, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 224, alignment: .leading)
                HStack {
                    Text(PlayerProgress.bestEndlessWave(for: map) > 20
                         ? "BEST ENDLESS: WAVE \(PlayerProgress.bestEndlessWave(for: map))"
                         : "\(map.startingLives) LIVES · \(map.startingGold) GOLD")
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    StarRow(earned: PlayerProgress.bestStars(for: map), scale: 1)
                }
            }
            .padding(14)
            .frame(width: 252)
            .pixelPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlocked ? "\(map.name), \(map.difficulty.title)" : "\(map.name), locked. \(lockMessage)")
    }

    private var lockMessage: String {
        guard let index = MapDefinition.all.firstIndex(of: map), index > 0 else { return "" }
        return "BEAT \(MapDefinition.all[index - 1].name.uppercased()) TO UNLOCK"
    }
}

struct DifficultyTag: View {
    let difficulty: Difficulty

    var body: some View {
        let color: PixelColor = switch difficulty {
        case .easy: Pal.lime
        case .normal: Pal.amber
        case .hard: Pal.red
        }
        PixelText(difficulty.title.uppercased(), pixel: 2, color: Theme.border, shadow: nil)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(pixel: color))
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 2))
    }
}
