import SwiftUI

// MARK: - App-level navigation state

/// Filter context passed from a detail page to the Transactions tab.
struct TxFilter {
    var periodLabel: String = ""
    var cashflow: String = "All"
    var category: String? = nil
    var location: String? = nil
    /// Incremented every time "View transactions" is tapped, even when the
    /// filter content is identical. This guarantees txFilterKey changes and
    /// TransactionsView is always recreated with fresh state from the detail page.
    var nonce: Int = 0
}

/// Shared observable object used to drive tab selection and populate the
/// Transactions tab's filters from anywhere in the navigation hierarchy.
@Observable
final class AppNavigationState {
    var selectedTab: Tab = .home
    var txFilter: TxFilter = TxFilter()

    // MARK: Sheet relay (set by TransactionsView, presented above the tab bar)

    /// Non-date filter sheet
    var txFilterSheetPresented: Bool = false
    var txFilterSheetHeight: CGFloat = 300
    var txFilterSheetContent: AnyView = AnyView(EmptyView())

    /// Date sheet — parameters stored directly so ContentView can render
    /// TxDateSheet as a concrete type (not AnyView), preserving its identity
    /// when txDatePickerHeight changes during calendar navigation inside the sheet.
    var txDatePickerPresented: Bool = false
    var txDatePickerHeight: CGFloat = TxDateSheet.compactHeight
    var txDatePickerInitialStart: Date? = nil
    var txDatePickerInitialEnd: Date? = nil
    var txDatePickerInitialPreset: DatePreset? = nil
    var txDatePickerOnCommit: ((Date?, Date?) -> Void)? = nil
    var txDatePickerOnCommitPreset: ((DatePreset?) -> Void)? = nil
    var txDatePickerOnDone: (() -> Void)? = nil

    /// All-filters summary sheet
    var txAllFiltersSheetPresented: Bool = false
    var txAllFiltersSheetContent: AnyView = AnyView(EmptyView())
    var txAllFiltersSheetHeight: CGFloat = TxAllFiltersSheet.compactHeight

}

// MARK: -

enum Tab {
    case home, transactions, banking, staff, analytics, more
}

struct ContentView: View {
    @State private var showBalance = false
    @State private var showProfitLossDetail = true
    @State private var navState = AppNavigationState()
    @State private var txStore  = TransactionStore()

    var body: some View {
        tabContent
            .environment(txStore)
            .animation(nil, value: navState.selectedTab)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomTabBar(selectedTab: navState.selectedTab) { tapped in
                    // Tap the active Home tab again → pop to root (standard iOS behaviour).
                    // Tapping Home from another tab restores the stack as the user left it.
                    if tapped == .home && navState.selectedTab == .home {
                        showProfitLossDetail = false
                    }
                    if tapped != .home { showBalance = false }
                    navState.selectedTab = tapped
                }
            }
            // Prevent the keyboard from pushing the tab bar up. Each individual
            // view that needs keyboard-aware layout handles it internally.
            .ignoresSafeArea(.keyboard)
            // Filter sheet — applied here, ABOVE the tab bar, so it covers it
            .customBottomSheet(
                isPresented:   $navState.txFilterSheetPresented,
                compactHeight: navState.txFilterSheetHeight
            ) {
                navState.txFilterSheetContent
            }
            // Date sheet — rendered as a concrete type (not AnyView) so that
            // SwiftUI preserves TxDateSheet's identity (and its @State) when
            // txDatePickerHeight changes during calendar navigation inside the sheet.
            .customBottomSheet(
                isPresented:   $navState.txDatePickerPresented,
                compactHeight: navState.txDatePickerHeight
            ) {
                if let onCommit = navState.txDatePickerOnCommit,
                   let onDone   = navState.txDatePickerOnDone {
                    TxDateSheet(
                        initialStart:   navState.txDatePickerInitialStart,
                        initialEnd:     navState.txDatePickerInitialEnd,
                        onCommit:       onCommit,
                        onDone:         onDone,
                        onHeightChange: { navState.txDatePickerHeight = $0 },
                        initialPreset:  navState.txDatePickerInitialPreset,
                        onCommitPreset: navState.txDatePickerOnCommitPreset
                    )
                }
            }
            // All-filters summary sheet — presented here, above the tab bar
            .customBottomSheet(
                isPresented:   $navState.txAllFiltersSheetPresented,
                compactHeight: navState.txAllFiltersSheetHeight
            ) {
                navState.txAllFiltersSheetContent
            }
    }

    // A unique key for the current Transactions filter — forces the NavigationStack
    // to recreate (applying fresh init-time state) whenever a P&L detail page fires
    // "View transactions". The nonce increments on every such tap so repeated taps
    // with identical filter content still produce a fresh view.
    private var txFilterKey: String {
        "\(navState.txFilter.nonce)|\(navState.txFilter.periodLabel)|\(navState.txFilter.cashflow)|\(navState.txFilter.category ?? "")|\(navState.txFilter.location ?? "")"
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            // Home is always kept alive so its NavigationStack (HomeView →
            // ProfitLossDetailView → Revenue/Expenses detail) survives tab
            // switches and the user can return to exactly where they were.
            NavigationStack {
                HomeView(showBalance: $showBalance,
                         showProfitLossDetail: $showProfitLossDetail)
            }
            .environment(navState)
            .opacity(navState.selectedTab == .home ? 1 : 0)
            .allowsHitTesting(navState.selectedTab == .home)

            // Transactions is also kept alive for scroll-position persistence.
            // Keyed to txFilterKey so the stack recreates with fresh state
            // whenever the filter changes (P&L "View transactions" taps).
            NavigationStack {
                TransactionsView(
                    periodLabel: navState.txFilter.periodLabel,
                    cashflow:    navState.txFilter.cashflow,
                    category:    navState.txFilter.category,
                    location:    navState.txFilter.location
                )
            }
            .id(txFilterKey)
            .environment(navState)
            .opacity(navState.selectedTab == .transactions ? 1 : 0)
            .allowsHitTesting(navState.selectedTab == .transactions)

            // Analytics / More placeholders
            if navState.selectedTab == .analytics || navState.selectedTab == .more {
                Color.white
            }
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
            Image("NavSearch")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(Color.gray1)
                .frame(width: 24, height: 24)

            Spacer()

            ZStack(alignment: .topTrailing) {
                // Figma inset: 12.5% top/bottom, 16.67% left/right → icon renders at 16×18 inside 24×24
                Image("NavBell")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 18)
                    .frame(width: 24, height: 24)

                // Figma badge: 14×14 blue circle, 2pt white border on the outside, "1" in 10pt semibold white
                // Offset 4pt outside top-right corner of the 24×24 icon frame
                ZStack {
                    // White circle (2pt larger on each side) acts as the outside border
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(Color.blue3)
                        .frame(width: 14, height: 14)
                    Text("1")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .offset(x: 4, y: -4)
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
    let selectedTab: Tab
    let onTap: (Tab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray5)
                .frame(height: 1)

            HStack(spacing: 0) {
                TabItem(icon: "TabHome", label: "Home",
                        isSelected: selectedTab == .home) { onTap(.home) }
                TabItem(icon: "TabBanking", label: "Banking",
                        isSelected: false) {}
                    .allowsHitTesting(false)
                TabItem(icon: "TabStaff", label: "Staff",
                        isSelected: false) {}
                    .allowsHitTesting(false)
                TabItem(icon: "TabTransfer", label: "Transactions",
                        isSelected: selectedTab == .transactions) { onTap(.transactions) }
                TabItem(icon: "TabMore", label: "More",
                        isSelected: false) {}
                    .allowsHitTesting(false)
            }
            .padding(.top, 13)
            .padding(.horizontal, 8)
        }
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
            .animation(nil, value: isSelected)
            .frame(maxWidth: .infinity, minHeight: 48)
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
                ForEach(["Home", "Transactions", "Analytics", "More"], id: \.self) { label in
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
