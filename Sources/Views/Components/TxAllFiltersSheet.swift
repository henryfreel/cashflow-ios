import SwiftUI

// MARK: - All Filters summary sheet

/// Bottom sheet that lists every filter category with its current value.
/// Tapping a row dismisses this sheet and opens the individual filter sheet.
struct TxAllFiltersSheet: View {
    let locationValue: String
    let dateValue:     String
    let cashflowValue: String
    let categoryValue: String
    var onClearAll: (() -> Void)? = nil
    var onDone:     (() -> Void)? = nil
    var onTap:      ((TxActiveFilter) -> Void)? = nil

    /// Compact height = top-pad(24) + header(48) + gap(16) + 4 rows × 56 + bottom-pad(64)
    static let compactHeight: CGFloat = 376

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sheetHeader
            sheetRows
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 64)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Subviews

    @ViewBuilder private var sheetHeader: some View {
        HStack(spacing: 8) {
            Text("Filter by")
                .font(.heading30)
                .foregroundStyle(Color.black.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { onClearAll?() } label: {
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
    }

    @ViewBuilder private var sheetRows: some View {
        VStack(spacing: 0) {
            AllFiltersRow(label: "Location", value: locationValue) { onTap?(.location) }
            AllFiltersRow(label: "Date",     value: dateValue)     { onTap?(.date) }
            AllFiltersRow(label: "Cashflow", value: cashflowValue) { onTap?(.cashflow) }
            AllFiltersRow(label: "Category", value: categoryValue) { onTap?(.category) }
        }
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

                Text(value)
                    .font(.paragraph30)
                    .foregroundStyle(Color.black.opacity(0.9))

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.gray3)
                    .frame(width: 16, height: 16)
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
