import SwiftUI
import UIKit

// MARK: - Month group model

struct TxMonthGroup: Identifiable {
    let id: String
    let title: String
    let items: [Transaction]
}

func txBuildGroups(from items: [Transaction]) -> [TxMonthGroup] {
    struct E { var month: Int; var year: Int; var items: [Transaction] }
    let names = ["January","February","March","April","May","June",
                 "July","August","September","October","November","December"]
    let cal = Calendar.current
    var keys: [String] = []
    var map: [String: E] = [:]
    for tx in items {
        let c = cal.dateComponents([.year,.month], from: tx.date)
        let y = c.year ?? 0
        let m = c.month ?? 0
        let k = String(format: "%04d-%02d", y, m)
        if map[k] == nil { keys.append(k); map[k] = E(month: m, year: y, items: []) }
        map[k]!.items.append(tx)
    }
    return keys.sorted(by: >).compactMap { k -> TxMonthGroup? in
        guard let e = map[k] else { return nil }
        let name = names[max(0, min(11, e.month - 1))]
        return TxMonthGroup(id: k, title: "\(name) \(e.year)", items: e.items)
    }
}

// MARK: - Filter bar

struct TxFilterBar: View {
    let periodLabel: String
    let cashflow: String
    let category: String?
    var location: String? = nil
    var hasFilters: Bool = false
    var transactionCount: Int = 0
    var onClear:          (() -> Void)? = nil
    var onTapLocation:    (() -> Void)? = nil
    var onTapDate:        (() -> Void)? = nil
    var onTapCashflow:    (() -> Void)? = nil
    var onTapCategory:    (() -> Void)? = nil
    var onTapAllFilters:  (() -> Void)? = nil

    @Binding var isSearching: Bool
    @Binding var searchText: String

    @FocusState private var isFocused: Bool

    // Separate from hasFilters: controls whether the count row occupies layout space.
    // Trails hasFilters on the way out — only collapses after the opacity fade finishes.
    @State private var showCountRowLayout: Bool = false

    // Frozen at the last filtered count so the number doesn't jump to the
    // full total during the fade-out animation when filters are cleared.
    @State private var frozenCount: Int = 0

    // Guards the keyboard-focus onChange so the pre-warm toggle doesn't
    // accidentally trigger the keyboard before the user taps.
    @State private var isPrewarming: Bool = false

    private var activeFilterCount: Int {
        (periodLabel.isEmpty ? 0 : 1)
        + (cashflow == "All" || cashflow.isEmpty ? 0 : 1)
        + (category != nil ? 1 : 0)
        + (location != nil ? 1 : 0)
    }

    // Bar is visible whenever chip filters OR text search are active.
    private var showCountRow: Bool { hasFilters || !searchText.isEmpty }

    // Estimated width of TxFilterCountButton: icon(8+24+8=40) or icon+badge(8+24+4+~8+10=54)
    private var filterButtonWidth: CGFloat { activeFilterCount > 0 ? 54 : 40 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
        GeometryReader { geo in
            // expandedSearchWidth leaves exactly enough room for the morph chip
            // (filterButtonWidth) plus 8pt gap and 24pt padding each side.
            let fbw: CGFloat = activeFilterCount > 0 ? 54 : 40
            let expandedSearchWidth = geo.size.width - 56 - fbw

            // Single ScrollView — search icon, morph chip, and remaining chips
            // all live in one horizontal row and scroll together.
            // When searching: scroll is locked and the search container + morph chip
            // fill the viewport exactly; other chips are pushed off to the right.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 8) {

                    // ── Search container — width animates 40 → expandedSearchWidth ──
                    Color.clear
                        .frame(width: isSearching ? expandedSearchWidth : 40, height: 40)
                        // Search icon: 40pt zone anchored to leading, never drifts.
                        .overlay(alignment: .leading) {
                            Image("NavSearch")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .foregroundStyle(Color.gray1)
                                .frame(width: 18, height: 18)
                                .frame(width: 40, height: 40)
                                .opacity(isSearching ? 0 : 1)
                                .animation(nil, value: isSearching)
                        }
                        // Expanded content: back arrow + textfield + X; instant swap.
                        .overlay(alignment: .leading) {
                            HStack(spacing: 12) {
                                Button {
                                    searchText = ""
                                    withAnimation(.easeInOut(duration: 0.25)) { isSearching = false }
                                } label: {
                                    Image("CalNavArrow")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .rotationEffect(.degrees(-90))
                                        .foregroundStyle(Color.gray1)
                                        .frame(width: 16, height: 16)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                .allowsHitTesting(isSearching)

                                TextField("", text: $searchText)
                                    .font(.paragraph20)
                                    .foregroundStyle(Color.gray1)
                                    .tint(Color.gray1)
                                    .focused($isFocused)
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                    .overlay(alignment: .leading) {
                                        Text("Search all transactions")
                                            .font(.paragraph20)
                                            .foregroundStyle(Color.gray3)
                                            .opacity((isSearching && searchText.isEmpty) ? 1 : 0)
                                            .animation(.easeInOut(duration: 0.25), value: isSearching)
                                            .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
                                            .allowsHitTesting(false)
                                    }
                                    .allowsHitTesting(isSearching)
                                    .onSubmit {
                                        // Return key with empty field collapses back to chip
                                        if searchText.isEmpty {
                                            withAnimation(.easeInOut(duration: 0.25)) { isSearching = false }
                                        }
                                    }

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        // If the field lost focus (keyboard hidden), bring it back
                                        if !isFocused {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                isFocused = true
                                            }
                                        }
                                    } label: {
                                        Image("TxSearchClear")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundStyle(Color.gray4)
                                            .frame(width: 13, height: 13)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(.plain)
                                    .allowsHitTesting(isSearching)
                                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                                }
                            }
                            .padding(.leading, 8)
                            .padding(.trailing, 12)
                            .frame(maxWidth: .infinity)
                            .opacity(isSearching ? 1 : 0)
                            .animation(nil, value: isSearching)
                            .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
                        }
                        .clipped()
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    isFocused ? Color.gray1 : Color.gray1.opacity(0.15),
                                    lineWidth: 1
                                )
                                .animation(.easeInOut(duration: 0.2), value: isFocused)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isSearching else { return }
                            withAnimation(.easeInOut(duration: 0.25)) { isSearching = true }
                        }

                    // ── Morph chip: Location filter ↔ All Filters button ──
                    // Same container, width + content both animate with isSearching.
                    // Dismiss keyboard before opening the all-filters sheet so it
                    // doesn't cover the sheet (isFocused lives here in TxFilterBar).
                    TxMorphFilterChip(
                        isSearching: isSearching,
                        activeFilterCount: activeFilterCount,
                        locationValue: location,
                        onTapLocation: onTapLocation,
                        onTapAllFilters: {
                            // Dismiss keyboard first, then present the sheet on the
                            // next run-loop tick so the two state changes don't conflict.
                            isFocused = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                onTapAllFilters?()
                            }
                        }
                    )

                    // ── Remaining chips — fade out and are pushed off-screen when searching ──
                    TxChip(label: "Date",     value: periodLabel.isEmpty ? nil : periodLabel, onTap: onTapDate)
                        .opacity(isSearching ? 0 : 1)
                        .allowsHitTesting(!isSearching)
                    TxChip(label: "Cashflow", value: cashflow == "All" || cashflow.isEmpty ? nil : cashflow, onTap: onTapCashflow)
                        .opacity(isSearching ? 0 : 1)
                        .allowsHitTesting(!isSearching)
                    TxChip(label: "Category", value: category, onTap: onTapCategory)
                        .opacity(isSearching ? 0 : 1)
                        .allowsHitTesting(!isSearching)
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.25), value: isSearching)
                .animation(.easeInOut(duration: 0.25),
                           value: "\(periodLabel)\(cashflow)\(category ?? "")\(location ?? "")")
            }
            .scrollDisabled(isSearching)
            .frame(width: geo.size.width, height: 40)
        }
        .frame(height: 40)

        // ── Count + Clear row ──
        // showCountRowLayout controls layout space; showCountRow controls opacity.
        // The row is visible whenever ANY filtering is active — chips or text search.
        // The "Clear filters" button is only shown when chip-based filters are active
        // so tapping it while there's still search text leaves the row visible.
        // On hide: opacity fades to 0 first (0.25s), then layout collapses (0.2s).
        // On show: layout expands immediately, then opacity fades in (0.25s).
        if showCountRowLayout {
            HStack(alignment: .center, spacing: 0) {
                Text("\(frozenCount) result\(frozenCount == 1 ? "" : "s")")
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray1)

                Spacer()

                if hasFilters {
                    Button { onClear?() } label: {
                        Text("Clear filters")
                            .font(.paragraphSemibold20)
                            .foregroundStyle(Color.blue3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .frame(height: 32)
                }
            }
            .frame(height: 32)
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .padding(.top, 4)
            .padding(.bottom, 4)
            .background(Color.gray7, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .opacity(showCountRow ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: showCountRow)
        }

        } // VStack
        .padding(.bottom, showCountRowLayout ? 8 : 16)
        .onChange(of: showCountRow, initial: true) { _, newValue in
            if newValue {
                // Either filters or search is active: sync count and expand layout immediately.
                frozenCount = transactionCount
                showCountRowLayout = true
            } else {
                // Collapse layout at the same time as the opacity fade so the list
                // moves up in sync — no staggered delay.
                withAnimation(.easeInOut(duration: 0.25)) {
                    showCountRowLayout = false
                }
            }
        }
        .onChange(of: transactionCount) { _, newValue in
            // Keep frozenCount live while any filter (chips or text) is active.
            if showCountRow { frozenCount = newValue }
        }
        .onChange(of: isSearching) { _, newValue in
            // Skip keyboard focus during the silent pre-warm toggle on appear.
            guard !isPrewarming else { return }
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isFocused = true }
            } else {
                isFocused = false
            }
        }
        .onAppear {
            // Pre-warm the EXACT animation path the user will trigger on first tap:
            // animate isSearching true→false at near-zero duration (0.0001 s < one frame)
            // so it's invisible but forces SwiftUI to compile Metal shaders, start the
            // CA display link, and cache geometry for the real view subtree.
            // isPrewarming suppresses keyboard focus during the silent toggle.
            isPrewarming = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.0001)) { isSearching = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.0001)) { isSearching = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isPrewarming = false
                    }
                }
            }
        }
    }
}


// MARK: - Morph chip: Location filter ↔ All Filters button

struct TxMorphFilterChip: View {
    let isSearching: Bool
    let activeFilterCount: Int
    let locationValue: String?
    var onTapLocation:   (() -> Void)? = nil
    var onTapAllFilters: (() -> Void)? = nil

    private var filterButtonWidth: CGFloat { activeFilterCount > 0 ? 54 : 40 }

    var body: some View {
        // Wrap in a Button (not onTapGesture) so that it has higher gesture
        // priority than the surrounding ScrollView's disabled scroll recognizer.
        Button {
            if isSearching { onTapAllFilters?() } else { onTapLocation?() }
        } label: {
            // The location label HStack IS the base view — it hugs its content
            // naturally so the chip is always exactly as wide as the text needs.
            // fixedSize() on each Text prevents the frame constraint from compressing
            // or wrapping the label when the container is narrower than the text.
            HStack(spacing: 6) {
                Text("Location")
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray3)
                    .fixedSize()
                    .opacity(isSearching ? 0 : 1)
                if let v = locationValue {
                    Text(v)
                        .font(.paragraphSemibold20)
                        .foregroundStyle(Color.gray1)
                        .fixedSize()
                        .opacity(isSearching ? 0 : 1)
                }
            }
            .padding(.horizontal, 12)
            .frame(width: isSearching ? filterButtonWidth : nil, height: 40)
            // ── Filter button content — fades in with the parent animation ──
            .overlay {
                HStack(spacing: 4) {
                    Image("TxFilterIcon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.gray1)
                        .frame(width: 18, height: 12)
                        .frame(width: 24, height: 24)
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.paragraphSemibold30)
                            .foregroundStyle(Color.blue3)
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, activeFilterCount > 0 ? 10 : 8)
                .opacity(isSearching ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: activeFilterCount)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.gray1.opacity(0.15), lineWidth: 1)
            }
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expanded search bar (search mode)

struct TxSearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    var activeFilterCount: Int = 0
    var onTapFilter: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Expanded text field + back + clear
            HStack(spacing: 12) {
                // Back — exits search mode
                Button {
                    text = ""
                    withAnimation(.easeInOut(duration: 3.0)) { isSearching = false }
                } label: {
                    Image("CalNavArrow")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(-90))
                        .foregroundStyle(Color.gray1)
                        .frame(width: 16, height: 16)
                        .frame(width: 24, height: 24)  // touch target
                }
                .buttonStyle(.plain)

                // Text field
                TextField("", text: $text)
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray1)
                    .tint(Color.gray1)
                    .placeholder(when: text.isEmpty) {
                        Text("Search all transactions")
                            .font(.paragraph20)
                            .foregroundStyle(Color.gray3)
                    }
                    .focused($isFocused)
                    .frame(maxWidth: .infinity)

                // X clear button — only when there's text
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image("TxSearchClear")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.gray4)
                            .frame(width: 13, height: 13)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.gray1.opacity(0.15), lineWidth: 1)
            }
            .animation(.easeInOut(duration: 0.15), value: text.isEmpty)

            // Filter count button — dismiss keyboard first, then open filter sheet
            TxFilterCountButton(count: activeFilterCount, onTap: {
                isFocused = false
                onTapFilter?()
            })
        }
        .onChange(of: isSearching) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isFocused = true
                }
            } else {
                isFocused = false
            }
        }
    }
}

// MARK: - Filter count button

struct TxFilterCountButton: View {
    let count: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button { onTap?() } label: {
            HStack(spacing: 4) {
                // SVG viewBox is 18×12 — match that exactly, with a 24pt layout frame
                Image("TxFilterIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.gray1)
                    .frame(width: 18, height: 12)
                    .frame(width: 24, height: 24)

                if count > 0 {
                    Text("\(count)")
                        .font(.paragraphSemibold30)
                        .foregroundStyle(Color.blue3)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            // Figma: pl-8 pr-10 when count shown, symmetric px-8 when icon only
            .padding(.leading, 8)
            .padding(.trailing, count > 0 ? 10 : 8)
            .frame(height: 40)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.gray1.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: count)
    }
}

// MARK: - Clear filters chip

struct TxClearFiltersChip: View {
    var onClear: (() -> Void)? = nil
    var body: some View {
        Button(action: { onClear?() }) {
            Text("Clear filters")
                .font(.paragraphSemibold20)
                .foregroundStyle(Color.blue3)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.gray1.opacity(0.15), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search icon button (normal mode)

struct TxSearchButton: View {
    var onTap: (() -> Void)? = nil
    var body: some View {
        Button { onTap?() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.gray1.opacity(0.15), lineWidth: 1)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.gray1)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder helper

private extension View {
    @ViewBuilder
    func placeholder<P: View>(when condition: Bool, @ViewBuilder placeholder: () -> P) -> some View {
        ZStack(alignment: .leading) {
            if condition { placeholder() }
            self
        }
    }
}

struct TxChip: View {
    let label: String
    var value: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        let chip = HStack(spacing: 6) {
            Text(label).font(.paragraph20).foregroundStyle(Color.gray3)
            if let v = value {
                Text(v).font(.paragraphSemibold20).foregroundStyle(Color.gray1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.gray1.opacity(0.15), lineWidth: 1)
        }

        if let action = onTap {
            Button(action: action) { chip }.buttonStyle(.plain)
        } else {
            chip
        }
    }
}

// MARK: - Month section

struct TxMonthSection: View {
    let group: TxMonthGroup
    let lastID: UUID?
    let hasMore: Bool
    var showLocation: Bool = true
    let onLoadMore: () -> Void
    var onSelectTx: ((Transaction) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(group.items) { tx in
                Group {
                    if case .cardPaymentGroup = tx.type {
                        TxGroupRow(transaction: tx, showLocation: showLocation, onSelectTx: onSelectTx)
                    } else {
                        TxRow(transaction: tx, showLocation: showLocation)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelectTx?(tx) }
                    }
                }
                .padding(.horizontal, 24)
                .onAppear {
                    if tx.id == lastID && hasMore { onLoadMore() }
                }
            }
        }
    }
}

// MARK: - Row

struct TxRow: View {
    let transaction: Transaction
    /// When false, location is hidden from the right-side subtitle (used when
    /// the list is already filtered to a single location — showing it on every
    /// row would be redundant).
    var showLocation: Bool = true
    /// Controls the chevron direction for group rows (passed in from TxGroupRow).
    var isExpanded: Bool = false

    /// Internal and automated transfer rows show an account name as their title —
    /// the right subtitle is suppressed and the amount top-aligns with it.
    /// Bank transfers are excluded: their title is the bank name, so the source/
    /// destination account can still appear as the right-side subtitle.
    private var isTransferRow: Bool {
        switch transaction.type {
        case .internalTransfer, .automatedTransfer: return true
        default: return false
        }
    }

    /// Right-side secondary text logic:
    ///   • Transfer rows          → nil (account name is already the title)
    ///   • Card purchase          → masked card/account identifier (cardInfo)
    ///   • Account-level / sales  → location name (when showLocation)
    private var rightSubtitle: String? {
        if isTransferRow { return nil }
        if let card = transaction.cardInfo { return card }
        if showLocation { return transaction.locationName }
        return nil
    }

    private var isGroup: Bool {
        if case .cardPaymentGroup = transaction.type { return true }
        return false
    }

    var body: some View {
        HStack(alignment: isTransferRow ? .top : .center, spacing: 16) {
            TxIcon(transaction: transaction)
            TxRowText(name: transaction.merchantName, sub: transaction.subtitle)
            Spacer(minLength: 8)
            TxRowMoney(amount: transaction.amount, secondaryText: rightSubtitle)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .leading) {
            if isGroup {
                Image("TxGroupChevron")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .foregroundStyle(Color.gray3)
                    .offset(x: -18)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Group row (expandable card payment groups)

struct TxGroupRow: View {
    let transaction: Transaction
    var showLocation: Bool = true
    var onSelectTx: ((Transaction) -> Void)? = nil
    @State private var isExpanded = false

    private var count: Int {
        if case .cardPaymentGroup(let n) = transaction.type { return n }
        return 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                TxRow(transaction: transaction, showLocation: showLocation, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            // Always in the layout but height=0 when collapsed so children
            // can only reveal downward — never bleeding above the parent row.
            ZStack(alignment: .topLeading) {
                // Connecting vertical line — inset 40pt from top and bottom
                Rectangle()
                    .fill(Color(white: 0, opacity: 0.12))
                    .frame(width: 1)
                    .padding(.leading, 20)
                    .padding(.vertical, 40)

                // Child rows
                    VStack(spacing: 0) {
                        let share = count > 0 ? transaction.amount / Double(count) : 0
                        ForEach(0..<count, id: \.self) { _ in
                            let childTx = Transaction(
                                id: UUID(),
                                date: transaction.date,
                                amount: share,
                                merchantName: "Card payment",
                                subtitle: transaction.subtitle,
                                locationName: transaction.locationName,
                                cardInfo: transaction.cardInfo,
                                type: .cardPayment,
                                expenseCategory: transaction.expenseCategory,
                                isRevenue: transaction.isRevenue
                            )
                            HStack(alignment: .center, spacing: 16) {
                                ZStack {
                                    Circle().fill(Color(white: 0, opacity: 0.05))
                                    Image("TxCardIcon")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 20, height: 14)
                                        .foregroundStyle(Color.gray1)
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Card payment")
                                        .font(.paragraphMedium30)
                                        .foregroundStyle(Color.gray1)
                                        .lineLimit(1)
                                    Text(transaction.subtitle)
                                        .font(.paragraph20)
                                        .foregroundStyle(Color.gray3)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                TxRowMoney(amount: share, secondaryText: nil)
                            }
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelectTx?(childTx) }
                        }
                    }
                .padding(.leading, 56)
            }
            .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
            .clipped()
            .animation(.easeInOut(duration: 0.25), value: isExpanded)
        }
    }
}

struct TxRowText: View {
    let name: String
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.paragraphMedium30).foregroundStyle(Color.gray1).lineLimit(1)
            Text(sub).font(.paragraph20).foregroundStyle(Color.gray3).lineLimit(1)
        }
    }
}

struct TxRowMoney: View {
    let amount: Double
    let secondaryText: String?
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(TxRowMoney.fmt(amount))
                .font(.paragraphMedium30).foregroundStyle(Color.gray1).lineLimit(1)
            if let sec = secondaryText {
                Text(sec)
                    .font(.paragraph20).foregroundStyle(Color.gray3).lineLimit(1)
            } else {
                // Invisible spacer keeps row height consistent with two-line rows.
                // Rendered transparent so it occupies space without showing text.
                Text(" ").font(.paragraph20).hidden()
            }
        }
    }
    static func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        let s = f.string(from: NSNumber(value: abs(v))) ?? "$0"
        return v < 0 ? "-\(s)" : s
    }
}

// MARK: - Avatar kind

/// The four visual styles for a transaction avatar.
/// Mirrors the four types defined in the Figma design system.
enum TxAvatarKind {
    /// Type 1 — translucent gray bg (`rgba(0,0,0,0.05)`), dark icon at ~24pt.
    case grayIcon
    /// Type 2 — solid brand-color bg, white icon/symbol at ~24pt.
    case colorIcon
    /// Type 3 — full-bleed brand photo filling the 40pt circle.
    ///   `border` true when the photo has a light or white background.
    ///   Brand accent hex stored on `Transaction.accentHex` for the detail view.
    case fullImage(border: Bool)
    /// Type 4 — 24pt brand logo centered on a solid bg color.
    ///   `border` true when bg lacks contrast against the white row background.
    ///   The bg color IS the accent hex (shown in avatar AND stored for detail view).
    case logoImage(border: Bool)
}

// MARK: - Icon config

struct TxIconConfig {
    let kind: TxAvatarKind
    let bg: Color
    /// Icon, symbol, or placeholder view rendered inside the avatar circle.
    /// For `.fullImage`: swap in `Image("asset").resizable().scaledToFill()` when photo is available.
    /// For `.logoImage`: swap in `Image("logo").resizable().scaledToFit()` when logo asset is available.
    let content: AnyView
    /// When true, the detail view avatar ring is white instead of the default light-header band color.
    var whiteAvatarBorder: Bool = false

    var border: Bool {
        switch kind {
        case .fullImage(let b), .logoImage(let b): return b
        default: return false
        }
    }

    // MARK: Factory

    static func make(for tx: Transaction) -> TxIconConfig {
        switch tx.type {
        case .cardPayment:
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color.gray6,
                content: AnyView(
                    Image("TxCardIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 14)
                        .foregroundStyle(Color.gray1)
                        .frame(width: 24, height: 24)
                ),
                whiteAvatarBorder: true)
        case .cardPaymentGroup:
            return TxIconConfig(
                kind: .colorIcon,
                bg: Color.gray1,
                content: AnyView(
                    Image("TxCardIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 14)
                        .foregroundStyle(Color.white)
                        .frame(width: 24, height: 24)
                ))

        case .internalTransfer:
            let arrowContent: AnyView = tx.isRevenue
                ? AnyView(
                    Image("TxArrowLeft")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(-45))
                        .foregroundStyle(Color.gray1)
                  )
                : AnyView(
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.gray1)
                  )
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color.gray6,
                content: arrowContent,
                whiteAvatarBorder: true)

        case .automatedTransfer:
            let isOutgoing = tx.amount < 0
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color.gray6,
                content: AnyView(
                    isOutgoing
                        ? AnyView(
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.gray1)
                          )
                        : AnyView(
                            Image("TxCycleIcon")
                                .resizable().renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(Color.gray1)
                          )
                ),
                whiteAvatarBorder: true)

        case .onlineOrder:
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color.gray6,
                content: AnyView(
                    // SVG is 18×18pt inside a 24pt container (list view).
                    // At 2× scaleEffect in TxDetailIcon: 36×36pt inside a 48pt container.
                    Image("TxOnlineOrderIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.gray1)
                        .frame(width: 24, height: 24)
                ),
                whiteAvatarBorder: true)

        case .cashPayment:
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color.gray6,
                content: AnyView(
                    // SVG is 20×14pt inside a 24pt square container (list view).
                    // At 2× scaleEffect in TxDetailIcon: 40×28pt inside a 48pt container —
                    // matching the Figma inset of 8.33% L/R and 20.83% T/B.
                    Image("TxCashIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 14)
                        .foregroundStyle(Color.gray1)
                        .frame(width: 24, height: 24)
                ),
                whiteAvatarBorder: true)

        case .giftCard:
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color.gray6,
                content: AnyView(
                    // SVG is 20×17pt (35:30 ratio at 20pt width) inside a 24pt container.
                    // At 2× scaleEffect in TxDetailIcon: 40×34pt inside a 48pt container.
                    Image("TxGiftCardIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 17)
                        .foregroundStyle(Color.gray1)
                        .frame(width: 24, height: 24)
                ),
                whiteAvatarBorder: true)

        case .bankTransfer:
            return bankTransfer(name: tx.merchantName)

        case .purchase:
            return purchase(name: tx.merchantName)
        }
    }

    // MARK: Per-type builders

    private static func bankTransfer(name: String) -> TxIconConfig {
        switch name {
        case _ where name.hasPrefix("Chase"):
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.067, green: 0.482, blue: 0.800),
                content: AnyView(label("CH", .white)))
        case _ where name.hasPrefix("Bank of America"), _ where name.hasPrefix("BofA"):
            return TxIconConfig(
                kind: .logoImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-bank-of-america").resizable().scaledToFit()))
        case _ where name.hasPrefix("Wells Fargo"):
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.780, green: 0.082, blue: 0.086),
                content: AnyView(label("WF", .white)))
        default:
            return TxIconConfig(
                kind: .logoImage(border: true),
                bg: Color.white,
                content: AnyView(label(abbrev(name), Color.gray2)))
        }
    }

    private static func purchase(name: String) -> TxIconConfig {
        switch name {
        case "Square Payroll":
            return TxIconConfig(
                kind: .colorIcon,
                bg: Color(red: 0.325, green: 0.698, blue: 0.282),
                content: AnyView(
                    // SVG viewBox 20×16 — 20pt wide inside 24pt container (list view).
                    // At 2× scaleEffect in TxDetailIcon: 40×32pt inside a 48pt container.
                    Image("TxPayrollIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 16)
                        .foregroundStyle(Color.white)
                        .frame(width: 24, height: 24)
                ))
        case "Inventory":
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color(white: 0, opacity: 0.05),
                content: AnyView(
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.gray1)
                ))
        case "Home Depot":
            return TxIconConfig(
                kind: .fullImage(border: false),
                bg: Color(red: 1.0, green: 0.388, blue: 0.0),
                content: AnyView(Image("txn-home-depot").resizable().scaledToFill()))
        case "Whole Foods":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.0, green: 0.420, blue: 0.235),
                content: AnyView(Image("txn-whole-foods").resizable().scaledToFit()))
        case "Faire Wholesale":
            return TxIconConfig(
                kind: .fullImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-faire").resizable().scaledToFill()))
        case "Tundra":
            return TxIconConfig(
                kind: .fullImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-tundra").resizable().scaledToFill()))
        case "Next Level Apparel":
            return TxIconConfig(
                kind: .fullImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-next-level-apparel").resizable().scaledToFill()))
        case "Amazon":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 1.0, green: 0.6, blue: 0.0),  // #FF9900
                content: AnyView(Image("txn-amazon").resizable().scaledToFit()))
        case "Etsy":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.875, green: 0.412, blue: 0.169),
                content: AnyView(Image("txn-etsy").resizable().scaledToFit()))
        case "Github":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.141, green: 0.161, blue: 0.180),
                content: AnyView(label("GH", .white)))
        case "Uline":
            return TxIconConfig(
                kind: .fullImage(border: false),
                bg: Color(red: 0x01/255.0, green: 0x31/255.0, blue: 0x69/255.0),  // #013169
                content: AnyView(Image("txn-uline").resizable().scaledToFill()))
        case "Airtable":
            return TxIconConfig(
                kind: .logoImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-air-table").resizable().scaledToFit()))
        case "UPS":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.251, green: 0.129, blue: 0.122),  // #40211F
                content: AnyView(Image("txn-ups").resizable().scaledToFit()))
        case "Zendesk":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.027, green: 0.565, blue: 0.859),
                content: AnyView(label("ZD", .white)))
        case "Landlord LLC":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.024, green: 0.118, blue: 0.165),
                content: AnyView(Image("txn-rent").resizable().scaledToFit()))
        case "Blue Bottle Coffee":
            return TxIconConfig(
                kind: .fullImage(border: true),
                bg: Color(red: 0.969, green: 0.969, blue: 0.969),
                content: AnyView(Image("txn-blue-bottle").resizable().scaledToFill()))
        case "Señor Sisig":
            return TxIconConfig(
                kind: .logoImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-senor-sisig").resizable().scaledToFit()))
        case "Starbucks":
            return TxIconConfig(
                kind: .fullImage(border: false),
                bg: Color(red: 0.0, green: 0.439, blue: 0.290),
                content: AnyView(Image("txn-starbucks").resizable().scaledToFill()))
        case "DoorDash":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0xEB/255.0, green: 0x17/255.0, blue: 0x00/255.0),
                content: AnyView(Image("txn-doordash").resizable().scaledToFit()))
        case "Noissue":
            return TxIconConfig(
                kind: .fullImage(border: false),
                bg: Color(red: 0x2B/255.0, green: 0x18/255.0, blue: 0x46/255.0),
                content: AnyView(Image("txn-noissue").resizable().scaledToFill()))
        case "Slack":
            return TxIconConfig(
                kind: .fullImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-slack").resizable().scaledToFill()))
        case "Staples":
            return TxIconConfig(
                kind: .fullImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-staples").resizable().scaledToFill()))
        default:
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color(white: 0, opacity: 0.05),
                content: AnyView(label(abbrev(name), Color.gray3)))
        }
    }

    // MARK: Helpers

    private static func abbrev(_ n: String) -> String {
        let w = n.split(separator: " ")
        return w.count >= 2
            ? String(w[0].prefix(1) + w[1].prefix(1)).uppercased()
            : String(n.prefix(2)).uppercased()
    }

    private static func label(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.custom(AppFont.Text.semiBold, size: 13))
            .foregroundStyle(color)
    }
}

// MARK: - Icon view

struct TxIcon: View {
    let transaction: Transaction
    var body: some View {
        let cfg = TxIconConfig.make(for: transaction)
        ZStack {
            Circle().fill(cfg.bg)
            iconContent(cfg)
            if cfg.border {
                Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    @ViewBuilder
    private func iconContent(_ cfg: TxIconConfig) -> some View {
        switch cfg.kind {
        case .fullImage(_):
            cfg.content
                .frame(width: 40, height: 40)
                .clipped()
        case .logoImage(_):
            cfg.content
                .frame(width: 24, height: 24)
                .clipped()
        case .grayIcon, .colorIcon:
            cfg.content
        }
    }
}

