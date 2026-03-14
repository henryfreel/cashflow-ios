import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @Binding var showBalance: Bool
    @Binding var showProfitLossDetail: Bool

    // contentOffset.y from the scroll view:
    //   0        → at rest
    //   positive → scrolled down (normal scroll, content moving up)
    //   negative → rubber-band overscroll pull-down
    @State private var contentOffsetY: CGFloat = 0
    @State private var greetingHeight: CGFloat = 0
    @State private var isScrolled = false

    // Period state lifted from ProfitLossCard so it can be passed to ProfitLossDetailView.
    @State private var cardPeriod:   String = "1M"
    @State private var cardYear:     Int    = AppFinancials.currentYear
    @State private var cardQuarter:  Int    = AppFinancials.currentQuarter
    @State private var cardMonth:    Int    = AppFinancials.currentMonth

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Normal scroll  → contentOffsetY > 0 → min(0, …) = 0 → no extra offset, greeting scrolls freely
                // Overscroll     → contentOffsetY < 0 → min(0, …) < 0 → greeting nudged up by that amount, stays fixed
                GreetingSection()
                    .offset(y: min(0, contentOffsetY))
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        greetingHeight = newHeight
                    }

                VStack(spacing: 24) {
                    ProfitLossCard(
                        showDetail:      $showProfitLossDetail,
                        selectedPeriod:  $cardPeriod,
                        selectedYear:    $cardYear,
                        selectedQuarter: $cardQuarter,
                        selectedMonth:   $cardMonth
                    )
                    LocationsCard()
                    SavingsCard()
                    CreditCardCard()
                    LoansCard()
                }
                .padding(.horizontal, 24)
            }
        }
        .contentMargins(.bottom, 86, for: .scrollContent)
        // contentOffset.y alone is negative at rest (it includes the safe-area
        // top inset). Adding contentInsets.top normalises it so the value is:
        //   0        → at rest
        //   positive → normal scroll (content moving up)
        //   negative → rubber-band pull-down overscroll
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, newValue in
            contentOffsetY = newValue
            let shouldShow = greetingHeight > 0 && newValue >= greetingHeight
            if shouldShow != showBalance {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showBalance = shouldShow
                }
            }
            let scrolled = newValue > 0
            if scrolled != isScrolled {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isScrolled = scrolled
                }
            }
        }
        .background(Color.gray7.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            TopNavigationBar(showBalance: showBalance, isScrolled: isScrolled)
        }
        .navigationDestination(isPresented: $showProfitLossDetail) {
            ProfitLossDetailView(
                initialPeriod:  { switch cardPeriod { case "1Q": return "Quarter"; case "1Y": return "Year"; default: return "Month" } }(),
                initialYear:    cardYear,
                initialQuarter: cardQuarter,
                initialMonth:   cardMonth
            )
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Greeting

private struct GreetingSection: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("You have \(Text(AppFinancials.netBalanceFormatted).foregroundStyle(Color.blue3)) across all your accounts")
                .foregroundStyle(Color.gray1)
                .font(.heading30)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 24)
            .padding(.trailing, 40)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(Color.white)

            // Container is 24pt tall (reserves layout space).
            // The gradient inside is 48pt, top-anchored and absolutely positioned
            // via overlay so it overhangs without pushing any content down.
            Color.clear
                .frame(height: 24)
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 48)
                        .allowsHitTesting(false)
                }
        }
    }
}

// MARK: - Shared Card Container

private struct CardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Shared Launcher Row

private struct LauncherRow: View {
    let title: String
    var subtitle: String? = nil
    let amount: String
    var amountSubtitle: String? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.paragraphMedium30)
                    .foregroundStyle(Color.gray1)

                if let sub = subtitle {
                    Text(sub)
                        .font(.paragraph20)
                        .foregroundStyle(Color.gray3)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.accountBalancePreview)
                    .lineSpacing(0)
                    .foregroundStyle(Color.gray1)

                if let sub = amountSubtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.paragraph20)
                        .foregroundStyle(Color.gray3)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Profit & Loss Card

private struct ProfitLossCard: View {
    @Binding var showDetail: Bool
    @Binding var selectedPeriod:  String
    @Binding var selectedYear:    Int
    @Binding var selectedQuarter: Int
    @Binding var selectedMonth:   Int

    @State private var activeBarIndex: Int? = nil
    @State private var chartWidth: CGFloat = 0
    @State private var chartTopInCard: CGFloat = 0  // measured; drives tooltip Y
    @State private var tooltipHeight: CGFloat = 36  // measured; drives upper line segment

    // Slide-transition control
    @State private var slideLeft: Bool = true   // true = new chart enters from right (going forward)
    @State private var useSlide:  Bool = false  // only true during swipe navigation; false for period-pill taps

    // Rubber-band feedback when swiping against a navigation boundary
    @State private var bounceOffset: CGFloat = 0

    let periods = ["1M", "1Q", "1Y"]

    // MARK: Navigation helpers

    private static let fullMonthNames = [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]

    // Can go back one full period before minYear (no-data placeholder period).
    private var canGoBack: Bool {
        switch selectedPeriod {
        case "1M": return !(selectedYear == AppFinancials.minYear - 1 && selectedMonth == 12)
        case "1Q": return !(selectedYear == AppFinancials.minYear - 1 && selectedQuarter == 4)
        default:   return selectedYear > AppFinancials.minYear - 1
        }
    }

    private var hasDataForPeriod: Bool { selectedYear >= AppFinancials.minYear }

    private var canGoForward: Bool {
        switch selectedPeriod {
        case "1M": return !(selectedYear == AppFinancials.currentYear && selectedMonth == AppFinancials.currentMonth)
        case "1Q": return !(selectedYear == AppFinancials.currentYear && selectedQuarter == AppFinancials.currentQuarter)
        default:   return selectedYear < AppFinancials.currentYear
        }
    }

    private func navigateBack(animation: Animation = .easeInOut(duration: 0.3)) {
        guard canGoBack else { return }
        slideLeft = false
        useSlide  = true
        withAnimation(animation) {
            activeBarIndex = nil
            switch selectedPeriod {
            case "1M":
                if selectedMonth == 1 { selectedMonth = 12; selectedYear -= 1 }
                else { selectedMonth -= 1 }
            case "1Q":
                if selectedQuarter == 1 { selectedQuarter = 4; selectedYear -= 1 }
                else { selectedQuarter -= 1 }
            default:
                selectedYear -= 1
            }
        }
    }

    private func navigateForward(animation: Animation = .easeInOut(duration: 0.3)) {
        guard canGoForward else { return }
        slideLeft = true
        useSlide  = true
        withAnimation(animation) {
            activeBarIndex = nil
            switch selectedPeriod {
            case "1M":
                if selectedMonth == 12 { selectedMonth = 1; selectedYear += 1 }
                else { selectedMonth += 1 }
            case "1Q":
                if selectedQuarter == 4 { selectedQuarter = 1; selectedYear += 1 }
                else { selectedQuarter += 1 }
            default:
                selectedYear += 1
            }
        }
    }

    // MARK: Slide transition

    /// Unique ID for the displayed chart slice. SwiftUI sees a new view whenever
    /// this changes, triggering the `.transition` defined on the container.
    private var navID: String {
        switch selectedPeriod {
        case "1M": return "1M_\(selectedYear)_\(selectedMonth)"
        case "1Q": return "1Q_\(selectedYear)_\(selectedQuarter)"
        default:   return "1Y_\(selectedYear)"
        }
    }

    /// Direction-aware slide for navigation swipes; plain opacity for period-pill taps.
    private var chartTransition: AnyTransition {
        guard useSlide else { return .opacity }
        // slideLeft = true  → user swiped left (forward in time):
        //   • old chart exits LEFT  (sign = -1 on removal)
        //   • new chart enters from RIGHT (sign = +1 on insertion)
        let sign: CGFloat = slideLeft ? 1 : -1
        return .asymmetric(
            insertion: .offset(x:  sign * 380).combined(with: .opacity),
            removal:   .offset(x: -sign * 380).combined(with: .opacity)
        )
    }

    // MARK: Page indicator data

    private var pageCount: Int {
        let years = AppFinancials.currentYear - AppFinancials.minYear + 1
        // +1 accounts for the single no-data placeholder period before minYear
        switch selectedPeriod {
        case "1M": return years * 12 + 1
        case "1Q": return years * 4 + 1
        default:   return years + 1
        }
    }

    private var currentPage: Int {
        // Page 0 is the no-data period (Dec/Q4/year before minYear); data pages start at 1.
        switch selectedPeriod {
        case "1M": return (selectedYear - AppFinancials.minYear) * 12 + (selectedMonth   - 1) + 1
        case "1Q": return (selectedYear - AppFinancials.minYear) * 4  + (selectedQuarter - 1) + 1
        default:   return  selectedYear - AppFinancials.minYear + 1
        }
    }

    // Shared gesture overlay placed on each bars HStack.
    // Uses UIKit gesture recognizers so vertical drags are cleanly rejected before
    // UIScrollView ever loses the touch.
    private var scrubOverlay: some View {
        ChartScrubOverlay(
            onScrubChanged: { x in
                let idx = barIndex(at: x)
                if activeBarIndex != idx {
                    activeBarIndex = idx
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            },
            onScrubEnded: {
                withAnimation(.easeOut(duration: 0.2)) { activeBarIndex = nil }
            }
        )
    }

    // MARK: Monthly bar model

    struct MonthBar: Identifiable {
        let id: Int
        let month: String          // single-letter label
        let fullMonth: String      // full name for tooltip
        let height: CGFloat        // positive = profit, negative = loss
        let value: Double          // dollar value for tooltip
        let isCurrentMonth: Bool   // partial/in-progress month shown dimmed at rest
    }

    // Single scale derived from the largest absolute value across all bars.
    // This keeps green and red heights proportional to each other — a $500
    // loss bar will be proportionally shorter than a $5,000 profit bar.
    // The one bar with the greatest absolute value always reaches exactly 60pt.
    private var bars: [MonthBar] {
        let data = AppFinancials.monthlyData(year: selectedYear)
        let maxAbs = data.map { abs($0.netProfit) }.max() ?? 1
        let scale = CGFloat(60.0 / maxAbs)
        // Current month indicator only applies when viewing the live year/month
        let isLiveYear = selectedYear == AppFinancials.currentYear
        let liveMonthId = AppFinancials.currentMonth - 1  // id is 0-based
        return data.map { m in
            MonthBar(
                id: m.id,
                month: m.month,
                fullMonth: m.fullMonth,
                height: CGFloat(m.netProfit) * scale,
                value: m.netProfit,
                isCurrentMonth: isLiveYear && m.id == liveMonthId
            )
        }
    }

    // MARK: Daily bar model (1M view)

    struct DayBar: Identifiable {
        let id: Int            // 0-based index for array access
        let dayNumber: Int     // 1-based day (1–31)
        let monthName: String  // e.g. "December"
        let height: CGFloat    // normalized ±60pt; 0 for future days
        let value: Double      // net profit
        let hasData: Bool      // false for future days
        let isToday: Bool      // current partial day shown dimmed at rest

        // Label shown on the axis: odd days only; even days return ""
        var dayLabel: String  { dayNumber % 2 == 1 ? "\(dayNumber)" : "" }
        var fullLabel: String { "\(monthName) \(dayNumber)" }
    }

    private var dayBars: [DayBar] {
        let data = AppFinancials.dailyData(year: selectedYear, month: selectedMonth)
        let maxAbs = data.filter { $0.hasData }.map { abs($0.netProfit) }.max() ?? 1
        let scale = CGFloat(60.0 / maxAbs)
        let monthName = Self.fullMonthNames[max(0, min(11, selectedMonth - 1))]
        let isLiveMonth = selectedYear == AppFinancials.currentYear && selectedMonth == AppFinancials.currentMonth
        return data.map { d in
            DayBar(
                id: d.id - 1,
                dayNumber: d.id,
                monthName: monthName,
                height: d.hasData ? CGFloat(d.netProfit) * scale : 0,
                value: d.netProfit,
                hasData: d.hasData,
                isToday: isLiveMonth && d.id == AppFinancials.currentDay
            )
        }
    }

    // MARK: Weekly bar model (1Q view)

    struct WeekBar: Identifiable {
        let id: Int
        let label: String         // axis label (every other week; "" for alternates)
        let fullLabel: String     // "Week of 9/23" for tooltip
        let height: CGFloat       // normalized ±60pt; 0 for future weeks
        let value: Double         // net profit
        let hasData: Bool         // false for future periods
        let isCurrentWeek: Bool   // Dec 9–15 = partial, shown dimmed at rest
    }

    private var weekBars: [WeekBar] {
        let data = AppFinancials.weeklyData(year: selectedYear, quarter: selectedQuarter)
        let maxAbs = data.filter { $0.hasData }.map { abs($0.netProfit) }.max() ?? 1
        let scale = CGFloat(60.0 / maxAbs)
        // Current-week dimming only applies when viewing the live quarter
        let isLiveQuarter = selectedYear == AppFinancials.currentYear && selectedQuarter == AppFinancials.currentQuarter
        return data.map { w in
            let weekNum = w.id + 1
            return WeekBar(
                id: w.id,
                label: w.hasData && w.id % 2 == 0 ? "W\(weekNum)" : "",
                fullLabel: w.dateRange,
                height: w.hasData ? CGFloat(w.netProfit) * scale : 0,
                value: w.netProfit,
                hasData: w.hasData,
                isCurrentWeek: isLiveQuarter && w.id == 10
            )
        }
    }

    // MARK: Active bar resolver

    private struct ActiveBarInfo {
        let label: String
        let value: Double
        let isFuture: Bool
    }

    private var activeBarInfo: ActiveBarInfo? {
        guard let idx = activeBarIndex else { return nil }
        switch selectedPeriod {
        case "1M":
            guard idx < dayBars.count else { return nil }
            let db = dayBars[idx]
            return ActiveBarInfo(label: db.fullLabel, value: db.value, isFuture: !db.hasData)
        case "1Q":
            guard idx < weekBars.count else { return nil }
            let wb = weekBars[idx]
            return ActiveBarInfo(label: wb.fullLabel, value: wb.value, isFuture: !wb.hasData)
        default:
            guard idx < bars.count else { return nil }
            let mb = bars[idx]
            return ActiveBarInfo(label: mb.fullMonth, value: mb.value, isFuture: false)
        }
    }

    // Net profit for the currently selected period (used when not scrubbing)
    private var periodTotal: Double {
        switch selectedPeriod {
        case "1M":
            return AppFinancials.dailyData(year: selectedYear, month: selectedMonth)
                .filter(\.hasData).map(\.netProfit).reduce(0, +)
        case "1Q":
            return AppFinancials.weeklyData(year: selectedYear, quarter: selectedQuarter)
                .filter(\.hasData).map(\.netProfit).reduce(0, +)
        default:
            return AppFinancials.monthlyData(year: selectedYear).map(\.netProfit).reduce(0, +)
        }
    }

    // Profit shown in the large number: scrubbing shows the active bar's value (future bars
    // keep the period total since TBD has no meaningful number to display there).
    private var displayedProfit: Double {
        if let info = activeBarInfo, !info.isFuture { return info.value }
        return periodTotal
    }

    private static let valueFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private func formattedValue(_ v: Double) -> String {
        let abs = Self.valueFormatter.string(from: NSNumber(value: Swift.abs(v))) ?? "$0.00"
        return v < 0 ? "-\(abs)" : abs
    }

    // Gap between bars, scaled to available chart width so the bar-to-gap
    // ratio stays consistent across device sizes.
    // Reference: 8pt gap at 310pt chart width (Figma). Clamped [3, 8].
    private var adaptiveBarGap: CGFloat {
        guard chartWidth > 0 else { return 8 }
        return max(3, min(8, chartWidth * 8 / 310))
    }

    // X center of bar slot i within the chart width
    private func barCenterX(for index: Int) -> CGFloat {
        if selectedPeriod == "1M" {
            let slotW = chartWidth / CGFloat(dayBars.count)
            return CGFloat(index) * slotW + slotW / 2
        }
        let gap = adaptiveBarGap
        let count = selectedPeriod == "1Q" ? weekBars.count : bars.count
        let barW = (chartWidth - CGFloat(count - 1) * gap) / CGFloat(count)
        return CGFloat(index) * (barW + gap) + barW / 2
    }

    // Bar index that contains x, clamped to valid range
    private func barIndex(at x: CGFloat) -> Int {
        if selectedPeriod == "1M" {
            let slotW = chartWidth / CGFloat(dayBars.count)
            return max(0, min(dayBars.count - 1, Int(x / slotW)))
        }
        let gap = adaptiveBarGap
        let count = selectedPeriod == "1Q" ? weekBars.count : bars.count
        let barW = (chartWidth - CGFloat(count - 1) * gap) / CGFloat(count)
        return max(0, min(count - 1, Int(x / (barW + gap))))
    }

    private var periodSubtitle: String {
        switch selectedPeriod {
        case "1M":
            let name = Self.fullMonthNames[max(0, min(11, selectedMonth - 1))]
            return "Net profit for \(name) \(selectedYear)"
        case "1Q":
            return "Net profit for Q\(selectedQuarter) \(selectedYear)"
        default:
            return "Net profit for \(selectedYear)"
        }
    }

    private func pillForeground(_ period: String) -> Color {
        period == selectedPeriod ? Color.gray3 : Color.gray4
    }

    private func pillBackground(_ period: String) -> Color {
        period == selectedPeriod ? Color.gray6 : Color.clear
    }

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(periods, id: \.self) { period in
                Text(period)
                    .font(.paragraphSemibold10)
                    .foregroundStyle(pillForeground(period))
                    .padding(.horizontal, 8)
                    .frame(minWidth: 32)
                    .frame(height: 24)
                    .background(pillBackground(period))
                    .clipShape(Capsule())
                    .onTapGesture {
                        if period == selectedPeriod {
                            useSlide = false
                            withAnimation(.easeOut(duration: 0.2)) {
                                activeBarIndex  = nil
                                selectedYear    = AppFinancials.currentYear
                                selectedMonth   = AppFinancials.currentMonth
                                selectedQuarter = AppFinancials.currentQuarter
                            }
                        } else {
                            selectedPeriod = period
                        }
                    }
            }
        }
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("Profit & Loss")
                        .font(.heading20)
                        .foregroundStyle(Color.gray1)

                    Spacer()

                    periodPicker
                }
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 2) {
                    SlotMachineText(
                        text: formattedValue(displayedProfit),
                        value: displayedProfit,
                        font: .display10,
                        color: Color.gray1
                    )

                    Text(periodSubtitle)
                        .font(.paragraph20)
                        .foregroundStyle(Color.gray3)
                }
                .padding(.top, 8)
                // No-data chart area is 24pt taller (well spacing); compensate here to keep card height fixed.
                .padding(.bottom, hasDataForPeriod ? 56 : 32)

                currentChartArea

                // Paging dots — anchored, never moves.
                ChartPageControl(numberOfPages: pageCount, currentPage: currentPage)
                    .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            // Tap anywhere on the card (except period pills, which handle their own taps)
            // navigates to the detail page. Guard prevents accidental navigation mid-scrub.
            .contentShape(Rectangle())
            .onTapGesture {
                guard activeBarIndex == nil else { return }
                showDetail = true
            }
        }
        // Tooltip lives OUTSIDE CardContainer's clipShape so it can travel to screen edges.
        // Y is driven by the measured chartTopInCard: tooltip bottom = chartTopInCard - 8pt,
        // so tooltip center = chartTopInCard - 8 - 20 = chartTopInCard - 28.
        .overlay {
            if let info = activeBarInfo, let idx = activeBarIndex,
               chartWidth > 0, chartTopInCard > 0 {
                GeometryReader { geo in
                    let barCardX = 24 + barCenterX(for: idx)
                    let tooltipHalf: CGFloat = 46
                    let cardMargin: CGFloat = 24
                    let minX = tooltipHalf - cardMargin
                    let maxX = geo.size.width - minX
                    let clampedX = max(minX, min(maxX, barCardX))

                    let gap = max(0, 28 - tooltipHeight / 2)
                    if gap > 0 {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 1, height: gap)
                            .position(x: barCardX, y: chartTopInCard - gap / 2)
                    }

                    BarScrubTooltip(month: info.label,
                                    value: info.isFuture ? "TBD" : formattedValue(info.value),
                                    valueOpacity: info.isFuture ? 0.5 : 1.0)
                        .fixedSize()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            tooltipHeight = $0
                        }
                        .position(x: clampedX, y: chartTopInCard - 28)
                }
                .allowsHitTesting(false)
            }
        }
        // Named coordinate space lets chartArea measure its exact Y within the card.
        .coordinateSpace(name: "profitCard")
        // Swipe left/right to navigate backward/forward in time.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard activeBarIndex == nil else { return }
                    let h = value.translation.width
                    let v = value.translation.height
                    guard abs(h) > abs(v) else {
                        if bounceOffset != 0 { bounceOffset = 0 }
                        return
                    }
                    let atBoundary = (h > 0 && !canGoBack) || (h < 0 && !canGoForward)
                    // Allowed direction: bars follow the finger 1:1.
                    // Boundary direction: damped rubber-band (~25%).
                    bounceOffset = atBoundary ? h * 0.25 : h
                }
                .onEnded { value in
                    guard activeBarIndex == nil else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { bounceOffset = 0 }
                        return
                    }
                    let h = value.translation.width
                    let v = value.translation.height
                    // Lower commit threshold (30 pt) since the user has already
                    // dragged the content; faster snap animation for the same reason.
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
        )
        .onChange(of: selectedPeriod) { _, _ in
            useSlide = false  // period-pill change: use opacity cross-fade, not slide
            withAnimation(.easeOut(duration: 0.2)) {
                activeBarIndex = nil
                // Reset to current period so tapping a pill always returns to "now"
                selectedYear    = AppFinancials.currentYear
                selectedMonth   = AppFinancials.currentMonth
                selectedQuarter = AppFinancials.currentQuarter
            }
        }
    }

    @ViewBuilder
    private var chartArea: some View {
        let gap = adaptiveBarGap
        VStack(spacing: 8) {
            // Bars row
            HStack(spacing: gap) {
                ForEach(bars) { bar in
                    BarColumn(bar: bar,
                              isActive: activeBarIndex == bar.id,
                              isScrubbing: activeBarIndex != nil)
                }
            }
            .frame(height: 120)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Color.gray5
                    .frame(height: 1)
                    .offset(y: 60)
            }
            // Lower line segment: behind the bars so bars naturally cover it.
            // Height 108pt stops 20pt above the labels row (128 - 20 = 108).
            .background {
                if let idx = activeBarIndex, chartWidth > 0 {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 1, height: 108)
                        .position(x: barCenterX(for: idx), y: 54)
                }
            }
            .overlay { scrubOverlay }
            // Bars slide on navigation and rubber-band on boundary; labels stay put.
            .id(navID)
            .transition(chartTransition)
            .offset(x: bounceOffset)

            // Month labels — fixed, never offset.
            HStack(spacing: gap) {
                ForEach(bars) { bar in
                    Text(bar.month)
                        .font(activeBarIndex == bar.id
                              ? .custom(AppFont.Text.semiBold, size: 10)
                              : .custom(AppFont.Text.regular,  size: 10))
                        .foregroundStyle(activeBarIndex == bar.id
                            ? Color.gray1
                            : Color.gray4)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 14)
        }
        // Clip so offset bars don't visually overflow into the labels row.
        .clipped()
        // Capture chart width for gesture math, and chart's Y in the card for tooltip placement.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
        .onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .named("profitCard")).minY
        } action: { chartTopInCard = $0 }
    }

    @ViewBuilder
    private var dailyChartArea: some View {
        VStack(spacing: 8) {
            // Bars row — 31 equal-width slots, each containing a 4pt-wide bar
            HStack(spacing: 0) {
                ForEach(dayBars) { bar in
                    DayColumn(bar: bar,
                              isActive: activeBarIndex == bar.id,
                              isScrubbing: activeBarIndex != nil)
                }
            }
            .frame(height: 120)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Color.gray5
                    .frame(height: 1)
                    .offset(y: 60)
            }
            .background {
                if let idx = activeBarIndex, chartWidth > 0, idx < dayBars.count {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 1, height: 108)
                        .position(x: barCenterX(for: idx), y: 54)
                }
            }
            .overlay { scrubOverlay }
            .id(navID)
            .transition(chartTransition)
            .offset(x: bounceOffset)

            // Day labels — fixed, never offset.
            //   • At rest: odd days only, 2× slot width for breathing room.
            //   • While scrubbing: active day always shows; the two immediate
            //     neighbours (±1 index) are hidden to avoid overlap; all other
            //     odd days remain visible.
            let slotW = chartWidth / CGFloat(dayBars.count)
            HStack(spacing: 0) {
                ForEach(dayBars) { bar in
                    let isActive    = activeBarIndex == bar.id
                    let isScrubbing = activeBarIndex != nil
                    let isNeighbor  = isScrubbing && abs(bar.id - (activeBarIndex ?? -99)) == 1
                    let showLabel   = isActive || (bar.dayNumber % 2 == 1 && !isNeighbor)
                    Color.clear
                        .frame(width: slotW, height: 14)
                        .overlay {
                            if showLabel {
                                Text("\(bar.dayNumber)")
                                    .font(isActive
                                          ? .custom(AppFont.Text.semiBold, size: 10)
                                          : .custom(AppFont.Text.regular,  size: 10))
                                    .foregroundStyle(isActive
                                        ? Color.gray1
                                        : Color.gray4)
                                    .frame(width: slotW * 2)
                            }
                        }
                }
            }
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
        .onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .named("profitCard")).minY
        } action: { chartTopInCard = $0 }
    }

    @ViewBuilder
    private var quarterlyChartArea: some View {
        let gap = adaptiveBarGap
        VStack(spacing: 8) {
            // Bars row — proportional width like 1Y, but 14 slots (12 data + 2 future)
            HStack(spacing: gap) {
                ForEach(weekBars) { bar in
                    WeekColumn(bar: bar,
                               isActive: activeBarIndex == bar.id,
                               isScrubbing: activeBarIndex != nil)
                }
            }
            .frame(height: 120)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Color.gray5
                    .frame(height: 1)
                    .offset(y: 60)
            }
            .background {
                if let idx = activeBarIndex, chartWidth > 0, idx < weekBars.count {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 1, height: 108)
                        .position(x: barCenterX(for: idx), y: 54)
                }
            }
            .overlay { scrubOverlay }
            .id(navID)
            .transition(chartTransition)
            .offset(x: bounceOffset)

            // Week labels — fixed, never offset.
            HStack(spacing: gap) {
                ForEach(weekBars) { bar in
                    Text("\(bar.id + 1)")
                        .font(activeBarIndex == bar.id
                              ? .custom(AppFont.Text.semiBold, size: 10)
                              : .custom(AppFont.Text.regular,  size: 10))
                        .foregroundStyle(activeBarIndex == bar.id
                            ? Color.gray1
                            : Color.gray4)
                        .frame(maxWidth: .infinity)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(height: 14)
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
        .onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .named("profitCard")).minY
        } action: { chartTopInCard = $0 }
    }

    // MARK: Chart area selection

    /// Routes to the correct chart area or the no-data well based on current state.
    /// Extracted into its own @ViewBuilder property to prevent Swift type-checker issues
    /// that arise from nesting a `switch` inside an `if/else` in a VStack body.
    @ViewBuilder
    private var currentChartArea: some View {
        if hasDataForPeriod {
            switch selectedPeriod {
            case "1M": dailyChartArea
            case "1Q": quarterlyChartArea
            default:   chartArea
            }
        } else {
            noDataChartArea
        }
    }

    // MARK: No-data chart area

    private static let noDataMonthInitials = ["J","F","M","A","M","J","J","A","S","O","N","D"]

    /// Figma no-data state: gray well (120pt, 8pt radius) + 32pt gap + month-initial labels.
    /// Total height matches the regular chart area so the card height stays fixed.
    private var noDataChartArea: some View {
        return VStack(spacing: 32) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray7)
                VStack(spacing: 4) {
                    Text("No data available")
                        .font(.paragraphSemibold20)
                        .foregroundStyle(Color.gray1)
                    Text("Try adjusting the date range")
                        .font(.paragraph20)
                        .foregroundStyle(Color.gray3)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }
            .frame(height: 120)

            HStack(spacing: 0) {
                ForEach(0..<12, id: \.self) { i in
                    Text(Self.noDataMonthInitials[i])
                        .font(.custom(AppFont.Text.regular, size: 10))
                        .foregroundStyle(Color.gray4)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 14)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
        .onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .named("profitCard")).minY
        } action: { chartTopInCard = $0 }
    }

    private struct WeekColumn: View {
        let bar: WeekBar
        let isActive: Bool
        let isScrubbing: Bool

        private let baseline: CGFloat = 60

        private var fillColor: Color {
            guard bar.hasData else { return .clear }
            let dimmed = isScrubbing && !isActive
            if bar.height < 0 {
                return dimmed ? Color.red6 : Color.red3
            } else {
                return dimmed ? Color.green7 : Color.green3
            }
        }

        var body: some View {
            let isNegative = bar.height < 0
            let absH = Swift.abs(bar.height)

            VStack(spacing: 0) {
                if bar.hasData && absH > 0 {
                    Color.clear.frame(height: isNegative ? baseline : max(0, baseline - absH))

            if isNegative {
                    UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
                        .fill(fillColor)
                        .overlay { if bar.isCurrentWeek { DiagonalStripes() } }
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4))
                        .frame(height: absH)
                } else {
                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                        .fill(fillColor)
                        .overlay { if bar.isCurrentWeek { DiagonalStripes() } }
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                        .frame(height: absH)
                }

                    Color.clear.frame(height: isNegative ? max(0, baseline - absH) : baseline)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 120)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.15), value: isActive)
        }
    }

    private struct BarColumn: View {
        let bar: MonthBar
        let isActive: Bool   // nil parent activeBarIndex means no scrub in progress
        let isScrubbing: Bool

        private let baseline: CGFloat = 60

        // Dimming rules:
        //   • While scrubbing: non-active bars are dimmed
        //   • At rest: the current (partial) month is always dimmed
        private var fillColor: Color {
            let dimmed = isScrubbing && !isActive
            if bar.height < 0 {
                return dimmed ? Color.red6 : Color.red3
            } else {
                return dimmed ? Color.green7 : Color.green3
            }
        }

        var body: some View {
            let isNegative = bar.height < 0
            let abs = Swift.abs(bar.height)

            VStack(spacing: 0) {
                Color.clear.frame(height: isNegative ? baseline : max(0, baseline - abs))

                if isNegative {
                    UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
                        .fill(fillColor)
                        .overlay { if bar.isCurrentMonth { DiagonalStripes() } }
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4))
                        .frame(height: abs)
                } else {
                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                        .fill(fillColor)
                        .overlay { if bar.isCurrentMonth { DiagonalStripes() } }
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                        .frame(height: abs)
                }

                Color.clear.frame(height: isNegative ? max(0, baseline - abs) : baseline)
            }
            .frame(maxWidth: .infinity, maxHeight: 120)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.15), value: isActive)
        }
    }

    // MARK: DayColumn — 4pt-wide bar for the 1M daily view

    private struct DayColumn: View {
        let bar: DayBar
        let isActive: Bool
        let isScrubbing: Bool

        private let barWidth: CGFloat = 4
        private let baseline: CGFloat = 60

        private var fillColor: Color {
            guard bar.hasData else { return .clear }
            let dimmed = isScrubbing && !isActive
            if bar.height < 0 {
                return dimmed ? Color.red6 : Color.red3
            } else {
                return dimmed ? Color.green7 : Color.green3
            }
        }

        var body: some View {
            let isNegative = bar.height < 0
            let absH = Swift.abs(bar.height)

            ZStack {
                if bar.hasData && absH > 0 {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: isNegative ? baseline : max(0, baseline - absH))

                        if isNegative {
                            UnevenRoundedRectangle(bottomLeadingRadius: 2, bottomTrailingRadius: 2)
                                .fill(fillColor)
                                .overlay { if bar.isToday { DiagonalStripes() } }
                                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 2, bottomTrailingRadius: 2))
                                .frame(width: barWidth, height: absH)
                        } else {
                            UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                                .fill(fillColor)
                                .overlay { if bar.isToday { DiagonalStripes() } }
                                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2))
                                .frame(width: barWidth, height: absH)
                        }

                        Color.clear.frame(height: isNegative ? max(0, baseline - absH) : baseline)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 120)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.15), value: isActive)
        }
    }
}

// MARK: - Diagonal stripe overlay (current / partial period)

/// White 45° diagonal lines at 2 pt width / 2 pt gap.
/// Apply as an `.overlay` then `.clipShape(...)` to hatch any bar shape.
private struct DiagonalStripes: View {
    var body: some View {
        Canvas { ctx, size in
            let pitch: CGFloat = 4 * 2.squareRoot()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to:    CGPoint(x: x,               y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                ctx.stroke(p, with: .color(.white), lineWidth: 2)
                x += pitch
            }
        }
    }
}

// MARK: - Bar Scrub Tooltip

private struct BarScrubTooltip: View {
    let month: String
    let value: String
    var valueOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Text(month)
                .foregroundStyle(Color(white: 1, opacity: 0.95))
            Text(value)
                .fixedSize()
                .foregroundStyle(Color(white: 1, opacity: 0.95 * valueOpacity))
        }
        .font(.custom(AppFont.Text.regular, size: 12))
        .lineSpacing(0)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color.gray1)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Chart Scrub Gesture Overlay
//
// UIKit-backed gesture overlay that allows proper simultaneous recognition with
// the parent UIScrollView. A pure-SwiftUI DragGesture(minimumDistance:0) claims
// UIKit touches before UIScrollView can, even with simultaneousGesture — this
// UIViewRepresentable approach uses the real UIGestureRecognizerDelegate protocol
// so vertical touches are explicitly rejected (letting ScrollView scroll) while
// horizontal drags and long-presses activate scrubbing.

// MARK: - Chart Page Control

/// Custom compact page indicator.
///
/// Size hierarchy (5 dots max visible at a time):
///   5+ pages: active + ±1 share the largest size; each further step shrinks.
///             [2pt, 3pt, 7pt, 7pt, 7pt, 5pt, 3pt, 2pt] → centred window of 5
///   <5 pages: every distance step maps to a unique size for a clear hierarchy.
///             2 dots → [7, 5]
///             3 dots → [7, 5, 3]   (active in middle)
///             4 dots → [5, 7, 5, 3]  etc.
///
/// A sliding window keeps the active dot centred as much as possible.
struct ChartPageControl: View {
    let numberOfPages: Int
    let currentPage:   Int

    // Dot geometry — four distinct tiers so every slot in the 5-dot window
    // always has a unique size, including the edge case where active is at
    // the far right/left and the window is [dist4, dist3, dist2, dist1, active].
    private let sizeActive: CGFloat = 7     // dist 0 and 1 — active + immediate neighbours
    private let sizeMid:    CGFloat = 5     // dist 2 — 4th dot outward
    private let sizeSmall:  CGFloat = 3     // dist 3 — 5th dot outward
    private let sizeTiny:   CGFloat = 2     // dist 4+ — beyond visible window at edge
    private let spacing: CGFloat = 6

    // The 5-dot window, centred on currentPage as much as possible.
    private var visiblePages: [Int] {
        guard numberOfPages > 1 else { return [] }
        let total    = min(numberOfPages, 5)
        let start    = max(0, min(currentPage - 2, numberOfPages - total))
        return Array(start..<(start + total))
    }

    var body: some View {
        if visiblePages.isEmpty { EmptyView() } else {
            HStack(spacing: spacing) {
                ForEach(visiblePages, id: \.self) { page in
                    let dist = abs(page - currentPage)

                    // Size rule:
                    //   5+ pages → active AND ±1 share the largest size (current default)
                    //   <5 pages → every distance step maps to a unique, progressively
                    //              smaller size so even 2-dot and 3-dot indicators show
                    //              a clear visual hierarchy.
                    let size: CGFloat = numberOfPages >= 5
                        ? (dist <= 1 ? sizeActive : dist == 2 ? sizeMid : dist == 3 ? sizeSmall : sizeTiny)
                        : (dist == 0 ? sizeActive : dist == 1 ? sizeMid : dist == 2 ? sizeSmall : sizeTiny)

                    let opacity: Double = dist == 0 ? 0.65
                                        : dist == 1 ? 0.40
                                        : dist == 2 ? 0.25
                                        : dist == 3 ? 0.17
                                        :             0.10
                    Circle()
                        .fill(Color.gray1.opacity(opacity))
                        .frame(width: size, height: size)
                        .transition(.opacity)
                }
            }
            // All dot size/opacity/position changes animate with the page change.
            .animation(.easeInOut(duration: 0.3), value: currentPage)
        }
    }
}

// MARK: - Chart Scrub Overlay

private struct ChartScrubOverlay: UIViewRepresentable {
    let onScrubChanged: (CGFloat) -> Void
    let onScrubEnded:   () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrubChanged: onScrubChanged, onScrubEnded: onScrubEnded)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        // Long-press only: scrubbing activates after 0.3 s of near-stationary touch.
        // allowableMovement stays at the default (~10 pt) so that a vertical scroll
        // cancels the recognizer before the threshold fires, letting UIScrollView
        // handle scrolling unobstructed. Once .began fires, the finger can drag freely
        // and .changed keeps reporting positions.
        let lp = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        lp.minimumPressDuration = 0.3
        lp.cancelsTouchesInView = false
        lp.delaysTouchesBegan   = false
        lp.delegate = context.coordinator
        view.addGestureRecognizer(lp)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onScrubChanged = onScrubChanged
        context.coordinator.onScrubEnded   = onScrubEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onScrubChanged: (CGFloat) -> Void
        var onScrubEnded:   () -> Void

        init(onScrubChanged: @escaping (CGFloat) -> Void,
             onScrubEnded:   @escaping () -> Void) {
            self.onScrubChanged = onScrubChanged
            self.onScrubEnded   = onScrubEnded
        }

        // Allow this recognizer to fire alongside UIScrollView's pan gesture.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
            switch sender.state {
            case .began:
                onScrubChanged(sender.location(in: sender.view).x)
                UISelectionFeedbackGenerator().selectionChanged()
            case .changed:
                onScrubChanged(sender.location(in: sender.view).x)
            case .ended, .cancelled, .failed:
                onScrubEnded()
            default: break
            }
        }
    }
}

// MARK: - Shared Card Components

/// Consistent title used across all cards.
private struct CardTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.heading20)
            .foregroundStyle(Color.gray1)
    }
}

/// Blue badge pill — used for APY labels, offer counts, etc.
private struct BadgePill: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.paragraphSemibold10)
            .foregroundStyle(Color.blue3)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue7)
            .clipShape(Capsule())
    }
}

/// Primary balance row: label + masked account number on the left, large amount on the right.
private struct BalanceSummaryRow: View {
    let label: String
    let maskedNumber: String
    let amount: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.paragraphMedium30)
                    .foregroundStyle(Color.gray1)
                Text(maskedNumber)
                    .font(.paragraph20)
                    .foregroundStyle(Color.gray3)
                    .tracking(1.4)
            }
            Spacer()
            Text(amount)
                .font(.accountBalancePreview)
                .lineSpacing(0)
                .foregroundStyle(Color.gray1)
        }
        .padding(.vertical, 12)
    }
}

/// Simple label / amount row at a fixed 32pt height. Used for sub-totals and secondary figures.
private struct KeyValueRow: View {
    let label: String
    let amount: String
    var amountFont: Font = .paragraphSemibold30

    var body: some View {
        HStack {
            Text(label)
                .font(.paragraph30)
                .foregroundStyle(Color.gray1)
            Spacer()
            Text(amount)
                .font(amountFont)
                .foregroundStyle(Color.gray1)
        }
        .frame(height: 32)
    }
}

/// Thin horizontal rule between sections inside a card.
private struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray5)
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}

// MARK: - Locations Card

private struct LocationsCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                CardTitle(title: "Locations")
                    .padding(.bottom, 16)

                LauncherRow(title: "Hayes Valley",   subtitle: "Square Checking", amount: "$42,847.33")
                LauncherRow(title: "Bernal Heights", subtitle: "Square Checking", amount: "$31,204.17")
                LauncherRow(title: "The Mission",    subtitle: "Square Checking", amount: "$23,461.34")
            }
            .padding(24)
        }
    }
}

// MARK: - Savings Card

private struct SavingsCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    CardTitle(title: "Savings")
                    Spacer()
                    BadgePill(label: "0.50% APY")
                }
                .padding(.bottom, 16)

                BalanceSummaryRow(
                    label: "Total Saved",
                    maskedNumber: "••• •071",
                    amount: "$87,450.00"
                )

                CardDivider()

                VStack(spacing: 0) {
                    KeyValueRow(label: "General Savings", amount: "$48,200.00")
                    KeyValueRow(label: "Sales Tax",       amount: "$24,750.00")
                    KeyValueRow(label: "Rainy Day",       amount: "$15,000.00")
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}

// MARK: - Credit Card Card

private struct CreditCardCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                // Figma specifies Bold 18pt here (not the standard heading20)
                Text("Credit Card")
                    .font(.custom(AppFont.Text.bold, size: 18))
                    .foregroundStyle(Color.gray1)
                    .padding(.bottom, 16)

                BalanceSummaryRow(
                    label: "Total outstanding",
                    maskedNumber: "•••••• 60123",
                    amount: "$8,472.53"
                )

                CardDivider()

                KeyValueRow(
                    label: "Available credit",
                    amount: "$41,527.47",
                    amountFont: .paragraphMedium30
                )
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}

// MARK: - Loans Card

private struct LoansCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    CardTitle(title: "Loans")
                    Spacer()
                    BadgePill(label: "1 new offer!")
                }
                .padding(.bottom, 16)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hayes Valley")
                            .font(.paragraphMedium30)
                            .foregroundStyle(Color.gray1)
                        Text("\(Text("$150,000").font(.custom(AppFont.Text.medium, size: 14))) available")
                            .font(.paragraph20)
                            .foregroundStyle(Color.blue3)
                    }
                    Spacer()
                    Button("View offer") {}
                        .font(.paragraphSemibold30)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue3)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .padding(.vertical, 12)

                LauncherRow(
                    title: "Bernal Heights",
                    subtitle: "$425.00 pending payment",
                    amount: "$46,718.63"
                )
                LauncherRow(
                    title: "The Mission",
                    subtitle: "$612.00 pending payment",
                    amount: "$68,541.29"
                )
            }
            .padding(24)
        }
    }
}

#Preview {
    HomeView(showBalance: .constant(false), showProfitLossDetail: .constant(false))
}
