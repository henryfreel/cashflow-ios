import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @Binding var showBalance: Bool
    @Binding var isScrolled: Bool

    // contentOffset.y from the scroll view:
    //   0        → at rest
    //   positive → scrolled down (normal scroll, content moving up)
    //   negative → rubber-band overscroll pull-down
    @State private var contentOffsetY: CGFloat = 0
    @State private var greetingHeight: CGFloat = 0

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
                    ProfitLossCard()
                    LocationsCard()
                    SavingsCard()
                    CreditCardCard()
                    LoansCard()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
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
        .background(Color(red: 247/255, green: 247/255, blue: 247/255).ignoresSafeArea())
    }
}

// MARK: - Greeting

private struct GreetingSection: View {
    var body: some View {
        VStack(spacing: 0) {
            (
                Text("You have ")
                    .foregroundStyle(Color(white: 0, opacity: 0.9))
                + Text(AppFinancials.netBalanceFormatted)
                    .foregroundStyle(Color(red: 0, green: 106/255, blue: 1))
                + Text(" across all your accounts")
                    .foregroundStyle(Color(white: 0, opacity: 0.9))
            )
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
                    .foregroundStyle(Color(white: 0, opacity: 0.9))

                if let sub = subtitle {
                    Text(sub)
                        .font(.paragraph20)
                        .foregroundStyle(Color(white: 0, opacity: 0.55))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.accountBalancePreview)
                    .lineSpacing(0)
                    .foregroundStyle(Color(white: 0, opacity: 0.9))

                if let sub = amountSubtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.paragraph20)
                        .foregroundStyle(Color(white: 0, opacity: 0.55))
                }
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Profit & Loss Card

private struct ProfitLossCard: View {
    @State private var selectedPeriod = "1Y"
    @State private var activeBarIndex: Int? = nil
    @State private var chartWidth: CGFloat = 0
    @State private var chartTopInCard: CGFloat = 0  // measured; drives tooltip Y
    @State private var tooltipHeight: CGFloat = 36  // measured; drives upper line segment

    let periods = ["1M", "1Q", "1Y"]

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
        let data = AppFinancials.monthly
        let maxAbs = data.map { abs($0.netProfit) }.max() ?? 1
        let scale = CGFloat(60.0 / maxAbs)
        let currentId = data.last?.id ?? -1
        return data.map { m in
            MonthBar(
                id: m.id,
                month: m.month,
                fullMonth: m.fullMonth,
                height: CGFloat(m.netProfit) * scale,
                value: m.netProfit,
                isCurrentMonth: m.id == currentId
            )
        }
    }

    // MARK: Daily bar model (1M view)

    struct DayBar: Identifiable {
        let id: Int            // 0-based index for array access
        let dayNumber: Int     // 1-based day (1–31)
        let height: CGFloat    // normalized ±60pt; 0 for future days
        let value: Double      // net profit
        let hasData: Bool      // false for days 16–31
        let isToday: Bool      // Dec 15 = partial, always shown dimmed at rest

        // Label shown on the axis: odd days only; even days return ""
        var dayLabel: String  { dayNumber % 2 == 1 ? "\(dayNumber)" : "" }
        var fullLabel: String { "December \(dayNumber)" }
    }

    private var dayBars: [DayBar] {
        let data = AppFinancials.decemberDaily
        let maxAbs = data.filter { $0.hasData }.map { abs($0.netProfit) }.max() ?? 1
        let scale = CGFloat(60.0 / maxAbs)
        return data.map { d in
            DayBar(
                id: d.id - 1,
                dayNumber: d.id,
                height: d.hasData ? CGFloat(d.netProfit) * scale : 0,
                value: d.netProfit,
                hasData: d.hasData,
                isToday: d.id == 15
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
        let data = AppFinancials.quarterlyWeeks
        let maxAbs = data.filter { $0.hasData }.map { abs($0.netProfit) }.max() ?? 1
        let scale = CGFloat(60.0 / maxAbs)
        return data.map { w in
            let weekNum = w.id + 1
            return WeekBar(
                id: w.id,
                label: w.hasData && w.id % 2 == 0 ? "W\(weekNum)" : "",
                fullLabel: w.dateRange,
                height: w.hasData ? CGFloat(w.netProfit) * scale : 0,
                value: w.netProfit,
                hasData: w.hasData,
                isCurrentWeek: w.id == 10
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
        case "1M": return AppFinancials.decemberDaily.filter(\.hasData).map(\.netProfit).reduce(0, +)
        case "1Q": return AppFinancials.quarterlyWeeks.filter(\.hasData).map(\.netProfit).reduce(0, +)
        default:   return AppFinancials.netProfit
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

    // X center of bar slot i within the chart width
    private func barCenterX(for index: Int) -> CGFloat {
        if selectedPeriod == "1M" {
            let slotW = chartWidth / CGFloat(dayBars.count)
            return CGFloat(index) * slotW + slotW / 2
        }
        let count = selectedPeriod == "1Q" ? weekBars.count : bars.count
        let barW = (chartWidth - CGFloat(count - 1) * 8) / CGFloat(count)
        return CGFloat(index) * (barW + 8) + barW / 2
    }

    // Bar index that contains x, clamped to valid range
    private func barIndex(at x: CGFloat) -> Int {
        if selectedPeriod == "1M" {
            let slotW = chartWidth / CGFloat(dayBars.count)
            return max(0, min(dayBars.count - 1, Int(x / slotW)))
        }
        let count = selectedPeriod == "1Q" ? weekBars.count : bars.count
        let barW = (chartWidth - CGFloat(count - 1) * 8) / CGFloat(count)
        return max(0, min(count - 1, Int(x / (barW + 8))))
    }

    private var periodSubtitle: String {
        switch selectedPeriod {
        case "1M": return "Net profit so far this month"
        case "1Q": return "Net profit so far this quarter"
        default:   return "Net profit so far this year"
        }
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("Profit & Loss")

                        .font(.heading20)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))

                    Spacer()

                    HStack(spacing: 0) {
                        ForEach(periods, id: \.self) { period in
                            Text(period)
                                .font(.paragraphSemibold10)
                                .foregroundStyle(
                                    period == selectedPeriod
                                        ? Color(white: 0, opacity: 0.55)
                                        : Color(white: 0, opacity: 0.3)
                                )
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(
                                    period == selectedPeriod
                                        ? Color(red: 235/255, green: 237/255, blue: 239/255)
                                        : Color.clear
                                )
                                .clipShape(Capsule())
                                .onTapGesture { selectedPeriod = period }
                        }
                    }
                }
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedValue(displayedProfit))
                        .font(.display10)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))

                    Text(periodSubtitle)
                        .font(.paragraph20)
                        .foregroundStyle(Color(white: 0, opacity: 0.55))
                }
                .padding(.top, 8)
                .padding(.bottom, 56)

                switch selectedPeriod {
                case "1M": dailyChartArea
                case "1Q": quarterlyChartArea
                default:   chartArea
                }
            }
            .padding(24)
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
        .onChange(of: selectedPeriod) { _, _ in
            withAnimation(.easeOut(duration: 0.2)) { activeBarIndex = nil }
        }
    }

    @ViewBuilder
    private var chartArea: some View {
        VStack(spacing: 8) {
            // Bars row
            HStack(spacing: 8) {
                ForEach(bars) { bar in
                    BarColumn(bar: bar,
                              isActive: activeBarIndex == bar.id,
                              isScrubbing: activeBarIndex != nil)
                }
            }
            .frame(height: 120)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Color(white: 0, opacity: 0.06)
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

            // Month labels
            HStack(spacing: 8) {
                ForEach(bars) { bar in
                    Text(bar.month)
                        .font(activeBarIndex == bar.id
                              ? .custom(AppFont.Text.semiBold, size: 10)
                              : .custom(AppFont.Text.regular,  size: 10))
                        .foregroundStyle(activeBarIndex == bar.id
                            ? Color(white: 0, opacity: 0.9)
                            : Color(white: 0, opacity: 0.3))
                        .frame(maxWidth: .infinity)
                }
            }
        }
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
                Color(white: 0, opacity: 0.06)
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

            // Day labels:
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
                                        ? Color(white: 0, opacity: 0.9)
                                        : Color(white: 0, opacity: 0.3))
                                    .frame(width: slotW * 2)
                            }
                        }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
        .onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .named("profitCard")).minY
        } action: { chartTopInCard = $0 }
    }

    @ViewBuilder
    private var quarterlyChartArea: some View {
        VStack(spacing: 8) {
            // Bars row — proportional width like 1Y, but 14 slots (12 data + 2 future)
            HStack(spacing: 8) {
                ForEach(weekBars) { bar in
                    WeekColumn(bar: bar,
                               isActive: activeBarIndex == bar.id,
                               isScrubbing: activeBarIndex != nil)
                }
            }
            .frame(height: 120)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Color(white: 0, opacity: 0.06)
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

            // Week labels — W1 through W12
            HStack(spacing: 8) {
                ForEach(weekBars) { bar in
                    Text("\(bar.id + 1)")
                        .font(activeBarIndex == bar.id
                              ? .custom(AppFont.Text.semiBold, size: 10)
                              : .custom(AppFont.Text.regular,  size: 10))
                        .foregroundStyle(activeBarIndex == bar.id
                            ? Color(white: 0, opacity: 0.9)
                            : Color(white: 0, opacity: 0.3))
                        .frame(maxWidth: .infinity)
                        .minimumScaleFactor(0.5)
                }
            }
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
            let dimmed = isScrubbing ? !isActive : bar.isCurrentWeek
            if bar.height < 0 {
                return dimmed
                    ? Color(red: 255/255, green: 204/255, blue: 213/255)
                    : Color(red: 204/255, green: 0,       blue: 35/255)
            } else {
                return dimmed
                    ? Color(red: 204/255, green: 255/255, blue: 221/255)
                    : Color(red: 0, green: 178/255, blue: 59/255)
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
                            .frame(height: absH)
                    } else {
                        UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                            .fill(fillColor)
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
            let dimmed = isScrubbing ? !isActive : bar.isCurrentMonth
            if bar.height < 0 {
                return dimmed
                    ? Color(red: 255/255, green: 204/255, blue: 213/255)  // Critical/30  #FFCCD5
                    : Color(red: 204/255, green: 0,       blue: 35/255)   // Critical/Fill #CC0023
            } else {
                return dimmed
                    ? Color(red: 204/255, green: 255/255, blue: 221/255)  // Success/30   #CCFFDD
                    : Color(red: 0, green: 178/255, blue: 59/255)         // Success/Fill #00B23B
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
                        .frame(height: abs)
                } else {
                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                        .fill(fillColor)
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
            let dimmed = isScrubbing ? !isActive : bar.isToday
            if bar.height < 0 {
                return dimmed
                    ? Color(red: 255/255, green: 204/255, blue: 213/255)
                    : Color(red: 204/255, green: 0,       blue: 35/255)
            } else {
                return dimmed
                    ? Color(red: 204/255, green: 255/255, blue: 221/255)
                    : Color(red: 0, green: 178/255, blue: 59/255)
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
                                .frame(width: barWidth, height: absH)
                        } else {
                            UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                                .fill(fillColor)
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
        .background(Color(red: 26/255, green: 26/255, blue: 26/255))
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

private struct ChartScrubOverlay: UIViewRepresentable {
    let onScrubChanged: (CGFloat) -> Void
    let onScrubEnded:   () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrubChanged: onScrubChanged, onScrubEnded: onScrubEnded)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        // Long-press: fires scrubbing after 0.3 s of near-stationary touch.
        // allowableMovement is very large so the gesture tracks indefinitely once
        // the 0.3 s threshold fires — the finger can drag freely afterwards.
        let lp = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        lp.minimumPressDuration = 0.3
        lp.allowableMovement = 10_000
        lp.cancelsTouchesInView = false
        lp.delegate = context.coordinator
        view.addGestureRecognizer(lp)

        // Pan: handles immediate horizontal drag activation. gestureRecognizerShouldBegin
        // rejects vertical-dominant movement so UIScrollView scrolls unobstructed.
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

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

        // Allow this recognizer to fire alongside any other (especially UIScrollView's pan).
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        // Pan only begins when movement is clearly horizontal. Returning false lets
        // UIKit pass the touch to the next recognizer (UIScrollView's pan gesture).
        func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
            guard let pan = gr as? UIPanGestureRecognizer,
                  let view = pan.view else { return true }
            let v = pan.velocity(in: view)
            let speed = hypot(v.x, v.y)
            guard speed > 20 else { return false }   // stationary → let long-press handle
            return abs(v.x) > abs(v.y)               // horizontal wins → begin; vertical → don't
        }

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

        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            switch sender.state {
            case .began:
                onScrubChanged(sender.location(in: sender.view).x)
                UISelectionFeedbackGenerator().selectionChanged()
            case .changed:
                onScrubChanged(sender.location(in: sender.view).x)
            case .ended, .cancelled:
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
            .foregroundStyle(Color(white: 0, opacity: 0.9))
    }
}

/// Blue badge pill — used for APY labels, offer counts, etc.
private struct BadgePill: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.paragraphSemibold10)
            .foregroundStyle(Color(red: 0, green: 106/255, blue: 1))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(red: 229/255, green: 240/255, blue: 255/255))
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
                    .foregroundStyle(Color(white: 0, opacity: 0.9))
                Text(maskedNumber)
                    .font(.paragraph20)
                    .foregroundStyle(Color(white: 0, opacity: 0.55))
                    .tracking(1.4)
            }
            Spacer()
            Text(amount)
                .font(.accountBalancePreview)
                .lineSpacing(0)
                .foregroundStyle(Color(white: 0, opacity: 0.9))
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
                .foregroundStyle(Color(white: 0, opacity: 0.9))
            Spacer()
            Text(amount)
                .font(amountFont)
                .foregroundStyle(Color(white: 0, opacity: 0.9))
        }
        .frame(height: 32)
    }
}

/// Thin horizontal rule between sections inside a card.
private struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(white: 0, opacity: 0.05))
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
                    .foregroundStyle(Color(white: 0, opacity: 0.9))
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
                            .foregroundStyle(Color(white: 0, opacity: 0.9))
                        (
                            Text("$150,000")
                                .font(.custom(AppFont.Text.medium, size: 14))
                            + Text(" available")
                                .font(.paragraph20)
                        )
                        .foregroundStyle(Color(red: 0, green: 106/255, blue: 1))
                    }
                    Spacer()
                    Button("View offer") {}
                        .font(.paragraphSemibold30)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(red: 0, green: 106/255, blue: 1))
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
    HomeView(showBalance: .constant(false), isScrolled: .constant(false))
}
