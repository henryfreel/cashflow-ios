import SwiftUI
import UIKit

// MARK: - Filter option model

struct TxFilterOption: Identifiable, Hashable {
    let id: String
    let label: String
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

    /// Staged selection — changes here do NOT propagate until Done is tapped.
    @State private var pendingKeys: Set<String>

    init(filter: TxActiveFilter, options: [TxFilterOption],
         initialKeys: Set<String>,
         onCommit: @escaping (Set<String>) -> Void,
         onDone: @escaping () -> Void) {
        self.filter     = filter
        self.options    = options
        self.initialKeys = initialKeys
        self.onCommit   = onCommit
        self.onDone     = onDone
        _pendingKeys    = State(initialValue: initialKeys)
    }

    private var someSelected: Bool {
        !pendingKeys.isEmpty && pendingKeys.count < options.count
    }

    @State private var isScrolled = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Header (fixed, outside scroll) ───────────────────────────────
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

            // ── Options (scrollable) ──────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    TxFilterRow(label: "All",
                                state: someSelected ? .indeterminate : .checked) {
                        pendingKeys = []
                    }
                    ForEach(options) { opt in
                        let state: TxCheckboxState =
                            (pendingKeys.isEmpty || pendingKeys.contains(opt.id))
                            ? .checked : .unchecked
                        TxFilterRow(label: opt.label, state: state) {
                            toggle(opt)
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
        if pendingKeys.contains(opt.id) {
            pendingKeys.remove(opt.id)
        } else {
            pendingKeys.insert(opt.id)
            if pendingKeys.count == options.count { pendingKeys = [] }
        }
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
