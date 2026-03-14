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
    @Binding var selectedKeys: Set<String>
    let onDone: () -> Void

    private var allSelected: Bool { selectedKeys.isEmpty }
    private var someSelected: Bool { !selectedKeys.isEmpty && selectedKeys.count < options.count }

    private var bottomRadius: CGFloat { UIScreen.main.displayCornerRadius }

    var body: some View {
        VStack(spacing: 0) {
            // ── Grabber (inside card, always visible) ─────────────────────────
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray4)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

            // ── Content (leading-aligned) ─────────────────────────────────────
            VStack(alignment: .leading, spacing: 16) {
                // Header (48pt)
                HStack(spacing: 10) {
                    Text(filter.title)
                        .font(.heading30)
                        .foregroundStyle(Color.gray1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onDone) {
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

                // Options
                VStack(spacing: 0) {
                    TxFilterRow(label: "All",
                                state: someSelected ? .indeterminate : .checked) {
                        selectedKeys = []
                    }
                    ForEach(options) { opt in
                        let state: TxCheckboxState = (selectedKeys.isEmpty || selectedKeys.contains(opt.id)) ? .checked : .unchecked
                        TxFilterRow(label: opt.label, state: state) {
                            toggle(opt)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 64)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 16
            )
            .fill(Color.white)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func toggle(_ opt: TxFilterOption) {
        if selectedKeys.contains(opt.id) {
            selectedKeys.remove(opt.id)
        } else {
            selectedKeys.insert(opt.id)
            // All individual options explicitly selected → revert to "All" (empty set)
            if selectedKeys.count == options.count {
                selectedKeys = []
            }
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
