import SwiftUI

// MARK: - Profit & Loss Detail

struct ProfitLossDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isScrolled = false
    // Measured height of the metrics section; used as a stable layout spacer so
    // the chart never shifts while the rows slide in/out. Seeded with a close
    // approximation so the first frame renders without a visible jump.
    @State private var metricsHeight: CGFloat = 200

    // MARK: Period selection & navigation state

    // Selected segment: "Year", "Quarter", or "Month".
    @State private var selectedPeriod: String = "Year"
    // Swipe navigates between full periods — year, quarter, or month.
    @State private var selectedYear:    Int = AppFinancials.currentYear
    @State private var selectedQuarter: Int = AppFinancials.currentQuarter
    @State private var selectedMonth:   Int = AppFinancials.currentMonth
    // Direction of last navigation (true = forward / left-swipe = newer period).
    @State private var slideLeft: Bool = true
    // Rubber-band offset applied only to the sliding metrics rows.
    @State private var bounceOffset: CGFloat = 0

    // MARK: Fixed full-year 2024 data (hero + rev/exp card are always current-year)

    private var months2024: [MonthlyFinancial] { AppFinancials.monthly }
    private var months2023: [MonthlyFinancial] { AppFinancials.monthly2023 }

    private var totalRevenue:   Double { months2024.reduce(0) { $0 + $1.revenue } }
    private var totalExpenses:  Double { months2024.reduce(0) { $0 + $1.expenses } }
    private var netProfit:      Double { totalRevenue - totalExpenses }

    private var totalRevenue23:  Double { months2023.reduce(0) { $0 + $1.revenue } }
    private var totalExpenses23: Double { months2023.reduce(0) { $0 + $1.expenses } }
    private var netProfit23:     Double { totalRevenue23 - totalExpenses23 }

    private var yoyDiff: Double { netProfit - netProfit23 }
    private var yoyPct:  Double { netProfit23 != 0 ? (yoyDiff / abs(netProfit23)) * 100 : 0 }

    private var revYoyPct: Double { totalRevenue23 != 0 ? ((totalRevenue - totalRevenue23) / abs(totalRevenue23)) * 100 : 0 }
    private var expYoyPct: Double { totalExpenses23 != 0 ? ((totalExpenses - totalExpenses23) / abs(totalExpenses23)) * 100 : 0 }

    // MARK: Label tables

    private static let monthNames = [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    private static let monthAbbrevs = [
        "Jan","Feb","Mar","Apr","May","Jun",
        "Jul","Aug","Sep","Oct","Nov","Dec"
    ]

    // MARK: Period-aware bar chart entries

    private var currentEntries: [BarChartEntry] {
        switch selectedPeriod {
        case "Quarter":
            let weeks = AppFinancials.weeklyData(year: selectedYear, quarter: selectedQuarter)
            let isCurrentPeriod = selectedYear == AppFinancials.currentYear
                                && selectedQuarter == AppFinancials.currentQuarter
            let currentWeekIdx = isCurrentPeriod
                ? (weeks.lastIndex(where: { $0.hasData }) ?? weeks.count - 1)
                : -1
            return weeks.map { w in
                let label = w.dateRange.isEmpty ? "Week \(w.id + 1)" : w.dateRange
                return BarChartEntry(id: w.id, label: "\(w.id + 1)", fullLabel: label,
                                     revenue: w.revenue, expenses: w.expenses,
                                     isCurrent: w.id == currentWeekIdx)
            }
        case "Month":
            let abbrev = Self.monthAbbrevs[selectedMonth - 1]
            let isCurrentPeriod = selectedYear == AppFinancials.currentYear
                                && selectedMonth == AppFinancials.currentMonth
            return AppFinancials.dailyData(year: selectedYear, month: selectedMonth).map { d in
                BarChartEntry(id: d.id - 1, label: "\(d.id)",
                              fullLabel: "\(abbrev) \(d.id)",
                              revenue: d.revenue, expenses: d.expenses,
                              isCurrent: isCurrentPeriod && d.id == AppFinancials.currentDay)
            }
        default: // "Year"
            let months = AppFinancials.monthlyData(year: selectedYear)
            let isCurrentYear = selectedYear == AppFinancials.currentYear
            return months.map {
                BarChartEntry(id: $0.id, label: $0.month, fullLabel: $0.fullMonth,
                              revenue: $0.revenue, expenses: $0.expenses,
                              isCurrent: isCurrentYear && $0.id == AppFinancials.currentMonth - 1)
            }
        }
    }

    private var prevYearEntries: [BarChartEntry] {
        let prev = selectedYear - 1
        guard prev >= AppFinancials.minYear else { return [] }
        switch selectedPeriod {
        case "Quarter":
            return AppFinancials.weeklyData(year: prev, quarter: selectedQuarter).map { w in
                let label = w.dateRange.isEmpty ? "Week \(w.id + 1)" : w.dateRange
                return BarChartEntry(id: w.id, label: "\(w.id + 1)", fullLabel: label,
                                     revenue: w.revenue, expenses: w.expenses)
            }
        case "Month":
            let abbrev = Self.monthAbbrevs[selectedMonth - 1]
            return AppFinancials.dailyData(year: prev, month: selectedMonth).map { d in
                BarChartEntry(id: d.id - 1, label: "\(d.id)",
                              fullLabel: "\(abbrev) \(d.id)",
                              revenue: d.revenue, expenses: d.expenses)
            }
        default: // "Year"
            return AppFinancials.monthlyData(year: prev).map {
                BarChartEntry(id: $0.id, label: $0.month, fullLabel: $0.fullMonth,
                              revenue: $0.revenue, expenses: $0.expenses)
            }
        }
    }

    // MARK: Period aggregate totals (drive the metric rows)

    private var periodRevenue:   Double { currentEntries.map(\.revenue).reduce(0, +) }
    private var periodExpenses:  Double { currentEntries.map(\.expenses).reduce(0, +) }
    private var periodNetProfit: Double { periodRevenue - periodExpenses }

    private var prevRevenue:    Double { prevYearEntries.map(\.revenue).reduce(0, +) }
    private var prevExpenses:   Double { prevYearEntries.map(\.expenses).reduce(0, +) }
    private var prevNetProfit:  Double { prevRevenue - prevExpenses }

    private var periodRevYoyPct: Double {
        prevRevenue  != 0 ? ((periodRevenue   - prevRevenue)   / abs(prevRevenue))   * 100 : 0
    }
    private var periodExpYoyPct: Double {
        prevExpenses != 0 ? ((periodExpenses  - prevExpenses)  / abs(prevExpenses))  * 100 : 0
    }
    private var periodNetYoyPct: Double {
        prevNetProfit != 0 ? ((periodNetProfit - prevNetProfit) / abs(prevNetProfit)) * 100 : 0
    }

    // MARK: Period nav header

    private var periodNavTitle: String {
        switch selectedPeriod {
        case "Quarter":
            let startMonth = (selectedQuarter - 1) * 3 + 1
            let endMonth   = selectedQuarter * 3
            let endDay     = (endMonth == 6 || endMonth == 9) ? 30 : 31
            return "\(Self.monthAbbrevs[startMonth - 1]) 1 – \(Self.monthAbbrevs[endMonth - 1]) \(endDay), \(selectedYear)"
        case "Month":
            return "\(Self.monthNames[selectedMonth - 1]), \(selectedYear)"
        default: // "Year"
            return "Jan 1 – Dec 31, \(selectedYear)"
        }
    }

    // MARK: Navigation helpers

    // Year view: navigation is disabled — the page is always scoped to one year.
    // Quarter view: navigate Q1–Q4 within the current year only.
    // Month view: navigate Jan–Dec within the current year only.

    private var canGoBack: Bool {
        switch selectedPeriod {
        case "Quarter": return selectedQuarter > 1
        case "Month":   return selectedMonth > 1
        default:        return false
        }
    }

    private var canGoForward: Bool {
        switch selectedPeriod {
        case "Quarter": return selectedQuarter < AppFinancials.currentQuarter
        case "Month":   return selectedMonth   < AppFinancials.currentMonth
        default:        return false
        }
    }

    private func navigateBack(animation: Animation = .easeInOut(duration: 0.3)) {
        guard canGoBack else { return }
        slideLeft = false
        withAnimation(animation) {
            switch selectedPeriod {
            case "Quarter": selectedQuarter -= 1
            case "Month":   selectedMonth   -= 1
            default: break
            }
        }
    }

    private func navigateForward(animation: Animation = .easeInOut(duration: 0.3)) {
        guard canGoForward else { return }
        slideLeft = true
        withAnimation(animation) {
            switch selectedPeriod {
            case "Quarter": selectedQuarter += 1
            case "Month":   selectedMonth   += 1
            default: break
            }
        }
    }

    // Range label used in the "View all … transactions" button.
    // Month: "December" | Quarter & Year: full date range from periodNavTitle.
    private var viewAllRangeLabel: String {
        switch selectedPeriod {
        case "Month": return Self.monthNames[selectedMonth - 1]
        default:      return periodNavTitle
        }
    }

    // Direction-aware slide transition for the metrics rows.
    private var metricsTransition: AnyTransition {
        let sign: CGFloat = slideLeft ? 1 : -1
        return .asymmetric(
            insertion: .offset(x:  sign * 400).combined(with: .opacity),
            removal:   .offset(x: -sign * 400).combined(with: .opacity)
        )
    }

    private var metricsAnimationKey: String {
        switch selectedPeriod {
        case "Quarter": return "Q\(selectedQuarter)-\(selectedYear)"
        case "Month":   return "M\(selectedMonth)-\(selectedYear)"
        default:        return "Y\(selectedYear)"
        }
    }

    // MARK: Drag gesture (applied on the metrics+chart zone)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let h = value.translation.width
                let v = value.translation.height
                guard abs(h) > abs(v) else {
                    if bounceOffset != 0 { bounceOffset = 0 }
                    return
                }
                let atBoundary = (h > 0 && !canGoBack) || (h < 0 && !canGoForward)
                bounceOffset = atBoundary ? h * 0.25 : h
            }
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                let isHorizontal = abs(h) > abs(v) * 1.5 && abs(h) > 30
                let blocked = (h > 0 && !canGoBack) || (h < 0 && !canGoForward)

                if isHorizontal && !blocked {
                    bounceOffset = 0
                    let snap: Animation = .easeOut(duration: 0.18)
                    if h > 0 { navigateBack(animation: snap) }
                    else     { navigateForward(animation: snap) }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        bounceOffset = 0
                    }
                }
            }
    }

    // MARK: Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // All remaining content shares a single 24pt horizontal padding container
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 24)
                        .padding(.bottom, 48)

                    revenueExpensesCard
                        .padding(.bottom, 48)

                    segmentedControl
                        .padding(.bottom, 40)

                    periodNav
                        .padding(.bottom, 24)

                    // Metrics rows slide left/right on month change; chart stays still.
                    // A Color.clear spacer holds the measured height so the chart
                    // never shifts. metricsSection is rendered once (in the overlay).
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: metricsHeight)
                            .overlay(alignment: .top) {
                                metricsSection
                                    .offset(x: bounceOffset)
                                    .id(metricsAnimationKey)
                                    .transition(metricsTransition)
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                                        if h > 0 { metricsHeight = h }
                                    }
                            }
                            .clipped()

                        chartSection
                            .padding(.top, 29)
                    }
                    .simultaneousGesture(swipeGesture)

                    viewAllButton
                        .padding(.top, 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .contentMargins(.bottom, 102, for: .scrollContent)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > 0
        } action: { _, scrolled in
            withAnimation(.easeInOut(duration: 0.2)) {
                isScrolled = scrolled
            }
        }
        .background(Color.white)
        .safeAreaInset(edge: .top, spacing: 0) {
            SecondaryNavBar(
                title: "Profit & Loss",
                onBack: { dismiss() },
                centerSubtitle: "\(AppFinancials.currentYear) • All locations",
                isScrolled: isScrolled
            )
        }
        .navigationBarHidden(true)
    }

    // MARK: Hero

    /// Figma "🧩 Full Page Hero" (10217:356662).
    /// pt=40, pb=48, px=16. Inner VStack gap=8.
    private var heroSection: some View {
        VStack(spacing: 8) {
            // Big number — Display Bold 56pt, gray1, 115% line height.
            // Stays at 56pt; auto-shrinks (min 50%) if value is too wide to fit.
            Text(fmt(netProfit))
                .font(.display20)
                .foregroundStyle(Color.gray1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // 115% of 56pt ≈ 64pt — cap the bounding box so line spacing
                // never expands beyond spec when the number fits on one line.
                .frame(maxWidth: .infinity, minHeight: 56 * 1.15, maxHeight: 56 * 1.15, alignment: .center)

            // Subtext block — two rows, items-center, each row 22pt tall
            VStack(spacing: 0) {
                // "Total net profit this year" — 14pt SemiBold, gray2, 22pt line height
                Text("Total net profit this year")
                    .font(.paragraphSemibold20)
                    .foregroundStyle(Color.gray2)
                    .frame(height: 22, alignment: .center)
                    .fixedSize(horizontal: true, vertical: false)

                // YoY comparison row — 14pt SemiBold, all green, 22pt line height
                HStack(spacing: 2) {
                    Image("PLUpArrow")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)

                    Text("\(fmt(abs(yoyDiff))) (\(Int(yoyPct.rounded()))%) more than last year")
                        .font(.paragraphSemibold20)
                        .foregroundStyle(Color.green1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: 22, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Revenue / Expenses Card

    /// Figma "Revenue-Expenses" (2334:15774). Total height 207pt.
    /// Outer:  px=24, py=12, rounded=12, gray4 border.
    /// Inner wrapper (Frame 9956): VStack spacing=12 → 12pt gaps around the divider.
    /// Each row: py=16, content 46–48pt tall.
    private var revenueExpensesCard: some View {
        // Inner wrapper — spacing:12 creates the gaps between row, divider, row
        VStack(spacing: 12) {
            revExpRow(
                image: "PLRowRingRevenue",
                title: "Total revenue",
                value: fmt(totalRevenue),
                subtitle: yoyLabel(revYoyPct, up: true) + " since last year"
            )

            // Divider — use gray4 (closest defined gray to Figma's rgba(0,0,0,0.15))
            Rectangle()
                .fill(Color.gray4)
                .frame(height: 1)

            revExpRow(
                image: "PLRowRingExpenses",
                title: "Total expenses",
                value: "–" + fmt(totalExpenses),
                subtitle: yoyLabel(expYoyPct, up: false) + " since last year"
            )
        }
        // Outer container padding & styling
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray4, lineWidth: 1)
        )
    }

    /// Figma row: icon left (grows) | text column right (238pt fixed).
    /// py=16 on the row itself; title+value same first line, subtitle below.
    private func revExpRow(image: String,
                            title: String,
                            value: String,
                            subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: 40×40 ring icon
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            // Right: fills remaining width — [title · value] on row 1, subtitle on row 2
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    Text(title)
                        .font(.paragraphSemibold30)
                        .foregroundStyle(Color.gray1)
                    Spacer()
                    Text(value)
                        .font(.paragraphSemibold30)
                        .foregroundStyle(Color.gray1)
                }
                .frame(height: 24)

                Text(subtitle)
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray2)
                    .frame(height: 22, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
    }

    // MARK: Segmented Control (static — Year selected)

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentPill("Month")
            segmentPill("Quarter")
            segmentPill("Year")
        }
        .frame(height: 48)
        .background(Color.gray5, in: Capsule())
    }

    private func segmentPill(_ label: String) -> some View {
        Button {
            guard selectedPeriod != label else { return }
            selectedPeriod = label
            // Reset navigation to the current live period
            selectedYear    = AppFinancials.currentYear
            selectedQuarter = AppFinancials.currentQuarter
            selectedMonth   = AppFinancials.currentMonth
        } label: {
            Text(label)
                .font(.paragraphSemibold30)
                .foregroundStyle(Color.gray1)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    Group {
                        if selectedPeriod == label {
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: Color.gray1.opacity(0.1), radius: 2, x: 0, y: 1)
                                .shadow(color: Color.gray1.opacity(0.1), radius: 4, x: 0, y: 0)
                        }
                    }
                )
                .padding(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Period Nav — tappable chevrons navigate months

    private var periodNav: some View {
        HStack(spacing: 16) {
            Button {
                navigateBack()
            } label: {
                Image("YearNavLeft")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(canGoBack ? Color.gray1 : Color.gray3)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            Text(periodNavTitle)
                .header2Style()
                .foregroundStyle(Color.gray1)
                .frame(height: 24, alignment: .center)
                .animation(nil, value: metricsAnimationKey)

            Button {
                navigateForward()
            } label: {
                Image("YearNavRight")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(canGoForward ? Color.gray1 : Color.gray3)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Metrics Rows (slide on month change)

    private var metricsSection: some View {
        let hasPrev = selectedYear > AppFinancials.minYear
        let yoySuffix = "since last year"
        return VStack(spacing: 0) {
            metricRow(
                indicator: .revenue,
                title: "Total Revenue",
                subtitle: hasPrev ? yoyLabel(periodRevYoyPct, up: true)  + " \(yoySuffix)" : "No previous data",
                value: fmt(periodRevenue),
                valueFont: .paragraphSemibold30
            )
            metricRow(
                indicator: .expenses,
                title: "Total Expenses",
                subtitle: hasPrev ? yoyLabel(periodExpYoyPct, up: false) + " \(yoySuffix)" : "No previous data",
                value: "–" + fmt(periodExpenses),
                valueFont: .paragraphSemibold30
            )
            metricRow(
                indicator: .net,
                title: "Total Net Profit",
                subtitle: hasPrev ? yoyLabel(periodNetYoyPct, up: true)  + " \(yoySuffix)" : "No previous data",
                value: fmt(periodNetProfit),
                valueFont: .header2
            )
        }
    }

    private enum IndicatorKind { case revenue, expenses, net }

    private func metricRow(indicator: IndicatorKind,
                            title: String,
                            subtitle: String,
                            value: String,
                            valueFont: Font) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Indicator: 16×24pt frame, shape centered at cy=12
            ZStack {
                switch indicator {
                case .revenue:
                    Circle()
                        .fill(Color.green5)
                        .frame(width: 16, height: 16)
                case .expenses:
                    Circle()
                        .fill(Color.red5)
                        .frame(width: 16, height: 16)
                case .net:
                    Capsule()
                        .fill(Color.gray1)
                        .frame(width: 16, height: 4)
                }
            }
            .frame(width: 16, height: 24)

            // Text column: title+value on first row, subtitle below
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 0) {
                    Text(title)
                        .font(.paragraphSemibold30)
                        .foregroundStyle(Color.gray1)
                    Spacer()
                    Text(value)
                        .font(valueFont)
                        .foregroundStyle(Color.gray1)
                        .multilineTextAlignment(.trailing)
                }

                Text(subtitle)
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray2)
                    .frame(height: 22, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 9)
    }

    // MARK: Chart — active bar tracks selected month; chart itself never slides

    private var chartSection: some View {
        PLYearBarChart(
            entries: currentEntries,
            activeIndex: currentEntries.firstIndex(where: { $0.isCurrent }) ?? -1
        )
    }

    // MARK: View All Button

    private var viewAllButton: some View {
        Button(action: {}) {
            Text("View all \(viewAllRangeLabel) transactions")
                .font(.paragraphSemibold30)
                .foregroundStyle(Color.blue2)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
        }
        .buttonStyle(ViewAllButtonStyle())
        .contentShape(Capsule())
    }

    // MARK: Helpers

    private func fmt(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: abs(value))) ?? "$0.00"
    }

    /// Currency with no cents — used for large summary totals.
    private func fmtWhole(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: abs(value))) ?? "$0"
    }

    private func yoyLabel(_ pct: Double, up: Bool) -> String {
        let arrow = up ? "↑" : "↓"
        return "\(arrow) \(Int(abs(pct).rounded()))%"
    }
}

private struct ViewAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.gray5 : Color.clear,
                in: Capsule()
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ProfitLossDetailView()
    }
}
#endif
