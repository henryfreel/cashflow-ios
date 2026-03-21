import SwiftUI

struct TransactionsView: View {
    // Incoming filter context (pre-populates state on init)
    let periodLabel: String
    let cashflow:    String
    let category:    String?
    let location:    String?

    // MARK: Filter state

    @State private var selectedStartDate: Date?
    @State private var selectedEndDate:   Date?
    @State private var selectedCashflows:  Set<String> = []
    @State private var selectedCategories: Set<String> = []
    @State private var selectedLocations:  Set<String> = []

    @State private var isSearching:  Bool   = false
    @State private var searchText:   String = ""

    @State private var visibleCount: Int  = 15
    @State private var isScrolled:   Bool = false
    @State private var selectedTransaction: Transaction? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigationState.self) private var navState
    @Environment(TransactionStore.self) private var txStore: TransactionStore?

    // MARK: Init

    init(periodLabel: String, cashflow: String, category: String?,
         location: String? = nil, transactions: [Transaction] = []) {
        self.periodLabel = periodLabel
        self.cashflow    = cashflow
        self.category    = category
        self.location    = location

        if let range = Self.dateRange(forPeriodLabel: periodLabel) {
            _selectedStartDate = State(initialValue: range.start)
            _selectedEndDate   = State(initialValue: range.end)
        }
        if cashflow != "All" && !cashflow.isEmpty {
            _selectedCashflows = State(initialValue: [cashflow])
        }
        if let cat = category { _selectedCategories = State(initialValue: [cat]) }
        if let loc = location { _selectedLocations  = State(initialValue: [loc]) }
    }

    // MARK: Derived state

    private var hasFilters: Bool {
        selectedStartDate != nil || !selectedCashflows.isEmpty
            || !selectedCategories.isEmpty || !selectedLocations.isEmpty
    }

    private var showLocation: Bool { selectedLocations.count != 1 }

    // MARK: Filter options

    private static let locationOptions: [TxFilterOption] = [
        TxFilterOption(id: "Hayes Valley",   label: "Hayes Valley"),
        TxFilterOption(id: "Bernal Heights", label: "Bernal Heights"),
        TxFilterOption(id: "The Mission",    label: "The Mission"),
    ]
    private static let cashflowOptions: [TxFilterOption] = [
        TxFilterOption(id: "Revenue",  label: "Revenue"),
        TxFilterOption(id: "Expenses", label: "Expenses"),
    ]
    // Revenue filter IDs use a "rev:" prefix so they stay distinct from expense category raw values.
    static let revCardKey   = "rev:card"
    static let revGiftCard  = "rev:giftCard"
    static let revOnline    = "rev:online"
    static let revCash      = "rev:cash"

    private static let categoryOptions: [TxFilterOption] = {
        // ── Expenses ─────────────────────────────────────────────────────────
        var opts: [TxFilterOption] = [.header("EXPENSES")]
        opts += ExpenseCategory.allCases.map { TxFilterOption(id: $0.rawValue, label: $0.rawValue) }
        // ── Revenue ───────────────────────────────────────────────────────────
        opts.append(.header("REVENUE"))
        opts += [
            TxFilterOption(id: revCardKey,  label: "Card payments"),
            TxFilterOption(id: revGiftCard, label: "Gift cards"),
            TxFilterOption(id: revOnline,   label: "Online payments"),
            TxFilterOption(id: revCash,     label: "Cash payments"),
        ]
        return opts
    }()

    /// Resolves a raw filter key to its display label by looking it up in the
    /// relevant options list. Falls back to the raw key if not found.
    static func label(forKey key: String, in options: [TxFilterOption]) -> String {
        options.first(where: { $0.id == key })?.label ?? key
    }

    /// Formats a date range for the filter chip and All Filters sheet, matching
    /// the conventions used in the P&L detail pages:
    ///   • Single day            → "Mon, Dec 8"
    ///   • Month (starts on 1st, same month) → "December 2024"
    ///   • Quarter (starts on Q start, same year) → "Q4 2024"
    ///   • Year (Jan 1 → any Dec date, same year) → "Jan – Dec, 2024"
    ///   • Any other range       → "Oct 10 – Oct 17"  /  "Dec 1, 2023 – Jan 5, 2024"
    static func chipDateLabel(start: Date, end: Date?) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "en_US")
        let effectiveEnd = end ?? start

        // Single day
        if cal.isDate(start, inSameDayAs: effectiveEnd) {
            fmt.dateFormat = "EEE, MMM d"
            return fmt.string(from: start)
        }

        let sy = cal.component(.year,  from: start)
        let sm = cal.component(.month, from: start)
        let sd = cal.component(.day,   from: start)
        let ey = cal.component(.year,  from: effectiveEnd)
        let em = cal.component(.month, from: effectiveEnd)

        // Year: starts Jan 1, end lands in December of the same year
        if sy == ey && sm == 1 && sd == 1 && em == 12 {
            return "Jan – Dec, \(sy)"
        }

        // Month: starts on the 1st, end in the same month and year
        if sd == 1 && sy == ey && sm == em {
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: start)
        }

        // Quarter: starts on a quarter-opening month (1, 4, 7, 10), day 1, same year
        if sy == ey && sd == 1 && [1, 4, 7, 10].contains(sm) {
            let q = (sm - 1) / 3 + 1
            return "Q\(q) \(sy)"
        }

        // Generic range
        fmt.dateFormat = "MMM d"
        let startStr = fmt.string(from: start)
        let endStr   = fmt.string(from: effectiveEnd)
        if sy == ey {
            return "\(startStr) – \(endStr)"
        } else {
            return "\(startStr), \(sy) – \(endStr), \(ey)"
        }
    }

    private func options(for f: TxActiveFilter) -> [TxFilterOption] {
        switch f {
        case .location: return Self.locationOptions
        case .cashflow: return Self.cashflowOptions
        case .category: return Self.categoryOptions
        case .date:     return []   // handled by TxDatePickerSheet
        }
    }

    private func selectedBinding(for f: TxActiveFilter) -> Binding<Set<String>> {
        switch f {
        case .location: return $selectedLocations
        case .cashflow: return $selectedCashflows
        case .category: return $selectedCategories
        case .date:     return .constant([])
        }
    }

    // MARK: Chip display values

    private func chipValue(_ keys: Set<String>, options: [TxFilterOption] = []) -> String? {
        switch keys.count {
        case 0:  return nil
        case 1:  return Self.label(forKey: keys.first!, in: options)
        default: return "\(keys.count) selected"
        }
    }

    private var dateLabelValue: String? {
        guard let start = selectedStartDate else { return nil }
        return Self.chipDateLabel(start: start, end: selectedEndDate)
    }

    // MARK: Filtered items

    private var displayItems: [Transaction] {
        let cal = Calendar.current
        return AppFinancials.allTransactions.filter { tx in
            let dateOk: Bool = {
                guard let s = selectedStartDate else { return true }
                let d = cal.startOfDay(for: tx.date)
                if let e = selectedEndDate { return d >= s && d <= e }
                return cal.isDate(d, inSameDayAs: s)
            }()
            let locOk  = selectedLocations.isEmpty
                || selectedLocations.contains(tx.locationName ?? "")
            let flowOk = selectedCashflows.isEmpty
                || (tx.isRevenue
                    ? selectedCashflows.contains("Revenue")
                    : selectedCashflows.contains("Expenses"))
            let catOk: Bool = {
                guard !selectedCategories.isEmpty else { return true }
                let revKeys = selectedCategories.filter { $0.hasPrefix("rev:") }
                let expKeys = selectedCategories.filter { !$0.hasPrefix("rev:") }
                if tx.isRevenue {
                    guard !revKeys.isEmpty else { return false }
                    return revKeys.contains { key in
                        switch key {
                        case Self.revCardKey:
                            if case .cardPayment      = tx.type { return true }
                            if case .cardPaymentGroup = tx.type { return true }
                            return false
                        case Self.revGiftCard:  return tx.type == .giftCard
                        case Self.revOnline:    return tx.type == .onlineOrder
                        case Self.revCash:      return tx.type == .cashPayment
                        default:               return false
                        }
                    }
                } else {
                    guard !expKeys.isEmpty else { return false }
                    // Use the resolved (possibly overridden) category so that
                    // reclassified transactions immediately reflect their new category.
                    guard let cat = txStore?.resolvedCategory(for: tx) ?? tx.expenseCategory
                    else { return false }
                    return expKeys.contains(cat)
                }
            }()
            let searchOk: Bool = {
                guard !searchText.isEmpty else { return true }
                let q = searchText.lowercased()
                return tx.merchantName.lowercased().contains(q)
                    || (tx.expenseCategory ?? "").lowercased().contains(q)
            }()
            return dateOk && locOk && flowOk && catOk && searchOk
        }.sorted { $0.date > $1.date }
    }

    // MARK: Date helpers

    private static let monthNames = [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]

    /// The app's data horizon — no data exists beyond this date.
    static var appToday: Date {
        Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 15))!
    }

    /// Parses a period label into a (start, end) Date range,
    /// clamping the end to `appToday` so future days are never included.
    static func dateRange(forPeriodLabel label: String) -> (start: Date, end: Date)? {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "en_US")
        let parts = label.components(separatedBy: " ")

        let horizon = appToday

        // "Q4 2024"
        if parts.count == 2, parts[0].hasPrefix("Q"),
           let q = Int(parts[0].dropFirst()), (1...4).contains(q),
           let year = Int(parts[1]) {
            let sm = (q - 1) * 3 + 1
            let em = q * 3
            let s  = cal.date(from: DateComponents(year: year, month: sm, day: 1))!
            let emonth = cal.date(from: DateComponents(year: year, month: em, day: 1))!
            let days   = cal.range(of: .day, in: .month, for: emonth)!.count
            let e      = cal.date(from: DateComponents(year: year, month: em, day: days))!
            return (cal.startOfDay(for: s), min(cal.startOfDay(for: e), horizon))
        }

        // "December 2024"
        fmt.dateFormat = "MMMM yyyy"
        if let d = fmt.date(from: label) {
            let y    = cal.component(.year, from: d)
            let m    = cal.component(.month, from: d)
            let days = cal.range(of: .day, in: .month, for: d)!.count
            let s    = cal.date(from: DateComponents(year: y, month: m, day: 1))!
            let e    = cal.date(from: DateComponents(year: y, month: m, day: days))!
            return (cal.startOfDay(for: s), min(cal.startOfDay(for: e), horizon))
        }

        // "2024" or "Jan – Dec, 2024"
        let yearStr = label.contains(",")
            ? (label.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces) ?? "")
            : label.trimmingCharacters(in: .whitespaces)
        if let year = Int(yearStr) {
            let s = cal.date(from: DateComponents(year: year, month: 1,  day: 1))!
            let e = cal.date(from: DateComponents(year: year, month: 12, day: 31))!
            return (cal.startOfDay(for: s), min(cal.startOfDay(for: e), horizon))
        }

        return nil
    }

    // MARK: Sheet helpers

    private func sheetHeight(for filter: TxActiveFilter) -> CGFloat {
        let rowCount = options(for: filter).count
        let full = CGFloat(29 + 48 + 16 + 56 * (1 + rowCount) + 32)
        return min(full, UIScreen.main.bounds.height * 0.60)
    }

    /// Builds the filter sheet content and relays it to `navState`
    /// so ContentView can present it above the tab bar.
    private func presentFilterSheet(_ filter: TxActiveFilter) {
        let binding = selectedBinding(for: filter)
        navState.txFilterSheetContent = AnyView(
            TxFilterSheet(
                filter:      filter,
                options:     options(for: filter),
                initialKeys: binding.wrappedValue,
                onCommit:    { newKeys in binding.wrappedValue = newKeys },
                onDone:      { navState.txFilterSheetPresented = false }
            )
        )
        navState.txFilterSheetHeight    = sheetHeight(for: filter)
        navState.txFilterSheetPresented = true
    }

    /// Builds the all-filters navigation sheet and relays it to `navState`
    /// so ContentView can present it above the tab bar.
    private func presentAllFiltersSheet() {
        navState.txAllFiltersSheetHeight = TxAllFiltersSheet.compactHeight
        navState.txAllFiltersSheetContent = AnyView(
            TxAllFiltersSheet(
                locationOptions:     Self.locationOptions,
                cashflowOptions:     Self.cashflowOptions,
                categoryOptions:     Self.categoryOptions,
                filterSheetHeight:   { [self] filter in sheetHeight(for: filter) },
                initialLocationKeys: selectedLocations,
                initialCashflowKeys: selectedCashflows,
                initialCategoryKeys: selectedCategories,
                initialDateStart:    selectedStartDate,
                initialDateEnd:      selectedEndDate,
                onClearAll: {
                    selectedStartDate  = nil
                    selectedEndDate    = nil
                    selectedCashflows  = []
                    selectedCategories = []
                    selectedLocations  = []
                    visibleCount       = 15
                    navState.txAllFiltersSheetPresented = false
                },
                onDone: { navState.txAllFiltersSheetPresented = false },
                onCommitFilter: { filter, newKeys in
                    selectedBinding(for: filter).wrappedValue = newKeys
                    visibleCount = 15
                },
                onCommitDate: { start, end in
                    selectedStartDate = start
                    selectedEndDate   = end
                    visibleCount      = 15
                },
                onHeightChange: { h in
                    navState.txAllFiltersSheetHeight = h
                }
            )
        )
        navState.txAllFiltersSheetPresented = true
    }

    /// Stores date-sheet parameters on navState so ContentView can render
    /// TxDateSheet directly as a concrete type (avoiding AnyView identity loss).
    private func presentDatePicker() {
        navState.txDatePickerInitialStart = selectedStartDate
        navState.txDatePickerInitialEnd   = selectedEndDate
        navState.txDatePickerOnCommit     = { [navState] start, end in
            selectedStartDate = start
            selectedEndDate   = end
            visibleCount      = 15
            _ = navState  // capture to silence warning
        }
        navState.txDatePickerOnDone    = { navState.txDatePickerPresented = false }
        navState.txDatePickerHeight    = TxDateSheet.compactHeight
        navState.txDatePickerPresented = true
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            SecondaryNavBar(title: "Transactions", leftAlignTitle: true)

            // Filter bar is outside the ScrollView so it stays fixed while the list scrolls
            TxFilterBar(
                periodLabel:      dateLabelValue ?? "",
                cashflow:         chipValue(selectedCashflows, options: Self.cashflowOptions) ?? "All",
                category:         chipValue(selectedCategories, options: Self.categoryOptions),
                location:         chipValue(selectedLocations,  options: Self.locationOptions),
                hasFilters:       hasFilters,
                transactionCount: displayItems.count,
                onClear: {
                    selectedStartDate  = nil
                    selectedEndDate    = nil
                    selectedCashflows  = []
                    selectedCategories = []
                    selectedLocations  = []
                    visibleCount       = 15
                },
                onTapLocation:   { presentFilterSheet(.location) },
                onTapDate:       { presentDatePicker()            },
                onTapCashflow:   { presentFilterSheet(.cashflow)  },
                onTapCategory:   { presentFilterSheet(.category)  },
                onTapAllFilters: { presentAllFiltersSheet()        },
                isSearching:     $isSearching,
                searchText:      $searchText
            )
            .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("txListTop")
                        TxPagedList(allItems: displayItems,
                                    visibleCount: $visibleCount,
                                    showLocation: showLocation,
                                    onSelectTx: { selectedTransaction = $0 })
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .contentMargins(.bottom, 94, for: .scrollContent)
                .onScrollGeometryChange(for: Bool.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top > 0
                } action: { _, scrolled in
                    withAnimation(.easeInOut(duration: 0.2)) { isScrolled = scrolled }
                }
                .onChange(of: isSearching) { _, searching in
                    if !searching {
                        withAnimation { proxy.scrollTo("txListTop", anchor: .top) }
                    }
                }
                .onChange(of: searchText) { _, text in
                    if !text.isEmpty {
                        proxy.scrollTo("txListTop", anchor: .top)
                    }
                }
            }
        }
        .overlay {
            Color.black
                .opacity(selectedTransaction != nil ? 0.75 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.35), value: selectedTransaction != nil)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $selectedTransaction) { tx in
            TransactionDetailView(transaction: tx)
        }
        .navigationBarHidden(true)
        .background(Color.white)
        .onChange(of: selectedStartDate)  { _, _ in visibleCount = 15 }
        .onChange(of: selectedCashflows)  { _, _ in visibleCount = 15 }
        .onChange(of: selectedCategories) { _, _ in visibleCount = 15 }
        .onChange(of: selectedLocations)  { _, _ in visibleCount = 15 }
        .onChange(of: searchText)         { _, _ in visibleCount = 15 }
        .onChange(of: isSearching) { _, searching in
            if !searching { searchText = "" }
        }
        .onChange(of: navState.selectedTab) { _, tab in
            // Resign first responder at the UIKit level when leaving this tab.
            // This prevents the TextField (kept alive at opacity 0) from leaking
            // keyboard focus to the destination tab, while preserving all filter
            // state so it's intact when the user returns via the tab bar.
            // Filters are only reset by navigating here from a P&L detail page
            // (which changes txFilterKey and recreates the view with fresh state).
            if tab != .transactions {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }
    }
}

// MARK: - Paged list

private struct TxPagedList: View {
    let allItems: [Transaction]
    @Binding var visibleCount: Int
    var showLocation: Bool = true
    var onSelectTx: ((Transaction) -> Void)? = nil
    var body: some View {
        let slice   = Array(allItems.prefix(visibleCount))
        let groups  = txBuildGroups(from: slice)
        let canLoad = visibleCount < allItems.count
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(groups) { g in
                Section {
                    TxMonthSection(group: g, showLocation: showLocation,
                                   onSelectTx: onSelectTx)
                        .padding(.bottom, 16)
                } header: {
                    Text(g.title)
                        .font(.heading20)
                        .foregroundStyle(Color.gray1)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        .padding(.horizontal, 24)
                        .background(Color.white)
                }
            }
            // Sentinel that auto-advances the page. A new identity each time
            // visibleCount changes so onAppear always fires — this cascades
            // until the content overflows the viewport, then stops until the
            // user scrolls down to it.
            if canLoad {
                Color.clear
                    .frame(height: 1)
                    .id("load-more-\(visibleCount)")
                    .onAppear {
                        visibleCount = min(visibleCount + 15, allItems.count)
                    }
            }
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Preview

#if DEBUG
/// Preview wrapper that mirrors the ContentView sheet-hosting layer so that
/// filter chips work correctly in canvas without needing the full app shell.
private struct TransactionsPreviewHost: View {
    @State private var navState = AppNavigationState()

    var body: some View {
        TransactionsView(
            periodLabel: "December 2024",
            cashflow: "All",
            category: nil
        )
        .environment(navState)
        .customBottomSheet(
            isPresented:   $navState.txFilterSheetPresented,
            compactHeight: navState.txFilterSheetHeight
        ) {
            navState.txFilterSheetContent
        }
        .customBottomSheet(
            isPresented:   $navState.txDatePickerPresented,
            compactHeight: navState.txDatePickerHeight
        ) {
            if let onCommit = navState.txDatePickerOnCommit,
               let onDone   = navState.txDatePickerOnDone {
                TxDatePickerSheet(
                    initialStart:   navState.txDatePickerInitialStart,
                    initialEnd:     navState.txDatePickerInitialEnd,
                    onCommit:       onCommit,
                    onDone:         onDone,
                    onHeightChange: { navState.txDatePickerHeight = $0 }
                )
            }
        }
        .customBottomSheet(
            isPresented:   $navState.txAllFiltersSheetPresented,
            compactHeight: navState.txAllFiltersSheetHeight
        ) {
            navState.txAllFiltersSheetContent
        }
    }
}

struct TransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsPreviewHost()
    }
}
#endif
