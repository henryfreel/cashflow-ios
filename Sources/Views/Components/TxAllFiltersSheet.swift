import SwiftUI

// MARK: - All Filters navigation sheet

/// Bottom sheet that lists every filter category and supports inline push/pop navigation
/// into individual filter views — all within the same sheet, no dismiss/reopen cycle.
struct TxAllFiltersSheet: View {

    // MARK: Filter options (for inline drill-down views)

    let locationOptions: [TxFilterOption]
    let cashflowOptions: [TxFilterOption]
    let categoryOptions: [TxFilterOption]

    /// Calculates the correct compact height for a given non-date filter's sheet.
    let filterSheetHeight: (TxActiveFilter) -> CGFloat

    // MARK: Initial filter state

    let initialLocationKeys: Set<String>
    let initialCashflowKeys: Set<String>
    let initialCategoryKeys: Set<String>
    let initialDateStart:    Date?
    let initialDateEnd:      Date?

    // MARK: Callbacks

    var onClearAll:     (() -> Void)?                            = nil
    var onDone:         (() -> Void)?                            = nil
    /// Called when a non-date filter's selection is committed.
    var onCommitFilter: ((TxActiveFilter, Set<String>) -> Void)? = nil
    /// Called when the date range is committed from the inline date picker.
    var onCommitDate:   ((Date?, Date?) -> Void)?                = nil
    /// Called whenever the sheet needs a different compact height.
    var onHeightChange: ((CGFloat) -> Void)?                     = nil

    /// Whether to show the Date row. Set false when the caller provides its own date navigation.
    var showDateRow: Bool = true

    /// Compact height = top-pad(24) + header(48) + gap(16) + N rows × 56 + bottom-pad(64)
    static let compactHeight: CGFloat = 376          // 4 rows (with date)
    static let compactHeightNoDate: CGFloat = 320    // 3 rows (without date)

    // MARK: Internal navigation state

    /// Staged copies of each filter's selection, kept in sync as the user commits changes
    /// so the All-Filters summary rows reflect the latest values without closing the sheet.
    @State private var locationKeys: Set<String>
    @State private var cashflowKeys: Set<String>
    @State private var categoryKeys: Set<String>
    @State private var dateStart:    Date?
    @State private var dateEnd:      Date?

    /// Which filter page is currently pushed. `nil` = all-filters list.
    @State private var drillFilter: TxActiveFilter? = nil

    // MARK: Init

    init(
        locationOptions:     [TxFilterOption],
        cashflowOptions:     [TxFilterOption],
        categoryOptions:     [TxFilterOption],
        filterSheetHeight:   @escaping (TxActiveFilter) -> CGFloat,
        initialLocationKeys: Set<String>,
        initialCashflowKeys: Set<String>,
        initialCategoryKeys: Set<String>,
        initialDateStart:    Date?,
        initialDateEnd:      Date?,
        onClearAll:          (() -> Void)?                            = nil,
        onDone:              (() -> Void)?                            = nil,
        onCommitFilter:      ((TxActiveFilter, Set<String>) -> Void)? = nil,
        onCommitDate:        ((Date?, Date?) -> Void)?                = nil,
        onHeightChange:      ((CGFloat) -> Void)?                     = nil
    ) {
        self.locationOptions     = locationOptions
        self.cashflowOptions     = cashflowOptions
        self.categoryOptions     = categoryOptions
        self.filterSheetHeight   = filterSheetHeight
        self.initialLocationKeys = initialLocationKeys
        self.initialCashflowKeys = initialCashflowKeys
        self.initialCategoryKeys = initialCategoryKeys
        self.initialDateStart    = initialDateStart
        self.initialDateEnd      = initialDateEnd
        self.onClearAll          = onClearAll
        self.onDone              = onDone
        self.onCommitFilter      = onCommitFilter
        self.onCommitDate        = onCommitDate
        self.onHeightChange      = onHeightChange
        _locationKeys = State(initialValue: initialLocationKeys)
        _cashflowKeys = State(initialValue: initialCashflowKeys)
        _categoryKeys = State(initialValue: initialCategoryKeys)
        _dateStart    = State(initialValue: initialDateStart)
        _dateEnd      = State(initialValue: initialDateEnd)
    }

    // MARK: Body

    var body: some View {
        // All Filters page is the base layer — it never moves, so it is never
        // clipped by the sheet frame during height animations.
        allFiltersPage
            .allowsHitTesting(drillFilter == nil)
        // Fill the full sheet content area so both overlays inherit that size.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Dim overlay: extends 24pt upward (negative padding) to cover the sheet's
        // top padding / drag-handle zone so no undimmed white strip is visible.
        // The sheet card's own clipShape clips the overflow at the card boundary.
        .overlay {
            if drillFilter != nil {
                Color.black.opacity(0.18)
                    .padding(.top, -24)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        // Filter page overlay: .overlay guarantees this is ALWAYS rendered on
        // top of the base layer — even during the removal transition — which
        // prevents the z-order flip that made the exiting view look transparent.
        // No outer .clipped() here — the sheet card's clipShape handles it.
        .overlay(alignment: .top) {
            if let filter = drillFilter {
                ZStack(alignment: .top) {
                    // Extend white background 24pt upward to cover the sheet's
                    // top padding / drag-handle zone, matching the dim overlay.
                    Color.white
                        .padding(.top, -24)
                    if filter == .date {
                        TxDateSheet(
                            initialStart: dateStart,
                            initialEnd:   dateEnd,
                            onCommit: { start, end in
                                dateStart = start
                                dateEnd   = end
                                onCommitDate?(start, end)
                            },
                            onDone:         { onDone?() },
                            onBack:         { popBack() },
                            onHeightChange: { h in onHeightChange?(h) }
                        )
                    } else {
                        TxFilterSheet(
                            filter:      filter,
                            options:     options(for: filter),
                            initialKeys: keys(for: filter),
                            onCommit: { newKeys in
                                updateKeys(for: filter, with: newKeys)
                                onCommitFilter?(filter, newKeys)
                            },
                            onDone: { onDone?() },
                            onBack: { popBack() }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing))
            }
        }
    }

    // MARK: - All Filters page

    @ViewBuilder
    private var allFiltersPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Filter by")
                    .font(.heading30)
                    .foregroundStyle(Color.black.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    locationKeys = []
                    cashflowKeys = []
                    categoryKeys = []
                    dateStart    = nil
                    dateEnd      = nil
                    onClearAll?()
                } label: {
                    Text("Clear all")
                        .font(.paragraphSemibold30)
                        .foregroundStyle(Color(white: 0.063))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Button { onDone?() } label: {
                    Text("Done")
                        .font(.paragraphSemibold30)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color(white: 0.063))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 48)

            VStack(spacing: 0) {
                AllFiltersRow(label: "Location", value: displayValue(locationKeys, options: locationOptions)) { drillInto(.location) }
                if showDateRow {
                    AllFiltersRow(label: "Date", value: computedDateValue) { drillInto(.date) }
                }
                AllFiltersRow(label: "Cashflow", value: displayValue(cashflowKeys, options: cashflowOptions)) { drillInto(.cashflow) }
                AllFiltersRow(label: "Category", value: displayValue(categoryKeys, options: categoryOptions)) { drillInto(.category) }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 64)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Navigation helpers

    private func drillInto(_ filter: TxActiveFilter) {
        let h: CGFloat = filter == .date ? TxDateSheet.compactHeight : filterSheetHeight(filter)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            drillFilter = filter
            onHeightChange?(h)
        }
    }

    private func popBack() {
        let h: CGFloat = showDateRow ? TxAllFiltersSheet.compactHeight : TxAllFiltersSheet.compactHeightNoDate
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            drillFilter = nil
            onHeightChange?(h)
        }
    }

    // MARK: - Filter data helpers

    private func options(for filter: TxActiveFilter) -> [TxFilterOption] {
        switch filter {
        case .location: return locationOptions
        case .cashflow: return cashflowOptions
        case .category: return categoryOptions
        case .date:     return []
        }
    }

    private func keys(for filter: TxActiveFilter) -> Set<String> {
        switch filter {
        case .location: return locationKeys
        case .cashflow: return cashflowKeys
        case .category: return categoryKeys
        case .date:     return []
        }
    }

    private func updateKeys(for filter: TxActiveFilter, with newKeys: Set<String>) {
        switch filter {
        case .location: locationKeys = newKeys
        case .cashflow: cashflowKeys = newKeys
        case .category: categoryKeys = newKeys
        case .date:     break
        }
    }

    private func displayValue(_ keys: Set<String>, options: [TxFilterOption] = []) -> String {
        switch keys.count {
        case 0:  return "All"
        case 1:  return TransactionsView.label(forKey: keys.first!, in: options)
        default: return "\(keys.count) selected"
        }
    }

    /// Human-readable date range label computed from the staged date state.
    /// Returns "" when no date is selected so the row shows no secondary text.
    private var computedDateValue: String {
        guard let start = dateStart else { return "" }
        return TransactionsView.chipDateLabel(start: start, end: dateEnd)
    }
}

// MARK: - Single filter row

private struct AllFiltersRow: View {
    let label:  String
    let value:  String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(label)
                    .font(.paragraphMedium30)
                    .foregroundStyle(Color.black.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !value.isEmpty {
                    Text(value)
                        .font(.paragraph30)
                        .foregroundStyle(Color.black.opacity(0.9))
                }

                Image("SheetRowChevron")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(Color.gray4)
                    .frame(width: 24, height: 24)
            }
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1)
        }
    }
}
