import Foundation

// MARK: - Expense Category
//
// Used for both expense breakdowns on monthly records and future transaction tagging.

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case sales          = "Sales"
    case cogs           = "Cost of Goods"
    case laborPayroll   = "Labor & Payroll"
    case rentUtilities  = "Rent & Utilities"
    case marketing      = "Marketing"
    case officeSupplies = "Office Supplies"
    case transportation = "Transportation"
    case taxesLicenses  = "Taxes & Licenses"
    case personal       = "Personal"
    case transfers      = "Transfers"

    var id: String { rawValue }

    /// Categories excluded from P&L net income calculations.
    var excludedFromPL: Bool {
        self == .personal || self == .transfers
    }
}

// MARK: - Expense Breakdown
//
// Proportional breakdown of a total expense figure for a 3-location boutique retail business.
// Proportions are held constant across periods; transaction-level data (future) will replace
// these estimates with actuals.
//
//   COGS       51.5%  - inventory / cost of goods sold
//   Labor      24.0%  - wages across all three locations
//   Rent       12.2%  - combined lease costs
//   Marketing   4.4%  - campaigns, social, events
//   Utilities   4.4%  - power, internet, POS, packaging
//   Misc        3.5%  - insurance, admin, miscellaneous

struct ExpenseBreakdown {
    let total: Double

    var cogs:       Double { total * 0.515 }
    var labor:      Double { total * 0.240 }
    var rent:       Double { total * 0.122 }
    var marketing:  Double { total * 0.044 }
    var utilities:  Double { total * 0.044 }
    // Absorbs rounding so sub-categories always sum to total exactly
    var misc:       Double { total - cogs - labor - rent - marketing - utilities }
}

// MARK: - Revenue Category
//
// Channels through which the boutique generates revenue.

enum RevenueCategory: String, CaseIterable, Identifiable {
    case squareCard = "Square Card Sales"
    case online     = "Online Payments"
    case cash       = "Cash Sales"
    case giftCard   = "Gift Cards"

    var id: String { rawValue }
}

// MARK: - Revenue Breakdown
//
// Proportional breakdown of a total revenue figure across sales channels.
// Proportions are held constant across periods; actuals will replace these
// once transaction-level data is available.
//
//   Square Card Sales  68%  - in-store card payments via Square terminals
//   Online Store       18%  - e-commerce orders
//   Cash Sales         10%  - in-store cash transactions
//   Gift Cards          4%  - gift card redemptions

struct RevenueBreakdown {
    let total: Double

    var squareCard: Double { total * 0.68 }
    var online:     Double { total * 0.18 }
    var cash:       Double { total * 0.10 }
    // Absorbs rounding so all channels sum to total exactly
    var giftCard:   Double { total - squareCard - online - cash }
}

// MARK: - Transaction

enum TransactionType: Equatable {
    case purchase
    case cardPayment
    /// Multiple card payments grouped together. `count` = number of individual payments.
    case cardPaymentGroup(count: Int)
    /// A single e-commerce / online-store order.
    case onlineOrder
    /// In-store cash sale.
    case cashPayment
    /// Gift card sale or redemption.
    case giftCard
    case bankTransfer
    case internalTransfer
    /// Recurring scheduled transfer — automated savings sweeps, loan payments, etc.
    case automatedTransfer
}

struct Transaction: Identifiable {
    let id: UUID
    let date: Date
    /// Positive = revenue inflow; negative = expense outflow.
    let amount: Double
    let merchantName: String
    /// Left-side secondary label: category name, date label, or descriptor.
    let subtitle: String
    /// Location associated with this transaction (e.g. "Hayes Valley").
    /// Set for account-level transfers, payroll, and card sales.
    /// Nil for company-wide or online purchases where no single location applies.
    let locationName: String?
    /// Masked card/account identifier shown as right-side subtitle for
    /// card-purchase transactions (e.g. "7832", "4812").
    /// Nil for account-level and sales transactions (which show locationName instead).
    let cardInfo: String?
    let type: TransactionType
    /// Matches `ExpenseCategory.rawValue`; nil for revenue transactions.
    let expenseCategory: String?
    let isRevenue: Bool
    /// Brand accent color as a hex string (e.g. `"#FF6300"`).
    /// Not displayed in the transaction list — reserved for the detail view.
    /// For `.logoImage` avatars this matches the avatar background color.
    /// For `.fullImage` avatars this is the brand's dominant color.
    let accentHex: String? = nil
}

// MARK: - Sample transaction generator

extension AppFinancials {

    private static let locations = ["Hayes Valley", "Bernal Heights", "The Mission"]

    /// Returns a plausible set of sample transactions for the given year + month.
    /// Revenue amounts use Square Card Sales proportions; expenses use the existing
    /// `ExpenseBreakdown` split. All values are scaled to match the month's seed data.
    static func sampleTransactions(year: Int, month: Int) -> [Transaction] {
        let months = monthlyData(year: year)
        guard month >= 1, month <= months.count else { return [] }
        let mData   = months[month - 1]
        let revTotal = mData.revenue
        let expTotal = mData.expenses
        let expB    = ExpenseBreakdown(total: expTotal)

        // Build a deterministic but varied date within the month.
        // For the current partial month (Dec 15) all canonical offsets (1...dim) are
        // scaled proportionally into 1...activeDays so no transaction lands after today.
        let dim = daysInMonth(year: year, month: month)
        let activeDays: Int = {
            if year < currentYear || (year == currentYear && month < currentMonth) {
                return dim          // completed month — full range
            } else if year == currentYear && month == currentMonth {
                return currentDay   // current month — up to today
            }
            return dim              // future months (shouldn't generate transactions)
        }()

        func scaledDay(_ offset: Int) -> Int {
            if activeDays < dim {
                return max(1, min(activeDays,
                    Int(ceil(Double(offset) * Double(activeDays) / Double(dim)))))
            }
            return max(1, min(offset, dim))
        }

        func day(_ offset: Int) -> Date {
            var comps = DateComponents()
            comps.year  = year
            comps.month = month
            comps.day   = scaledDay(offset)
            return Calendar.current.date(from: comps) ?? Date()
        }

        // Subtitle label using the same scaled day so displayed dates never exceed activeDays.
        func label(_ offset: Int) -> String {
            dateLabel(year: year, month: month, day: scaledDay(offset))
        }

        var items: [Transaction] = []

        // ── Revenue: card payments (Square Card Sales ≈ 68 % of revenue) ─────────
        // 15 entries on ODD day offsets only (1,3,5,…29).  For any partial month
        // scaledDay maps odd N → unique day N/2 so no two cards ever land on the
        // same date.  Non-card items share these same odd days (inserted after) so
        // each date in the list reads "card → cash/online/gift card", never "card
        // → card".  Fractions sum to exactly 1.00.
        let cardSalesTotal = revTotal * 0.68
        items.append(Transaction(id: UUID(), date: day(1),  amount: cardSalesTotal * 0.035,
            merchantName: "Card payment",      subtitle: label(1),
            locationName: locations[0], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(3),  amount: cardSalesTotal * 0.038,
            merchantName: "Card payment",      subtitle: label(3),
            locationName: locations[1], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(5),  amount: cardSalesTotal * 0.040,
            merchantName: "Card payment",      subtitle: label(5),
            locationName: locations[2], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(7),  amount: cardSalesTotal * 0.076,
            merchantName: "Card payments (2)", subtitle: label(7),
            locationName: locations[0], cardInfo: nil, type: .cardPaymentGroup(count: 2),
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(9),  amount: cardSalesTotal * 0.042,
            merchantName: "Card payment",      subtitle: label(9),
            locationName: locations[1], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(11), amount: cardSalesTotal * 0.155,
            merchantName: "Card payments (4)", subtitle: label(11),
            locationName: locations[2], cardInfo: nil, type: .cardPaymentGroup(count: 4),
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(13), amount: cardSalesTotal * 0.040,
            merchantName: "Card payment",      subtitle: label(13),
            locationName: locations[0], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(15), amount: cardSalesTotal * 0.082,
            merchantName: "Card payments (2)", subtitle: label(15),
            locationName: locations[1], cardInfo: nil, type: .cardPaymentGroup(count: 2),
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(17), amount: cardSalesTotal * 0.038,
            merchantName: "Card payment",      subtitle: label(17),
            locationName: locations[2], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(19), amount: cardSalesTotal * 0.118,
            merchantName: "Card payments (3)", subtitle: label(19),
            locationName: locations[0], cardInfo: nil, type: .cardPaymentGroup(count: 3),
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(21), amount: cardSalesTotal * 0.042,
            merchantName: "Card payment",      subtitle: label(21),
            locationName: locations[1], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(23), amount: cardSalesTotal * 0.080,
            merchantName: "Card payments (2)", subtitle: label(23),
            locationName: locations[2], cardInfo: nil, type: .cardPaymentGroup(count: 2),
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(25), amount: cardSalesTotal * 0.040,
            merchantName: "Card payment",      subtitle: label(25),
            locationName: locations[0], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(27), amount: cardSalesTotal * 0.122,
            merchantName: "Card payments (3)", subtitle: label(27),
            locationName: locations[1], cardInfo: nil, type: .cardPaymentGroup(count: 3),
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(29), amount: cardSalesTotal * 0.052,
            merchantName: "Card payment",      subtitle: label(29),
            locationName: locations[2], cardInfo: nil, type: .cardPayment,
            expenseCategory: nil, isRevenue: true))

        // ── Revenue: Online Payments (18 %) ───────────────────────────────────────
        // 5 payments on EVEN days — each pairs with the preceding odd-day card so
        // every calendar date has both revenue types. Fractions sum to 1.00.
        let onlineTotal = revTotal * 0.18
        items.append(Transaction(id: UUID(), date: day(4),  amount: onlineTotal * 0.22,
            merchantName: "Online payment", subtitle: label(4),
            locationName: nil, cardInfo: nil, type: .onlineOrder,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(10), amount: onlineTotal * 0.20,
            merchantName: "Online payment", subtitle: label(10),
            locationName: nil, cardInfo: nil, type: .onlineOrder,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(18), amount: onlineTotal * 0.18,
            merchantName: "Online payment", subtitle: label(18),
            locationName: nil, cardInfo: nil, type: .onlineOrder,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(24), amount: onlineTotal * 0.22,
            merchantName: "Online payment", subtitle: label(24),
            locationName: nil, cardInfo: nil, type: .onlineOrder,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(28), amount: onlineTotal * 0.18,
            merchantName: "Online payment", subtitle: label(28),
            locationName: nil, cardInfo: nil, type: .onlineOrder,
            expenseCategory: nil, isRevenue: true))

        // ── Revenue: Cash Sales (10 %) ────────────────────────────────────────────
        // 6 payments on even days, each a different day from online/gift card.
        // Fractions sum to 1.00.
        let cashTotal = revTotal * 0.10
        items.append(Transaction(id: UUID(), date: day(2),  amount: cashTotal * 0.18,
            merchantName: "Cash payment", subtitle: label(2),
            locationName: locations[2], cardInfo: nil, type: .cashPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(8),  amount: cashTotal * 0.20,
            merchantName: "Cash payment", subtitle: label(8),
            locationName: locations[0], cardInfo: nil, type: .cashPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(14), amount: cashTotal * 0.17,
            merchantName: "Cash payment", subtitle: label(14),
            locationName: locations[1], cardInfo: nil, type: .cashPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(20), amount: cashTotal * 0.18,
            merchantName: "Cash payment", subtitle: label(20),
            locationName: locations[2], cardInfo: nil, type: .cashPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(26), amount: cashTotal * 0.15,
            merchantName: "Cash payment", subtitle: label(26),
            locationName: locations[0], cardInfo: nil, type: .cashPayment,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(30), amount: cashTotal * 0.12,
            merchantName: "Cash payment", subtitle: label(30),
            locationName: locations[1], cardInfo: nil, type: .cashPayment,
            expenseCategory: nil, isRevenue: true))

        // ── Revenue: Gift Cards (4 %) ─────────────────────────────────────────────
        // 2 sales on even days not used by online or cash. Fractions sum to 1.00.
        let giftCardTotal = revTotal * 0.04
        items.append(Transaction(id: UUID(), date: day(6),  amount: giftCardTotal * 0.55,
            merchantName: "Gift card", subtitle: label(6),
            locationName: locations[0], cardInfo: nil, type: .giftCard,
            expenseCategory: nil, isRevenue: true))
        items.append(Transaction(id: UUID(), date: day(22), amount: giftCardTotal * 0.45,
            merchantName: "Gift card", subtitle: label(22),
            locationName: locations[2], cardInfo: nil, type: .giftCard,
            expenseCategory: nil, isRevenue: true))

        // ── Expenses: COGS — card purchases ───────────────────────────────────────
        // May gets a special override: a Faire Wholesale summer inventory order
        // is the notable purchase (~16 % of COGS, ≈ $10 k) but the remaining
        // COGS is spread across six vendors so the daily chart stays balanced.
        // Fractions sum to 1.00. All other months use the normal spread below.
        if month == 5 {
            // UPS reduced from ~$6,900 → ~$902 (0.0144) and Home Depot from ~$5,600 → ~$647 (0.0104).
            // The freed ~$11k is redistributed equally (+0.0438 each) across the four main vendors.
            items.append(Transaction(
                id: UUID(), date: day(3), amount: -expB.cogs * 0.2438,
                merchantName: "Tundra", subtitle: label(3),
                locationName: "Hayes Valley", cardInfo: "Square Card 4812", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(8), amount: -expB.cogs * 0.2038,
                merchantName: "Faire Wholesale", subtitle: label(8),
                locationName: nil, cardInfo: "Visa 7832", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(12), amount: -expB.cogs * 0.1638,
                merchantName: "Faire Wholesale", subtitle: label(12),
                locationName: nil, cardInfo: "Visa 7832", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(16), amount: -expB.cogs * 0.2238,
                merchantName: "Next Level Apparel", subtitle: label(16),
                locationName: nil, cardInfo: "Square Card 4812", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(21), amount: -expB.cogs * 0.14,
                merchantName: "Noissue", subtitle: label(21),
                locationName: "Bernal Heights", cardInfo: "Visa 7832", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(25), amount: -expB.cogs * 0.0144,
                merchantName: "UPS", subtitle: label(25),
                locationName: nil, cardInfo: "Square Card 4812", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(28), amount: -expB.cogs * 0.0104,
                merchantName: "Home Depot", subtitle: label(28),
                locationName: "The Mission", cardInfo: "Amex 5678", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
        } else {
            // Normal months: spread COGS across days that sit between card payment rows.
            // Tundra (0.48) is split: ~60% stays as Tundra (0.29), ~40% goes to Faire Wholesale (0.19).
            items.append(Transaction(
                id: UUID(), date: day(3), amount: -expB.cogs * 0.29,
                merchantName: "Tundra", subtitle: label(3),
                locationName: "Hayes Valley", cardInfo: "Square Card 4812", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(8), amount: -expB.cogs * 0.19,
                merchantName: "Faire Wholesale", subtitle: label(8),
                locationName: nil, cardInfo: "Visa 7832", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(11), amount: -expB.cogs * 0.12,
                merchantName: "UPS", subtitle: label(11),
                locationName: nil, cardInfo: "Visa 7832", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(15), amount: -expB.cogs * 0.20,
                merchantName: "Next Level Apparel", subtitle: label(15),
                locationName: nil, cardInfo: "Square Card 4812", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(20), amount: -expB.cogs * 0.12,
                merchantName: "Noissue", subtitle: label(20),
                locationName: "Bernal Heights", cardInfo: "Visa 7832", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(25), amount: -expB.cogs * 0.08,
                merchantName: "Home Depot", subtitle: label(25),
                locationName: "The Mission", cardInfo: "Amex 5678", type: .purchase,
                expenseCategory: ExpenseCategory.cogs.rawValue, isRevenue: false))
        }

        // ── Expenses: Labor — Square Payroll (account-level, per location) ─────────
        let payrollSplit: [(Double, String)] = [
            (0.40, "Hayes Valley"),
            (0.35, "Bernal Heights"),
            (0.25, "The Mission")
        ]
        for (frac, loc) in payrollSplit {
            items.append(Transaction(
                id: UUID(), date: day(1), amount: -expB.labor * frac * 0.5,
                merchantName: "Square Payroll", subtitle: label(1),
                locationName: loc, cardInfo: nil, type: .purchase,
                expenseCategory: ExpenseCategory.laborPayroll.rawValue, isRevenue: false))
            items.append(Transaction(
                id: UUID(), date: day(16), amount: -expB.labor * frac * 0.5,
                merchantName: "Square Payroll", subtitle: label(16),
                locationName: loc, cardInfo: nil, type: .purchase,
                expenseCategory: ExpenseCategory.laborPayroll.rawValue, isRevenue: false))
        }

        // ── Expenses: Rent — ACH per location (no card) ───────────────────────────
        items.append(Transaction(
            id: UUID(), date: day(1), amount: -expB.rent * 0.45,
            merchantName: "Landlord LLC", subtitle: label(1),
            locationName: "Hayes Valley", cardInfo: nil, type: .purchase,
            expenseCategory: ExpenseCategory.rentUtilities.rawValue, isRevenue: false))
        items.append(Transaction(
            id: UUID(), date: day(1), amount: -expB.rent * 0.35,
            merchantName: "Landlord LLC", subtitle: label(1),
            locationName: "Bernal Heights", cardInfo: nil, type: .purchase,
            expenseCategory: ExpenseCategory.rentUtilities.rawValue, isRevenue: false))
        items.append(Transaction(
            id: UUID(), date: day(1), amount: -expB.rent * 0.20,
            merchantName: "Landlord LLC", subtitle: label(1),
            locationName: "The Mission", cardInfo: nil, type: .purchase,
            expenseCategory: ExpenseCategory.rentUtilities.rawValue, isRevenue: false))

        // ── Expenses: Marketing — card purchases ───────────────────────────────────
        items.append(Transaction(
            id: UUID(), date: day(10), amount: -expB.marketing * 0.50,
            merchantName: "Etsy", subtitle: label(10),
            locationName: nil, cardInfo: "Visa 7832", type: .purchase,
            expenseCategory: ExpenseCategory.marketing.rawValue, isRevenue: false))
        items.append(Transaction(
            id: UUID(), date: day(21), amount: -expB.marketing * 0.50,
            merchantName: "Etsy", subtitle: label(21),
            locationName: nil, cardInfo: "Square Card 4812", type: .purchase,
            expenseCategory: ExpenseCategory.marketing.rawValue, isRevenue: false))

        // ── Expenses: Utilities — card purchases ───────────────────────────────────
        items.append(Transaction(
            id: UUID(), date: day(12), amount: -expB.utilities * 0.60,
            merchantName: "Uline", subtitle: label(12),
            locationName: nil, cardInfo: "Square Card 4812", type: .purchase,
            expenseCategory: ExpenseCategory.rentUtilities.rawValue, isRevenue: false))
        items.append(Transaction(
            id: UUID(), date: day(22), amount: -expB.utilities * 0.40,
            merchantName: "Amazon", subtitle: label(22),
            locationName: nil, cardInfo: "Visa 7832", type: .purchase,
            expenseCategory: ExpenseCategory.rentUtilities.rawValue, isRevenue: false))

        // ── Expenses: Misc — card purchases ────────────────────────────────────────
        items.append(Transaction(
            id: UUID(), date: day(6), amount: -expB.misc * 0.22,
            merchantName: "Staples", subtitle: label(6),
            locationName: "Hayes Valley", cardInfo: "Square Card 4812", type: .purchase,
            expenseCategory: ExpenseCategory.officeSupplies.rawValue, isRevenue: false))
        items.append(Transaction(
            id: UUID(), date: day(14), amount: -expB.misc * 0.28,
            merchantName: "Señor Sisig", subtitle: label(14),
            locationName: "Bernal Heights", cardInfo: "Visa 7832", type: .purchase,
            expenseCategory: ExpenseCategory.officeSupplies.rawValue, isRevenue: false))
        items.append(Transaction(
            id: UUID(), date: day(19), amount: -expB.misc * 0.25,
            merchantName: "Slack", subtitle: label(19),
            locationName: "Hayes Valley", cardInfo: "Square Card 4812", type: .purchase,
            expenseCategory: ExpenseCategory.officeSupplies.rawValue, isRevenue: false))
        items.append(Transaction(
            id: UUID(), date: day(24), amount: -expB.misc * 0.25,
            merchantName: "Airtable", subtitle: label(24),
            locationName: nil, cardInfo: "Square Card 4812", type: .purchase,
            expenseCategory: ExpenseCategory.officeSupplies.rawValue, isRevenue: false))

        // ── Personal expenses (excluded from all P&L charts and calculations) ──────
        // These are owner personal purchases that appear naturally in the transaction
        // list but never affect revenue, expenses, or net profit.
        let personalCard = "Visa 7832"
        // Blue Bottle Coffee — coffee runs, ~$6–$9 each, most days of the month
        let bluBottleDays: [(Int, Double)] = [
            (2, 7.50), (4, 6.25), (6, 8.75), (8, 5.50), (10, 7.25),
            (12, 9.00), (14, 6.75), (16, 8.25), (18, 7.00), (20, 8.50)
        ]
        for (d, amt) in bluBottleDays {
            items.append(Transaction(
                id: UUID(), date: day(d), amount: -amt,
                merchantName: "Blue Bottle Coffee", subtitle: label(d),
                locationName: "Hayes Valley", cardInfo: personalCard, type: .purchase,
                expenseCategory: ExpenseCategory.personal.rawValue, isRevenue: false))
        }
        // DoorDash — lunch/dinner deliveries, ~$35–$65 each, a few times a week
        let doordashDays: [(Int, Double)] = [
            (3, 42.50), (7, 38.75), (11, 55.00), (17, 47.25), (23, 61.50), (27, 35.00)
        ]
        for (d, amt) in doordashDays {
            items.append(Transaction(
                id: UUID(), date: day(d), amount: -amt,
                merchantName: "DoorDash", subtitle: label(d),
                locationName: nil, cardInfo: personalCard, type: .purchase,
                expenseCategory: ExpenseCategory.personal.rawValue, isRevenue: false))
        }
        // Whole Foods — grocery runs, ~$45–$85 each, once a week or so
        let wholeFoodsDays: [(Int, Double)] = [
            (5, 68.40), (13, 45.75), (21, 82.50), (29, 52.30)
        ]
        for (d, amt) in wholeFoodsDays {
            items.append(Transaction(
                id: UUID(), date: day(d), amount: -amt,
                merchantName: "Whole Foods", subtitle: label(d),
                locationName: nil, cardInfo: personalCard, type: .purchase,
                expenseCategory: ExpenseCategory.personal.rawValue, isRevenue: false))
        }

        // ── Automated transfers (savings sweep, loan payment) ─────────────────────
        items.append(Transaction(
            id: UUID(), date: day(30), amount: -(expTotal * 0.02),
            merchantName: "General Savings", subtitle: label(30),
            locationName: "Hayes Valley", cardInfo: nil, type: .automatedTransfer,
            expenseCategory: ExpenseCategory.transfers.rawValue, isRevenue: false))
        items.append(Transaction(
            id: UUID(), date: day(15), amount: -(expTotal * 0.015),
            merchantName: "BofA 1892", subtitle: label(15),
            locationName: "General Savings", cardInfo: nil, type: .bankTransfer,
            expenseCategory: ExpenseCategory.transfers.rawValue, isRevenue: false))

        return items.sorted { $0.date < $1.date }
    }

    /// Human-readable date label used as a transaction subtitle ("Dec 15, 2024").
    static func dateLabel(year: Int, month: Int, day: Int) -> String {
        let abbrevs = ["Jan","Feb","Mar","Apr","May","Jun",
                       "Jul","Aug","Sep","Oct","Nov","Dec"]
        let m = abbrevs[max(0, min(11, month - 1))]
        return "\(m) \(day), \(year)"
    }

    /// Transactions for a full quarter (all months in the quarter concatenated).
    static func sampleTransactions(year: Int, quarter: Int) -> [Transaction] {
        let startMonth = (quarter - 1) * 3 + 1
        return (startMonth...(startMonth + 2)).flatMap {
            sampleTransactions(year: year, month: $0)
        }
    }

    /// Transactions for a full year.
    static func sampleTransactions(year: Int) -> [Transaction] {
        (1...12).flatMap { sampleTransactions(year: year, month: $0) }
    }

    /// All available transactions across every data year.
    /// Stored as `let` so the full list is generated exactly once and reused.
    static let allTransactions: [Transaction] =
        (minYear...currentYear).flatMap { sampleTransactions(year: $0) }

    /// Sum the absolute expense amounts for each P&L-included `ExpenseCategory`
    /// across all transactions in the given year.  Category overrides from the
    /// session store are applied: a transaction overridden to Personal/Transfers
    /// is omitted; one moved from an excluded to an included category is counted
    /// under the new category.  Categories with no transactions are absent from
    /// the returned dictionary so callers can filter them out.
    static func expenseCategoryTotals(year: Int,
                                       overrides: [UUID: String] = [:]) -> [String: Double] {
        var totals: [String: Double] = [:]
        for tx in sampleTransactions(year: year) {
            guard !tx.isRevenue else { continue }
            let catRaw = overrides[tx.id] ?? tx.expenseCategory ?? ""
            guard let expCat = ExpenseCategory(rawValue: catRaw),
                  !expCat.excludedFromPL
            else { continue }
            totals[catRaw, default: 0] += abs(tx.amount)
        }
        return totals
    }
}

// MARK: - Generic Bar Chart Entry
//
// Unified data type for the P&L detail bar chart across all three period modes
// (Year → monthly, Quarter → weekly, Month → daily).

struct BarChartEntry: Identifiable {
    let id: Int           // 0-based index within its period
    let label: String     // short x-axis label (e.g. "J", "1", "15")
    let fullLabel: String // full display label (e.g. "January", "Week 1", "Dec 15")
    let revenue: Double
    let expenses: Double
    /// True when this bar represents the current (partial) period — rendered with diagonal hatching.
    var isCurrent: Bool = false
    /// True only for genuinely future periods (e.g. Dec 16-31 while today is Dec 15).
    /// Distinct from `hasData` so that past days with zero transactions are not
    /// mistaken for future bars when the user scrubs over them.
    var isFuture: Bool = false

    var netProfit: Double { revenue - expenses }
    var hasData: Bool { revenue > 0 || expenses > 0 }
}

// MARK: - Monthly Financial Record

struct MonthlyFinancial: Identifiable {
    let id: Int
    let month: String       // single-letter chart label
    let fullMonth: String   // full name for tooltips
    let revenue: Double
    let expenses: Double

    var netProfit: Double { revenue - expenses }

    /// Proportional breakdown of this month's expenses by category.
    var expenseBreakdown: ExpenseBreakdown { ExpenseBreakdown(total: expenses) }
}

// MARK: - Weekly Financial Record

struct WeeklyFinancial: Identifiable {
    let id: Int             // 0-based (0-12)
    let startLabel: String  // axis label e.g. "10/1"; empty for future periods
    let dateRange: String   // tooltip label e.g. "Oct 1 - Oct 7"
    let revenue: Double
    let expenses: Double

    var netProfit: Double { revenue - expenses }
    var hasData: Bool { revenue > 0 || expenses > 0 }
}

// MARK: - Daily Financial Record

struct DailyFinancial: Identifiable {
    let id: Int       // day number 1-31
    let revenue: Double
    let expenses: Double
    /// True only for days that haven't happened yet (e.g. Dec 16-31 on Dec 15).
    /// Past days that simply had no transactions have isFuture = false but hasData = false.
    var isFuture: Bool = false

    var netProfit: Double { revenue - expenses }
    var hasData: Bool { revenue > 0 || expenses > 0 }
}

// MARK: - App Financials (YTD through December 15)
//
// Business profile: 3-location boutique retail operation (US)
//
//   Annual revenue  : ~$1,100,075
//   Annual expenses : ~$968,073
//   Net profit      : ~$132,002  (~12% margin)
//
// 12% is solid for independent boutique retail (industry average: 9-11%).
// Expense mix: COGS 51.5% | Labor 24% | Rent 12.2% | Marketing 4.4% |
//              Utilities 4.4% | Misc 3.5%
//
// Seasonal shape: strong Jan-Feb (post-holiday clearance + Valentine's),
// soft spring dip, May-Jul loss months (slow season + summer inventory buy),
// steady Q3 recovery, strong Q4 holiday run.
//
// Scale: original seed values multiplied by revenue ×11.14 and expenses ×17.05.

enum AppFinancials {

    // MARK: - Account Balances
    //
    // Current balances for a 3-location boutique retail operation.
    // Net balance = checking + all savings - outstanding loans (cash position).
    // Credit card outstanding is excluded; it is paid from operating cash flow.

    // Checking — one Square Checking account per location
    static let checkingHayesValley:   Double = 42_847.33
    static let checkingBernalHeights: Double = 31_204.17
    static let checkingTheMission:    Double = 23_461.34
    static let totalChecking: Double = checkingHayesValley + checkingBernalHeights + checkingTheMission

    // Savings — general operating reserve, sales-tax set-aside, and rainy-day fund
    static let savingsGeneral:  Double = 48_200.00
    static let savingsSalesTax: Double = 24_750.00
    static let savingsRainyDay: Double = 15_000.00
    static let totalSavings: Double = savingsGeneral + savingsSalesTax + savingsRainyDay

    // Loans — outstanding principal per location
    static let loanBernalHeights: Double = 46_718.63
    static let loanTheMission:    Double = 68_541.29
    static let totalLoans: Double = loanBernalHeights + loanTheMission

    // Net cash position (checking + savings − loans)
    static let netBalance: Double = totalChecking + totalSavings - totalLoans

    static let netBalanceFormatted: String = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: netBalance)) ?? "$0.00"
    }()

    // Revenue ~$1,172,000 | Expenses ~$943,000 | Net ~$229,000 (~19.5% margin)
    // Winter months boosted (holiday + clearance traffic); spring/summer expenses
    // trimmed (realistic for a boutique that manages inventory buys more tightly).
    // May is still the worst month — a big summer inventory purchase lands mid-month —
    // but it's a manageable dip rather than a catastrophic loss.
    static let monthly: [MonthlyFinancial] = [
        .init(id:  0, month: "J", fullMonth: "January",   revenue: 124_318.47, expenses:  79_234.18),  // net  45,084.29  holiday clearance + strong traffic
        .init(id:  1, month: "F", fullMonth: "February",  revenue: 115_847.93, expenses:  77_891.45),  // net  37,956.48
        .init(id:  2, month: "M", fullMonth: "March",     revenue:  98_998.06, expenses:  78_758.72),  // net  20,239.34
        .init(id:  3, month: "A", fullMonth: "April",     revenue:  87_109.56, expenses:  79_418.33),  // net   7,691.23
        .init(id:  4, month: "M", fullMonth: "May",       revenue:  79_432.15, expenses: 121_847.63),  // net -42,415.48  large Faire wholesale order lands mid-month
        .init(id:  5, month: "J", fullMonth: "June",      revenue:  81_247.89, expenses:  83_612.34),  // net  -2,364.45
        .init(id:  6, month: "J", fullMonth: "July",      revenue:  84_518.32, expenses:  79_841.27),  // net   4,677.05
        .init(id:  7, month: "A", fullMonth: "August",    revenue:  88_935.86, expenses:  80_758.01),  // net   8,177.85
        .init(id:  8, month: "S", fullMonth: "September", revenue:  97_354.91, expenses:  80_144.72),  // net  17,210.19
        .init(id:  9, month: "O", fullMonth: "October",   revenue: 103_464.20, expenses:  78_006.99),  // net  25,457.21
        .init(id: 10, month: "N", fullMonth: "November",  revenue: 121_384.67, expenses:  78_234.51),  // net  43,150.16  pre-holiday buildup
        .init(id: 11, month: "D", fullMonth: "December",  revenue:  89_847.53, expenses:  56_418.73),  // net  33,428.80  holiday through Dec 15
    ]

    // MARK: - Quarterly weekly data (Q4: Oct 1 - Dec 31, 13 weeks)
    //
    // Weeks 0-10 have data; weeks 11-12 are future/empty (Dec 16-31).

    static let quarterlyWeeks: [WeeklyFinancial] = [
        .init(id:  0, startLabel: "10/1",  dateRange: "Oct 1 - Oct 7",    revenue:  23_302.99, expenses:  17_552.47),
        .init(id:  1, startLabel: "10/8",  dateRange: "Oct 8 - Oct 14",   revenue:  23_444.91, expenses:  17_695.17),
        .init(id:  2, startLabel: "10/15", dateRange: "Oct 15 - Oct 21",  revenue:  23_264.11, expenses:  17_469.95),
        .init(id:  3, startLabel: "10/22", dateRange: "Oct 22 - Oct 28",  revenue:  23_369.83, expenses:  17_621.52),
        .init(id:  4, startLabel: "10/29", dateRange: "Oct 29 - Nov 4",   revenue:  24_658.05, expenses:  17_899.61),
        .init(id:  5, startLabel: "11/5",  dateRange: "Nov 5 - Nov 11",   revenue:  25_483.20, expenses:  17_958.42),
        .init(id:  6, startLabel: "11/12", dateRange: "Nov 12 - Nov 18",  revenue:  25_607.85, expenses:  18_114.09),
        .init(id:  7, startLabel: "11/19", dateRange: "Nov 19 - Nov 25",  revenue:  25_341.38, expenses:  17_860.39),
        .init(id:  8, startLabel: "11/26", dateRange: "Nov 26 - Dec 2",   revenue:  28_701.43, expenses:  20_338.43),
        .init(id:  9, startLabel: "12/3",  dateRange: "Dec 3 - Dec 9",    revenue:  33_489.62, expenses:  25_576.19),
        .init(id: 10, startLabel: "12/10", dateRange: "Dec 10 - Dec 15",  revenue:  31_675.81, expenses:  21_838.66),
        .init(id: 11, startLabel: "",      dateRange: "Dec 16 - Dec 22",  revenue:  0,         expenses:  0),
        .init(id: 12, startLabel: "",      dateRange: "Dec 23 - Dec 31",  revenue:  0,         expenses:  0),
    ]

    // MARK: - December daily data (days 1-15 have data; 16-31 are future/empty)
    //
    // Revenue sum  : ~$75,661   (matches December monthly)
    // Expenses sum : ~$54,920   (matches December monthly)
    // Net profit   : ~$20,741   (matches December monthly)

    static let decemberDaily: [DailyFinancial] = {
        let active: [(Int, Double, Double)] = [
            ( 1,  4_717.45,  3_381.35),  // net  1,336.10
            ( 2,  5_777.54,  4_122.35),  // net  1,655.19
            ( 3,  4_336.13,  3_196.02),  // net  1,140.11
            ( 4,  4_034.69,  4_397.71),  // net   -363.02
            ( 5,  4_918.87,  3_573.85),  // net  1,345.02
            ( 6,  5_428.54,  3_724.40),  // net  1,704.14
            ( 7,  4_221.85,  3_124.75),  // net  1,097.10
            ( 8,  5_956.02,  4_208.45),  // net  1,747.57
            ( 9,  4_593.91,  3_351.01),  // net  1,242.90
            (10,  5_613.89,  3_890.30),  // net  1,723.59
            (11,  5_205.61,  3_643.24),  // net  1,562.37
            (12,  6_147.39,  4_251.59),  // net  1,895.80
            (13,  4_438.96,  3_288.09),  // net  1,150.87
            (14,  5_444.85,  3_776.07),  // net  1,668.78
            (15,  4_825.51,  2_990.38),  // net  1,835.13  (today, partial)
        ]
        let byDay = Dictionary(uniqueKeysWithValues: active.map {
            ($0.0, DailyFinancial(id: $0.0, revenue: $0.1, expenses: $0.2))
        })
        return (1...31).map { day in
            byDay[day] ?? DailyFinancial(id: day, revenue: 0, expenses: 0, isFuture: true)
        }
    }()

    // MARK: - Computed totals (2024)

    static var totalRevenue: Double  { monthly.map(\.revenue).reduce(0, +) }
    static var totalExpenses: Double { monthly.map(\.expenses).reduce(0, +) }
    static var netProfit: Double     { totalRevenue - totalExpenses }

    // MARK: - Currency formatting

    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func formatted(_ value: Double) -> String {
        let abs = currencyFormatter.string(from: NSNumber(value: Swift.abs(value))) ?? "$0.00"
        return value < 0 ? "-\(abs)" : abs
    }

    static var netProfitFormatted: String    { formatted(netProfit) }
    static var totalRevenueFormatted: String { formatted(totalRevenue) }
    static var totalExpensesFormatted: String { formatted(totalExpenses) }

    // =========================================================================
    // MARK: - Time-travel data (multi-year/quarter/month navigation)
    // =========================================================================

    // MARK: Current date context & navigation bounds

    static let currentYear    = 2024
    static let currentMonth   = 12   // December
    static let currentDay     = 15
    static let currentQuarter = 4
    static let minYear        = 2023  // How far back the user can navigate

    // MARK: - 2023 Monthly Data
    //
    // 2023 was a slightly softer year for the business — similar seasonal shape
    // but ~21% less net profit (~$180K vs ~$229K in 2024).
    // Revenue ran about 9% lower; expenses about 6% lower (fixed costs stayed).
    //
    //   Annual revenue  : ~$1,057,019
    //   Annual expenses : ~$876,559
    //   Net profit      : ~$180,460  (~17.1% margin)

    static let monthly2023: [MonthlyFinancial] = [
        .init(id:  0, month: "J", fullMonth: "January",   revenue: 113_210.47, expenses:  74_481.83),  // net  38,728.64
        .init(id:  1, month: "F", fullMonth: "February",  revenue: 105_423.19, expenses:  73_218.62),  // net  32,204.57
        .init(id:  2, month: "M", fullMonth: "March",     revenue:  90_087.31, expenses:  74_026.44),  // net  16,060.87
        .init(id:  3, month: "A", fullMonth: "April",     revenue:  79_267.83, expenses:  74_648.17),  // net   4,619.66
        .init(id:  4, month: "M", fullMonth: "May",       revenue:  72_284.56, expenses:  85_391.72),  // net -13,107.16  deeper loss than 2024
        .init(id:  5, month: "J", fullMonth: "June",      revenue:  73_936.48, expenses:  78_593.21),  // net  -4,656.73
        .init(id:  6, month: "J", fullMonth: "July",      revenue:  76_911.29, expenses:  75_046.83),  // net   1,864.46
        .init(id:  7, month: "A", fullMonth: "August",    revenue:  80_932.74, expenses:  75_908.19),  // net   5,024.55
        .init(id:  8, month: "S", fullMonth: "September", revenue:  88_593.15, expenses:  75_341.87),  // net  13,251.28
        .init(id:  9, month: "O", fullMonth: "October",   revenue:  94_152.38, expenses:  73_332.76),  // net  20,819.62
        .init(id: 10, month: "N", fullMonth: "November",  revenue: 110_461.84, expenses:  73_541.27),  // net  36,920.57
        .init(id: 11, month: "D", fullMonth: "December",  revenue:  81_757.43, expenses:  53_027.81),  // net  28,729.62
    ]

    // MARK: - Multi-year / multi-period accessors

    /// Monthly financials for a given year (2023 or 2024).
    /// Returns empty array for years outside the data range (e.g. 2022).
    static func monthlyData(year: Int) -> [MonthlyFinancial] {
        switch year {
        case 2023: return monthly2023
        case 2024: return monthly
        default:   return []
        }
    }

    /// Monthly financials adjusted for category overrides.
    /// Transactions overridden to an excluded category reduce the monthly expense
    /// total; those moved from excluded to included increase it.
    static func monthlyData(year: Int, overrides: [UUID: String]) -> [MonthlyFinancial] {
        guard !overrides.isEmpty else { return monthlyData(year: year) }
        var base = monthlyData(year: year)
        for monthIdx in base.indices {
            let m   = base[monthIdx]
            let txs = sampleTransactions(year: year, month: m.id + 1) // id is 0-based

            // Compute the same normalization factor used in dailyDataFromTransactions
            let rawExpSum  = txs.filter { !$0.isRevenue }.map { abs($0.amount) }.reduce(0, +)
            let expScale   = rawExpSum > 0 ? m.expenses / rawExpSum : 1.0

            var expDelta = 0.0
            for tx in txs where !tx.isRevenue {
                guard let override = overrides[tx.id] else { continue }
                let wasExcluded = (tx.expenseCategory.flatMap(ExpenseCategory.init)?.excludedFromPL ?? false)
                let nowExcluded = (ExpenseCategory(rawValue: override)?.excludedFromPL ?? false)
                if !wasExcluded && nowExcluded  { expDelta -= abs(tx.amount) * expScale }
                if  wasExcluded && !nowExcluded { expDelta += abs(tx.amount) * expScale }
            }
            if expDelta != 0 {
                base[monthIdx] = MonthlyFinancial(
                    id: m.id, month: m.month, fullMonth: m.fullMonth,
                    revenue: m.revenue, expenses: max(0, m.expenses + expDelta)
                )
            }
        }
        return base
    }

    /// 13-week quarterly data for any supported year + quarter.
    /// Q4 2024 delegates to the hand-crafted `quarterlyWeeks` array;
    /// all other periods are computed proportionally from monthly data.
    /// Returns empty array for years outside the data range.
    static func weeklyData(year: Int, quarter: Int) -> [WeeklyFinancial] {
        guard year >= minYear else { return [] }
        if year == 2024 && quarter == 4 { return quarterlyWeeks }
        return buildWeeklyData(year: year, quarter: quarter, months: monthlyData(year: year))
    }

    /// Overload that applies category overrides before distributing into weeks.
    /// When overrides alter expense totals, those changes propagate into weekly figures.
    static func weeklyData(year: Int, quarter: Int,
                            overrides: [UUID: String]) -> [WeeklyFinancial] {
        guard year >= minYear else { return [] }
        guard !overrides.isEmpty else { return weeklyData(year: year, quarter: quarter) }
        let adjusted = monthlyData(year: year, overrides: overrides)
        return buildWeeklyData(year: year, quarter: quarter, months: adjusted)
    }

    /// Daily data for any supported year + month, with optional category overrides.
    /// Derived directly from `sampleTransactions` so the bar chart always
    /// matches what the Transactions page shows for that month.
    /// Transactions overridden to an excluded category (Personal/Transfers) are
    /// removed from the expense totals; those moved to an included category are added.
    /// Monthly revenue and adjusted expense totals are preserved via normalisation.
    static func dailyData(year: Int, month: Int,
                           overrides: [UUID: String] = [:]) -> [DailyFinancial] {
        guard year >= minYear else { return [] }
        return dailyDataFromTransactions(year: year, month: month, overrides: overrides)
    }

    /// Aggregates per-day revenue and expense amounts from the sample transactions,
    /// applying any category overrides, then normalises values to monthly record totals.
    ///
    /// - `overrides`: category raw-value keyed by transaction UUID; empty = no changes.
    /// - Future days (beyond the active cutoff) are marked `isFuture = true`.
    /// - Past days with zero transactions have `isFuture = false`, `hasData = false`.
    private static func dailyDataFromTransactions(year: Int, month: Int,
                                                   overrides: [UUID: String] = [:]) -> [DailyFinancial] {
        let months    = monthlyData(year: year)
        let mData     = months[month - 1]
        let totalDays = daysInMonth(year: year, month: month)
        let cal       = Calendar.current
        let txs       = sampleTransactions(year: year, month: month)

        // ── Compute the adjusted monthly expense target ───────────────────────
        // We normalise raw transaction amounts to the monthly record.  Overrides
        // that exclude previously-included expenses shrink the target; overrides
        // that include previously-excluded expenses grow it.
        let fullRawExpSum = txs.filter { !$0.isRevenue }.map { abs($0.amount) }.reduce(0, +)
        let baseExpScale  = fullRawExpSum > 0 ? mData.expenses / fullRawExpSum : 1.0

        var effectiveExclusion = 0.0
        if !overrides.isEmpty {
            for tx in txs where !tx.isRevenue {
                guard let override = overrides[tx.id] else { continue }
                let wasExcluded = (tx.expenseCategory.flatMap(ExpenseCategory.init)?.excludedFromPL ?? false)
                let nowExcluded = (ExpenseCategory(rawValue: override)?.excludedFromPL ?? false)
                if !wasExcluded && nowExcluded { effectiveExclusion += abs(tx.amount) * baseExpScale }
                if  wasExcluded && !nowExcluded { effectiveExclusion -= abs(tx.amount) * baseExpScale }
            }
        }
        let adjustedMonthlyExp = max(0, mData.expenses - effectiveExclusion)

        // ── Aggregate per-day amounts, skipping excluded expenses ─────────────
        var txRevByDay = [Int: Double]()
        var txExpByDay = [Int: Double]()

        for tx in txs {
            let d = cal.component(.day, from: tx.date)
            if tx.isRevenue {
                txRevByDay[d, default: 0] += tx.amount
            } else {
                let catRaw   = overrides[tx.id] ?? tx.expenseCategory ?? ""
                let excluded = ExpenseCategory(rawValue: catRaw)?.excludedFromPL ?? false
                if !excluded { txExpByDay[d, default: 0] += abs(tx.amount) }
            }
        }

        // ── Normalise to monthly targets ──────────────────────────────────────
        let rawRevSum          = txRevByDay.values.reduce(0, +)
        let rawExpSumRemaining = txExpByDay.values.reduce(0, +)
        let revScale    = rawRevSum          > 0 ? mData.revenue        / rawRevSum          : 1.0
        let expScale    = rawExpSumRemaining > 0 ? adjustedMonthlyExp   / rawExpSumRemaining : 1.0

        let activeDays: Int = {
            if year < currentYear || (year == currentYear && month < currentMonth) {
                return totalDays
            } else if year == currentYear && month == currentMonth {
                return currentDay
            }
            return 0
        }()

        return (1...totalDays).map { day in
            let future = day > activeDays
            return DailyFinancial(
                id:       day,
                revenue:  future ? 0 : (txRevByDay[day]  ?? 0) * revScale,
                expenses: future ? 0 : (txExpByDay[day] ?? 0) * expScale,
                isFuture: future
            )
        }
    }

    // MARK: - Private: calendar helpers

    private static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2:
            let isLeap = (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0)
            return isLeap ? 29 : 28
        case 4, 6, 9, 11: return 30
        default:           return 31
        }
    }

    private static let monthAbbrev = [
        "Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"
    ]

    // MARK: - Private: weekly data generator

    /// Distributes 3 months of financial data into 13 seven-day weeks starting
    /// on the first day of the quarter.  Each week's value is the proportional
    /// share of its constituent month-days, giving mathematically consistent
    /// totals without any hand-crafted numbers.
    private static func buildWeeklyData(year: Int, quarter: Int,
                                         months: [MonthlyFinancial]) -> [WeeklyFinancial] {
        let startMonth = (quarter - 1) * 3 + 1   // 1-indexed: Q1→1, Q2→4, Q3→7, Q4→10

        var results: [WeeklyFinancial] = []
        var curMonth = startMonth
        var curDay   = 1

        for weekIdx in 0..<13 {
            var weekRev  = 0.0
            var weekExp  = 0.0
            let startM = curMonth
            let startD = curDay
            var daysLeft = 7
            var m = curMonth
            var d = curDay

            // Accumulate exactly 7 calendar days across month boundaries
            while daysLeft > 0 && m <= 12 {
                let dim   = daysInMonth(year: year, month: m)
                let avail = min(daysLeft, dim - d + 1)
                let mData = months[m - 1]
                let daily = 1.0 / Double(dim)
                weekRev  += mData.revenue  * daily * Double(avail)
                weekExp  += mData.expenses * daily * Double(avail)
                daysLeft -= avail
                d        += avail
                if d > dim { d = 1; m += 1 }
            }

            // Compute end label (day before the new cursor position)
            var endM = m
            var endD = d - 1
            if endD <= 0 {
                endM -= 1
                if endM >= 1 { endD = daysInMonth(year: year, month: endM) }
            }
            endM = max(1, min(12, endM))

            // Format "Mon DD - Mon DD"
            let sA = monthAbbrev[startM - 1]
            let eA = monthAbbrev[endM   - 1]
            let dateRange = startM == endM
                ? "\(sA) \(startD) – \(sA) \(endD)"
                : "\(sA) \(startD) – \(eA) \(endD)"

            // All generated quarters are fully in the past — hasData == true for all weeks
            results.append(WeeklyFinancial(
                id: weekIdx, startLabel: "", dateRange: dateRange,
                revenue: weekRev, expenses: weekExp
            ))

            curMonth = m
            curDay   = d
        }
        return results
    }

    // MARK: - Private: daily data generator

    /// Distributes a month's revenue and expenses into per-day values using a
    /// deterministic sine-based pattern so the data looks organic but is
    /// reproducible and always sums exactly to the monthly total.
    private static func buildDailyData(year: Int, month: Int) -> [DailyFinancial] {
        let months   = monthlyData(year: year)
        let mData    = months[month - 1]
        let totalDays = daysInMonth(year: year, month: month)

        // How many days actually have data
        let activeDays: Int
        if year < currentYear || (year == currentYear && month < currentMonth) {
            activeDays = totalDays   // completed month
        } else if year == currentYear && month == currentMonth {
            activeDays = currentDay  // current month, up to today
        } else {
            activeDays = 0           // future month
        }

        guard activeDays > 0 else {
            return (1...totalDays).map { DailyFinancial(id: $0, revenue: 0, expenses: 0, isFuture: true) }
        }

        // Generate weights: two overlapping sine waves for organic-looking variation
        var revW = (1...activeDays).map { day -> Double in
            let t = Double(day)
            let s = Double(year) * 0.0011 + Double(month) * 0.013
            return max(0.4, 1.0 + sin(t * 0.73 + s * 13.7) * 0.18
                                + sin(t * 1.31 + s *  7.3) * 0.09)
        }
        var expW = (1...activeDays).map { day -> Double in
            let t = Double(day)
            let s = Double(year) * 0.0011 + Double(month) * 0.013
            return max(0.4, 1.0 + cos(t * 0.61 + s * 11.3) * 0.14
                                + cos(t * 1.73 + s *  5.9) * 0.07)
        }

        // Normalize so totals match the monthly record exactly
        let revSum = revW.reduce(0, +)
        let expSum = expW.reduce(0, +)
        revW = revW.map { $0 / revSum * mData.revenue  }
        expW = expW.map { $0 / expSum * mData.expenses }

        return (1...totalDays).map { day in
            if day <= activeDays {
                return DailyFinancial(id: day, revenue: revW[day-1], expenses: expW[day-1])
            }
            return DailyFinancial(id: day, revenue: 0, expenses: 0, isFuture: true)
        }
    }
}
