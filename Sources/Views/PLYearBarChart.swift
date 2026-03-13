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
// Active bar uses green/red colors; inactive bars use gray5/gray4.
// Net-profit line indicator (2pt) only rendered for the active bar.
// Works for all three period modes: Year (12 months), Quarter (13 weeks),
// Month (N days).

struct PLYearBarChart: View {
    let entries: [BarChartEntry]
    let activeIndex: Int

    private let barAreaH:     CGFloat = 160
    private let zeroY:        CGFloat = 80
    private let yAxisW:       CGFloat = 32
    private let barGap:       CGFloat = 8
    private let axisToBarGap: CGFloat = 8

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

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                chartArea(totalW: geo.size.width)
            }
            .frame(height: barAreaH)

            monthLabels
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
        ZStack(alignment: .topLeading) {
            gridlines(barZoneW: barZoneW + axisToBarGap)
            yAxisView
            HStack(spacing: adaptiveGap) {
                ForEach(entries.indices, id: \.self) { i in
                    barColumn(entries[i], isActive: i == activeIndex)
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
                    .foregroundStyle(Color.gray3)
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
                    if visible.contains(i) {
                        let cx = yAxisW + axisToBarGap + CGFloat(i) * (barW + g) + barW / 2
                        Text(entries[i].label)
                            .font(.custom(AppFont.Text.regular, size: 10))
                            .foregroundStyle(Color.gray3)
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
    private func barColumn(_ m: BarChartEntry, isActive: Bool) -> some View {
        let s      = scale
        let revH   = CGFloat(m.revenue  / s) * zeroY
        let expH   = CGFloat(m.expenses / s) * zeroY
        let net    = m.revenue - m.expenses
        let netH   = CGFloat(abs(net) / s) * zeroY
        let isPos  = net >= 0

        // Light fill for the base portion; darker shade marks the net-profit segment.
        // Current (partial) period bars use diagonal hatching instead of a solid fill.
        // Net-profit line appears on every bar that has data.
        let lineY: CGFloat = isPos
            ? zeroY - min(netH, revH)
            : zeroY + min(netH, expH)

        ZStack(alignment: .topLeading) {
            revenueBar(revH: revH, netH: netH, isPos: isPos,
                       light: .green5, dark: .green1, isCurrent: m.isCurrent)
            expenseBar(expH: expH, netH: netH, isPos: isPos,
                       light: .red6,   dark: .red1,   isCurrent: m.isCurrent)
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
                    .fill(Color.gray1)
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
