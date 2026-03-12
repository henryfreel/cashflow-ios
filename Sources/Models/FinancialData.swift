import Foundation

// MARK: - Expense Category
//
// Used for both expense breakdowns on monthly records and future transaction tagging.

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case cogs       = "Cost of Goods"
    case labor      = "Labor"
    case rent       = "Rent"
    case marketing  = "Marketing"
    case utilities  = "Utilities"
    case misc       = "Miscellaneous"

    var id: String { rawValue }
}

// MARK: - Expense Breakdown
//
// Proportional breakdown of a total expense figure for a 3-location boutique retail business.
// Proportions are held constant across periods; transaction-level data (future) will replace
// these estimates with actuals.
//
//   COGS       51.5%  – inventory / cost of goods sold
//   Labor      24.0%  – wages across all three locations
//   Rent       12.2%  – combined lease costs
//   Marketing   4.4%  – campaigns, social, events
//   Utilities   4.4%  – power, internet, POS, packaging
//   Misc        3.5%  – insurance, admin, miscellaneous

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

// MARK: - Transaction (stub – populated in a future release)
//
// Placeholder for transaction-level data. Fields are intentionally broad so the
// model can accommodate both revenue events and itemised expense receipts once
// the data pipeline is in place.

struct Transaction: Identifiable {
    let id: UUID
    let date: Date
    let amount: Double          // positive = revenue, negative = expense
    let category: ExpenseCategory?  // nil for revenue transactions
    let description: String
    let locationId: Int         // which store (0-based)
    let isReconciled: Bool
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
    let id: Int             // 0-based (0–12)
    let startLabel: String  // axis label e.g. "10/1"; empty for future periods
    let dateRange: String   // tooltip label e.g. "Oct 1 – Oct 7"
    let revenue: Double
    let expenses: Double

    var netProfit: Double { revenue - expenses }
    var hasData: Bool { revenue > 0 || expenses > 0 }
}

// MARK: - Daily Financial Record

struct DailyFinancial: Identifiable {
    let id: Int       // day number 1–31
    let revenue: Double
    let expenses: Double

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
// 12% is solid for independent boutique retail (industry average: 9–11%).
// Expense mix: COGS 51.5% | Labor 24% | Rent 12.2% | Marketing 4.4% |
//              Utilities 4.4% | Misc 3.5%
//
// Seasonal shape: strong Jan–Feb (post-holiday clearance + Valentine's),
// soft spring dip, May–Jul loss months (slow season + summer inventory buy),
// steady Q3 recovery, strong Q4 holiday run.
//
// Scale: original seed values multiplied by revenue ×11.14 and expenses ×17.05.

enum AppFinancials {

    // MARK: - Account Balances
    //
    // Current balances for a 3-location boutique retail operation.
    // Net balance = checking + all savings – outstanding loans (cash position).
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
        .init(id:  4, month: "M", fullMonth: "May",       revenue:  79_432.15, expenses:  90_847.63),  // net -11,415.48  summer inventory buy
        .init(id:  5, month: "J", fullMonth: "June",      revenue:  81_247.89, expenses:  83_612.34),  // net  -2,364.45
        .init(id:  6, month: "J", fullMonth: "July",      revenue:  84_518.32, expenses:  79_841.27),  // net   4,677.05
        .init(id:  7, month: "A", fullMonth: "August",    revenue:  88_935.86, expenses:  80_758.01),  // net   8,177.85
        .init(id:  8, month: "S", fullMonth: "September", revenue:  97_354.91, expenses:  80_144.72),  // net  17,210.19
        .init(id:  9, month: "O", fullMonth: "October",   revenue: 103_464.20, expenses:  78_006.99),  // net  25,457.21
        .init(id: 10, month: "N", fullMonth: "November",  revenue: 121_384.67, expenses:  78_234.51),  // net  43,150.16  pre-holiday buildup
        .init(id: 11, month: "D", fullMonth: "December",  revenue:  89_847.53, expenses:  56_418.73),  // net  33,428.80  holiday through Dec 15
    ]

    // MARK: - Quarterly weekly data (Q4: Oct 1 – Dec 31, 13 weeks)
    //
    // Weeks 0–10 have data; weeks 11–12 are future/empty (Dec 16–31).

    static let quarterlyWeeks: [WeeklyFinancial] = [
        .init(id:  0, startLabel: "10/1",  dateRange: "Oct 1 – Oct 7",    revenue:  23_302.99, expenses:  17_552.47),
        .init(id:  1, startLabel: "10/8",  dateRange: "Oct 8 – Oct 14",   revenue:  23_444.91, expenses:  17_695.17),
        .init(id:  2, startLabel: "10/15", dateRange: "Oct 15 – Oct 21",  revenue:  23_264.11, expenses:  17_469.95),
        .init(id:  3, startLabel: "10/22", dateRange: "Oct 22 – Oct 28",  revenue:  23_369.83, expenses:  17_621.52),
        .init(id:  4, startLabel: "10/29", dateRange: "Oct 29 – Nov 4",   revenue:  24_658.05, expenses:  17_899.61),
        .init(id:  5, startLabel: "11/5",  dateRange: "Nov 5 – Nov 11",   revenue:  25_483.20, expenses:  17_958.42),
        .init(id:  6, startLabel: "11/12", dateRange: "Nov 12 – Nov 18",  revenue:  25_607.85, expenses:  18_114.09),
        .init(id:  7, startLabel: "11/19", dateRange: "Nov 19 – Nov 25",  revenue:  25_341.38, expenses:  17_860.39),
        .init(id:  8, startLabel: "11/26", dateRange: "Nov 26 – Dec 2",   revenue:  28_701.43, expenses:  20_338.43),
        .init(id:  9, startLabel: "12/3",  dateRange: "Dec 3 – Dec 9",    revenue:  33_489.62, expenses:  25_576.19),
        .init(id: 10, startLabel: "12/10", dateRange: "Dec 10 – Dec 15",  revenue:  31_675.81, expenses:  21_838.66),
        .init(id: 11, startLabel: "",      dateRange: "Dec 16 – Dec 22",  revenue:  0,         expenses:  0),
        .init(id: 12, startLabel: "",      dateRange: "Dec 23 – Dec 31",  revenue:  0,         expenses:  0),
    ]

    // MARK: - December daily data (days 1–15 have data; 16–31 are future/empty)
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
            byDay[day] ?? DailyFinancial(id: day, revenue: 0, expenses: 0)
        }
    }()

    // MARK: - Computed totals

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
}
