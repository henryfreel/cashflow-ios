import SwiftUI

// MARK: - P&L Bar Chart
//
// Figma "Chart-single color" (2334:15839). Total 186pt.
// Layout: 160pt bar area (zero at y=80) + 16pt gap + x-axis labels.
// Y-axis: 32pt left column. Bar zone: remaining width, N columns, 8pt gaps.
// Each bar column has three layers:
//   • Light revenue bar  — grows UP from zero (top-rounded corners)
//   • Light expense bar  — grows DOWN from zero (bottom-rounded corners)
//   • Dark net-profit overlay — sits at the zero end of the relevant bar
// Active bar uses green/red colors; inactive bars use gray7/gray5.
// Net-profit line indicator (2pt) only rendered for the active bar.
// Works for all three period modes: Year (12 months), Quarter (13 weeks),
// Month (N days).
//
// Scrubbing: set scrubbingIndex + supply onScrubChanged/onScrubEnded callbacks.
// While scrubbing all non-active bars dim to 35% opacity; a thin vertical
// reference line appears behind the active bar; a tooltip floats above it.

struct PLYearBarChart: View {
    let entries: [BarChartEntry]
    let activeIndex: Int

    // Scrub state — supplied by parent; chart fires callbacks when gesture fires.
    var scrubbingIndex: Int? = nil
    var onScrubChanged: (Int) -> Void = { _ in }
    var onScrubEnded: () -> Void = {}

    /// Horizontal padding the parent applies on each side of this chart.
    /// The tooltip overlay expands into this region so it can reach the screen edge.
    var viewportHPadding: CGFloat = 0

    private let barAreaH:     CGFloat = 160
    private let zeroY:        CGFloat = 80
    private let yAxisW:       CGFloat = 32
    private let barGap:       CGFloat = 8
    private let axisToBarGap: CGFloat = 8

    // Measured in onGeometryChange; drives barIndex(at:) and tooltip positioning.
    @State private var chartTotalWidth: CGFloat = 0
    @State private var tooltipHeight: CGFloat = 32
    @State private var tooltipWidth: CGFloat = 60

    private var scale: Double {
        max(entries.map(\.revenue).max() ?? 1,
            entries.map(\.expenses).max() ?? 1)
    }

    private func axisLabel(_ v: Double) -> String {
        let k = v / 1_000
        if k == 0 { return "0" }
        if k >= 1_000 { return "\(Int((k / 1_000).rounded()))m" }
        return "\(Int(k.rounded()))k"
    }

    // MARK: Bar index / center helpers

    private func barIndex(at x: CGFloat) -> Int {
        guard chartTotalWidth > 0 else { return 0 }
        let barZoneW = chartTotalWidth - yAxisW - axisToBarGap
        let g = gap(for: barZoneW)
        let n = entries.count
        let barW = max(0, (barZoneW - g * CGFloat(n - 1)) / CGFloat(n))
        let adjustedX = x - yAxisW - axisToBarGap
        return max(0, min(n - 1, Int(adjustedX / (barW + g))))
    }

    private func barCenterX(for index: Int) -> CGFloat {
        guard chartTotalWidth > 0 else { return 0 }
        let barZoneW = chartTotalWidth - yAxisW - axisToBarGap
        let g = gap(for: barZoneW)
        let n = entries.count
        let barW = max(0, (barZoneW - g * CGFloat(n - 1)) / CGFloat(n))
        return yAxisW + axisToBarGap + CGFloat(index) * (barW + g) + barW / 2
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    chartArea(totalW: geo.size.width)

                    // Long-press scrub gesture overlay
                    PLChartScrubOverlay(
                        onScrubChanged: { x in
                            onScrubChanged(barIndex(at: x))
                        },
                        onScrubEnded: onScrubEnded
                    )
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                    chartTotalWidth = $0
                }
            }
            .frame(height: barAreaH)

            monthLabels
        }
        .background(alignment: .top) {
            // Vertical line behind chart: y=0 to y=168 (8pt into the 16pt gap, splitting the difference).
            // Renders under bars; only tip and bottom visible.
            if let si = scrubbingIndex, chartTotalWidth > 0 {
                let cx = barCenterX(for: si)
                let lineH = barAreaH + 8
                Rectangle()
                    .fill(Color.gray1)
                    .frame(width: 1, height: lineH)
                    .position(x: cx, y: lineH / 2)
            }
        }
        // Tooltip overlay; tip segment (-16 to 0) drawn here (above chart, no bars)
        // so only the tip (above bars) and bottom (below bars) are visible.
        .overlay(alignment: .top) {
            if let si = scrubbingIndex, chartTotalWidth > 0 {
                let cx = barCenterX(for: si)
                GeometryReader { geo in
                    let halfW = tooltipWidth / 2
                    // Keep 12 pt between the tooltip edge and the screen edge.
                    // geo.size.width is the chart width; viewportHPadding lets the tooltip
                    // overflow into the parent's horizontal inset to reach the screen edge.
                    let edgeMargin: CGFloat = 12
                    let clampedX = max(halfW - viewportHPadding + edgeMargin,
                                       min(geo.size.width + viewportHPadding - halfW - edgeMargin, cx))

                    // Tooltip center 16pt above chart top (8pt higher than before).
                    let tooltipCenterY = -(tooltipHeight / 2 + 16)

                    // Tip segment: tooltip bottom (-16) to chart top (0). Above bars, no overlap.
                    Rectangle()
                        .fill(Color.gray1)
                        .frame(width: 1, height: 16)
                        .position(x: cx, y: -8)

                    PLBarTooltip(
                        label: si < entries.count ? entries[si].fullLabel : ""
                    )
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                        tooltipHeight = size.height
                        tooltipWidth  = size.width
                    }
                    .position(x: clampedX, y: tooltipCenterY)
                }
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: Chart area

    private func gap(for barZoneW: CGFloat) -> CGFloat {
        let countFactor = CGFloat(12) / CGFloat(max(12, entries.count))
        return max(1.5, min(barGap * countFactor, barZoneW * barGap * countFactor / 310)) + 3
    }

    @ViewBuilder
    private func chartArea(totalW: CGFloat) -> some View {
        let barZoneW    = totalW - yAxisW - axisToBarGap
        let adaptiveGap = gap(for: barZoneW)
        let isScrubbing = scrubbingIndex != nil

        ZStack(alignment: .topLeading) {
            gridlines(barZoneW: barZoneW + axisToBarGap)
            yAxisView

            HStack(spacing: adaptiveGap) {
                ForEach(entries.indices, id: \.self) { i in
                    barColumn(entries[i],
                              isActive: i == activeIndex,
                              isScrubbing: isScrubbing,
                              isActiveScrub: i == scrubbingIndex)
                }
            }
            .frame(width: barZoneW)
            .offset(x: yAxisW + axisToBarGap)
        }
    }

    // MARK: Gridlines
    // Figma: stroke-dasharray="0.01 3", stroke-linecap="round", stroke-opacity=0.15
    // Near-zero dash + round caps = circular dots; 3pt gap between dots.

    @ViewBuilder
    private func gridlines(barZoneW: CGFloat) -> some View {
        let ys: [CGFloat] = [0, 40, 80, 120, 160]
        let style = StrokeStyle(lineWidth: 1, lineCap: .round, dash: [0.01, 3])
        ForEach(ys, id: \.self) { y in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: barZoneW, y: 0.5))
            }
            .stroke(Color.gray1.opacity(0.15), style: style)
            .frame(width: barZoneW, height: 1)
            .offset(x: yAxisW, y: y)
        }
    }

    // MARK: Y-axis labels

    private struct YAxisEntry: Identifiable {
        let id: Int
        let y: CGFloat
        let label: String
    }

    private var yAxisEntries: [YAxisEntry] {
        let s = scale
        return [
            YAxisEntry(id: 0, y: 0,   label: axisLabel(s)),
            YAxisEntry(id: 1, y: 40,  label: axisLabel(s / 2)),
            YAxisEntry(id: 2, y: 80,  label: "0"),
            YAxisEntry(id: 3, y: 120, label: "-\(axisLabel(s / 2))"),
            YAxisEntry(id: 4, y: 160, label: "-\(axisLabel(s))")
        ]
    }

    private var yAxisView: some View {
        ZStack(alignment: .topLeading) {
            ForEach(yAxisEntries) { entry in
                Text(entry.label)
                    .font(.custom(AppFont.Text.regular, size: 10))
                    .foregroundStyle(Color.gray4)
                    .frame(width: yAxisW - 4, alignment: .trailing)
                    .offset(y: entry.y - 5)
            }
        }
    }

    // MARK: Month labels

    /// Returns the set of bar indices that should receive an x-axis label.
    /// For month view (>13 bars) we pick a `numLabels` that makes (N-1)
    /// perfectly divisible — giving a uniform stride.  For 30-day months
    /// (29 is prime, no perfect fit) we fall back to linspace, which
    /// distributes the two uneven gaps evenly across the whole axis.
    private var labelIndices: Set<Int> {
        let n = entries.count
        guard n > 13 else { return Set(0..<n) }

        // Try common label counts (in preference order) for an exact stride.
        let candidates = [10, 11, 8, 9, 12, 7, 6]
        var numLabels = 10
        for k in candidates where k >= 2 && (n - 1) % (k - 1) == 0 {
            numLabels = k
            break
        }

        return Set((0..<numLabels).map { i in
            Int((Double(i) * Double(n - 1) / Double(numLabels - 1)).rounded())
        })
    }

    private var monthLabels: some View {
        let visible = labelIndices
        return GeometryReader { geo in
            let totalW   = geo.size.width
            let barZoneW = totalW - yAxisW - axisToBarGap
            let g        = gap(for: barZoneW)
            let n        = entries.count
            let barW     = max(0, (barZoneW - g * CGFloat(n - 1)) / CGFloat(n))
            ZStack(alignment: .topLeading) {
                ForEach(entries.indices, id: \.self) { i in
                    let isActiveScrub = i == scrubbingIndex
                    // Always show the scrubbing-active label, even if normally hidden
                    let isVisible = visible.contains(i) || isActiveScrub
                    if isVisible {
                        let cx = yAxisW + axisToBarGap + CGFloat(i) * (barW + g) + barW / 2
                        Text(entries[i].label)
                            .font(.custom(AppFont.Text.regular, size: 10))
                            .foregroundStyle(isActiveScrub ? Color.gray1 : Color.gray4)
                            .fixedSize()
                            .position(x: cx, y: 5)
                    }
                }
            }
        }
        .frame(height: 10)
    }

    // MARK: Bar column

    @ViewBuilder
    private func barColumn(_ m: BarChartEntry,
                            isActive: Bool,
                            isScrubbing: Bool,
                            isActiveScrub: Bool) -> some View {
        let s      = scale
        let revH   = CGFloat(m.revenue  / s) * zeroY
        let expH   = CGFloat(m.expenses / s) * zeroY
        let net    = m.revenue - m.expenses
        let netH   = CGFloat(abs(net) / s) * zeroY
        let isPos  = net >= 0

        // While scrubbing, non-active bars switch to neutral grays.
        // Active (hovered) bar keeps its full green/red palette.
        let dimmed = isScrubbing && !isActiveScrub
        let revLight: Color = dimmed ? .gray7  : .green7
        let revDark:  Color = dimmed ? .gray5  : .green3
        let expLight: Color = dimmed ? .gray7  : .red7
        let expDark:  Color = dimmed ? .gray5  : .red2
        let lineColor: Color = dimmed ? .gray5 : .gray1

        let lineY: CGFloat = isPos
            ? zeroY - min(netH, revH)
            : zeroY + min(netH, expH)

        ZStack(alignment: .topLeading) {
            revenueBar(revH: revH, netH: netH, isPos: isPos,
                       light: revLight, dark: revDark, isCurrent: m.isCurrent)
            expenseBar(expH: expH, netH: netH, isPos: isPos,
                       light: expLight, dark: expDark, isCurrent: m.isCurrent)
                .offset(y: zeroY)
        }
        .frame(height: barAreaH, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipped()
        // Overlay applied AFTER .clipped() so the round caps can bleed
        // 2pt beyond the bar edge on each side without being cropped.
        .overlay(alignment: .top) {
            if m.hasData && netH > 0 {
                Capsule()
                    .fill(lineColor)
                    .frame(height: 2)
                    .padding(.horizontal, -2)
                    .offset(y: lineY - 1)
            }
        }
    }

    // MARK: Revenue bar (top half, top-rounded)

    @ViewBuilder
    private func revenueBar(revH: CGFloat, netH: CGFloat, isPos: Bool,
                             light: Color, dark: Color, isCurrent: Bool) -> some View {
        if revH > 0 {
            VStack(spacing: 0) {
                if isPos {
                    barSegment(color: light, height: max(0, revH - netH), isCurrent: isCurrent)
                    barSegment(color: dark,  height: min(netH, revH),     isCurrent: isCurrent)
                } else {
                    barSegment(color: light, height: revH, isCurrent: isCurrent)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 4, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 4
            ))
            .frame(height: zeroY, alignment: .bottom)
        } else {
            Color.clear.frame(height: zeroY)
        }
    }

    // MARK: Expense bar (bottom half, bottom-rounded)

    @ViewBuilder
    private func expenseBar(expH: CGFloat, netH: CGFloat, isPos: Bool,
                             light: Color, dark: Color, isCurrent: Bool) -> some View {
        if expH > 0 {
            VStack(spacing: 0) {
                if !isPos {
                    barSegment(color: dark,  height: min(netH, expH),     isCurrent: isCurrent)
                    barSegment(color: light, height: max(0, expH - netH), isCurrent: isCurrent)
                } else {
                    barSegment(color: light, height: expH, isCurrent: isCurrent)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 0
            ))
            .frame(height: zeroY, alignment: .top)
        } else {
            Color.clear.frame(height: zeroY)
        }
    }

    // MARK: Bar segment — solid or hatched

    /// Single rectangular segment of a bar. When `isCurrent` is true the segment
    /// renders as diagonal hatching (2 pt white lines at 45°, 2 pt gap) over the fill color.
    @ViewBuilder
    private func barSegment(color: Color, height: CGFloat, isCurrent: Bool) -> some View {
        if height > 0 {
            if isCurrent {
                DiagonalHatch(color: color).frame(height: height)
            } else {
                Rectangle().fill(color).frame(height: height)
            }
        }
    }
}

// MARK: - Bar tooltip

private struct PLBarTooltip: View {
    let label: String

    var body: some View {
        Text(label)
            .foregroundStyle(Color(white: 1, opacity: 0.9))
            .font(.custom(AppFont.Text.regular, size: 12))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray1)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Scrub gesture overlay

/// A UIKit long-press gesture recognizer wrapped for SwiftUI.
/// Activates after 0.3 s of near-stationary touch, then tracks drag freely.
/// `cancelsTouchesInView = false` + `shouldRecognizeSimultaneouslyWith` let
/// the surrounding ScrollView's pan gesture continue unobstructed.
struct PLChartScrubOverlay: UIViewRepresentable {
    let onScrubChanged: (CGFloat) -> Void
    let onScrubEnded:   () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrubChanged: onScrubChanged, onScrubEnded: onScrubEnded)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

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

// MARK: - Diagonal hatch fill

/// A view that fills its frame with `color` overlaid with 2 pt white diagonal
/// lines at 45 ° and a 2 pt gap — used to indicate the current / partial period.
private struct DiagonalHatch: View {
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            // Perpendicular pitch = 2 pt line + 2 pt gap = 4 pt
            // Horizontal spacing between line origins = 4 × √2 ≈ 5.66 pt
            let pitch: CGFloat = 4 * 2.squareRoot()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to:    CGPoint(x: x,              y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                ctx.stroke(p, with: .color(.white), lineWidth: 2)
                x += pitch
            }
        }
        .background(color)
    }
}

#if DEBUG
#Preview("PLYearBarChart – Year") {
    PLYearBarChart(
        entries: AppFinancials.monthly.map {
            BarChartEntry(id: $0.id, label: $0.month, fullLabel: $0.fullMonth,
                          revenue: $0.revenue, expenses: $0.expenses,
                          isCurrent: $0.id == AppFinancials.currentMonth - 1)
        },
        activeIndex: AppFinancials.currentMonth - 1
    )
    .padding(24)
}
#endif
