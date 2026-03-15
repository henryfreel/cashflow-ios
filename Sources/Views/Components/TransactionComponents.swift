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
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
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
            .animation(.easeInOut(duration: 0.25),
                       value: "\(hasFilters)\(periodLabel)\(cashflow)\(category ?? "")\(location ?? "")")
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
                bg: Color(red: 0.949, green: 0.949, blue: 0.949),
                content: AnyView(
                    Image("TxCardIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 14)
                        .foregroundStyle(Color.gray1)
                ))
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
                bg: Color(white: 0, opacity: 0.05),
                content: arrowContent)

        case .automatedTransfer:
            return TxIconConfig(
                kind: .grayIcon,
                bg: Color(white: 0, opacity: 0.05),
                content: AnyView(
                    Image("TxCycleIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.gray1)
                ))

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
                    Image("TxPayrollIcon")
                        .resizable().renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.white)
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
        case "Tundra":
            return TxIconConfig(
                kind: .logoImage(border: true),
                bg: Color.white,
                content: AnyView(Image("txn-tundra").resizable().scaledToFit()))
        case "Next Level Apparel":
            return TxIconConfig(
                kind: .fullImage(border: false),
                bg: Color.white,
                content: AnyView(Image("txn-next-level-apparel").resizable().scaledToFill()))
        case "Amazon":
            return TxIconConfig(
                kind: .logoImage(border: false),
                bg: Color(red: 0.251, green: 0.129, blue: 0.122),  // #40211F
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
                bg: Color.white,
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
                kind: .logoImage(border: false),
                bg: Color(red: 0.969, green: 0.969, blue: 0.969),
                content: AnyView(Image("txn-blue-bottle").resizable().scaledToFit()))
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
            // Full-bleed: fills the entire 40pt circle.
            // When the brand photo asset is ready, replace cfg.content with:
            //   Image("BrandPhoto").resizable().scaledToFill()
            cfg.content
                .frame(width: 40, height: 40)
                .clipped()
        case .logoImage(_):
            // 24pt centered logo.
            // When the brand logo asset is ready, replace cfg.content with:
            //   Image("BrandLogo").resizable().scaledToFit()
            cfg.content
                .frame(width: 24, height: 24)
                .clipped()
        case .grayIcon, .colorIcon:
            cfg.content
        }
    }
}
