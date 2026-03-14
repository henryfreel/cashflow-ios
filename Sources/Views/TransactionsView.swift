import SwiftUI

struct TransactionsView: View {
    // Incoming filter context (used to pre-populate state on init)
    let periodLabel: String
    let cashflow:    String
    let category:    String?
    let location:    String?

    // MARK: Filter state
    @State private var selectedDates:      Set<String> = []
    @State private var selectedCashflows:  Set<String> = []
    @State private var selectedCategories: Set<String> = []
    @State private var selectedLocations:  Set<String> = []

    @State private var activeFilter: TxActiveFilter? = nil
    @State private var visibleCount: Int = 15
    @State private var isScrolled: Bool = false

    @Environment(\.dismiss) private var dismiss

    // MARK: Init

    init(periodLabel: String, cashflow: String, category: String?,
         location: String? = nil, transactions: [Transaction] = []) {
        self.periodLabel = periodLabel
        self.cashflow    = cashflow
        self.category    = category
        self.location    = location

        // Expand period label → constituent month keys (handles Month/Quarter/Year)
        let dates = Self.monthKeys(forPeriodLabel: periodLabel)
        if !dates.isEmpty { _selectedDates = State(initialValue: dates) }

        if cashflow != "All" && !cashflow.isEmpty {
            _selectedCashflows = State(initialValue: [cashflow])
        }
        if let cat = category {
            _selectedCategories = State(initialValue: [cat])
        }
        if let loc = location {
            _selectedLocations = State(initialValue: [loc])
        }
    }

    // MARK: Derived state

    private var hasFilters: Bool {
        !selectedDates.isEmpty || !selectedCashflows.isEmpty
            || !selectedCategories.isEmpty || !selectedLocations.isEmpty
    }

    /// Hide per-row location label when exactly one location is filtered
    /// (every visible row would show the same value — redundant).
    private var showLocation: Bool { selectedLocations.count != 1 }

    // MARK: Filter options (static where possible)

    private static let locationOptions: [TxFilterOption] = [
        TxFilterOption(id: "Hayes Valley",   label: "Hayes Valley"),
        TxFilterOption(id: "Bernal Heights", label: "Bernal Heights"),
        TxFilterOption(id: "The Mission",    label: "The Mission"),
    ]

    private static let cashflowOptions: [TxFilterOption] = [
        TxFilterOption(id: "Revenue",  label: "Revenue"),
        TxFilterOption(id: "Expenses", label: "Expenses"),
    ]

    private static let categoryOptions: [TxFilterOption] =
        ExpenseCategory.allCases.map { TxFilterOption(id: $0.rawValue, label: $0.rawValue) }

    /// Unique month-year labels derived from all available transactions, newest first.
    private var dateOptions: [TxFilterOption] {
        var seen   = Set<String>()
        var result = [TxFilterOption]()
        for tx in AppFinancials.allTransactions.sorted(by: { $0.date > $1.date }) {
            let k = Self.monthKey(tx.date)
            if seen.insert(k).inserted { result.append(TxFilterOption(id: k, label: k)) }
        }
        return result
    }

    private func options(for f: TxActiveFilter) -> [TxFilterOption] {
        switch f {
        case .location: return Self.locationOptions
        case .date:     return dateOptions
        case .cashflow: return Self.cashflowOptions
        case .category: return Self.categoryOptions
        }
    }

    private func selectedBinding(for f: TxActiveFilter) -> Binding<Set<String>> {
        switch f {
        case .location: return $selectedLocations
        case .date:     return $selectedDates
        case .cashflow: return $selectedCashflows
        case .category: return $selectedCategories
        }
    }

    // MARK: Chip display values

    private func chipValue(_ keys: Set<String>) -> String? {
        switch keys.count {
        case 0:  return nil
        case 1:  return keys.first
        default: return "\(keys.count) selected"
        }
    }

    /// For Date: if the current selectedDates exactly matches the original
    /// period label's expansion, show the original label (e.g. "Q4 2024")
    /// rather than "3 selected".
    private var dateLabelValue: String? {
        if selectedDates.isEmpty { return nil }
        let original = Self.monthKeys(forPeriodLabel: periodLabel)
        if !original.isEmpty && selectedDates == original { return periodLabel }
        return chipValue(selectedDates)
    }

    // MARK: Filtered items

    private var displayItems: [Transaction] {
        AppFinancials.allTransactions.filter { tx in
            let dateOk = selectedDates.isEmpty
                || selectedDates.contains(Self.monthKey(tx.date))
            let locOk  = selectedLocations.isEmpty
                || selectedLocations.contains(tx.locationName ?? "")
            let flowOk = selectedCashflows.isEmpty
                || (tx.isRevenue
                    ? selectedCashflows.contains("Revenue")
                    : selectedCashflows.contains("Expenses"))
            let catOk: Bool = {
                guard !selectedCategories.isEmpty else { return true }
                // Revenue transactions are not filtered by expense category
                guard let cat = tx.expenseCategory else { return true }
                return selectedCategories.contains(cat)
            }()
            return dateOk && locOk && flowOk && catOk
        }.sorted { $0.date > $1.date }
    }

    // MARK: Date helpers

    private static let monthNames = [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]

    /// "January 2024" key for a given date.
    static func monthKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(monthNames[max(0, min(11, (c.month ?? 1) - 1))]) \(c.year ?? 0)"
    }

    /// Expands a period label into the set of month-year keys it covers.
    ///   "December 2024" → ["December 2024"]
    ///   "Q4 2024"       → ["October 2024", "November 2024", "December 2024"]
    ///   "2024"          → ["January 2024", ..., "December 2024"]
    static func monthKeys(forPeriodLabel label: String) -> Set<String> {
        let parts = label.components(separatedBy: " ")
        if parts.count == 2, let year = Int(parts[1]) {
            let first = parts[0]
            if first.hasPrefix("Q"), let q = Int(first.dropFirst()), (1...4).contains(q) {
                let start = (q - 1) * 3
                return Set((start..<start + 3).map { "\(monthNames[$0]) \(year)" })
            }
            if monthNames.contains(first) { return [label] }
        }
        if parts.count == 1, let year = Int(parts[0]) {
            return Set(monthNames.map { "\($0) \(year)" })
        }
        // "Jan - Dec, 2024" (year header format used on detail pages)
        if label.contains("-"), let year = Int(label.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces) ?? "") {
            return Set(monthNames.map { "\($0) \(year)" })
        }
        return []
    }

    // MARK: Sheet height

    /// Content-fitted height: 24pt top pad + 48pt header + 16pt gap +
    /// 56pt × (All row + N option rows) + 64pt bottom pad.
    private func sheetHeight(for filter: TxActiveFilter) -> CGFloat {
        let rowCount = options(for: filter).count
        // 29pt grabber + 48pt header + 16pt gap + 56pt × (All + N rows) + 32pt bottom inset
        let full = CGFloat(29 + 48 + 16 + 56 * (1 + rowCount) + 32)
        // Cap compact state at 60% of screen height; user can swipe up to .large
        let max  = UIScreen.main.bounds.height * 0.60
        return min(full, max)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            SecondaryNavBar(title: "Transactions", onBack: { dismiss() }, isScrolled: isScrolled)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    TxFilterBar(
                        periodLabel:   dateLabelValue ?? "",
                        cashflow:      chipValue(selectedCashflows) ?? "All",
                        category:      chipValue(selectedCategories),
                        location:      chipValue(selectedLocations),
                        hasFilters:    hasFilters,
                        onClear: {
                            selectedDates      = []
                            selectedCashflows  = []
                            selectedCategories = []
                            selectedLocations  = []
                            visibleCount       = 15
                        },
                        onTapLocation: { activeFilter = .location },
                        onTapDate:     { activeFilter = .date     },
                        onTapCashflow: { activeFilter = .cashflow  },
                        onTapCategory: { activeFilter = .category  }
                    )
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                    if displayItems.isEmpty {
                        TxEmptyState()
                    } else {
                        TxPagedList(allItems: displayItems,
                                    visibleCount: $visibleCount,
                                    showLocation: showLocation)
                    }
                }
            }
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 0
            } action: { _, scrolled in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isScrolled = scrolled
                }
            }
        }
        .navigationBarHidden(true)
        .background(Color.white)
        .sheet(item: $activeFilter) { filter in
            TxFilterSheet(
                filter:      filter,
                options:     options(for: filter),
                initialKeys: selectedBinding(for: filter).wrappedValue,
                onCommit:    { newKeys in
                    selectedBinding(for: filter).wrappedValue = newKeys
                },
                onDone: { activeFilter = nil }
            )
            .presentationDetents([.height(sheetHeight(for: filter)), .large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(16)
            .presentationBackground(Color.white)
        }
        .onChange(of: selectedDates)      { _, _ in visibleCount = 15 }
        .onChange(of: selectedCashflows)  { _, _ in visibleCount = 15 }
        .onChange(of: selectedCategories) { _, _ in visibleCount = 15 }
        .onChange(of: selectedLocations)  { _, _ in visibleCount = 15 }
    }
}

// MARK: - Empty state

private struct TxEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("No transactions").font(.paragraphMedium30).foregroundStyle(Color.gray1)
            Text("Try adjusting the date range.").font(.paragraph20).foregroundStyle(Color.gray3)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }
}

// MARK: - Paged list

private struct TxPagedList: View {
    let allItems: [Transaction]
    @Binding var visibleCount: Int
    var showLocation: Bool = true
    var body: some View {
        let slice  = Array(allItems.prefix(visibleCount))
        let groups = txBuildGroups(from: slice)
        let lastID = groups.last?.items.last?.id
        let canLoad = visibleCount < allItems.count
        VStack(spacing: 24) {
            ForEach(groups) { g in
                TxMonthSection(group: g, lastID: lastID, hasMore: canLoad,
                               showLocation: showLocation) {
                    visibleCount = min(visibleCount + 15, allItems.count)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 32)
    }
}

// MARK: - Preview

#if DEBUG
struct TransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsView(
            periodLabel: "December 2024",
            cashflow: "All",
            category: nil
        )
    }
}
#endif
