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
    @State private var selectedPeriod: String = "Month"
    // Swipe navigates between full periods — year, quarter, or month.
    // Prototype context: Dec 15, 2024 — default to current year/quarter/month.
    @State private var selectedYear:    Int = AppFinancials.currentYear
    @State private var selectedQuarter: Int = AppFinancials.currentQuarter
    @State private var selectedMonth:   Int = AppFinancials.currentMonth
    // Direction of last navigation (true = forward / left-swipe = newer period).
    @State private var slideLeft: Bool = true
    /// When true, metrics rows use slide transition. When false (filter switch), use opacity only.
    @State private var useSlideForMetrics: Bool = false
    // Rubber-band offset applied only to the sliding metrics rows.
    @State private var bounceOffset: CGFloat = 0
    // Scrubbing: which bar index is currently being hovered (nil = not scrubbing).
    @State private var scrubIndex: Int? = nil
    // Direction of last scrub movement (true = moved to higher index / right).
    // Used when releasing to animate metrics out in that direction, period totals in from opposite.
    @State private var lastScrubDirection: Bool = true

    // MARK: Hero + revenue/expenses card (driven by selectedYear)

    private var monthsForSelectedYear: [MonthlyFinancial] {
        AppFinancials.monthlyData(year: selectedYear)
    }

    private var monthsForPrevYear: [MonthlyFinancial] {
        let prev = selectedYear - 1
        guard prev >= AppFinancials.minYear else { return [] }
        return AppFinancials.monthlyData(year: prev)
    }

    private var totalRevenue:   Double { monthsForSelectedYear.reduce(0) { $0 + $1.revenue } }
    private var totalExpenses:  Double { monthsForSelectedYear.reduce(0) { $0 + $1.expenses } }
    private var netProfit:      Double { totalRevenue - totalExpenses }

    private var totalRevenuePrev:  Double { monthsForPrevYear.reduce(0) { $0 + $1.revenue } }
    private var totalExpensesPrev: Double { monthsForPrevYear.reduce(0) { $0 + $1.expenses } }
    private var netProfitPrev:    Double { totalRevenuePrev - totalExpensesPrev }

    private var hasPrevYearData: Bool { !monthsForPrevYear.isEmpty }

    private var yoyDiff: Double { netProfit - netProfitPrev }
    private var yoyPct:  Double { netProfitPrev != 0 ? (yoyDiff / abs(netProfitPrev)) * 100 : 0 }

    private var revYoyPct: Double { totalRevenuePrev != 0 ? ((totalRevenue - totalRevenuePrev) / abs(totalRevenuePrev)) * 100 : 0 }
    private var expYoyPct: Double { totalExpensesPrev != 0 ? ((totalExpenses - totalExpensesPrev) / abs(totalExpensesPrev)) * 100 : 0 }

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

    private var hasDataForPeriod: Bool { selectedYear >= AppFinancials.minYear }

    private var currentEntries: [BarChartEntry] {
        guard hasDataForPeriod else {
            // Placeholder bars when navigating beyond data (e.g. 2022)
            switch selectedPeriod {
            case "Quarter": return (0..<13).map { BarChartEntry(id: $0, label: "\($0 + 1)", fullLabel: "Week \($0 + 1)", revenue: 0, expenses: 0) }
            case "Month":
                let comps = DateComponents(year: selectedYear, month: selectedMonth)
                let date = Calendar.current.date(from: comps) ?? Date()
                let days = Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 31
                let abbrev = Self.monthAbbrevs[selectedMonth - 1]
                return (0..<days).map { BarChartEntry(id: $0, label: "\($0 + 1)", fullLabel: "\(abbrev) \($0 + 1)", revenue: 0, expenses: 0) }
            default: return (0..<12).map { BarChartEntry(id: $0, label: Self.monthAbbrevs[$0], fullLabel: Self.monthNames[$0], revenue: 0, expenses: 0) }
            }
        }
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

    // MARK: Scrub-specific data (drive metric rows while hovering)

    /// Human-readable label for the bar currently under the user's finger.
    /// Year view → full month name ("December").
    /// Quarter view → week date range ("Oct 1 – Oct 7").
    /// Month view → full date with ordinal ("December 1st, 2024").
    private var scrubLabel: String? {
        guard let si = scrubIndex, si < currentEntries.count else { return nil }
        let entry = currentEntries[si]
        switch selectedPeriod {
        case "Month":
            // "December 12th" — no year (the period header already shows it)
            let day = entry.id + 1   // entry.id is 0-based; day number is 1-based
            let monthName = Self.monthNames[selectedMonth - 1]
            return "\(monthName) \(day)\(ordinalSuffix(day))"
        case "Quarter":
            // Replace en dash with hyphen for compact list-row titles
            return entry.fullLabel.replacingOccurrences(of: "–", with: "-")
        default: // Year
            return entry.fullLabel
        }
    }

    private var scrubRevenue:   Double {
        guard let si = scrubIndex, si < currentEntries.count else { return periodRevenue }
        return currentEntries[si].revenue
    }
    private var scrubExpenses:  Double {
        guard let si = scrubIndex, si < currentEntries.count else { return periodExpenses }
        return currentEntries[si].expenses
    }
    private var scrubNetProfit: Double { scrubRevenue - scrubExpenses }

    private var scrubPrevRevenue:   Double {
        guard let si = scrubIndex, si < prevYearEntries.count else { return 0 }
        return prevYearEntries[si].revenue
    }
    private var scrubPrevExpenses:  Double {
        guard let si = scrubIndex, si < prevYearEntries.count else { return 0 }
        return prevYearEntries[si].expenses
    }
    private var scrubPrevNetProfit: Double { scrubPrevRevenue - scrubPrevExpenses }

    private var scrubRevYoyPct: Double {
        scrubPrevRevenue   != 0 ? ((scrubRevenue   - scrubPrevRevenue)   / abs(scrubPrevRevenue))   * 100 : 0
    }
    private var scrubExpYoyPct: Double {
        scrubPrevExpenses  != 0 ? ((scrubExpenses  - scrubPrevExpenses)  / abs(scrubPrevExpenses))  * 100 : 0
    }
    private var scrubNetYoyPct: Double {
        scrubPrevNetProfit != 0 ? ((scrubNetProfit - scrubPrevNetProfit) / abs(scrubPrevNetProfit)) * 100 : 0
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

    // Year view: swipe between available years (minYear .. currentYear).
    // Quarter view: navigate Q1–Q4, crossing into previous/next year when at boundaries.
    // Month view: navigate Jan–Dec, crossing into previous/next year when at boundaries.

    /// Allow one period beyond data boundary (e.g. 2022 when minYear is 2023).
    private var canGoBack: Bool {
        let oneBeforeMin = AppFinancials.minYear - 1
        switch selectedPeriod {
        case "Quarter": return selectedQuarter > 1 || (selectedQuarter == 1 && selectedYear > oneBeforeMin)
        case "Month":   return selectedMonth > 1 || (selectedMonth == 1 && selectedYear > oneBeforeMin)
        case "Year":    return selectedYear > oneBeforeMin
        default:        return false
        }
    }

    private var canGoForward: Bool {
        switch selectedPeriod {
        case "Quarter": return selectedYear < AppFinancials.currentYear || (selectedYear == AppFinancials.currentYear && selectedQuarter < AppFinancials.currentQuarter)
        case "Month":   return selectedYear < AppFinancials.currentYear || (selectedYear == AppFinancials.currentYear && selectedMonth < AppFinancials.currentMonth)
        case "Year":    return selectedYear < AppFinancials.currentYear
        default:        return false
        }
    }

    private func navigateBack(animation: Animation = .easeInOut(duration: 0.3)) {
        guard canGoBack else { return }
        slideLeft = false
        useSlideForMetrics = true  // Swipe navigation: slide animation
        withAnimation(animation) {
            switch selectedPeriod {
            case "Quarter":
                if selectedQuarter > 1 { selectedQuarter -= 1 }
                else { selectedYear -= 1; selectedQuarter = 4 }
            case "Month":
                if selectedMonth > 1 { selectedMonth -= 1 }
                else { selectedYear -= 1; selectedMonth = 12 }
            case "Year": selectedYear -= 1
            default: break
            }
        }
    }

    private func navigateForward(animation: Animation = .easeInOut(duration: 0.3)) {
        guard canGoForward else { return }
        slideLeft = true
        useSlideForMetrics = true  // Swipe navigation: slide animation
        withAnimation(animation) {
            switch selectedPeriod {
            case "Quarter":
                if selectedQuarter < 4 { selectedQuarter += 1 }
                else { selectedYear += 1; selectedQuarter = 1 }
            case "Month":
                if selectedMonth < 12 { selectedMonth += 1 }
                else { selectedYear += 1; selectedMonth = 1 }
            case "Year": selectedYear += 1
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
    // Only slide when user has swiped left/right (or tap same filter to return to current).
    // When switching filter type (Month↔Quarter↔Year), no horizontal movement — content updates in place.
    private var metricsTransition: AnyTransition {
        guard useSlideForMetrics else { return .identity }
        let sign: CGFloat = slideLeft ? 1 : -1
        return .asymmetric(
            insertion: .offset(x:  sign * 400).combined(with: .opacity),
            removal:   .offset(x: -sign * 400).combined(with: .opacity)
        )
    }

    private var metricsAnimationKey: String {
        let base: String
        switch selectedPeriod {
        case "Quarter": base = "Q\(selectedQuarter)-\(selectedYear)"
        case "Month":   base = "M\(selectedMonth)-\(selectedYear)"
        default:       base = "Y\(selectedYear)"
        }
        if let si = scrubIndex {
            return "\(base)-scrub-\(si)"
        }
        return base
    }

    // MARK: Drag gesture (applied on the metrics+chart zone)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // Do not interfere while the scrub gesture is active
                guard scrubIndex == nil else {
                    if bounceOffset != 0 { bounceOffset = 0 }
                    return
                }
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
                guard scrubIndex == nil else { return }
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
                        .padding(.bottom, 32)

                    // Header + list rows + chart: full area responds to pagination swipe
                    VStack(spacing: 0) {
                        periodNav
                            .padding(.bottom, 24)

                        // Swipe: id changes → slide. Filter switch: stable id → content updates in place (no horizontal movement).
                        metricsSection
                            .offset(x: bounceOffset)
                            .id(useSlideForMetrics ? metricsAnimationKey : "metrics-inplace")
                            .transition(metricsTransition)
                            .animation(.easeOut(duration: 0.25), value: useSlideForMetrics ? metricsAnimationKey : "\(selectedPeriod)-\(selectedQuarter)-\(selectedMonth)-\(selectedYear)")
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                                if h > 0 { metricsHeight = h }
                            }
                            .background(Color.clear.frame(height: metricsHeight))

                        chartSection
                            .padding(.top, 37)
                    }
                    .contentShape(Rectangle())  // Full area responds to swipe, including gaps between text
                    .simultaneousGesture(swipeGesture)

                    viewAllButton
                        .padding(.top, 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .contentMargins(.bottom, 94, for: .scrollContent)
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
                centerSubtitle: "All locations",
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
                .contentTransition(.numericText(value: netProfit))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // 115% of 56pt ≈ 64pt — cap the bounding box so line spacing
                // never expands beyond spec when the number fits on one line.
                .frame(maxWidth: .infinity, minHeight: 56 * 1.15, maxHeight: 56 * 1.15, alignment: .center)

            // Subtext block — two rows, items-center, each row 22pt tall
            VStack(spacing: 0) {
                // "Total net profit for YYYY" — 14pt SemiBold, gray3, 22pt line height
                Text("Total net profit for \(String(selectedYear))")
                    .font(.paragraphSemibold20)
                    .foregroundStyle(Color.gray3)
                    .frame(height: 22, alignment: .center)
                    .fixedSize(horizontal: true, vertical: false)

                // YoY comparison row, or Figma "Account message" when no previous data
                if hasPrevYearData {
                    HStack(spacing: 2) {
                        Image("PLUpArrow")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Color.green3)

                        Text("\(fmt(abs(yoyDiff))) (\(Int(yoyPct.rounded()))%) from last year")
                            .font(.paragraphSemibold20)
                            .foregroundStyle(Color.green3)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(height: 22, alignment: .center)
                } else {
                    noPreviousDataView
                        .frame(height: 22, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Revenue / Expenses Card

    /// Figma "Revenue-Expenses" (2337:39056). Outer: px=24, py=8, gap=4, rounded=12.
    /// Each row: py=16, icon-to-text gap=12, items vertically centered.
    private var revenueExpensesCard: some View {
        let noData = !hasDataForPeriod
        // Subtitle: YoY comparison when prev data exists; directional "No previous data" otherwise.
        let revSubtitle: String = hasPrevYearData
            ? yoyLabel(revYoyPct, up: true) + " since last year"
            : "↑ No previous data"
        let expSubtitle: String = hasPrevYearData
            ? yoyLabel(expYoyPct, up: false) + " since last year"
            : "↓ No previous data"
        return VStack(spacing: 4) {
            revExpRow(
                image: noData ? "PLRowRingEmpty" : "PLRowRingRevenue",
                title: "Total revenue",
                value: fmt(totalRevenue),
                subtitle: noData ? "↑ No previous data" : revSubtitle,
                animateValue: totalRevenue
            )

            // Divider
            Rectangle()
                .fill(Color.gray5)
                .frame(height: 1)

            revExpRow(
                image: noData ? "PLRowRingEmpty" : "PLRowRingExpenses",
                title: "Total expenses",
                value: fmt(totalExpenses),
                valuePrefix: noData ? "" : "–",
                subtitle: noData ? "↓ No previous data" : expSubtitle,
                animateValue: totalExpenses
            )
        }
        // Outer container padding & styling
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray5, lineWidth: 1)
        )
    }

    /// Hero "no previous data" row — up-arrow + text in gray4.
    private var noPreviousDataView: some View {
        HStack(spacing: 2) {
            Image("PLUpArrow")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.gray4)
            Text("No previous data available")
                .font(.paragraphSemibold20)
                .foregroundStyle(Color.gray4)
                .lineSpacing(22 - 14)
        }
        .frame(height: 22, alignment: .leading)
    }

    private func revExpRow(image: String,
                            title: String,
                            value: String,
                            valuePrefix: String = "",
                            subtitle: String?,
                            noPreviousData: Bool = false,
                            greyValue: Bool = false,
                            animateValue: Double? = nil) -> some View {
        HStack(alignment: .center, spacing: 12) {
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
                    HStack(spacing: 0) {
                        if !valuePrefix.isEmpty {
                            Text(valuePrefix)
                                .font(.paragraphSemibold30)
                                .foregroundStyle(greyValue ? Color.gray4 : Color.gray1)
                        }
                        Text(value)
                            .font(.paragraphSemibold30)
                            .foregroundStyle(greyValue ? Color.gray4 : Color.gray1)
                            .contentTransition(animateValue != nil ? .numericText(value: animateValue!) : .identity)
                            .monospacedDigit()
                    }
                }
                .frame(height: 24)

                Group {
                    if noPreviousData {
                        Text("No previous data")
                            .font(.paragraph20)
                            .foregroundStyle(Color.gray3)
                    } else if let s = subtitle {
                        Text(s)
                            .font(.paragraph20)
                            .foregroundStyle(Color.gray3)
                    }
                }
                .frame(height: 22, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
    }

    // MARK: Segmented Control

    private let periodLabels = ["Month", "Quarter", "Year"]

    private var selectedPeriodIndex: Int {
        periodLabels.firstIndex(of: selectedPeriod) ?? 2
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(periodLabels, id: \.self) { label in
                segmentPill(label)
            }
        }
        .frame(height: 48)
        .background {
            ZStack(alignment: .topLeading) {
                Capsule().fill(Color.gray7)
                // Pill is 40pt tall (4pt inset each side) and 4pt from left/right edge of its segment
                GeometryReader { geo in
                    let segmentW = geo.size.width / 3
                    let pillW = segmentW - 8  // 4pt from each horizontal edge of the segment
                    let pillX = CGFloat(selectedPeriodIndex) * segmentW + 4
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: Color.gray1.opacity(0.1), radius: 2, x: 0, y: 1)
                        .shadow(color: Color.gray1.opacity(0.1), radius: 4, x: 0, y: 0)
                        .frame(width: pillW, height: 40)
                        .offset(x: pillX, y: 4)
                }
            }
        }
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
    }

    private func segmentPill(_ label: String) -> some View {
        Button {
            // Filter switch: no slide, no residual offset. Only swipe or "tap same filter to return" triggers slide.
            useSlideForMetrics = false
            bounceOffset = 0
            if selectedPeriod == label {
                // Tapping same period — if not on current, jump to current (like Home P&L card)
                switch label {
                case "Year":
                    // Tap same filter: return to current year (Dec 15, 2024 context)
                    if selectedYear != AppFinancials.currentYear {
                        useSlideForMetrics = true
                        slideLeft = selectedYear < AppFinancials.currentYear
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedYear = AppFinancials.currentYear
                        }
                    }
                case "Quarter":
                    if selectedYear != AppFinancials.currentYear || selectedQuarter != AppFinancials.currentQuarter {
                        useSlideForMetrics = true
                        slideLeft = selectedYear < AppFinancials.currentYear
                            || (selectedYear == AppFinancials.currentYear && selectedQuarter < AppFinancials.currentQuarter)
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedYear = AppFinancials.currentYear
                            selectedQuarter = AppFinancials.currentQuarter
                        }
                    }
                case "Month":
                    if selectedYear != AppFinancials.currentYear || selectedMonth != AppFinancials.currentMonth {
                        useSlideForMetrics = true
                        slideLeft = selectedYear < AppFinancials.currentYear
                            || (selectedYear == AppFinancials.currentYear && selectedMonth < AppFinancials.currentMonth)
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedYear = AppFinancials.currentYear
                            selectedMonth = AppFinancials.currentMonth
                        }
                    }
                default: break
                }
                return
            }
            let previousPeriod = selectedPeriod
            withAnimation(.easeOut(duration: 0.25)) {
                bounceOffset = 0  // Ensure no residual from prior swipe
                selectedPeriod = label
                // Stay within the larger time frame: don't jump years when expanding view
                switch label {
                case "Year":
                    // Keep current year (e.g. Quarter 2024 → Year stays 2024)
                    break
                case "Quarter":
                    if previousPeriod == "Year" {
                        selectedQuarter = selectedYear == AppFinancials.currentYear ? AppFinancials.currentQuarter : 4
                    } else {
                        // Month → Quarter: show quarter containing current month
                        selectedQuarter = ((selectedMonth - 1) / 3) + 1
                    }
                    break
                case "Month":
                    if previousPeriod == "Year" {
                        selectedQuarter = selectedYear == AppFinancials.currentYear ? AppFinancials.currentQuarter : 4
                        selectedMonth = (selectedQuarter - 1) * 3 + 1
                    } else {
                        // Quarter → Month: show first month of current quarter
                        selectedMonth = (selectedQuarter - 1) * 3 + 1
                    }
                    break
                default: break
                }
            }
        } label: {
            Text(label)
                .font(.paragraphSemibold30)
                .foregroundStyle(Color.gray1)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(.plain)
        .padding(4)
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
                    .foregroundStyle(canGoBack ? Color.gray1 : Color.gray4)
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
                    .foregroundStyle(canGoForward ? Color.gray1 : Color.gray4)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Metrics Rows (slide on month change)

    /// Explicit scrub vs period branches so SwiftUI runs remove/insert transitions
    /// when releasing from scrub — otherwise it may treat it as an in-place update.
    /// When no data for period (e.g. 2022), show Figma no-data design.
    @ViewBuilder
    private var metricsSection: some View {
        if !hasDataForPeriod {
            metricsNoDataView
        } else if scrubIndex != nil {
            scrubMetricsContent
        } else {
            periodMetricsContent
        }
    }

    /// Figma "No data available" (2365:44412).
    /// Container: pt=24, pb=32, gap=24, centered. Icon: 64×64 circle. Text: 254pt, gap=8, lh=22.
    private var metricsNoDataView: some View {
        VStack(spacing: 24) {
            // Figma image 339 (node 2366:47948): 64×64 circle, object-cover fill.
            Image("NoDataChart")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())

            // Text group: 254pt wide, centered, gap 8, line-height 22
            VStack(spacing: 8) {
                Text("No data available")
                    .font(.custom(AppFont.Text.semiBold, size: 18))
                    .foregroundStyle(Color(red: 16/255, green: 16/255, blue: 16/255))
                    .frame(maxWidth: 254)
                    .multilineTextAlignment(.center)
                    .lineSpacing(22 - 18)

                Text("Try adjusting the date range or applying different filters")
                    .font(.custom(AppFont.Text.regular, size: 14))
                    .foregroundStyle(Color.gray3)
                    .frame(maxWidth: 254)
                    .multilineTextAlignment(.center)
                    .lineSpacing(22 - 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    private var scrubMetricsContent: some View {
        let label = scrubLabel!
        let hasPrev = (scrubIndex ?? 0) < prevYearEntries.count && prevYearEntries[scrubIndex ?? 0].hasData
        let yoySuffix = "since last year"
        return metricsRows(
            revTitle: "\(label) revenue",
            expTitle: "\(label) expenses",
            netTitle: "\(label) net profit",
            revValue: scrubRevenue,
            expValue: scrubExpenses,
            netValue: scrubNetProfit,
            revYoy: scrubRevYoyPct,
            expYoy: scrubExpYoyPct,
            netYoy: scrubNetYoyPct,
            hasPrev: hasPrev,
            yoySuffix: yoySuffix,
            animateNumbers: false  // No slot animation while scrubbing
        )
    }

    private var periodMetricsContent: some View {
        let hasPrev = selectedYear > AppFinancials.minYear
        let yoySuffix = "since last year"
        return metricsRows(
            revTitle: "Total revenue",
            expTitle: "Total expenses",
            netTitle: "Total net profit",
            revValue: periodRevenue,
            expValue: periodExpenses,
            netValue: periodNetProfit,
            revYoy: periodRevYoyPct,
            expYoy: periodExpYoyPct,
            netYoy: periodNetYoyPct,
            hasPrev: hasPrev,
            yoySuffix: yoySuffix,
            animateNumbers: true  // Slot animation when switching years/filters
        )
    }

    private func metricsRows(
        revTitle: String, expTitle: String, netTitle: String,
        revValue: Double, expValue: Double, netValue: Double,
        revYoy: Double, expYoy: Double, netYoy: Double,
        hasPrev: Bool, yoySuffix: String,
        animateNumbers: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            metricRow(
                indicator: .revenue,
                title: revTitle,
                subtitle: hasPrev ? yoyLabel(revYoy, up: true) + " \(yoySuffix)" : nil,
                value: fmt(revValue),
                valueFont: .paragraphSemibold30,
                noPreviousData: !hasPrev,
                animateValue: animateNumbers ? revValue : nil
            )
            metricRow(
                indicator: .expenses,
                title: expTitle,
                subtitle: hasPrev ? yoyLabel(expYoy, up: false) + " \(yoySuffix)" : nil,
                value: fmt(expValue),
                valuePrefix: "–",
                valueFont: .paragraphSemibold30,
                noPreviousData: !hasPrev,
                animateValue: animateNumbers ? expValue : nil
            )
            metricRow(
                indicator: .net,
                title: netTitle,
                subtitle: hasPrev ? yoyLabel(netYoy, up: true) + " \(yoySuffix)" : nil,
                value: fmt(netValue),
                valueFont: .header2,
                noPreviousData: !hasPrev,
                animateValue: animateNumbers ? netValue : nil
            )
        }
    }

    private enum IndicatorKind { case revenue, expenses, net }

    private func metricRow(indicator: IndicatorKind,
                            title: String,
                            subtitle: String?,
                            value: String,
                            valuePrefix: String = "",
                            valueFont: Font,
                            noPreviousData: Bool = false,
                            animateValue: Double? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Indicator: 12×24pt frame (Figma "Indicator default"), shape centered at cy=12
            ZStack {
                switch indicator {
                case .revenue:
                    Circle()
                        .fill(Color.green7)
                        .frame(width: 12, height: 12)
                        .offset(y: -2)
                case .expenses:
                    Circle()
                        .fill(Color.red6)
                        .frame(width: 12, height: 12)
                        .offset(y: -2)
                case .net:
                    Capsule()
                        .fill(Color.gray1)
                        .frame(width: 12, height: 4)
                }
            }
            .frame(width: 12, height: 24)

            // Text column: title+value on first row, subtitle below
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 0) {
                    Text(title)
                        .font(.paragraphSemibold30)
                        .foregroundStyle(Color.gray1)
                    Spacer()
                    HStack(spacing: 0) {
                        if !valuePrefix.isEmpty { Text(valuePrefix).font(valueFont).foregroundStyle(Color.gray1) }
                        Text(value)
                            .font(valueFont)
                            .foregroundStyle(Color.gray1)
                            .contentTransition(animateValue != nil ? .numericText(value: animateValue!) : .identity)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    }
                }

                Group {
                    if noPreviousData {
                        Text("No previous data")
                            .font(.paragraph20)
                            .foregroundStyle(Color.gray3)
                    } else if let s = subtitle {
                        Text(s)
                            .font(.paragraph20)
                            .foregroundStyle(Color.gray3)
                    }
                }
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
            activeIndex: currentEntries.firstIndex(where: { $0.isCurrent }) ?? -1,
            scrubbingIndex: scrubIndex,
            onScrubChanged: { idx in
                if scrubIndex != idx {
                    lastScrubDirection = idx > (scrubIndex ?? -1)
                    scrubIndex = idx
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            },
            onScrubEnded: {
                let direction = !lastScrubDirection
                withAnimation(.easeOut(duration: 0.25)) {
                    slideLeft = direction
                    scrubIndex = nil
                }
            },
            viewportHPadding: 24
        )
    }

    // MARK: View All Button

    private var viewAllButton: some View {
        let enabled = hasDataForPeriod
        return Button(action: {}) {
            Text(enabled ? "View \(viewAllRangeLabel) transactions" : "No transactions available")
                .font(.paragraphSemibold30)
                .foregroundStyle(enabled ? Color.blue3 : Color.gray4)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
        }
        .buttonStyle(ViewAllButtonStyle())
        .contentShape(Capsule())
        .disabled(!enabled)
    }

    // MARK: Helpers

    private func ordinalSuffix(_ n: Int) -> String {
        let mod100 = n % 100
        if (11...13).contains(mod100) { return "th" }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

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
                configuration.isPressed ? Color.gray7 : Color.clear,
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
