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

    @State private var showDatePicker: Bool = false
    @State private var activeFilter:   TxActiveFilter? = nil
    @State private var visibleCount:   Int  = 15
    @State private var isScrolled:     Bool = false

    @Environment(\.dismiss) private var dismiss

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
    private static let categoryOptions: [TxFilterOption] =
        ExpenseCategory.allCases.map { TxFilterOption(id: $0.rawValue, label: $0.rawValue) }

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

    private func chipValue(_ keys: Set<String>) -> String? {
        switch keys.count {
        case 0:  return nil
        case 1:  return keys.first
        default: return "\(keys.count) selected"
        }
    }

    private var dateLabelValue: String? {
        guard let start = selectedStartDate else { return nil }
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "en_US")

        if let end = selectedEndDate {
            let sy = cal.component(.year,  from: start)
            let sm = cal.component(.month, from: start)
            let ey = cal.component(.year,  from: end)
            let em = cal.component(.month, from: end)

            if sy == ey && sm == em {
                // Same month — "Dec 2024"
                fmt.dateFormat = "MMM yyyy"
                return fmt.string(from: start)
            } else if sy == ey {
                // Same year — "Jan – Dec 2024"
                fmt.dateFormat = "MMM"
                return "\(fmt.string(from: start)) – \(fmt.string(from: end)) \(sy)"
            } else {
                // Cross-year — "Jan 2023 – Dec 2024"
                fmt.dateFormat = "MMM yyyy"
                return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
            }
        } else {
            fmt.dateFormat = "MMM d, yyyy"
            return fmt.string(from: start)
        }
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

        // "2024" or "Jan - Dec, 2024"
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

    @ViewBuilder
    private func filterSheetContent(for filter: TxActiveFilter) -> some View {
        let binding = selectedBinding(for: filter)
        TxFilterSheet(
            filter:      filter,
            options:     options(for: filter),
            initialKeys: binding.wrappedValue,
            onCommit:    { newKeys in binding.wrappedValue = newKeys },
            onDone:      { activeFilter = nil }
        )
        .presentationDetents([.height(sheetHeight(for: filter)), .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.white)
    }

    // MARK: Sheet height (for non-date filters)

    private func sheetHeight(for filter: TxActiveFilter) -> CGFloat {
        let rowCount = options(for: filter).count
        let full = CGFloat(29 + 48 + 16 + 56 * (1 + rowCount) + 32)
        return min(full, UIScreen.main.bounds.height * 0.60)
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
                            selectedStartDate  = nil
                            selectedEndDate    = nil
                            selectedCashflows  = []
                            selectedCategories = []
                            selectedLocations  = []
                            visibleCount       = 15
                        },
                        onTapLocation: { activeFilter = .location  },
                        onTapDate:     { showDatePicker = true      },
                        onTapCashflow: { activeFilter = .cashflow   },
                        onTapCategory: { activeFilter = .category   }
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
                withAnimation(.easeInOut(duration: 0.2)) { isScrolled = scrolled }
            }
        }
        .navigationBarHidden(true)
        .background(Color.white)
        // Non-date filter sheet
        .sheet(item: $activeFilter) { filter in
            filterSheetContent(for: filter)
        }
        // Date picker sheet
        .sheet(isPresented: $showDatePicker) {
            TxDatePickerSheet(
                initialStart: selectedStartDate,
                initialEnd:   selectedEndDate,
                onCommit: { start, end in
                    selectedStartDate = start
                    selectedEndDate   = end
                    visibleCount      = 15
                },
                onDone: { showDatePicker = false }
            )
            .presentationDetents([.height(TxDatePickerSheet.compactHeight), .large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.white)
        }
        .onChange(of: selectedStartDate)  { _, _ in visibleCount = 15 }
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
