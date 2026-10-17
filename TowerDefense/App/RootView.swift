import SwiftUI

/// Top-level navigation: start screen, gameplay and the onboarding overlay.
struct RootView: View {
    @State private var session: GameSession?
    @State private var screen = Screen.home
    @State private var showOnboarding = false

    private enum Screen { case home, research, medals }
    @AppStorage(StorageKey.onboardingSeen) private var onboardingSeen = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let session {
                GameView(
                    session: session,
                    onRestart: { start(session.map) },
                    onNextMap: session.map.next.map { next in { start(next) } },
                    onQuit: { quit(to: .home) },
                    onResearch: { quit(to: .research) },
                    onHowToPlay: { showOnboarding = true }
                )
                .id(session.id)
                .transition(.opacity)
            } else {
                switch screen {
                case .home:
                    StartView(
                        onPlay: start,
                        onHowToPlay: { showOnboarding = true },
                        onResearch: { withAnimation(.easeOut(duration: 0.2)) { screen = .research } },
                        onMedals: { withAnimation(.easeOut(duration: 0.2)) { screen = .medals } }
                    )
                    .transition(.opacity)
                case .research:
                    ResearchLabView { withAnimation(.easeOut(duration: 0.2)) { screen = .home } }
                        .transition(.move(edge: .trailing))
                case .medals:
                    MedalsView { withAnimation(.easeOut(duration: 0.2)) { screen = .home } }
                        .transition(.move(edge: .trailing))
                }
            }

            if showOnboarding {
                OnboardingView {
                    onboardingSeen = true
                    withAnimation(.easeOut(duration: 0.2)) { showOnboarding = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            SoundEngine.shared.prepare()
            if !onboardingSeen { showOnboarding = true }
            #if DEBUG
            // Launch arguments for simulator checks: `-landscape` rotates without manual input,
            // `-unlockAll` grants full research, `-richStart` (in GameSession) adds gold.
            if ProcessInfo.processInfo.arguments.contains("-unlockAll") {
                PlayerProgress.research = .complete
                PlayerProgress.researchPoints = max(PlayerProgress.researchPoints, 120)
            }
            if ProcessInfo.processInfo.arguments.contains("-landscape") {
                for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                }
            }
            #endif
        }
    }

    private func quit(to destination: Screen) {
        withAnimation(.easeInOut(duration: 0.25)) {
            screen = destination
            session = nil
        }
    }

    private func start(_ map: MapDefinition) {
        withAnimation(.easeInOut(duration: 0.25)) {
            session = GameSession(map: map)
        }
    }
}
