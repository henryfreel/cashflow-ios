import SwiftUI

enum Tab {
    case home, transfer, analytics, more
}

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var showBalance = false
    @State private var showProfitLossDetail = false

    var body: some View {
        tabContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomTabBar(selectedTab: $selectedTab, onHomeTap: {
                    showProfitLossDetail = false
                })
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .home { showBalance = false }
            }
    }

    @ViewBuilder
    private var tabContent: some View {
        NavigationStack {
            HomeView(showBalance: $showBalance, showProfitLossDetail: $showProfitLossDetail)
        }
    }
}

// MARK: - Top Navigation Bar

struct TopNavigationBar: View {
    let showBalance: Bool
    let isScrolled: Bool

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
                    .fill(Color.red3)
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
                    Text(AppFinancials.netBalanceFormatted)
                        .font(.heading20)
                        .foregroundStyle(Color.blue3)
                        // Enters sliding down from above; exits sliding back up
                        .transition(.asymmetric(
                            insertion: .offset(y: -14).combined(with: .opacity),
                            removal:   .offset(y: -14).combined(with: .opacity)
                        ))
                }
            }
        }
        .background(Color.white)
        .overlay(alignment: .bottom) {
            if isScrolled {
                Rectangle()
                    .fill(Color.gray5)
                    .frame(height: 1)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isScrolled)
    }
}

// MARK: - Bottom Tab Bar

// Figma frame: 4 tabs × 94pt wide, centered on 390pt screen.
// Top border: 1px gray5 (matches nav bar bottom separator). Top padding: 13pt. Tab height: 48pt.
// Active color: #006AFF. Inactive: gray1.
private struct BottomTabBar: View {
    @Binding var selectedTab: Tab
    let onHomeTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 1px top border
            Rectangle()
                .fill(Color.gray5)
                .frame(height: 1)

            // Tabs row: 13pt top padding, 48pt tall tabs
            HStack(spacing: 0) {
                TabItem(icon: "TabHome", label: "Home", isSelected: selectedTab == .home) {
                    onHomeTap()
                    selectedTab = .home
                }
                TabItem(icon: "TabTransfer", label: "Transfer", isSelected: false) {}
                    .allowsHitTesting(false)
                TabItem(icon: "TabAnalytics", label: "Analytics", isSelected: false) {}
                    .allowsHitTesting(false)
                TabItem(icon: "TabMore", label: "More", isSelected: false) {}
                    .allowsHitTesting(false)
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
            ? Color.blue3
            : Color.gray1
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

#if DEBUG
// ContentView renders the full app tree (HomeView + NavigationStack + Liquid Glass).
// Use individual view previews for faster iteration; this one is intentionally
// lightweight so it doesn't time out the canvas.
#Preview("Tab shell") {
    VStack(spacing: 0) {
        Spacer()
        Text("Use HomeView or ProfitLossDetailView previews")
            .font(.body)
            .foregroundStyle(.secondary)
        Spacer()
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
        VStack(spacing: 0) {
            Rectangle().fill(Color.gray5).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(["Home", "Transfer", "Analytics", "More"], id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(label == "Home" ? Color.blue3 : Color.gray1)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 13)
                        .padding(.bottom, 8)
                }
            }
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }
}
#endif
