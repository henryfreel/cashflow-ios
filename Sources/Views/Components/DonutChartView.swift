import SwiftUI

/// Interactive donut (ring) chart for the Revenue and Expenses detail pages.
///
/// Renders one arc segment per category. Tapping a segment selects it;
/// the center label and value update to reflect the selection.
/// The accent color is green for Revenue pages and red for Expenses pages.
struct DonutChartView: View {

    // MARK: - Public API

    struct Segment: Identifiable {
        let id: Int
        let name: String
        let value: Double
    }

    let segments: [Segment]
    /// Applied to the selected arc and the center category label.
    let accentColor: Color
    /// Short date-range string shown in the center below the value.
    /// e.g. "Jan – Dec 2024"
    let periodLabel: String

    // MARK: - State

    /// Which segment is currently highlighted. Owned by the parent so other
    /// parts of the screen (e.g. the metrics rows) can read the selection.
    @Binding var selectedSegmentIndex: Int

    // MARK: - Layout constants

    /// Stroke width as a fraction of the outer radius (40 / 160 = 0.25 for a 320pt chart).
    private let strokeRatio: CGFloat = 0.25
    /// Desired visible gap between adjacent arc caps, in points.
    private let gapPts: CGFloat = 8
    /// Corner radius applied to each arc end (rounded-rectangle style).
    private let cornerRadius: CGFloat = 6

    // MARK: - Geometry helpers

    private var total: Double { segments.reduce(0) { $0 + $1.value } }

    /// (startAngle, endAngle) in degrees for each segment.
    /// Uses the standard math convention: 0° = 3-o'clock, increasing clockwise
    /// on screen (iOS y-axis flipped). Start is -90° so the first segment
    /// begins at 12-o'clock.
    ///
    /// `gapDeg` is computed at render time from `gapPts` and the actual mid-radius
    /// so the visual gap stays constant regardless of chart size.
    private func computeAngles(gapDeg: Double) -> [(start: Double, end: Double)] {
        guard total > 0 else { return segments.map { _ in (0, 0) } }
        let totalGap = gapDeg * Double(segments.count)
        let available = 360.0 - totalGap
        var result: [(Double, Double)] = []
        // Start half a gap past 12-o'clock so the first gap is perfectly centred
        // at -90° (straight up). This guarantees the cap bisector at that gap is
        // exactly -90°, making the top split edges perfectly vertical.
        var cursor = -90.0 + gapDeg / 2
        for seg in segments {
            let sweep = (seg.value / total) * available
            result.append((cursor, cursor + sweep))
            cursor += sweep + gapDeg
        }
        return result
    }

    // MARK: - Hit test

    /// Returns the segment index hit by `tap`, or nil if the tap missed all arcs.
    private func hitSegment(at tap: CGPoint,
                             outerR: CGFloat, innerR: CGFloat,
                             center: CGPoint,
                             angs: [(start: Double, end: Double)]) -> Int? {
        // Negate dx to mirror the tap back to the CW angle space used by `angs`.
        let dx = center.x - tap.x
        let dy = tap.y - center.y
        let r = sqrt(dx * dx + dy * dy)
        guard r >= innerR, r <= outerR else { return nil }

        // Angle from 12-o'clock, increasing clockwise, in [0, 360).
        var deg = atan2(dx, -dy) * 180 / .pi
        if deg < 0 { deg += 360 }

        for (i, ang) in angs.enumerated() {
            var s = ang.start + 90; if s < 0 { s += 360 }; if s >= 360 { s -= 360 }
            var e = ang.end   + 90; if e < 0 { e += 360 }; if e >= 360 { e -= 360 }
            let hit = s < e ? (deg >= s && deg < e) : (deg >= s || deg < e)
            if hit { return i }
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { geo in
                    let dim:     CGFloat = min(geo.size.width, geo.size.height)
                    let outerR:  CGFloat = dim / 2
                    let strokeW: CGFloat = outerR * strokeRatio
                    let innerR:  CGFloat = outerR - strokeW
                    let midR:    CGFloat = (outerR + innerR) / 2
                    let cx:      CGFloat = geo.size.width / 2
                    let cy:      CGFloat = dim / 2
                    let center           = CGPoint(x: cx, y: cy)
                    let gapDeg:  Double  = Double(((2 * cornerRadius + gapPts) / midR) * (180 / .pi))
                    let angs             = computeAngles(gapDeg: gapDeg)

                    ZStack {
                        arcCanvas(midR: midR, strokeW: strokeW, angs: angs)
                            .frame(width: geo.size.width, height: dim)
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { val in
                                        if let idx = hitSegment(at: val.location,
                                                                outerR: outerR,
                                                                innerR: innerR,
                                                                center: center,
                                                                angs: angs) {
                                            withAnimation(.easeOut(duration: 0.18)) {
                                                selectedSegmentIndex = idx
                                            }
                                            UISelectionFeedbackGenerator().selectionChanged()
                                        }
                                    }
                            )

                        centerLabel(innerR: innerR)
                            .position(x: cx, y: cy)
                            .animation(.easeOut(duration: 0.18), value: selectedSegmentIndex)
                    }
                    .frame(width: geo.size.width, height: dim)
                }
            }
    }

    // MARK: - Drawing helpers

    /// Mid-angle of the gap that runs clockwise from `endDeg` to `startDeg`.
    /// Handles the 360° wrap so the bisector is always inside the gap.
    private func gapBisector(from endDeg: Double, to startDeg: Double) -> Double {
        var s = startDeg
        if s <= endDeg { s += 360 }   // ensure s is clockwise-after endDeg
        return (endDeg + s) / 2
    }

    /// Reflects an angle around the 12–6 o'clock vertical axis: θ → −180° − θ.
    /// Applying this to every angle in the CW layout produces the identical
    /// layout running counter-clockwise, with 12 o'clock still as the origin.
    private func R(_ deg: Double) -> Double { -180.0 - deg }

    /// Canvas that draws all arc segments with rounded-rectangle end caps.
    /// Arcs run counter-clockwise (angles reflected around the vertical axis).
    private func arcCanvas(midR: CGFloat,
                           strokeW: CGFloat,
                           angs: [(start: Double, end: Double)]) -> some View {
        Canvas { ctx, size in
            let c         = CGPoint(x: size.width / 2, y: size.height / 2)
            let cr        = cornerRadius
            let bodyStyle = StrokeStyle(lineWidth: strokeW, lineCap: .butt)
            let n         = angs.count

            for i in 0 ..< n {
                let a     = angs[i]
                let color: Color = i == selectedSegmentIndex ? accentColor : Color.gray6

                // Arc body — reflected angles + clockwise:true draws CCW on screen
                var arcPath = Path()
                arcPath.addArc(center: c, radius: midR,
                               startAngle: .degrees(R(a.start)),
                               endAngle:   .degrees(R(a.end)),
                               clockwise: true)
                ctx.stroke(arcPath, with: .color(color), style: bodyStyle)

                // Start cap — reflected position and bisector
                let prevEnd     = angs[(i - 1 + n) % n].end
                let startBisect = gapBisector(from: prevEnd, to: a.start)
                drawCap(ctx: ctx, center: c, midR: midR, strokeW: strokeW,
                        posAngleDeg: R(a.start), rotAngleDeg: R(startBisect),
                        cr: cr, color: color)

                // End cap — reflected position and bisector
                let nextStart  = angs[(i + 1) % n].start
                let endBisect  = gapBisector(from: a.end, to: nextStart)
                drawCap(ctx: ctx, center: c, midR: midR, strokeW: strokeW,
                        posAngleDeg: R(a.end), rotAngleDeg: R(endBisect),
                        cr: cr, color: color)
            }
        }
    }

    /// Draws one rounded-rectangle cap.
    /// - `posAngleDeg`: where on the midline circle the cap is centered (arc endpoint).
    /// - `rotAngleDeg`: the angle used to rotate the rectangle (gap bisector),
    ///   which makes the cap face parallel to its neighbour across the gap.
    private func drawCap(ctx: GraphicsContext,
                         center: CGPoint,
                         midR: CGFloat,
                         strokeW: CGFloat,
                         posAngleDeg: Double,
                         rotAngleDeg: Double,
                         cr: CGFloat,
                         color: Color) {
        let posRad: CGFloat = CGFloat(posAngleDeg) * .pi / 180
        let rotRad: CGFloat = CGFloat(rotAngleDeg) * .pi / 180
        let cx: CGFloat     = center.x + midR * cos(posRad)
        let cy: CGFloat     = center.y + midR * sin(posRad)
        let rect            = CGRect(x: -strokeW / 2, y: -cr, width: strokeW, height: cr * 2)
        var t               = CGAffineTransform(translationX: cx, y: cy)
        t                   = t.rotated(by: rotRad)
        let capPath: Path   = Path(roundedRect: rect, cornerRadius: cr).applying(t)
        ctx.fill(capPath, with: .color(color))
    }

    /// Center VStack with category name, value, and period label.
    private func centerLabel(innerR: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(segments[selectedSegmentIndex].name.uppercased())
                .font(.custom(AppFont.Text.medium, size: 12))
                .foregroundStyle(accentColor)
                .tracking(0.6)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(fmtCurrency(segments[selectedSegmentIndex].value))
                .font(.display10)
                .foregroundStyle(Color.black.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(periodLabel)
                .font(.custom(AppFont.Text.regular, size: 12))
                .foregroundStyle(Color.black.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(width: (innerR - 12) * 2)
    }

    // MARK: - Formatting

    private func fmtCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }
}
