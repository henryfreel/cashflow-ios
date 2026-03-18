import SwiftUI
import UIKit

// MARK: - Filter option model

struct TxFilterOption: Identifiable, Hashable {
    let id: String
    let label: String
    /// When true this item renders as a non-interactive section header, not a row.
    var isHeader: Bool = false

    static func header(_ title: String) -> TxFilterOption {
        TxFilterOption(id: "__header__\(title)", label: title, isHeader: true)
    }
}

// MARK: - Active filter enum

enum TxActiveFilter: String, Identifiable {
    case location, date, cashflow, category
    var id: String { rawValue }
    var title: String {
        switch self {
        case .location: return "Location"
        case .date:     return "Date"
        case .cashflow: return "Cashflow"
        case .category: return "Category"
        }
    }
}

// MARK: - Sheet view

struct TxFilterSheet: View {
    let filter: TxActiveFilter
    let options: [TxFilterOption]
    /// The committed selection passed in from the parent.
    let initialKeys: Set<String>
    /// Called with the final selection only when Done is tapped.
    let onCommit: (Set<String>) -> Void
    let onDone: () -> Void
    /// When set, renders a back-button header (drill-down from All Filters).
    /// Tapping back pops without committing.
    var onBack: (() -> Void)? = nil

    /// Staged selection — changes here do NOT propagate until Done is tapped.
    @State private var pendingKeys: Set<String>

    init(filter: TxActiveFilter, options: [TxFilterOption],
         initialKeys: Set<String>,
         onCommit: @escaping (Set<String>) -> Void,
         onDone: @escaping () -> Void,
         onBack: (() -> Void)? = nil) {
        self.filter      = filter
        self.options     = options
        self.initialKeys = initialKeys
        self.onCommit    = onCommit
        self.onDone      = onDone
        self.onBack      = onBack
        _pendingKeys     = State(initialValue: initialKeys)
    }

    private var selectableOptions: [TxFilterOption] { options.filter { !$0.isHeader } }

    private var someSelected: Bool {
        !pendingKeys.isEmpty && pendingKeys.count < selectableOptions.count
    }

    @State private var isScrolled = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Header (fixed, outside scroll) ───────────────────────────────
            if let onBack {
                drillDownHeader(onBack: onBack)
            } else {
                standaloneHeader
            }

            // ── Options (scrollable) ──────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    TxFilterRow(label: "All",
                                state: someSelected ? .indeterminate : .checked) {
                        pendingKeys = []
                    }
                    ForEach(options) { opt in
                        if opt.isHeader {
                            TxFilterSectionHeader(title: opt.label)
                        } else {
                            let state: TxCheckboxState =
                                (pendingKeys.isEmpty || pendingKeys.contains(opt.id))
                                ? .checked : .unchecked
                            TxFilterRow(label: opt.label, state: state) {
                                toggle(opt)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 32) }
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 0
            } action: { _, scrolled in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isScrolled = scrolled
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func toggle(_ opt: TxFilterOption) {
        guard !opt.isHeader else { return }
        if pendingKeys.contains(opt.id) {
            pendingKeys.remove(opt.id)
        } else {
            pendingKeys.insert(opt.id)
            if pendingKeys.count == selectableOptions.count { pendingKeys = [] }
        }
    }

    // MARK: - Headers

    /// Standard standalone header: left-aligned title + Done on the right.
    private var standaloneHeader: some View {
        HStack(spacing: 10) {
            Text(filter.title)
                .font(.heading30)
                .foregroundStyle(Color.gray1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onCommit(pendingKeys)
                onDone()
            } label: {
                Text("Done")
                    .font(.paragraphSemibold30)
                    .foregroundStyle(Color.white)
                    .frame(height: 48)
                    .padding(.horizontal, 22)
                    .background(Color.gray1)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 48)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
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

    /// Drill-down header (from All Filters): back button + centered title + Done.
    private func drillDownHeader(onBack: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image("NavBack")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Color.gray1)
                    .frame(width: 24, height: 24)
                    .padding(12)
                    .background(Color.gray6)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(filter.title)
                .font(.heading20)
                .foregroundStyle(Color.black.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                onCommit(pendingKeys)
                onDone()
            } label: {
                Text("Done")
                    .font(.paragraphSemibold30)
                    .foregroundStyle(Color.white)
                    .frame(height: 48)
                    .padding(.horizontal, 22)
                    .background(Color.gray1)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 48)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
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

// MARK: - Section header

struct TxFilterSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.custom(AppFont.Text.medium, size: 13))
            .foregroundStyle(Color.gray3)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }
}

// MARK: - Row

struct TxFilterRow: View {
    let label: String
    let state: TxCheckboxState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(label)
                    .font(.paragraphMedium30)
                    .foregroundStyle(Color.gray1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TxCheckbox(state: state)
            }
            .frame(height: 56)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Color.black.opacity(0.05).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Checkbox

enum TxCheckboxState { case unchecked, checked, indeterminate }

struct TxCheckbox: View {
    let state: TxCheckboxState

    var body: some View {
        ZStack {
            // Background fill (only when checked)
            RoundedRectangle(cornerRadius: 4)
                .fill(state == .checked ? Color.gray1 : Color.clear)
            // Border (only when not checked)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    state == .checked ? Color.clear : Color.gray1.opacity(0.30),
                    lineWidth: 2
                )
            // Content
            switch state {
            case .checked:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            case .indeterminate:
                Rectangle()
                    .fill(Color.gray1)
                    .frame(width: 8, height: 2)
                    .clipShape(Capsule())
            case .unchecked:
                EmptyView()
            }
        }
        .frame(width: 20, height: 20)
    }
}
