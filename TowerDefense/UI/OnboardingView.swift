import SwiftUI

/// Four-page "How to play" shown on first launch and from the menus.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pageCount = 4

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color(pixel: Pal.ink).ignoresSafeArea()
                VStack(spacing: landscape ? 8 : 16) {
                    TabView(selection: $page) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            OnboardingPage(index: index, landscape: landscape)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    HStack(spacing: 8) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Rectangle()
                                .fill(index == page ? Theme.highlight : Theme.panelLight)
                                .frame(width: index == page ? 18 : 8, height: 8)
                        }
                    }
                    .accessibilityHidden(true)

                    HStack(spacing: 12) {
                        Button {
                            playTap()
                            onFinish()
                        } label: {
                            PixelText("SKIP", pixel: 2, shadow: nil).frame(width: 100)
                        }
                        .buttonStyle(PixelButtonStyle.neutral)
                        .opacity(page == pageCount - 1 ? 0 : 1)
                        .disabled(page == pageCount - 1)

                        Button {
                            playTap()
                            if page < pageCount - 1 {
                                withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                            } else {
                                onFinish()
                            }
                        } label: {
                            PixelText(page == pageCount - 1 ? "LET'S GO!" : "NEXT", pixel: 2, shadow: nil)
                                .frame(width: 130)
                        }
                        .buttonStyle(PixelButtonStyle.primary)
                    }
                }
                .padding(.vertical, landscape ? 10 : 24)
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct OnboardingPage: View {
    let index: Int
    let landscape: Bool

    var body: some View {
        let layout = landscape ? AnyLayout(HStackLayout(spacing: 28)) : AnyLayout(VStackLayout(spacing: 22))
        layout {
            illustration
                .frame(minWidth: landscape ? 260 : nil)
            VStack(alignment: landscape ? .leading : .center, spacing: 12) {
                PixelText(title, pixel: 3, color: Theme.highlight)
                Text(message)
                    .font(Theme.body(13, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(landscape ? .leading : .center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 380)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch index {
        case 0: "DEFEND THE CRYSTAL"
        case 1: "RECRUIT HEROES"
        case 2: "POWERS AND RESEARCH"
        default: "KNOW THE VILLAINS"
        }
    }

    private var message: String {
        switch index {
        case 0:
            "Villains walk the path to your crystal. Each one that gets there costs lives. Survive 20 waves to win."
        case 1:
            "Pick a hero, tap a highlighted tile, then tap it again to build. Heroes attack on their own. Villains drop gold."
        case 2:
            "Tap a hero to upgrade it. Tier 3 gives a power you trigger yourself. Only one path can go past tier 2. Matches earn Research Points to spend in the Lab."
        default:
            "Some villains fly, some are cloaked, and some are immune to a damage type. Mix your heroes. The Codex lists them all."
        }
    }

    @ViewBuilder
    private var illustration: some View {
        switch index {
        case 0:
            HStack(alignment: .bottom, spacing: 12) {
                PixelImage(image: Art.enemyIcon(.runner), scale: 3)
                PixelImage(image: Art.enemyIcon(.drone), scale: 3)
                PixelImage(image: Art.enemyIcon(.brute), scale: 3)
                PixelText(">>", pixel: 3, color: Theme.secondaryText)
                    .padding(.bottom, 12)
                PixelImage(image: Art.coreImage, scale: 4)
            }
        case 1:
            VStack(spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(58), spacing: 6), count: landscape ? 7 : 5), spacing: 8) {
                    ForEach(TowerKind.allCases) { kind in
                        VStack(spacing: 4) {
                            PixelImage(image: Art.towerIcon(kind), scale: 2)
                            Text(kind.shortName.uppercased())
                                .font(Theme.body(10))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                HStack(spacing: 6) {
                    GoldLabel(amount: 50, pixel: 2)
                    Text("AND UP").font(Theme.body(11)).foregroundStyle(Theme.secondaryText)
                }
            }
        case 2:
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(Array([[0, 0], [2, 0], [4, 2]].enumerated()), id: \.offset) { index, tiers in
                        PixelImage(image: Art.towerIcon(.pulse, tiers: tiers), scale: 4)
                        if index < 2 {
                            PixelIcon(icon: .upgrade, scale: 2)
                                .rotationEffect(.degrees(90))
                        }
                    }
                }
                HStack(spacing: 8) {
                    PixelIcon(icon: .bolt, scale: 2)
                    PixelText("HYPERDRIVE!", pixel: 2, color: Theme.highlight)
                    PixelIcon(icon: .flask, scale: 2)
                }
            }
        default:
            let columns = [GridItem(.adaptive(minimum: landscape ? 150 : 140), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach([EnemyKind.drone, .wisp, .phantom, .ironclad, .voidling, .gargoyle, .titan, .overlord], id: \.self) { kind in
                    HStack(spacing: 6) {
                        PixelImage(image: Art.enemyIcon(kind), scale: 2)
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kind.name.uppercased())
                                .font(Theme.body(10))
                                .foregroundStyle(Color(pixel: Pal.enemy(kind)))
                            Text(kind.ability)
                                .font(Theme.body(9, weight: .regular))
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: 340)
        }
    }
}
