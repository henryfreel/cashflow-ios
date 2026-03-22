import SwiftUI
import UIKit

// MARK: - Navigation back-gesture enabler

/// Re-enables UIKit's interactive pop gesture recognizer for views that hide
/// the navigation bar. Without this, `.navigationBarHidden(true)` causes UIKit
/// to disable `interactivePopGestureRecognizer`, breaking the edge-swipe-back.
private struct NavigationBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Impl { Impl() }
    func updateUIViewController(_ vc: Impl, context: Context) {}

    final class Impl: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // Resetting the delegate to nil restores UIKit's default behaviour,
            // which allows the gesture when there is more than one VC on the stack.
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

// MARK: - Profit & Loss Detail

struct ProfitLossDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigationState.self) private var navState: AppNavigationState?
    @Environment(TransactionStore.self) private var txStore: TransactionStore?

    /// Convenience accessor — falls back to empty dict when store isn't in the environment.
    private var overrides: [UUID: String] { txStore?.categoryOverrides ?? [:] }

    // MARK: Filter state (for the persistent chip bar)
    @State private var plSelectedLocations:  Set<String> = []
    @State private var plSelectedCashflows:  Set<String> = []
    @State private var plSelectedCategories: Set<String> = []
    @State private var plSelectedStartDate:  Date? = nil
    @State private var plSelectedEndDate:    Date? = nil
    // Measured height of the metrics section while data is available.
    // Stored separately so metricsNoDataView can match it exactly, preventing
    // the chart from shifting when navigating to a period with no data.
    @State private var metricsHeight: CGFloat = 200
    @State private var normalMetricsHeight: CGFloat = 0

    // MARK: Period selection & navigation state

    // Selected segment: "Year", "Quarter", or "Month".
    @State private var selectedPeriod: String
    /// Tracks which donut segment is selected on Revenue / Expenses pages.
    @State private var selectedDonutIndex: Int = 0
    // Swipe navigates between full periods — year, quarter, or month.
    // Prototype context: Dec 15, 2024 — default to current year/quarter/month.
    @State private var selectedYear:    Int
    @State private var selectedQuarter: Int
    @State private var selectedMonth:   Int

    /// Seeds the view with the period already visible on the Home card so the
    /// bar chart opens on exactly the right month / quarter / year.
    /// Navigation bar title shown at the top of the page.
    let pageTitle: String
    /// When false the revenue/expenses donut-arc card is hidden.
    /// Used by the Revenue and Expenses detail pages which share this
    /// view's structure but are focused on a single metric.
    let showRevenueExpensesCard: Bool

    init(
        pageTitle:       String  = "Profit & Loss",
        showRevenueExpensesCard: Bool = true,
        initialPeriod:   String  = "Year",
        initialYear:     Int     = AppFinancials.currentYear,
        initialQuarter:  Int     = AppFinancials.currentQuarter,
        initialMonth:    Int     = AppFinancials.currentMonth
    ) {
        self.pageTitle = pageTitle
        self.showRevenueExpensesCard = showRevenueExpensesCard
        _selectedPeriod  = State(initialValue: initialPeriod)
        _selectedYear    = State(initialValue: initialYear)
        _selectedQuarter = State(initialValue: initialQuarter)
        _selectedMonth   = State(initialValue: initialMonth)
    }

    // Navigation state for drilling into Revenue / Expenses detail pages.
    @State private var showRevenueDetail  = false
    @State private var showExpensesDetail = false
    // Direction of last navigation (true = forward / left-swipe = newer period).
    @State private var slideLeft: Bool = true
    // Incremented on every swipe/chevron navigation. The metrics container is keyed
    // to this counter so container replacement (and the slide transition) only fires
    // during actual navigation — never during period-type switches (Month→Quarter etc).
    @State private var metricsNavCounter: Int = 0
    // Rubber-band offset applied only to the sliding metrics rows.
    @State private var bounceOffset: CGFloat = 0
    // True while a confirmed horizontal swipe is in progress; suppresses row taps.
    @State private var isDragging: Bool = false
    // Scrubbing: which bar index is currently being hovered (nil = not scrubbing).
    @State private var scrubIndex: Int? = nil
    // Direction of last scrub movement (true = moved to higher index / right).
    // Used when releasing to animate metrics out in that direction, period totals in from opposite.
    @State private var lastScrubDirection: Bool = true

    // MARK: Annual totals (driven by selectedYear)

    private var monthsForSelectedYear: [MonthlyFinancial] {
        AppFinancials.monthlyData(year: selectedYear, overrides: overrides)
    }

    private var monthsForPrevYear: [MonthlyFinancial] {
        let prev = selectedYear - 1
        guard prev >= AppFinancials.minYear else { return [] }
        return AppFinancials.monthlyData(year: prev, overrides: overrides)
    }

    private var totalRevenue:   Double { monthsForSelectedYear.reduce(0) { $0 + $1.revenue } }
    private var totalExpenses:  Double { monthsForSelectedYear.reduce(0) { $0 + $1.expenses } }
    private var netProfit:      Double { totalRevenue - totalExpenses }

    private var totalRevenuePrev:  Double { monthsForPrevYear.reduce(0) { $0 + $1.revenue } }
    private var totalExpensesPrev: Double { monthsForPrevYear.reduce(0) { $0 + $1.expenses } }
    private var netProfitPrev:    Double { totalRevenuePrev - totalExpensesPrev }

    // MARK: Category breakdowns for Revenue / Expenses detail pages

    private var revenueDonutSegments: [DonutChartView.Segment] {
        let b = RevenueBreakdown(total: totalRevenue)
        return [
            .init(id: 0, name: RevenueCategory.squareCard.rawValue, value: b.squareCard),
            .init(id: 1, name: RevenueCategory.online.rawValue,     value: b.online),
            .init(id: 2, name: RevenueCategory.cash.rawValue,       value: b.cash),
            .init(id: 3, name: RevenueCategory.giftCard.rawValue,   value: b.giftCard),
        ]
    }

    private var expenseDonutSegments: [DonutChartView.Segment] {
        let b = ExpenseBreakdown(total: totalExpenses)
        return [
            .init(id: 0, name: ExpenseCategory.cogs.rawValue,         value: b.cogs),
            .init(id: 1, name: ExpenseCategory.laborPayroll.rawValue,  value: b.labor),
            .init(id: 2, name: ExpenseCategory.rentUtilities.rawValue, value: b.rent + b.utilities),
            .init(id: 3, name: ExpenseCategory.marketing.rawValue,     value: b.marketing),
        ]
    }

    /// Fixed-proportion share of the selected segment within the annual total.
    /// Because proportions are constant, this equals the category's share for any sub-period.
    private var selectedCategoryProportion: Double {
        guard !showRevenueExpensesCard else { return 0 }
        let segs      = pageTitle == "Revenue" ? revenueDonutSegments : expenseDonutSegments
        let annual    = pageTitle == "Revenue" ? totalRevenue         : totalExpenses
        guard selectedDonutIndex < segs.count, annual > 0 else { return 0 }
        return segs[selectedDonutIndex].value / annual
    }

    /// Category value for the current period (scales with the period total).
    private var categoryPeriodValue: Double {
        (pageTitle == "Revenue" ? periodRevenue : periodExpenses) * selectedCategoryProportion
    }

    /// Category value for the bar currently under the user's finger while scrubbing.
    private var categoryScrubValue: Double {
        (pageTitle == "Revenue" ? scrubRevenue : scrubExpenses) * selectedCategoryProportion
    }

    /// Display name of the currently selected category segment.
    private var selectedCategoryName: String {
        let segs = pageTitle == "Revenue" ? revenueDonutSegments : expenseDonutSegments
        guard selectedDonutIndex < segs.count else { return "" }
        return segs[selectedDonutIndex].name
    }

    // MARK: Label tables

    private static let monthNames = [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    private static let monthAbbrevs = [
        "Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"
    ]
    /// Single-character labels matching the real MonthlyFinancial.month values ("J","F",…).
    private static let monthChars = [
        "J","F","M","A","M","J","J","A","S","O","N","D"
    ]

    // MARK: Period-aware bar chart entries

    private var hasDataForPeriod: Bool { selectedYear >= AppFinancials.minYear }

    private var currentEntries: [BarChartEntry] {
        guard hasDataForPeriod else {
            // Placeholder bars when navigating beyond data (e.g. 2022)
            switch selectedPeriod {
            case "Quarter": return (0..<13).map { BarChartEntry(id: $0, label: "\($0 + 1)", fullLabel: "Week \($0 + 1)", revenue: 0, expenses: 0) }
            case "Month":
                let comps = DateComponents(year: selectedYear, month: selectedMonth)
                let date = Calendar.current.date(from: comps) ?? Date()
                let days = Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 31
                let abbrev = Self.monthAbbrevs[selectedMonth - 1]
                return (0..<days).map { i in
                    let day = i + 1
                    let dc = DateComponents(year: selectedYear, month: selectedMonth, day: day)
                    let wdAbbrev: String
                    if let d = Calendar.current.date(from: dc) {
                        let idx = Calendar.current.component(.weekday, from: d) - 1
                        wdAbbrev = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][idx]
                    } else { wdAbbrev = "" }
                    let fl = wdAbbrev.isEmpty ? "\(abbrev) \(day)" : "\(wdAbbrev), \(abbrev) \(day)"
                    return BarChartEntry(id: i, label: "\(day)", fullLabel: fl, revenue: 0, expenses: 0)
                }
            default: return (0..<12).map { BarChartEntry(id: $0, label: Self.monthChars[$0], fullLabel: Self.monthNames[$0], revenue: 0, expenses: 0) }
            }
        }
        switch selectedPeriod {
        case "Quarter":
            let weeks = AppFinancials.weeklyData(year: selectedYear, quarter: selectedQuarter,
                                                  overrides: overrides)
            let isCurrentPeriod = selectedYear == AppFinancials.currentYear
                                && selectedQuarter == AppFinancials.currentQuarter
            let currentWeekIdx = isCurrentPeriod
                ? (weeks.lastIndex(where: { $0.hasData }) ?? weeks.count - 1)
                : -1
            return weeks.map { w in
                let label = w.dateRange.isEmpty ? "Week \(w.id + 1)" : w.dateRange
                return BarChartEntry(id: w.id, label: "\(w.id + 1)", fullLabel: label,
                                     revenue: w.revenue, expenses: w.expenses,
                                     isCurrent: w.id == currentWeekIdx)
            }
        case "Month":
            let abbrev = Self.monthAbbrevs[selectedMonth - 1]
            let isCurrentPeriod = selectedYear == AppFinancials.currentYear
                                && selectedMonth == AppFinancials.currentMonth
            return AppFinancials.dailyData(year: selectedYear, month: selectedMonth,
                                            overrides: overrides).map { d in
                let dc = DateComponents(year: selectedYear, month: selectedMonth, day: d.id)
                let wdAbbrev: String
                if let date = Calendar.current.date(from: dc) {
                    let idx = Calendar.current.component(.weekday, from: date) - 1
                    wdAbbrev = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][idx]
                } else { wdAbbrev = "" }
                let fl = wdAbbrev.isEmpty ? "\(abbrev) \(d.id)" : "\(wdAbbrev), \(abbrev) \(d.id)"
                return BarChartEntry(id: d.id - 1, label: "\(d.id)",
                              fullLabel: fl,
                              revenue: d.revenue, expenses: d.expenses,
                              isCurrent: isCurrentPeriod && d.id == AppFinancials.currentDay,
                              isFuture: d.isFuture)
            }
        default: // "Year"
            let months = AppFinancials.monthlyData(year: selectedYear, overrides: overrides)
            let isCurrentYear = selectedYear == AppFinancials.currentYear
            return months.map {
                BarChartEntry(id: $0.id, label: $0.month, fullLabel: $0.fullMonth,
                              revenue: $0.revenue, expenses: $0.expenses,
                              isCurrent: isCurrentYear && $0.id == AppFinancials.currentMonth - 1)
            }
        }
    }

    private var prevYearEntries: [BarChartEntry] {
        let prev = selectedYear - 1
        guard prev >= AppFinancials.minYear else { return [] }
        switch selectedPeriod {
        case "Quarter":
            return AppFinancials.weeklyData(year: prev, quarter: selectedQuarter,
                                             overrides: overrides).map { w in
                let label = w.dateRange.isEmpty ? "Week \(w.id + 1)" : w.dateRange
                return BarChartEntry(id: w.id, label: "\(w.id + 1)", fullLabel: label,
                                     revenue: w.revenue, expenses: w.expenses)
            }
        case "Month":
            let abbrev = Self.monthAbbrevs[selectedMonth - 1]
            return AppFinancials.dailyData(year: prev, month: selectedMonth,
                                            overrides: overrides).map { d in
                BarChartEntry(id: d.id - 1, label: "\(d.id)",
                              fullLabel: "\(abbrev) \(d.id)",
                              revenue: d.revenue, expenses: d.expenses)
            }
        default: // "Year"
            return AppFinancials.monthlyData(year: prev, overrides: overrides).map {
                BarChartEntry(id: $0.id, label: $0.month, fullLabel: $0.fullMonth,
                              revenue: $0.revenue, expenses: $0.expenses)
            }
        }
    }

    // MARK: Period aggregate totals (drive the metric rows)

    private var periodRevenue:   Double { currentEntries.map(\.revenue).reduce(0, +) }
    private var periodExpenses:  Double { currentEntries.map(\.expenses).reduce(0, +) }
    private var periodNetProfit: Double { periodRevenue - periodExpenses }

    private var prevRevenue:    Double { prevYearEntries.map(\.revenue).reduce(0, +) }
    private var prevExpenses:   Double { prevYearEntries.map(\.expenses).reduce(0, +) }
    private var prevNetProfit:  Double { prevRevenue - prevExpenses }

    private var periodRevYoyPct: Double {
        prevRevenue  != 0 ? ((periodRevenue   - prevRevenue)   / abs(prevRevenue))   * 100 : 0
    }
    private var periodExpYoyPct: Double {
        prevExpenses != 0 ? ((periodExpenses  - prevExpenses)  / abs(prevExpenses))  * 100 : 0
    }
    private var periodNetYoyPct: Double {
        prevNetProfit != 0 ? ((periodNetProfit - prevNetProfit) / abs(prevNetProfit)) * 100 : 0
    }

    // MARK: Scrub-specific data (drive metric rows while hovering)

    /// Human-readable label for the bar currently under the user's finger.
    /// Year view → full month name ("December").
    /// Quarter view → week date range ("Oct 1 - Oct 7").
    /// Month view → full date with ordinal ("December 1st, 2024").
    private var scrubLabel: String? {
        guard let si = scrubIndex, si < currentEntries.count else { return nil }
        let entry = currentEntries[si]
        switch selectedPeriod {
        case "Month":
            // "Wed, Jan 1" — weekday abbreviation, month abbreviation, day number
            let day = entry.id + 1   // entry.id is 0-based; day number is 1-based
            let comps = DateComponents(year: selectedYear, month: selectedMonth, day: day)
            if let date = Calendar.current.date(from: comps) {
                let wdIdx = Calendar.current.component(.weekday, from: date) - 1  // 0 = Sun
                let wd = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][wdIdx]
                return "\(wd), \(Self.monthAbbrevs[selectedMonth - 1]) \(day)"
            }
            return "\(Self.monthAbbrevs[selectedMonth - 1]) \(day)"
        case "Quarter":
            // Replace en dash with hyphen for compact list-row titles
            return entry.fullLabel.replacingOccurrences(of: "-", with: "-")
        default: // Year
            return entry.fullLabel
        }
    }

    private var scrubRevenue:   Double {
        guard let si = scrubIndex, si < currentEntries.count else { return periodRevenue }
        return currentEntries[si].revenue
    }
    private var scrubExpenses:  Double {
        guard let si = scrubIndex, si < currentEntries.count else { return periodExpenses }
        return currentEntries[si].expenses
    }
    private var scrubNetProfit: Double { scrubRevenue - scrubExpenses }

    private var scrubPrevRevenue:   Double {
        guard let si = scrubIndex, si < prevYearEntries.count else { return 0 }
        return prevYearEntries[si].revenue
    }
    private var scrubPrevExpenses:  Double {
        guard let si = scrubIndex, si < prevYearEntries.count else { return 0 }
        return prevYearEntries[si].expenses
    }
    private var scrubPrevNetProfit: Double { scrubPrevRevenue - scrubPrevExpenses }

    private var scrubRevYoyPct: Double {
        scrubPrevRevenue   != 0 ? ((scrubRevenue   - scrubPrevRevenue)   / abs(scrubPrevRevenue))   * 100 : 0
    }
    private var scrubExpYoyPct: Double {
        scrubPrevExpenses  != 0 ? ((scrubExpenses  - scrubPrevExpenses)  / abs(scrubPrevExpenses))  * 100 : 0
    }
    private var scrubNetYoyPct: Double {
        scrubPrevNetProfit != 0 ? ((scrubNetProfit - scrubPrevNetProfit) / abs(scrubPrevNetProfit)) * 100 : 0
    }

    // MARK: Period nav header

    private var periodNavTitle: String {
        switch selectedPeriod {
        case "Quarter":
            return "Q\(selectedQuarter) \(selectedYear)"
        case "Month":
            return "\(Self.monthNames[selectedMonth - 1]) \(selectedYear)"
        default: // "Year"
            return "Jan – Dec, \(selectedYear)"
        }
    }

    // MARK: Navigation helpers

    // Year view: swipe between available years (minYear .. currentYear).
    // Quarter view: navigate Q1-Q4, crossing into previous/next year when at boundaries.
    // Month view: navigate Jan-Dec, crossing into previous/next year when at boundaries.

    /// Allow one period beyond data boundary (e.g. 2022 when minYear is 2023).
    private var canGoBack: Bool {
        let oneBeforeMin = AppFinancials.minYear - 1
        switch selectedPeriod {
        case "Quarter": return selectedQuarter > 1 || (selectedQuarter == 1 && selectedYear > oneBeforeMin)
        case "Month":   return selectedMonth > 1 || (selectedMonth == 1 && selectedYear > oneBeforeMin)
        case "Year":    return selectedYear > oneBeforeMin
        default:        return false
        }
    }

    private var canGoForward: Bool {
        switch selectedPeriod {
        case "Quarter": return selectedYear < AppFinancials.currentYear || (selectedYear == AppFinancials.currentYear && selectedQuarter < AppFinancials.currentQuarter)
        case "Month":   return selectedYear < AppFinancials.currentYear || (selectedYear == AppFinancials.currentYear && selectedMonth < AppFinancials.currentMonth)
        case "Year":    return selectedYear < AppFinancials.currentYear
        default:        return false
        }
    }

    private func navigateBack(animation: Animation = .easeOut(duration: 0.18)) {
        guard canGoBack else { return }
        scrubIndex = nil
        slideLeft = false
        // metricsNavCounter and the period change together in one withAnimation so the
        // new container renders with the correct data on the first pass. Task defers to
        // the next run-loop tick, which is needed for chevron button taps (synchronous)
        // to get two render passes; swipe gesture calls are already async so Task is
        // effectively a no-op for them.
        Task { @MainActor in
            withAnimation(animation) {
                metricsNavCounter += 1
                switch selectedPeriod {
                case "Quarter":
                    if selectedQuarter > 1 { selectedQuarter -= 1 }
                    else { selectedYear -= 1; selectedQuarter = 4 }
                case "Month":
                    if selectedMonth > 1 { selectedMonth -= 1 }
                    else { selectedYear -= 1; selectedMonth = 12 }
                case "Year": selectedYear -= 1
                default: break
                }
            }
        }
    }

    private func navigateForward(animation: Animation = .easeOut(duration: 0.18)) {
        guard canGoForward else { return }
        scrubIndex = nil
        slideLeft = true
        Task { @MainActor in
            withAnimation(animation) {
                metricsNavCounter += 1
                switch selectedPeriod {
                case "Quarter":
                    if selectedQuarter < 4 { selectedQuarter += 1 }
                    else { selectedYear += 1; selectedQuarter = 1 }
                case "Month":
                    if selectedMonth < 12 { selectedMonth += 1 }
                    else { selectedYear += 1; selectedMonth = 1 }
                case "Year": selectedYear += 1
                default: break
                }
            }
        }
    }

    // Range label used in the "View all … transactions" button.
    // Month: "December" | Quarter & Year: full date range from periodNavTitle.
    private var viewAllRangeLabel: String {
        switch selectedPeriod {
        case "Month": return Self.monthNames[selectedMonth - 1]
        default:      return periodNavTitle
        }
    }

    // MARK: Transaction context for TransactionsView

    /// "All", "Revenue", or "Expenses" cashflow label for the filter chip.
    private var transactionCashflow: String {
        switch pageTitle {
        case "Revenue":  return "Revenue"
        case "Expenses": return "Expenses"
        default:         return "All"
        }
    }

    /// Raw transactions for the current period, filtered to the page context.
    private var transactionsForPeriod: [Transaction] {
        let raw: [Transaction]
        switch selectedPeriod {
        case "Month":
            raw = AppFinancials.sampleTransactions(year: selectedYear, month: selectedMonth)
        case "Quarter":
            raw = AppFinancials.sampleTransactions(year: selectedYear, quarter: selectedQuarter)
        default: // "Year"
            raw = AppFinancials.sampleTransactions(year: selectedYear)
        }

        switch pageTitle {
        case "Revenue":
            return raw.filter { $0.isRevenue }
        case "Expenses":
            return raw.filter { !$0.isRevenue 
            }
        default: // P&L — show everything
            return raw
        }
    }

    // Direction-aware slide transition for the metrics rows — pure offset, no opacity.
    // This transition ALWAYS slides; it only ever fires when metricsNavCounter changes
    // (i.e. during swipe/chevron navigation). Period-type switches (Month→Quarter) do
    // not change the counter, so the container is never replaced and no transition fires.
    private var metricsTransition: AnyTransition {
        let sign: CGFloat = slideLeft ? 1 : -1
        return .asymmetric(
            insertion: .offset(x:  sign * 390),
            removal:   .offset(x: -sign * 390)
        )
    }

    // Keyed only to the navigation counter — NOT to the period/year/month/quarter.
    // This means container replacement only happens when we explicitly navigate,
    // not when the period type is switched via the segment pill.
    private var metricsAnimationKey: String { "nav-\(metricsNavCounter)" }

    // MARK: Drag gesture (applied on the metrics+chart zone)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // Yield the left-edge zone (~20pt) to UIKit's interactive pop gesture.
                guard value.startLocation.x > 20 else {
                    if bounceOffset != 0 { bounceOffset = 0 }
                    return
                }
                // Do not interfere while the scrub gesture is active
                guard scrubIndex == nil else {
                    if bounceOffset != 0 { bounceOffset = 0 }
                    return
                }
                let h = value.translation.width
                let v = value.translation.height
                guard abs(h) > abs(v) else {
                    if bounceOffset != 0 { bounceOffset = 0 }
                    return
                }
                // Confirmed horizontal drag — suppress any concurrent row taps.
                isDragging = true
                let atBoundary = (h > 0 && !canGoBack) || (h < 0 && !canGoForward)
                bounceOffset = atBoundary ? h * 0.25 : h
            }
            .onEnded { value in
                // Always reset on the next run loop so any button action that fires
                // synchronously in the same gesture cycle sees isDragging == true
                // and bails out, while future taps work normally.
                defer { DispatchQueue.main.async { self.isDragging = false } }

                guard value.startLocation.x > 20 else { return }
                guard scrubIndex == nil else { return }
                let h = value.translation.width
                let v = value.translation.height
                let isHorizontal = abs(h) > abs(v) * 1.5 && abs(h) > 30
                let blocked = (h > 0 && !canGoBack) || (h < 0 && !canGoForward)

                if isHorizontal && !blocked {
                    bounceOffset = 0
                    let snap: Animation = .easeOut(duration: 0.18)
                    if h > 0 { navigateBack(animation: snap) }
                    else     { navigateForward(animation: snap) }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        bounceOffset = 0
                    }
                }
            }
    }

    // MARK: Body

    /// Large hero display used on the P&L page for net profit.
    /// Shows the period-scoped value (responds to bar-chart scrubbing) and a
    /// YoY % badge — no status-dot indicator.
    private var netProfitHeroRow: some View {
        let isScrubbing = scrubIndex != nil
        let value   = isScrubbing ? scrubNetProfit   : periodNetProfit
        let yoyPct  = isScrubbing ? scrubNetYoyPct   : periodNetYoyPct
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total net profit")
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray3)

                SlotMachineText(
                    text: fmt(value),
                    value: value,
                    font: .display10,
                    color: Color.gray1,
                    animated: isScrubbing
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            YoyBadge(pct: yoyPct)
        }
    }

    /// Hero display for Revenue and Expenses detail pages — same layout and font
    /// as `netProfitHeroRow` but driven by the page-specific metric.
    private var singleMetricHeroRow: some View {
        let isScrubbing = scrubIndex != nil
        let scrubBarHasData = scrubIndex.map { $0 < currentEntries.count && !currentEntries[$0].isFuture } ?? false
        let isFutureScrub   = isScrubbing && !scrubBarHasData
        let hasPrev = isScrubbing && !isFutureScrub
            ? (scrubIndex ?? 0) < prevYearEntries.count && prevYearEntries[scrubIndex ?? 0].hasData
            : (!isScrubbing && selectedYear > AppFinancials.minYear)

        let isRevenue = pageTitle == "Revenue"
        let title     = isRevenue ? "Total revenue" : "Total expenses"
        let rawValue  = isRevenue
            ? (isScrubbing ? scrubRevenue  : periodRevenue)
            : (isScrubbing ? scrubExpenses : periodExpenses)
        let rawYoy    = isRevenue
            ? (isScrubbing ? scrubRevYoyPct : periodRevYoyPct)
            : (isScrubbing ? scrubExpYoyPct : periodExpYoyPct)
        let yoyPct: Double? = (hasPrev && !isFutureScrub) ? (isRevenue ? rawYoy : -rawYoy) : nil
        let prefix = isRevenue ? "" : "-"

        return HStack(alignment: .center, spacing: 0) {
            // Indicator dot — same pattern as metricRow. Slides in from the left when
            // scrubbing begins; dot sits at top + 2pt to align with the title label.
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(isRevenue ? Color.barRevPrimary : Color.barExpPrimary)
                    .frame(width: 12, height: 12)
                    .padding(.top, 2)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .frame(width: isScrubbing ? 12 : 0)
            .clipped()
            .padding(.trailing, isScrubbing ? 8 : 0)
            .opacity(isScrubbing ? 1 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isScrubbing)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray3)

                HStack(spacing: 0) {
                    if !prefix.isEmpty {
                        Text(prefix)
                            .font(.display10)
                            .foregroundStyle(Color.gray1)
                    }
                    SlotMachineText(
                        text: fmt(rawValue),
                        value: rawValue,
                        font: .display10,
                        color: Color.gray1,
                        animated: isScrubbing
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            YoyBadge(pct: yoyPct)
                .padding(.leading, 8)
        }
    }

    /// Compact category row shown 16pt below the hero on Revenue / Expenses detail pages.
    /// Uses the same metricRow style as the P&L summary rows. The category value and
    /// YoY badge update live while the user scrubs the bar chart. Because category
    /// proportions are fixed, the YoY% always equals the parent metric's YoY%.
    private var categoryRowForDetailPage: some View {
        let isScrubbing     = scrubIndex != nil
        let scrubBarHasData = scrubIndex.map { $0 < currentEntries.count && !currentEntries[$0].isFuture } ?? false
        let isFutureScrub   = isScrubbing && !scrubBarHasData
        let hasPrev = isScrubbing && !isFutureScrub
            ? (scrubIndex ?? 0) < prevYearEntries.count && prevYearEntries[scrubIndex ?? 0].hasData
            : (!isScrubbing && selectedYear > AppFinancials.minYear)

        let isRevenue = pageTitle == "Revenue"
        let catValue  = isScrubbing ? categoryScrubValue : categoryPeriodValue
        let rawYoy    = isRevenue
            ? (isScrubbing ? scrubRevYoyPct : periodRevYoyPct)
            : (isScrubbing ? scrubExpYoyPct : periodExpYoyPct)
        let yoyPct: Double? = (hasPrev && !isFutureScrub) ? (isRevenue ? rawYoy : -rawYoy) : nil

        return metricRow(
            indicator:      isRevenue ? .revenue : .expenses,
            title:          selectedCategoryName,
            yoyPct:         yoyPct,
            value:          fmt(catValue),
            valuePrefix:    isRevenue ? "" : "-",
            animateValue:   isScrubbing ? catValue : nil,
            onTap:          { presentCategoryPicker() },
            indicatorVisible: isScrubbing
        )
    }

    /// Opens the category picker bottom sheet above the tab bar.
    private func presentCategoryPicker() {
        guard let navState else { return }
        let isRevenue = pageTitle == "Revenue"
        let title     = isRevenue ? "Revenue Category" : "Expense Category"
        let options   = (isRevenue ? revenueDonutSegments : expenseDonutSegments)
                            .map { (id: $0.id, label: $0.name) }

        let sheet = PLCategoryPickerSheet(
            title:        title,
            options:      options,
            initialIndex: selectedDonutIndex,
            onSelect: { [self] idx in selectedDonutIndex = idx },
            onDone:   { navState.categoryPickerSheetPresented = false }
        )

        navState.categoryPickerSheetHeight    = PLCategoryPickerSheet.height(rowCount: options.count)
        navState.categoryPickerSheetContent   = AnyView(sheet)
        navState.categoryPickerSheetPresented = true
    }

    /// Routes to the correct animated section for the current page context.
    /// P&L page shows the compact revenue + expenses rows; Revenue/Expenses pages
    /// show their respective metric in the same large hero style as the net profit row,
    /// followed by the first-category breakdown row 16pt below.
    @ViewBuilder
    private var animatedMetricsSection: some View {
        if showRevenueExpensesCard {
            metricsSection
        } else {
            Group {
                if !hasDataForPeriod {
                    metricsNoDataView
                        // Match the height of hero + category row so the chart below
                        // doesn't shift when navigating to an empty period.
                        .frame(height: normalMetricsHeight > 0 ? normalMetricsHeight : nil,
                               alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        singleMetricHeroRow
                        categoryRowForDetailPage
                            .padding(.top, 16)
                    }
                }
            }
        }
    }

    private var scrollContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Net profit hero and the metrics rows are bundled into a single
                // identity container so they ALL slide together when navigating periods.
                VStack(spacing: 0) {
                    if showRevenueExpensesCard && hasDataForPeriod {
                        netProfitHeroRow
                            .padding(.bottom, 16)
                    }
                    animatedMetricsSection
                }
                .id(metricsAnimationKey)
                .transition(metricsTransition)
                .animation(.easeOut(duration: 0.25), value: metricsAnimationKey)
                .offset(x: bounceOffset)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                    if h > 0 {
                        metricsHeight = h
                        if hasDataForPeriod { normalMetricsHeight = h }
                    }
                }

                chartSection
                    .padding(.top, 37)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(swipeGesture)

            viewAllButton
                .padding(.top, 40)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                scrollContent
                    .padding(.horizontal, 16)
            }
        }
        .scrollDisabled(true)
        .contentMargins(.bottom, 94, for: .scrollContent)
        .navigationDestination(isPresented: $showRevenueDetail) {
            ProfitLossDetailView(
                pageTitle: "Revenue",
                showRevenueExpensesCard: false,
                initialPeriod:  selectedPeriod,
                initialYear:    selectedYear,
                initialQuarter: selectedQuarter,
                initialMonth:   selectedMonth
            )
        }
        .navigationDestination(isPresented: $showExpensesDetail) {
            ProfitLossDetailView(
                pageTitle: "Expenses",
                showRevenueExpensesCard: false,
                initialPeriod:  selectedPeriod,
                initialYear:    selectedYear,
                initialQuarter: selectedQuarter,
                initialMonth:   selectedMonth
            )
        }
        .background(Color.white)
        .background(NavigationBackGestureEnabler())
        // Keep global date + location in sync with this page's current period/location.
        .onAppear { updateGlobalFilters() }
        .onChange(of: selectedYear)      { updateGlobalFilters() }
        .onChange(of: selectedPeriod)    { updateGlobalFilters() }
        .onChange(of: selectedQuarter)   { updateGlobalFilters() }
        .onChange(of: selectedMonth)     { updateGlobalFilters() }
        .onChange(of: plSelectedStartDate) { updateGlobalFilters() }
        .onChange(of: plSelectedEndDate)   { updateGlobalFilters() }
        .onChange(of: plSelectedLocations) { updateGlobalFilters() }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                SecondaryNavBar(
                    title: pageTitle,
                    onBack: { dismiss() }
                )
                plFilterChipsRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .background(Color.white)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: Filter chips row

    /// Shared PLFilterChipsBar wired to this page's navigation and filter state.
    private var plFilterChipsRow: some View {
        PLFilterChipsBar(
            periodLabel:       periodChipLabel,
            canGoBack:         canGoBack,
            canGoForward:      canGoForward,
            onBack:            { navigateBack() },
            onForward:         { navigateForward() },
            onTapPeriod:       { presentDatePicker() },
            onTapLocation:      { presentLocationSheet() },
            locationFilterCount: plSelectedLocations.count
        )
    }

    /// Opens the TxDateSheet via navState — same sheet as the transactions page date chip.
    /// Pre-selects the preset matching the current period granularity. When Done is tapped,
    /// translates the chosen preset back into selectedPeriod / Year / Quarter / Month so
    /// the chip label and all data below update immediately.
    private func presentDatePicker() {
        guard let navState else { return }
        let preset: DatePreset? = {
            switch selectedPeriod {
            case "Month":   return .thisMonth
            case "Quarter": return .thisQuarter
            default:        return .thisYear
            }
        }()
        navState.txDatePickerInitialStart  = plSelectedStartDate
        navState.txDatePickerInitialEnd    = plSelectedEndDate
        navState.txDatePickerInitialPreset = preset
        navState.txDatePickerOnCommit = { [self] start, end in
            plSelectedStartDate = start
            plSelectedEndDate   = end
        }
        navState.txDatePickerOnCommitPreset = { [self] chosen in
            guard let chosen else { return }
            let cal   = Calendar.current
            let start = chosen.dateRange.start
            let year  = cal.component(.year,  from: start)
            let month = cal.component(.month, from: start)
            withAnimation(.easeOut(duration: 0.18)) {
                metricsNavCounter += 1
                selectedYear = year
                switch chosen {
                case .today, .thisWeek, .thisMonth:
                    selectedPeriod = "Month"
                    selectedMonth  = month
                case .thisQuarter:
                    selectedPeriod   = "Quarter"
                    selectedQuarter  = ((month - 1) / 3) + 1
                case .thisYear:
                    selectedPeriod = "Year"
                }
            }
        }
        navState.txDatePickerOnDone    = { navState.txDatePickerPresented = false }
        navState.txDatePickerHeight    = TxDateSheet.compactHeight
        navState.txDatePickerPresented = true
    }

    private func plFilterSheetHeight(for filter: TxActiveFilter) -> CGFloat {
        let rowCount: Int
        switch filter {
        case .location: rowCount = TransactionsView.locationOptions.count
        case .cashflow: rowCount = TransactionsView.cashflowOptions.count
        case .category: rowCount = TransactionsView.categoryOptions.count
        case .date:     rowCount = 0
        }
        let full = CGFloat(29 + 48 + 16 + 56 * (1 + rowCount) + 32)
        return min(full, UIScreen.main.bounds.height * 0.60)
    }

    private func plCommitFilter(_ filter: TxActiveFilter, newKeys: Set<String>) {
        switch filter {
        case .location: plSelectedLocations  = newKeys
        case .cashflow: plSelectedCashflows  = newKeys
        case .category: plSelectedCategories = newKeys
        case .date:     break
        }
    }

    /// Writes the current period + location to AppNavigationState globals so that
    /// TransactionsView always reflects whatever date/location is active here.
    private func updateGlobalFilters() {
        guard let navState else { return }
        let cal      = Calendar.current
        let appToday = TransactionsView.appToday

        if let start = plSelectedStartDate {
            // Custom date range selected via the date picker.
            navState.globalStartDate = start
            navState.globalEndDate   = plSelectedEndDate
        } else {
            // Standard period — compute the date range from year/quarter/month.
            switch selectedPeriod {
            case "Month":
                let start = cal.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1))!
                let nextMonthStart = selectedMonth < 12
                    ? cal.date(from: DateComponents(year: selectedYear, month: selectedMonth + 1, day: 1))!
                    : cal.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1))!
                let end = cal.date(byAdding: .day, value: -1, to: nextMonthStart)!
                navState.globalStartDate = start
                navState.globalEndDate   = min(end, appToday)
            case "Quarter":
                let startMonth = (selectedQuarter - 1) * 3 + 1
                let endMonth   = startMonth + 2
                let start      = cal.date(from: DateComponents(year: selectedYear, month: startMonth, day: 1))!
                let daysInEnd  = cal.range(of: .day, in: .month,
                    for: cal.date(from: DateComponents(year: selectedYear, month: endMonth, day: 1))!)!.count
                let end        = cal.date(from: DateComponents(year: selectedYear, month: endMonth, day: daysInEnd))!
                navState.globalStartDate = start
                navState.globalEndDate   = min(end, appToday)
            default: // Year
                let start = cal.date(from: DateComponents(year: selectedYear, month: 1,  day: 1))!
                let end   = cal.date(from: DateComponents(year: selectedYear, month: 12, day: 31))!
                navState.globalStartDate = start
                navState.globalEndDate   = min(end, appToday)
            }
        }
        navState.globalLocations = plSelectedLocations
    }

    /// Opens a location filter sheet directly, relayed via navState so ContentView
    /// presents it above the tab bar.
    private func presentLocationSheet() {
        guard let navState else { return }
        navState.txFilterSheetContent = AnyView(
            TxFilterSheet(
                filter:      .location,
                options:     TransactionsView.locationOptions,
                initialKeys: plSelectedLocations,
                onCommit:    { [self] newKeys in plSelectedLocations = newKeys },
                onDone:      { navState.txFilterSheetPresented = false }
            )
        )
        navState.txFilterSheetHeight    = plFilterSheetHeight(for: .location)
        navState.txFilterSheetPresented = true
    }

    /// Chip label for the period navigator.
    /// Format mirrors the bar chart scrub/tooltip pattern: "{type} • {value}".
    /// Year: "Year • 2024" | Quarter: "Quarter • Q1" | Month: "Month • December"
    private var periodChipLabel: String {
        switch selectedPeriod {
        case "Quarter": return "Quarter • Q\(selectedQuarter)"
        case "Month":   return "Month • \(Self.monthNames[selectedMonth - 1])"
        default:        return "Year • \(selectedYear)"
        }
    }


    // MARK: Metrics Rows (slide on period change)

    @ViewBuilder
    private var metricsSection: some View {
        if !hasDataForPeriod {
            metricsNoDataView
                // Match the height of the full P&L metrics block (hero + rows) so the
                // chart below doesn't shift position when navigating to an empty period.
                .frame(height: normalMetricsHeight > 0 ? normalMetricsHeight : nil,
                       alignment: .center)
        } else {
            unifiedMetricsContent
        }
    }

    /// The no-data content itself — no fixed padding; callers wrap this in a
    /// frame(height: normalMetricsHeight) so it matches the rows it replaces.
    private var metricsNoDataView: some View {
        VStack(spacing: 8) {
            Image("no-data")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            // Header 18pt / 26pt line-height, subtext 14pt / 22pt line-height, no gap between them.
            VStack(spacing: 0) {
                Text("No data available")
                    .font(.custom(AppFont.Text.semiBold, size: 18))
                    .foregroundStyle(Color(red: 16/255, green: 16/255, blue: 16/255))
                    .frame(maxWidth: 254)
                    .multilineTextAlignment(.center)
                    .lineSpacing(26 - 18)

                Text("Try adjusting the date range")
                    .font(.custom(AppFont.Text.regular, size: 14))
                    .foregroundStyle(Color.gray3)
                    .frame(maxWidth: 254)
                    .multilineTextAlignment(.center)
                    .lineSpacing(22 - 14)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var unifiedMetricsContent: some View {
        let isScrubbing = scrubIndex != nil
        // A future bar has no data yet — show "TBD" instead of a YoY% that would be misleading.
        let scrubBarHasData = scrubIndex.map { $0 < currentEntries.count && !currentEntries[$0].isFuture } ?? false
        let isFutureScrub = isScrubbing && !scrubBarHasData
        let hasPrev = isScrubbing && !isFutureScrub
            ? (scrubIndex ?? 0) < prevYearEntries.count && prevYearEntries[scrubIndex ?? 0].hasData
            : (!isScrubbing && selectedYear > AppFinancials.minYear)

        return metricsRows(
            revTitle: "Total revenue",
            expTitle: "Total expenses",
            revValue: isScrubbing ? scrubRevenue  : periodRevenue,
            expValue: isScrubbing ? scrubExpenses : periodExpenses,
            revYoy:   isScrubbing ? scrubRevYoyPct : periodRevYoyPct,
            expYoy:   isScrubbing ? scrubExpYoyPct : periodExpYoyPct,
            hasPrev: hasPrev,
            isFutureScrub: isFutureScrub,
            animateNumbers: isScrubbing,
            revOnTap: showRevenueExpensesCard ? { showRevenueDetail = true } : nil,
            expOnTap: showRevenueExpensesCard ? { showExpensesDetail = true } : nil
        )
    }

    private func metricsRows(
        revTitle: String, expTitle: String,
        revValue: Double, expValue: Double,
        revYoy: Double, expYoy: Double,
        hasPrev: Bool,
        isFutureScrub: Bool = false,
        animateNumbers: Bool = false,
        revOnTap: (() -> Void)? = nil,
        expOnTap: (() -> Void)? = nil
    ) -> some View {
        return VStack(spacing: 0) {
            if pageTitle != "Expenses" {
                metricRow(
                    indicator: .revenue,
                    title: revTitle,
                    yoyPct: (hasPrev && !isFutureScrub) ? revYoy : nil,
                    value: fmt(revValue),
                    animateValue: animateNumbers ? revValue : nil,
                    onTap: revOnTap,
                    indicatorVisible: animateNumbers
                )
            }
            if pageTitle != "Revenue" {
                metricRow(
                    indicator: .expenses,
                    title: expTitle,
                    yoyPct: (hasPrev && !isFutureScrub) ? -expYoy : nil,
                    value: fmt(expValue),
                    valuePrefix: "-",
                    animateValue: animateNumbers ? expValue : nil,
                    onTap: expOnTap,
                    indicatorVisible: animateNumbers
                )
            }
        }
    }

    private enum IndicatorKind {
        case revenue
        case expenses
    }

    private func metricRow(indicator: IndicatorKind,
                            title: String,
                            yoyPct: Double?,
                            value: String,
                            valuePrefix: String = "",
                            animateValue: Double? = nil,
                            onTap: (() -> Void)? = nil,
                            indicatorVisible: Bool = false) -> some View {
        let rowContent = HStack(alignment: .center, spacing: 0) {
            // Indicator slides in from the left when scrubbing begins. Uses spacing: 0
            // so no phantom gap appears when the indicator is hidden (width: 0). The 8pt
            // gap between the dot and the text is baked into the trailing padding, which
            // also collapses to 0, so the text sits flush at the left edge when idle.
            // The container stretches the full row height; the dot sits at top + 2pt to
            // align with the title label, matching the Figma "Indicator default" spec.
            ZStack(alignment: .topLeading) {
                switch indicator {
                case .revenue:
                    Circle()
                        .fill(Color.barRevPrimary)
                        .frame(width: 12, height: 12)
                        .padding(.top, 2)
                case .expenses:
                    Circle()
                        .fill(Color.barExpPrimary)
                        .frame(width: 12, height: 12)
                        .padding(.top, 2)
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .frame(width: indicatorVisible ? 12 : 0)
            .clipped()
            .padding(.trailing, indicatorVisible ? 8 : 0)
            .opacity(indicatorVisible ? 1 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: indicatorVisible)

            // Text column fills all remaining width, pushing badge+chevron to trailing edge.
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray3)
                HStack(spacing: 0) {
                    if !valuePrefix.isEmpty {
                        Text(valuePrefix)
                            .font(.paragraphSemibold30)
                            .foregroundStyle(Color.gray1)
                    }
                    SlotMachineText(
                        text: value,
                        value: animateValue ?? 0,
                        font: .paragraphSemibold30,
                        color: Color.gray1,
                        animated: animateValue != nil
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 8pt between text and badge, 8pt between badge and chevron.
            YoyBadge(pct: yoyPct)
                .padding(.leading, 8)

            if onTap != nil {
                Image("icon16ChevronRight")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Color.gray4)
                    .frame(width: 16, height: 16)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)

        return Group {
            if let action = onTap {
                Button(action: {
                    guard !isDragging else { return }
                    action()
                }) {
                    rowContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                rowContent
            }
        }
    }

    // MARK: Chart — active bar tracks selected month; chart itself never slides

    /// Determines bar rendering mode based on the current page context.
    /// Revenue/Expenses pages use single-axis charts; P&L uses the default net-profit layout.
    private var chartMode: PLYearBarChart.ChartMode {
        switch pageTitle {
        case "Revenue":  return .revenueOnly(selectedCategoryProportion)
        case "Expenses": return .expensesOnly(selectedCategoryProportion)
        default:         return .netProfit
        }
    }

    private var chartSection: some View {
        PLYearBarChart(
            entries: currentEntries,
            activeIndex: currentEntries.firstIndex(where: { $0.isCurrent }) ?? -1,
            scrubbingIndex: scrubIndex,
            onScrubChanged: { idx in
                if scrubIndex != idx {
                    lastScrubDirection = idx > (scrubIndex ?? -1)
                    // Explicit animation context so SlotMachineText digit transitions
                    // fire only during scrubbing — not during swipes or filter changes.
                    withAnimation(.easeOut(duration: 0.12)) {
                        scrubIndex = idx
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            },
            onScrubEnded: {
                withAnimation(.easeOut(duration: 0.25)) {
                    scrubIndex = nil
                }
            },
            viewportHPadding: 24,
            mode: chartMode
        )
    }

    // MARK: View All Button

    /// Maps a RevenueCategory display name to the "rev:" prefixed key used by
    /// TransactionsView's catOk filter. Returns nil for unknown names (falls
    /// back to no category filter).
    private func txRevKey(for revCategoryName: String) -> String? {
        switch revCategoryName {
        case RevenueCategory.squareCard.rawValue: return TransactionsView.revCardKey
        case RevenueCategory.online.rawValue:     return TransactionsView.revOnline
        case RevenueCategory.cash.rawValue:       return TransactionsView.revCash
        case RevenueCategory.giftCard.rawValue:   return TransactionsView.revGiftCard
        default:                                  return nil
        }
    }

    private var viewAllButton: some View {
        let enabled = hasDataForPeriod
        return Button {
            guard enabled else { return }
            // For revenue category pages, translate the display name to the "rev:" key
            // that TransactionsView's filter logic expects. For expense pages the raw
            // expense category name matches directly.
            let categoryKey: String? = {
                guard !showRevenueExpensesCard else { return nil }
                // The selected category row (selectedDonutIndex) is the primary category filter.
                // Fall back to an explicit All Filters chip selection if no donut row is active.
                let name = selectedCategoryName
                if !name.isEmpty {
                    if pageTitle == "Revenue" { return txRevKey(for: name) }
                    return name
                }
                guard plSelectedCategories.count == 1, let key = plSelectedCategories.first else { return nil }
                if pageTitle == "Revenue" { return txRevKey(for: key) }
                return key
            }()
            let prevNonce = navState?.txFilter.nonce ?? 0
            navState?.txFilter = TxFilter(
                periodLabel: periodNavTitle,
                cashflow:    transactionCashflow,
                category:    categoryKey,
                nonce:       prevNonce + 1
            )
            navState?.selectedTab = .transactions
        } label: {
            Text(enabled ? "View \(viewAllRangeLabel) transactions" : "No transactions available")
                .font(.paragraphSemibold30)
                .foregroundStyle(enabled ? Color.blue3 : Color.gray4)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
        }
        .buttonStyle(ViewAllButtonStyle())
        .contentShape(Capsule())
        .disabled(!enabled)
    }

    // MARK: Helpers

    private func ordinalSuffix(_ n: Int) -> String {
        let mod100 = n % 100
        if (11...13).contains(mod100) { return "th" }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    private func fmt(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: abs(value))) ?? "$0.00"
    }

    /// Currency with no cents — used for large summary totals.
    private func fmtWhole(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: abs(value))) ?? "$0"
    }

}

private struct ViewAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.gray6 : Color.gray7,
                in: Capsule()
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ProfitLossDetailView()
    }
}
#endif
