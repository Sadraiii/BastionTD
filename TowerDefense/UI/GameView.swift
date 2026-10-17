import SwiftUI

/// The gameplay screen. Landscape puts the controls in a side panel; portrait
/// uses a top status bar and a bottom panel. The battlefield view keeps its
/// identity across rotations so the running scene is never rebuilt.
struct GameView: View {
    let session: GameSession
    let onRestart: () -> Void
    let onNextMap: (() -> Void)?
    let onQuit: () -> Void
    let onResearch: () -> Void
    let onHowToPlay: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let layout = landscape ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            layout {
                if !landscape {
                    TopBar(session: session)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                battlefield
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ControlPanel(session: session, landscape: landscape)
                    .frame(width: landscape ? 214 : nil, height: landscape ? nil : 172)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay { menus }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.pauseForInterruption() }
        }
    }

    private var battlefield: some View {
        ZStack {
            GameSceneView(scene: session.scene)
            DamageFlash(trigger: session.damagePulse)
            // Tips sit at the top: in portrait the crystal is at the bottom of the board.
            VStack(spacing: 6) {
                if let message = session.coachMessage {
                    CoachBanner(message: message, onHide: session.finishCoach)
                        .transition(.opacity)
                }
                if let banner = session.banner {
                    WaveBannerView(banner: banner)
                        .id(banner.id)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(8)
            .overlay(alignment: .center) {
                if let toast = session.toast {
                    PixelText(toast, pixel: 2, color: Theme.highlight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(pixel: Pal.ink).opacity(0.75))
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.15), value: session.toast)
            .animation(.easeOut(duration: 0.2), value: session.banner)
            .animation(.easeOut(duration: 0.2), value: session.coachMessage)
        }
        .clipped()
    }

    @ViewBuilder
    private var menus: some View {
        if let outcome = session.outcome {
            GameOverView(
                outcome: outcome,
                session: session,
                onRestart: onRestart,
                onNextMap: onNextMap,
                onQuit: onQuit,
                onResearch: onResearch
            )
            .transition(.opacity)
        } else if session.isPaused {
            PauseMenuView(
                onResume: session.togglePause,
                onRestart: onRestart,
                onHowToPlay: onHowToPlay,
                onQuit: onQuit
            )
            .transition(.opacity)
        }
    }
}

/// Red frame that blinks when the crystal takes damage.
struct DamageFlash: View {
    let trigger: Int
    @State private var visible = false

    var body: some View {
        Rectangle()
            .strokeBorder(Theme.danger, lineWidth: 6)
            .opacity(visible ? 0.9 : 0)
            .allowsHitTesting(false)
            .onChange(of: trigger) {
                visible = true
                Task {
                    try? await Task.sleep(for: .milliseconds(120))
                    visible = false
                    try? await Task.sleep(for: .milliseconds(80))
                    visible = true
                    try? await Task.sleep(for: .milliseconds(120))
                    visible = false
                }
            }
    }
}

/// Big pixel banner announcing a new wave.
struct WaveBannerView: View {
    let banner: WaveBanner

    var body: some View {
        VStack(spacing: 6) {
            PixelText(banner.title, pixel: 4, color: banner.isBoss ? Theme.danger : Theme.highlight)
            if let subtitle = banner.subtitle {
                Text(subtitle.uppercased())
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .pixelPanel()
        .allowsHitTesting(false)
    }
}

/// First-game hint shown over the top of the battlefield.
struct CoachBanner: View {
    let message: String
    let onHide: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PixelIcon(icon: .question, scale: 2)
                .padding(4)
                .background(Color(pixel: Pal.blue))
            Text(message)
                .font(Theme.body(12))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
            Button {
                playTap()
                onHide()
            } label: {
                Text("HIDE")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(minWidth: 44, minHeight: 36)
            }
            .accessibilityLabel("Hide tips")
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .frame(maxWidth: 460)
        .pixelPanel(fill: Color(pixel: Pal.navy).opacity(0.94))
    }
}
