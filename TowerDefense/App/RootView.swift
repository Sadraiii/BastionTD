import SwiftUI

/// Top-level navigation: start screen, gameplay and the onboarding overlay.
struct RootView: View {
    @State private var session: GameSession?
    @State private var screen = Screen.home
    @State private var showOnboarding = false

    private enum Screen { case home, research, medals, codex, modes }
    @AppStorage(StorageKey.onboardingSeen) private var onboardingSeen = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let session {
                GameView(
                    session: session,
                    onRestart: {
                        session.endRunIfNeeded()
                        start(session.map, session.setup)
                    },
                    nextMap: session.setup.isEvent ? nil : session.map.next,
                    onNextMap: { start($0, session.setup) },
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
                        onResume: PlayerProgress.savedMatch.flatMap { $0.rules == SavedMatch.currentRules ? $0 : nil }.map { saved in { resume(saved) } },
                        onModes: { withAnimation(.easeOut(duration: 0.2)) { screen = .modes } },
                        onHowToPlay: { showOnboarding = true },
                        onResearch: { withAnimation(.easeOut(duration: 0.2)) { screen = .research } },
                        onMedals: { withAnimation(.easeOut(duration: 0.2)) { screen = .medals } },
                        onCodex: { withAnimation(.easeOut(duration: 0.2)) { screen = .codex } }
                    )
                    .transition(.opacity)
                case .research:
                    ResearchLabView { withAnimation(.easeOut(duration: 0.2)) { screen = .home } }
                        .transition(.move(edge: .trailing))
                case .medals:
                    MedalsView { withAnimation(.easeOut(duration: 0.2)) { screen = .home } }
                        .transition(.move(edge: .trailing))
                case .codex:
                    CodexView { withAnimation(.easeOut(duration: 0.2)) { screen = .home } }
                        .transition(.move(edge: .trailing))
                case .modes:
                    ModesView(
                        onDaily: {
                            let daily = MatchSetup.daily(for: Date())
                            start(daily.map, daily.setup)
                        },
                        onBossRush: { start(.arena, MatchSetup(bossRush: true)) },
                        onExpedition: {
                            let expedition = MatchSetup.expedition(
                                seed: UInt64.random(in: 1...UInt64.max),
                                maps: MapDefinition.all.filter(PlayerProgress.isUnlocked),
                                heroes: TowerKind.allCases.filter(PlayerProgress.research.isHeroUnlocked)
                            )
                            start(expedition.map, expedition.setup)
                        },
                        onBack: { withAnimation(.easeOut(duration: 0.2)) { screen = .home } }
                    )
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
            // `-unlockAll` grants full research, `-richStart` (in GameSession) adds gold,
            // `-demo` jumps into a self-playing showcase match.
            if ProcessInfo.processInfo.arguments.contains("-demo") {
                PlayerProgress.research = .complete
                onboardingSeen = true
                showOnboarding = false
                start(.circuit)
            }
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
        session?.endRunIfNeeded()
        PlayerProgress.savedMatch = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            screen = destination
            session = nil
        }
    }

    private func start(_ map: MapDefinition, _ setup: MatchSetup = MatchSetup()) {
        var setup = setup
        setup.commander = PlayerProgress.commanderLoadout
        PlayerProgress.savedMatch = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            session = GameSession(map: map, setup: setup)
        }
    }

    private func resume(_ saved: SavedMatch) {
        guard let map = saved.map else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            session = GameSession(map: map, setup: saved.setup, resuming: saved)
        }
    }
}
