import SwiftUI

/// Lives with a heart that jolts whenever the crystal is hit.
struct LivesLabel: View {
    let lives: Int
    let pulse: Int
    var pixel: CGFloat = 2
    @State private var jolt = false

    var body: some View {
        HStack(spacing: pixel * 2) {
            PixelIcon(icon: .heart, scale: pixel)
                .offset(y: jolt ? -pixel * 2 : 0)
            PixelText("\(lives)", pixel: pixel, color: jolt ? Theme.danger : Theme.text)
        }
        .onChange(of: pulse) {
            jolt = true
            Task {
                try? await Task.sleep(for: .milliseconds(160))
                jolt = false
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(lives) lives")
    }
}

/// Stepped progress bar, filled in whole segments.
struct PixelProgressBar: View {
    let progress: Double
    var segments = 20
    var color: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            let filled = Int((progress * Double(segments)).rounded(.down))
            let width = (geo.size.width - 4) / CGFloat(segments)
            HStack(spacing: 0) {
                ForEach(0..<segments, id: \.self) { i in
                    Rectangle()
                        .fill(i < filled ? color : Theme.panelLight)
                        .frame(width: width)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(Theme.border.opacity(0.5)).frame(width: 1)
                        }
                }
            }
            .padding(2)
            .background(Theme.border)
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel("Wave progress \(Int(progress * 100)) percent")
    }
}

struct WaveLabel: View {
    let session: GameSession
    var pixel: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: pixel * 2) {
                PixelIcon(icon: .skull, scale: pixel)
                PixelText(session.isEndless ? "ENDLESS \(session.waveNumber)" : "WAVE \(max(1, session.waveNumber))/\(session.totalWaves)", pixel: pixel)
            }
            PixelProgressBar(progress: session.phase == .waveActive ? session.waveProgress : (session.waveNumber == 0 ? 0 : 1))
        }
        .accessibilityElement(children: .combine)
    }
}

/// The next wave's villains and their numbers, shown during the break. Bosses count in red.
struct NextWaveStrip: View {
    let entries: [ScoutEntry]

    var body: some View {
        HStack(spacing: 8) {
            PixelText("NEXT", pixel: 1, color: Theme.secondaryText)
            ForEach(entries.prefix(6), id: \.kind) { entry in
                HStack(spacing: 2) {
                    PixelImage(image: Art.enemyIcon(entry.kind), scale: 1)
                    PixelText("X\(entry.count)", pixel: 1, color: entry.kind.isBoss ? Theme.danger : Theme.text)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(pixel: Pal.ink).opacity(0.75))
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Next wave: " + entries.map { "\($0.count) \($0.kind.name)" }.joined(separator: ", "))
    }
}

struct SpeedButton: View {
    let session: GameSession

    var body: some View {
        Button(action: session.cycleSpeed) {
            HStack(spacing: 3) {
                PixelIcon(icon: .fastForward, scale: 2, outlined: false)
                PixelText(session.speed.label, pixel: 2, shadow: nil)
            }
            .frame(minWidth: 40)
        }
        .buttonStyle(session.speed == .normal ? PixelButtonStyle.neutral : PixelButtonStyle.gold)
        .accessibilityLabel("Game speed \(session.speed.rawValue)x")
    }
}

struct PauseButton: View {
    let session: GameSession

    var body: some View {
        Button(action: session.togglePause) {
            PixelIcon(icon: .pause, scale: 2, outlined: false)
                .frame(minWidth: 22)
        }
        .buttonStyle(PixelButtonStyle.neutral)
        .accessibilityLabel("Pause")
    }
}

/// Portrait status bar: lives, gold, wave and the speed/pause controls.
struct TopBar: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 8) {
            LivesLabel(lives: session.lives, pulse: session.damagePulse)
            GoldLabel(amount: session.gold)
            WaveLabel(session: session)
                .frame(maxWidth: .infinity)
            SpeedButton(session: session)
            PauseButton(session: session)
        }
        .frame(height: 48)
    }
}

/// Landscape side-panel header with the same information.
struct SideStats: View {
    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LivesLabel(lives: session.lives, pulse: session.damagePulse)
                Spacer()
                GoldLabel(amount: session.gold)
            }
            HStack(spacing: 6) {
                WaveLabel(session: session)
                SpeedButton(session: session)
                PauseButton(session: session)
            }
        }
    }
}
