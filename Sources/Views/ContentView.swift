import SwiftUI

enum Tab {
    case home, transfer, analytics, more
}

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var showBalance = false

    var body: some View {
        tabContent
            .safeAreaInset(edge: .top, spacing: 0) {
                TopNavigationBar(showBalance: showBalance)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomTabBar(selectedTab: $selectedTab)
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .home { showBalance = false }
            }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            HomeView(showBalance: $showBalance)
        case .transfer, .analytics, .more:
            ScrollView {
                Text("Coming soon")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(24)
            }
            .background(Color(red: 247/255, green: 247/255, blue: 247/255).ignoresSafeArea())
        }
    }
}

// MARK: - Top Navigation Bar

private struct TopNavigationBar: View {
    let showBalance: Bool

    var body: some View {
        // Figma frame: 390×80pt. Icons 24×24pt.
        // Search: 24pt from left. Center: JewelMark or balance. Bell: 24pt from right.
        // Vertical: 28pt top, 28pt bottom.
        // Icons sit in the HStack edges; center content is a full-width overlay so it
        // is never constrained by the JewelMark's 24pt intrinsic width.
        HStack(spacing: 0) {
            // Figma inset: ~14.5% each side → icon renders at 16.71×16.7 inside 24×24 container
            Image("NavSearch")
                .resizable()
                .scaledToFit()
                .frame(width: 16.71, height: 16.7)
                .frame(width: 24, height: 24)

            Spacer()

            ZStack(alignment: .topTrailing) {
                // Figma inset: 12.5% top/bottom, 16.67% left/right → icon renders at 16×18 inside 24×24
                Image("NavBell")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 18)
                    .frame(width: 24, height: 24)

                Circle()
                    .fill(Color(red: 204 / 255, green: 0 / 255, blue: 35 / 255))
                    .frame(width: 6, height: 6)
                    .offset(x: 2, y: -2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .overlay {
            ZStack {
                if !showBalance {
                    JewelMark()
                        // Enters sliding up from below; exits sliding back down
                        .transition(.asymmetric(
                            insertion: .offset(y: 14).combined(with: .opacity),
                            removal:   .offset(y: 14).combined(with: .opacity)
                        ))
                }

                if showBalance {
                    // Figma Secondary Nav: Heading/20, color #006AFF
                    Text("$12,189.42")
                        .font(.heading20)
                        .foregroundStyle(Color(red: 0, green: 106 / 255, blue: 1))
                        // Enters sliding down from above; exits sliding back up
                        .transition(.asymmetric(
                            insertion: .offset(y: -14).combined(with: .opacity),
                            removal:   .offset(y: -14).combined(with: .opacity)
                        ))
                }
            }
        }
        .background(Color.white)
    }
}

// MARK: - Bottom Tab Bar

// Figma frame: 4 tabs × 94pt wide, centered on 390pt screen.
// Top border: 1px #D5D7D9. Top padding: 13pt. Tab height: 48pt.
// Active color: #006AFF. Inactive: rgba(0,0,0,0.9).
private struct BottomTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        VStack(spacing: 0) {
            // 1px top border, color Core/Gray Lighter: #D5D7D9
            Rectangle()
                .fill(Color(red: 213 / 255, green: 215 / 255, blue: 217 / 255))
                .frame(height: 1)

            // Tabs row: 13pt top padding, 48pt tall tabs
            HStack(spacing: 0) {
                TabItem(icon: "TabHome", label: "Home", isSelected: selectedTab == .home) {
                    selectedTab = .home
                }
                TabItem(icon: "TabTransfer", label: "Transfer", isSelected: selectedTab == .transfer) {
                    selectedTab = .transfer
                }
                TabItem(icon: "TabAnalytics", label: "Analytics", isSelected: selectedTab == .analytics) {
                    selectedTab = .analytics
                }
                TabItem(icon: "TabMore", label: "More", isSelected: selectedTab == .more) {
                    selectedTab = .more
                }
            }
            .padding(.top, 13)
        }
        // Extend white background behind the home indicator
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }
}

private struct TabItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    // Active: Emphasis/Fill #006AFF. Inactive: Fill/10 black at 90% opacity.
    private var color: Color {
        isSelected
            ? Color(red: 0, green: 106 / 255, blue: 1)
            : Color(white: 0, opacity: 0.9)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text(label)
                    .font(.paragraphSemibold10)
                    .frame(height: 16)
            }
            .foregroundStyle(color)
            .frame(width: 94, height: 48)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Jewel Mark

private struct JewelMark: View {
    var body: some View {
        Image("JewelMark")
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
    }
}

#Preview {
    ContentView()
}
