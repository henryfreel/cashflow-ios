import SwiftUI

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss

    /// Local category override — updated when user picks from the category sheet.
    @State private var localCategory: String?
    @State private var showingCategoryPicker  = false
    @State private var categorySheetExpanded  = false

    init(transaction: Transaction) {
        self.transaction = transaction
        // Seed the local category so the picker opens with the right selection pre-highlighted.
        // Card payments are pinned to Sales; transfer types default to Transfers if unset.
        let initial: String?
        switch transaction.type {
        case .cardPayment, .cardPaymentGroup:
            initial = ExpenseCategory.sales.rawValue
        case .internalTransfer, .automatedTransfer, .bankTransfer:
            initial = transaction.expenseCategory ?? ExpenseCategory.transfers.rawValue
        default:
            initial = transaction.expenseCategory
        }
        _localCategory = State(initialValue: initial)
    }

    // MARK: Derived properties

    private var iconConfig: TxIconConfig { TxIconConfig.make(for: transaction) }

    // Design tokens for the white-bg (light) header variant — from Figma.
    private static let lightHeaderBand   = Color.gray6
    private static let lightHeaderBtn    = Color(white: 0.698)  // #B2B2B2

    /// Header band color — light gray for icon/white-bg transactions, brand color otherwise.
    private var headerBgColor: Color {
        isLightHeader ? Self.lightHeaderBand : iconConfig.bg
    }

    /// True when the header should use the light (#DEDEDE) style.
    /// Applies to both white-bg logo transactions (border: true) and
    /// grayIcon transactions (card payments, transfers, etc.).
    private var isLightHeader: Bool {
        if iconConfig.border { return true }
        if case .grayIcon = iconConfig.kind { return true }
        return false
    }

    /// Background color for the circular nav buttons (X / ⋯).
    private var navBtnBg: Color {
        isLightHeader ? Self.lightHeaderBtn : Color.white.opacity(0.12)
    }

    /// Foreground color for the nav button icons.
    private var navIconColor: Color { Color.white }

    /// Border color for the 100pt avatar ring.
    private var avatarBorderColor: Color {
        if iconConfig.whiteAvatarBorder { return .white }
        return isLightHeader ? Self.lightHeaderBand : Color.white
    }

    private var amountString: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        let abs = f.string(from: NSNumber(value: Swift.abs(transaction.amount))) ?? "$0"
        return transaction.amount < 0 ? "-\(abs)" : abs
    }

    private var dateTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy 'at' h:mma"
        return f.string(from: transaction.date)
    }

    /// Three contextually relevant alternative categories for this transaction,
    /// ordered by likelihood. Excludes the current selection. Used as suggestions
    /// in the compact category picker sheet.
    private var contextualSuggestions: [ExpenseCategory] {
        let name = transaction.merchantName.lowercased()

        // Ordered candidate list — most likely first — chosen by transaction context.
        let candidates: [ExpenseCategory]
        if transaction.isRevenue {
            candidates = [.sales, .cogs, .marketing, .laborPayroll,
                          .rentUtilities, .officeSupplies, .transportation, .taxesLicenses]
        } else {
            switch transaction.type {
            case .cardPayment, .cardPaymentGroup:
                candidates = [.sales, .cogs, .marketing, .laborPayroll,
                              .rentUtilities, .officeSupplies, .transportation, .taxesLicenses]
            case .bankTransfer, .internalTransfer, .automatedTransfer:
                candidates = [.rentUtilities, .taxesLicenses, .laborPayroll, .officeSupplies,
                              .cogs, .marketing, .transportation, .sales]
            case .purchase:
                if name.contains("tundra") || name.contains("whole foods")
                    || name.contains("señor sisig") || name.contains("next level") {
                    candidates = [.cogs, .officeSupplies, .transportation, .marketing,
                                  .rentUtilities, .laborPayroll, .taxesLicenses, .sales]
                } else if name.contains("uline") || name.contains("home depot")
                    || name.contains("amazon") {
                    candidates = [.officeSupplies, .cogs, .transportation, .marketing,
                                  .rentUtilities, .laborPayroll, .taxesLicenses, .sales]
                } else if name.contains("ups") {
                    candidates = [.transportation, .cogs, .officeSupplies, .marketing,
                                  .rentUtilities, .laborPayroll, .taxesLicenses, .sales]
                } else if name.contains("rent") || name.contains("utilities")
                    || name.contains("pg&e") || name.contains("comcast") {
                    candidates = [.rentUtilities, .taxesLicenses, .officeSupplies, .laborPayroll,
                                  .cogs, .marketing, .transportation, .sales]
                } else if name.contains("starbucks") || name.contains("blue bottle")
                    || name.contains("airtable") {
                    candidates = [.officeSupplies, .marketing, .cogs, .transportation,
                                  .rentUtilities, .laborPayroll, .taxesLicenses, .sales]
                } else {
                    candidates = [.officeSupplies, .cogs, .marketing, .rentUtilities,
                                  .laborPayroll, .transportation, .taxesLicenses, .sales]
                }
            }
        }

        let cur = (localCategory ?? transaction.expenseCategory).flatMap(ExpenseCategory.init(rawValue:))
        var result: [ExpenseCategory] = []
        for cat in candidates where cat != cur && result.count < 3 {
            result.append(cat)
        }
        return result
    }

    /// True for internal transactions (card payments, automated/internal transfers).
    /// These do not show the completion status card at the bottom.
    private var isInternalTransaction: Bool {
        switch transaction.type {
        case .cardPayment, .cardPaymentGroup, .internalTransfer, .automatedTransfer:
            return true
        default:
            return false
        }
    }

    /// Only card payments are locked to Sales and cannot be recategorised.
    private var isCategoryDisabled: Bool {
        switch transaction.type {
        case .cardPayment, .cardPaymentGroup: return true
        default: return false
        }
    }

    private var categoryName: String? {
        localCategory ?? transaction.expenseCategory
    }

    private var categoryAsset: String {
        guard let raw = localCategory ?? transaction.expenseCategory,
              let cat = ExpenseCategory(rawValue: raw) else { return "CatOfficeSupplies" }
        switch cat {
        case .sales:          return "CatSales"
        case .cogs:           return "CatCostOfGoods"
        case .laborPayroll:   return "CatLaborPayroll"
        case .rentUtilities:  return "CatRentUtilities"
        case .marketing:      return "CatMarketing"
        case .officeSupplies: return "CatOfficeSupplies"
        case .transportation: return "CatTransportation"
        case .taxesLicenses:  return "CatTaxesLicenses"
        case .personal:       return "CatPersonal"
        case .transfers:      return "CatTransfers"
        }
    }

    /// Primary status label (bold line in the bottom card).
    private var completionTitle: String {
        switch transaction.type {
        case .cardPayment, .cardPaymentGroup:
            return transaction.isRevenue ? "Payment received" : "Payment completed"
        case .purchase:
            if transaction.merchantName == "Square Payroll" { return "Payroll sent" }
            return transaction.isRevenue ? "Payment received" : "Payment completed"
        case .internalTransfer:
            return transaction.isRevenue ? "Transfer received" : "Transfer sent"
        case .automatedTransfer:
            return "Transfer completed"
        case .bankTransfer:
            return transaction.isRevenue ? "Transfer received" : "Transfer sent"
        }
    }

    /// Secondary description line (light line in the bottom card).
    private var completionDetail: String {
        switch transaction.type {
        case .cardPayment, .cardPaymentGroup:
            if transaction.isRevenue {
                if let loc = transaction.locationName { return "Received at \(loc)" }
                return "Received via card terminal"
            }
            if let card = transaction.cardInfo { return "Spent via \(card)" }
            return "Spent via card"

        case .purchase:
            if transaction.merchantName == "Square Payroll" {
                if let loc = transaction.locationName { return "From \(loc) account" }
                return "From business account"
            }
            if transaction.isRevenue {
                if let loc = transaction.locationName { return "Received at \(loc)" }
                return "Received via Square"
            }
            if let card = transaction.cardInfo { return "Spent via \(card)" }
            if let loc = transaction.locationName { return "Charged to \(loc) account" }
            return "Spent from account"

        case .internalTransfer:
            if transaction.isRevenue {
                if let loc = transaction.locationName { return "From \(loc) account" }
                return "From internal account"
            } else {
                if let loc = transaction.locationName { return "To \(loc) account" }
                return "To internal account"
            }

        case .automatedTransfer:
            return "To \(transaction.merchantName)"

        case .bankTransfer:
            if transaction.isRevenue {
                return "From \(transaction.merchantName)"
            } else {
                return "To \(transaction.merchantName)"
            }
        }
    }

    // MARK: Layout constants

    private let colorBandHeight: CGFloat = 160
    private let avatarSize: CGFloat = 100

    /// Street line of the fake address (line 1).
    private var fakeStreet: String {
        switch transaction.merchantName {
        case "Starbucks":          return "2120 Fillmore St"
        case "Home Depot":         return "2550 Taylor St"
        case "Whole Foods":        return "1765 California St"
        case "Amazon":             return "410 Terry Ave N"
        case "Tundra":             return "3101 16th St"
        case "Next Level Apparel": return "6811 Commerce Ave"
        case "Uline":              return "2200 S Lakeside Dr"
        case "Etsy":               return "117 Adams St"
        case "Airtable":           return "155 5th St"
        case "Blue Bottle Coffee": return "300 Webster St"
        case "Señor Sisig":        return "990 Brannan St"
        case "UPS":                return "741 Eccles Ave"
        case "BofA 1892":          return "315 Montgomery St"
        default:
            if let loc = transaction.locationName {
                switch loc {
                case "Hayes Valley":   return "384 Hayes St"
                case "Bernal Heights": return "415 Cortland Ave"
                case "The Mission":    return "2870 Mission St"
                default: break
                }
            }
            return "123 Market St"
        }
    }

    /// True only for purchases at physical store locations (shows street address).
    /// All account-level and card transactions show a location/account line instead.
    private var showsAddress: Bool {
        switch transaction.type {
        case .purchase:
            return transaction.merchantName != "Square Payroll"
        default:
            return false
        }
    }

    /// Single subtitle line used instead of the address for non-physical transactions.
    private var locationSubtitle: String? {
        switch transaction.type {
        case .cardPayment, .cardPaymentGroup:
            return transaction.locationName
        case .purchase where transaction.merchantName == "Square Payroll":
            return transaction.locationName
        case .bankTransfer:
            if let loc = transaction.locationName {
                return transaction.isRevenue ? "To \(loc)" : "From \(loc)"
            }
            return nil
        case .automatedTransfer:
            // Title = source account; subtitle = destination ("To X" for outgoing).
            if let loc = transaction.locationName {
                return transaction.amount < 0 ? "To \(loc)" : "From \(loc)"
            }
            return transaction.amount < 0 ? "To operating account" : "From savings"
        case .internalTransfer:
            // merchantName = destination account; locationName = source account.
            // Transfer in (revenue): title = destination, subtitle = "From [source]".
            // Transfer out:          title = source,      subtitle = "To [destination]".
            if let loc = transaction.locationName {
                return transaction.isRevenue ? "From \(loc)" : "To \(loc)"
            }
            return nil
        default:
            return transaction.locationName
        }
    }

    /// City/state line of the fake address (line 2).
    private var fakeCity: String {
        switch transaction.merchantName {
        case "Amazon":             return "Seattle, WA"
        case "Next Level Apparel": return "Los Angeles, CA"
        case "Uline":              return "Waukegan, IL"
        case "Etsy":               return "Brooklyn, NY"
        case "Blue Bottle Coffee": return "Oakland, CA"
        case "UPS":                return "South San Francisco, CA"
        default:                   return "San Francisco, CA"
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection(safeTop: geo.safeAreaInsets.top)

                    // Fixed 56pt gap below the header address/subtitle line
                    Color.clear.frame(height: 56)

                    // Amount + date + category — anchored 56pt below header
                    middleSection

                    // Fill all remaining space so bottom card stays at screen bottom
                    Spacer(minLength: 0)

                    // Bottom card flush to the screen edge — hidden for internal transactions
                    if !isInternalTransaction {
                        bottomCard
                            .padding(.horizontal, 16)
                    } else {
                        Color.clear.frame(height: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(edges: .top)
        .interactiveDismissDisabled(showingCategoryPicker)
        .customBottomSheet(
            isPresented:   $showingCategoryPicker,
            compactHeight: CategoryPickerSheet.compactHeight,
            forceExpanded: $categorySheetExpanded
        ) {
            CategoryPickerSheet(
                currentCategory: localCategory,
                suggestedOthers: contextualSuggestions,
                onSelect: { selected in
                    localCategory = selected.rawValue
                    showingCategoryPicker = false
                },
                onDone: {
                    showingCategoryPicker = false
                    categorySheetExpanded = false
                },
                onShowAll: {
                    categorySheetExpanded = true
                },
                isSheetExpanded: categorySheetExpanded
            )
        }
        .onChange(of: showingCategoryPicker) { _, shown in
            if !shown { categorySheetExpanded = false }
        }
    }

    // MARK: - Header

    private func headerSection(safeTop: CGFloat) -> some View {
        // Use ZStack(alignment: .top) so we can place avatar precisely
        // with padding from the top of the whole stack.
        ZStack(alignment: .top) {
            // Background layers (sizes the ZStack's height naturally)
            VStack(spacing: 0) {
                // Colored band — fills behind status bar + 160pt design height
                headerBgColor
                    .frame(height: colorBandHeight + safeTop)

                // White section: avatar bottom half + name + 2-line address + padding
                Color.white
                    .frame(height: avatarSize / 2 + 16 + 24 + 4 + 44 + 28)
            }

            // Nav buttons — sit on top of the colored band
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(navIconColor)
                        .frame(width: 24, height: 24)
                        .padding(12)
                        .background(navBtnBg, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {} label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(navIconColor)
                        .frame(width: 24, height: 24)
                        .padding(12)
                        .background(navBtnBg, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, safeTop + 24)
            .zIndex(10)

            // Avatar — center aligned at the color/white boundary
            // Top of avatar = colorBandHeight + safeTop - avatarSize/2
            TxDetailIcon(transaction: transaction, size: avatarSize)
                .overlay(Circle().strokeBorder(avatarBorderColor, lineWidth: 2))
                .padding(.top, colorBandHeight + safeTop - avatarSize / 2)

            // Merchant name + address/location — below avatar
            VStack(spacing: 8) {
                Text(transaction.merchantName)
                    .font(.paragraphMedium30)
                    .lineSpacing(8)
                    .foregroundStyle(Color.black.opacity(0.9))
                    .multilineTextAlignment(.center)
                if showsAddress {
                    VStack(spacing: 4) {
                        Text(fakeStreet)
                            .font(.paragraph20)
                            .lineSpacing(8)
                            .foregroundStyle(Color.black.opacity(0.55))
                            .multilineTextAlignment(.center)
                        Text(fakeCity)
                            .font(.paragraph20)
                            .lineSpacing(8)
                            .foregroundStyle(Color.black.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                } else if let subtitle = locationSubtitle {
                    Text(subtitle)
                        .font(.paragraph20)
                        .lineSpacing(8)
                        .foregroundStyle(Color.black.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
            }
            // Top of name = avatar bottom + 16pt gap
            // Avatar bottom = colorBandHeight + safeTop + avatarSize/2
            .padding(.top, colorBandHeight + safeTop + avatarSize / 2 + 16)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Middle

    private var middleSection: some View {
        VStack(spacing: 24) {
            // Amount + date
            VStack(spacing: 4) {
                Text(amountString)
                    .font(.custom(AppFont.Display.bold, size: 48))
                    .tracking(-1.2)
                    .foregroundStyle(Color.gray1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(dateTimeString)
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray3)
            }
            .multilineTextAlignment(.center)

            // Category pill
            if let name = categoryName {
                Button {
                    if !isCategoryDisabled { showingCategoryPicker = true }
                } label: {
                    categoryPill(name: name, isDisabled: isCategoryDisabled)
                }
                .buttonStyle(.plain)
                .disabled(isCategoryDisabled)
            }
        }
        .padding(.horizontal, 24)
    }

    private func categoryPill(name: String, isDisabled: Bool = false) -> some View {
        let fg: Color = isDisabled ? Color.gray4 : Color.gray1
        let bg: Color = isDisabled ? Color.gray6 : Color.white
        return HStack(spacing: 8) {
            Image(categoryAsset)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(fg)

            Text(name)
                .font(.custom(AppFont.Text.semiBold, size: 14))
                .foregroundStyle(fg)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(fg)
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(bg, in: Capsule())
        .overlay(Capsule().strokeBorder(Color(white: 0.851), lineWidth: 1))
        .fixedSize()
    }

    // MARK: - Bottom card

    private var bottomCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image("TxCheckmarkCircle")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.black.opacity(0.9))

                Text(completionTitle)
                    .font(.paragraphSemibold20)
                    .foregroundStyle(Color.black.opacity(0.9))
            }

            Text(completionDetail)
                .font(.paragraph20)
                .foregroundStyle(Color.black.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .background(Color.gray7, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Large avatar for detail view

/// Replicates TxIcon at a larger size (default 98pt) for the transaction detail header.
struct TxDetailIcon: View {
    let transaction: Transaction
    var size: CGFloat = 98

    private var cfg: TxIconConfig { TxIconConfig.make(for: transaction) }

    private var bgColor: Color { cfg.bg }

    var body: some View {
        ZStack {
            Circle().fill(bgColor)
            iconContent
            if cfg.border {
                Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var iconContent: some View {
        switch cfg.kind {
        case .fullImage:
            cfg.content
                .frame(width: size, height: size)
                .clipped()
        case .logoImage:
            cfg.content
                .frame(width: size * 0.48, height: size * 0.48)
                .clipped()
        case .grayIcon, .colorIcon:
            // Scale icon proportionally to 48pt at 100pt avatar size
            cfg.content
                .scaleEffect(size / 50)
        }
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    let currentCategory: String?
    /// Three contextually relevant alternative categories (excluding current selection).
    var suggestedOthers: [ExpenseCategory] = []
    let onSelect: (ExpenseCategory) -> Void
    let onDone: () -> Void
    var onShowAll: (() -> Void)? = nil
    /// Set to true when the sheet is expanded externally (e.g. via drag-up gesture).
    var isSheetExpanded: Bool = false

    @State private var showAll     = false
    @State private var isScrolled  = false

    // ── All 8 P&L categories (used as the pool for sorting) ──────────────────
    static let allPLCategories: [ExpenseCategory] = [
        .sales, .cogs,
        .laborPayroll, .rentUtilities,
        .marketing, .officeSupplies,
        .transportation, .taxesLicenses
    ]
    static let excludeCategories: [ExpenseCategory] = [.personal, .transfers]

    // ── Compact height (collapsed: 4 suggestions + "Show all" button) ────────
    static var compactHeight: CGFloat {
        let modifierTopPad: CGFloat = 24
        let header:         CGFloat = 48
        let headerGap:      CGFloat = 16
        let subheader:      CGFloat = 46   // py-12 top + 22pt line + 12pt bottom
        let gridRow:        CGFloat = 102
        let gridGap:        CGFloat = 16
        let gridBottomPad:  CGFloat = 8
        let buttonGap:      CGFloat = 16
        let button:         CGFloat = 48
        let bottomPad:      CGFloat = 64
        return modifierTopPad + header + headerGap + subheader +
               gridRow + gridGap + gridRow + gridBottomPad +
               buttonGap + button + bottomPad
    }

    static func asset(for cat: ExpenseCategory) -> String {
        switch cat {
        case .sales:          return "CatSales"
        case .cogs:           return "CatCostOfGoods"
        case .laborPayroll:   return "CatLaborPayroll"
        case .rentUtilities:  return "CatRentUtilities"
        case .marketing:      return "CatMarketing"
        case .officeSupplies: return "CatOfficeSupplies"
        case .transportation: return "CatTransportation"
        case .taxesLicenses:  return "CatTaxesLicenses"
        case .personal:       return "CatPersonal"
        case .transfers:      return "CatTransfers"
        }
    }

    /// True when the current category belongs to the exclude section (not a P&L category).
    private var currentIsExclude: Bool {
        guard let cur = currentCategory.flatMap(ExpenseCategory.init(rawValue:)) else { return false }
        return Self.excludeCategories.contains(cur)
    }

    /// Four cards for the compact view: selected category always first (including Personal/
    /// Transfers), then 3 contextual P&L suggestions. When nothing is selected, 4 suggestions.
    private var suggestions: [ExpenseCategory] {
        let cur = currentCategory.flatMap(ExpenseCategory.init(rawValue:))
        let fallback: [ExpenseCategory] = [
            .officeSupplies, .cogs, .rentUtilities, .marketing,
            .laborPayroll, .transportation, .taxesLicenses, .sales
        ]
        // Fill 3 other slots from contextual suggestions, then fallback — skip cur.
        var others: [ExpenseCategory] = Array(suggestedOthers.prefix(3))
        if others.count < 3 {
            for cat in fallback where cat != cur && !others.contains(cat) && others.count < 3 {
                others.append(cat)
            }
        }
        guard let cur else { return Array(others.prefix(4)) }
        return [cur] + others
    }

    /// Items displayed in the P&L grid.
    /// Compact: 4 suggestions (selected P&L category first + 3 contextual).
    /// Expanded: selected P&L category first (alphabetical rest after); exclude categories
    ///   are only shown selected in the Exclude section, never duplicated here.
    private var displayedPLCategories: [ExpenseCategory] {
        if showAll {
            let cur = currentCategory.flatMap(ExpenseCategory.init(rawValue:))
            let plCur: ExpenseCategory? = (cur != nil && !currentIsExclude) ? cur : nil
            let rest = Self.allPLCategories
                .filter { $0 != plCur }
                .sorted { $0.rawValue < $1.rawValue }
            if let plCur { return [plCur] + rest }
            return rest
        }
        return suggestions
    }

    var body: some View {
        let twoCol = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

        VStack(spacing: 0) {
            // ── Pinned header ────────────────────────────────────────────────
            HStack(spacing: 10) {
                Text("Category")
                    .font(.heading30)
                    .foregroundStyle(Color.black.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDone) {
                    Text("Done")
                        .font(.paragraphSemibold30)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color(white: 0.063))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 48)
            .padding(.horizontal, 24)
            .padding(.bottom, showAll ? 20 : 0)
            .overlay(alignment: .bottom) {
                if isScrolled {
                    Rectangle()
                        .fill(Color.gray5)
                        .frame(height: 1)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isScrolled)

            // ── Scrollable content ───────────────────────────────────────────
            ScrollView {
                VStack(spacing: 0) {
                    // Category section
                    VStack(alignment: .leading, spacing: 0) {

                        // Section subheader
                        HStack(spacing: 4) {
                            if !showAll {
                                Image("CatLightning")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(Color.gray3)
                                    .transition(.opacity)
                            }
                            Text(showAll ? "ALL CATEGORIES" : "SUGGESTED CATEGORIES")
                                .font(.custom(AppFont.Text.medium, size: 14))
                                .foregroundStyle(Color.gray3)
                                .tracking(0.7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .animation(nil, value: showAll)
                        }
                        .padding(.vertical, 12)
                        .animation(.easeInOut(duration: 0.2), value: showAll)

                        // P&L grid — cards animate to new positions when showAll changes
                        LazyVGrid(columns: twoCol, spacing: 16) {
                            ForEach(displayedPLCategories) { cat in
                                categoryCard(cat)
                                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                            }
                        }
                        .padding(.bottom, 8)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85),
                                   value: displayedPLCategories.map(\.rawValue))

                        // Exclude section — only in expanded view
                        if showAll {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("EXCLUDE")
                                    .font(.custom(AppFont.Text.medium, size: 14))
                                    .foregroundStyle(Color.gray3)
                                    .tracking(0.7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)

                                LazyVGrid(columns: twoCol, spacing: 16) {
                                    ForEach(Self.excludeCategories) { cat in
                                        categoryCard(cat)
                                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }

                    // "Show all categories" button — only in collapsed view
                    if !showAll {
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                showAll = true
                            }
                            onShowAll?()
                        } label: {
                            Text("Show all categories")
                                .font(.paragraphSemibold30)
                                .foregroundStyle(Color.blue3)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                        .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 64)
            }
            .scrollDisabled(!showAll)
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 0
            } action: { _, scrolled in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isScrolled = scrolled
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .onChange(of: isSheetExpanded) { _, expanded in
            if expanded && !showAll {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showAll = true
                }
            }
        }
    }

    @ViewBuilder
    private func categoryCard(_ cat: ExpenseCategory) -> some View {
        let isSelected = currentCategory == cat.rawValue
        Button { onSelect(cat) } label: {
            VStack(spacing: 8) {
                Image(Self.asset(for: cat))
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.gray1)

                Text(cat.rawValue)
                    .font(.paragraphSemibold20)
                    .foregroundStyle(Color.black.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 102)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.gray1 : Color(white: 0.851),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Array chunked helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Preview

#Preview("Purchase") {
    let tx = AppFinancials.allTransactions.first(where: { $0.merchantName == "Starbucks" })
        ?? AppFinancials.allTransactions[0]
    TransactionDetailView(transaction: tx)
}

#Preview("Transfer Out") {
    let tx = AppFinancials.allTransactions.first(where: { $0.merchantName == "General Savings" })
        ?? AppFinancials.allTransactions[0]
    TransactionDetailView(transaction: tx)
}

#Preview("Transfer In") {
    let tx = AppFinancials.allTransactions.first(where: {
        if case .internalTransfer = $0.type { return $0.isRevenue }
        return false
    }) ?? AppFinancials.allTransactions[0]
    TransactionDetailView(transaction: tx)
}

#Preview("Bank Transfer") {
    let tx = AppFinancials.allTransactions.first(where: { $0.type == .bankTransfer })
        ?? AppFinancials.allTransactions[0]
    TransactionDetailView(transaction: tx)
}
