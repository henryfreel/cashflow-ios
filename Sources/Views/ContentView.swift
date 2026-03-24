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
    /// When true, the date sheet shows P&L mode: only Month/Quarter/Year presets,
    /// icon "go to current" button instead of Done, and auto-dismisses on selection.
    var txDatePickerPLMode: Bool = false
    var txDatePickerCurrentPeriodPreset: DatePreset? = nil
    /// Called when the calendar-today icon is tapped in P&L mode; navigates to the
    /// actual current period (today, this week, etc.) and dismisses.
    var txDatePickerOnGoToCurrent: (() -> Void)? = nil

    /// All-filters summary sheet
    var txAllFiltersSheetPresented: Bool = false
    var txAllFiltersSheetContent: AnyView = AnyView(EmptyView())
    var txAllFiltersSheetHeight: CGFloat = TxAllFiltersSheet.compactHeight

    /// Category picker sheet (Revenue / Expenses detail pages)
    var categoryPickerSheetPresented: Bool = false
    var categoryPickerSheetContent: AnyView = AnyView(EmptyView())
    var categoryPickerSheetHeight: CGFloat = PLCategoryPickerSheet.height(rowCount: 4)

    // Global date + location — written by P&L pages, always applied to Transactions.
    // Defaults to the app's current year (2024) so Transactions always opens with a date.
    var globalStartDate: Date? = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))
    var globalEndDate:   Date? = Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 15))
    var globalLocations: Set<String> = []

    // Period state shared across the P&L, Revenue, and Expenses pages.
    // Written by every page on each period/location change; the P&L parent
    // reads these on re-appear so it stays in sync when popping back from a child.
    var plPeriod:    String = "Year"
    var plYear:      Int    = AppFinancials.currentYear
    var plQuarter:   Int    = AppFinancials.currentQuarter
    var plMonth:     Int    = AppFinancials.currentMonth
    var plDay:       Int    = AppFinancials.currentDay
    var plWeekStart: Date   = {
        let cal = Calendar.current
        let today = cal.date(from: DateComponents(year: 2024, month: 12, day: 15))!
        let weekday = cal.component(.weekday, from: today)
        let daysBack = weekday == 1 ? 6 : weekday - 2
        return cal.date(byAdding: .day, value: -daysBack, to: today)!
    }()
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
                        initialStart:        navState.txDatePickerInitialStart,
                        initialEnd:          navState.txDatePickerInitialEnd,
                        onCommit:            onCommit,
                        onDone:              onDone,
                        onHeightChange:      { navState.txDatePickerHeight = $0 },
                        initialPreset:       navState.txDatePickerInitialPreset,
                        onCommitPreset:      navState.txDatePickerOnCommitPreset,
                        plMode:              navState.txDatePickerPLMode,
                        currentPeriodPreset: navState.txDatePickerCurrentPeriodPreset,
                        onGoToCurrent:       navState.txDatePickerOnGoToCurrent
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
            // Category picker sheet (Revenue / Expenses detail pages)
            .customBottomSheet(
                isPresented:   $navState.categoryPickerSheetPresented,
                compactHeight: navState.categoryPickerSheetHeight
            ) {
                navState.categoryPickerSheetContent
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
                        .font(.paragraphSemibold9)
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

// Layout spec (total height = 102pt from screen bottom to tab bar top):
//   Content block: icon 24pt + gap 4pt + label 12pt = 40pt.
//   Padding: 12pt top, 16pt bottom → VStack = 68pt above safe area.
//   Background extends ~34pt into system safe area → 68 + 34 = 102pt total visual height.
//   Top border: 1pt gray5 Rectangle inside the frame.
//   Tab items are content-sized (no equal-width stretching); Spacers distribute
//   remaining horizontal space so labels never truncate.
//   Active pill: height 56pt (8pt above + 40pt content + 8pt below), r=12, gray6.
//   Active pill width: label-width + 16pt (8pt each side), minimum 64pt.
private struct BottomTabBar: View {
    let selectedTab: Tab
    let onTap: (Tab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray5)
                .frame(height: 1)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                TabItem(icon: "TabHome", label: "Home", isSelected: selectedTab == .home,
                        notificationCount: 1) { onTap(.home) }
                Spacer(minLength: 0)
                TabItem(icon: "TabBanking", label: "Banking",
                        isSelected: false) {}
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                TabItem(icon: "TabStaff", label: "Staff",
                        isSelected: false) {}
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                TabItem(icon: "TabTransfer", label: "Transactions",
                        isSelected: selectedTab == .transactions) { onTap(.transactions) }
                Spacer(minLength: 0)
                TabItem(icon: "TabMore", label: "More",
                        isSelected: false) {}
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }
}

private struct TabItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var notificationCount: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(icon)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    if notificationCount > 0 {
                        ZStack {
                            // Outer circle acts as the border; color matches pill background
                            // when selected (gray6) so it blends in, white otherwise.
                            Circle()
                                .fill(isSelected ? Color.gray6 : Color.white)
                                .frame(width: 20, height: 20)
                            Circle()
                                .fill(Color.blue3)
                                .frame(width: 16, height: 16)
                            Text("\(notificationCount)")
                                .font(.paragraphSemibold9)
                                .foregroundStyle(Color.white)
                        }
                        .offset(x: 8, y: -4)
                    }
                }

                Text(label)
                    .font(.paragraphSemibold9)
                    .fixedSize()
                    .frame(height: 12)
            }
            .foregroundStyle(Color.gray1)
            // 8pt padding each side grows the pill to label-width + 16pt.
            // frame(minWidth: 64) enforces a minimum pill width for short labels.
            // No frame(maxWidth: .infinity) — each item hugs its content so labels
            // are never truncated; Spacers in BottomTabBar distribute leftover space.
            .padding(.horizontal, 8)
            .frame(minWidth: 64)
            .background {
                if isSelected {
                    // Content block = 40pt. Pill = 56pt centered in 40pt → extends 8pt
                    // above and 8pt below with no manual offset required.
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray6)
                        .frame(height: 56)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)
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
