import SwiftUI

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
    var onClear:       (() -> Void)? = nil
    var onTapLocation: (() -> Void)? = nil
    var onTapDate:     (() -> Void)? = nil
    var onTapCashflow: (() -> Void)? = nil
    var onTapCategory: (() -> Void)? = nil
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TxSearchButton()
                if hasFilters {
                    TxClearFiltersChip(onClear: onClear)
                }
                TxChip(label: "Location", value: location,
                       onTap: onTapLocation)
                TxChip(label: "Date",     value: periodLabel.isEmpty ? nil : periodLabel,
                       onTap: onTapDate)
                TxChip(label: "Cashflow", value: cashflow == "All" || cashflow.isEmpty ? nil : cashflow,
                       onTap: onTapCashflow)
                TxChip(label: "Category", value: category,
                       onTap: onTapCategory)
            }
            .padding(.horizontal, 24)
        }
    }
}

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

struct TxSearchButton: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.gray1.opacity(0.15), lineWidth: 1)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.gray1)
        }
        .frame(width: 40, height: 40)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.title)
                .font(.heading20)
                .foregroundStyle(Color.gray1)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, 24)
            ForEach(group.items) { tx in
                TxRow(transaction: tx, showLocation: showLocation)
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

    /// Right-side secondary text logic:
    ///   • Card purchase  → masked card/account identifier (cardInfo)
    ///   • Account-level / sales (no cardInfo) → location name (when showLocation)
    private var rightSubtitle: String? {
        if let card = transaction.cardInfo { return card }
        if showLocation { return transaction.locationName }
        return nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            TxIcon(transaction: transaction)
            TxRowText(name: transaction.merchantName, sub: transaction.subtitle)
            Spacer(minLength: 8)
            TxRowMoney(amount: transaction.amount, secondaryText: rightSubtitle)
        }
        .padding(.vertical, 16)
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
                // Reserve height so all rows stay the same size
                Text(" ").font(.paragraph20)
            }
        }
    }
    static func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        let s = f.string(from: NSNumber(value: abs(v))) ?? "$0"
        return v < 0 ? "–\(s)" : s
    }
}

// MARK: - Icon

struct TxIcon: View {
    let transaction: Transaction
    var body: some View {
        let cfg = TxIconConfig.make(for: transaction)
        ZStack {
            Circle().fill(cfg.bg)
            if cfg.border { Circle().stroke(Color.gray1.opacity(0.10), lineWidth: 1) }
            cfg.view
        }
        .frame(width: 40, height: 40)
    }
}

struct TxIconConfig {
    let bg: Color
    let border: Bool
    let view: AnyView

    static func make(for tx: Transaction) -> TxIconConfig {
        switch tx.type {
        case .cardPayment, .cardPaymentGroup:
            return icon(Color(white: 0.06), false,
                AnyView(Image(systemName: "creditcard.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white)))
        case .internalTransfer:
            return icon(Color(red: 0.898, green: 0.941, blue: 1.0), false,
                AnyView(Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.blue3)))
        case .bankTransfer:
            let isChase = tx.merchantName.hasPrefix("Chase")
            let bg: Color = isChase ? Color(red: 0, green: 0.329, blue: 0.667) : .white
            let abbr = String((tx.merchantName.components(separatedBy: " ").first ?? "?").prefix(2)).uppercased()
            return icon(bg, !isChase,
                AnyView(Text(abbr)
                    .font(.custom(AppFont.Text.semiBold, size: 13))
                    .foregroundStyle(isChase ? Color.white : Color.gray1)))
        case .purchase:
            return purchase(tx.merchantName)
        }
    }

    private static func icon(_ bg: Color, _ border: Bool, _ view: AnyView) -> TxIconConfig {
        TxIconConfig(bg: bg, border: border, view: view)
    }

    private static func abbr(_ n: String) -> String {
        let w = n.split(separator: " ")
        return w.count >= 2
            ? String(w[0].prefix(1) + w[1].prefix(1)).uppercased()
            : String(n.prefix(2)).uppercased()
    }

    private static func purchase(_ name: String) -> TxIconConfig {
        let white = Color.white
        switch name {
        case "Square Payroll":
            return icon(Color(red: 0.325, green: 0.698, blue: 0.282), false,
                AnyView(Image(systemName: "person.2.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(white)))
        case "Restaurant Supply":
            return icon(Color(red: 0, green: 0.322, blue: 0.553), false,
                AnyView(Image(systemName: "cart.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(white)))
        case "Home Depot":
            return icon(Color(red: 1, green: 0.388, blue: 0), false,
                AnyView(Text("HD").font(.custom(AppFont.Text.bold, size: 11)).foregroundStyle(white)))
        case "Amazon":
            return icon(Color(red: 1, green: 0.6, blue: 0), false,
                AnyView(Text("a").font(.custom(AppFont.Text.bold, size: 17)).foregroundStyle(white)))
        case "Etsy":
            return icon(Color(red: 0.875, green: 0.412, blue: 0.169), false,
                AnyView(Text("e").font(.custom(AppFont.Text.bold, size: 17)).foregroundStyle(white)))
        case "Github", "Uline", "Airtable":
            return icon(.white, true,
                AnyView(Text(abbr(name)).font(.custom(AppFont.Text.semiBold, size: 13)).foregroundStyle(Color.gray2)))
        case "Landlord LLC", "Whole Foods", "Sightglass":
            return icon(Color(red: 0.024, green: 0.118, blue: 0.165), false,
                AnyView(Text(abbr(name)).font(.custom(AppFont.Text.semiBold, size: 13)).foregroundStyle(white)))
        default:
            return icon(Color(white: 0, opacity: 0.05), false,
                AnyView(Text(abbr(name)).font(.custom(AppFont.Text.semiBold, size: 13)).foregroundStyle(Color.gray3)))
        }
    }
}
