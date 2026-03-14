import SwiftUI

/// Renders a pre-formatted number string (e.g. "$1,234.56") with a per-digit
/// slot-machine scroll animation modelled on the Apple Stocks ticker.
///
/// Each digit lives in its own clipped "slot" sized to the font's line height.
/// Digits scroll vertically (no opacity cross-fade) and cascade right-to-left
/// — the least-significant digit settles first, the most-significant last,
/// producing the mechanical odometer feel visible in the reference.
///
/// When `value` increases digits scroll upward (old exits down, new enters from
/// the top). When `value` decreases digits scroll downward.
/// Non-digit characters — $, commas, periods — are rendered statically.
struct SlotMachineText: View {
    let text: String
    /// Numeric value used solely to determine scroll direction.
    let value: Double
    var font: Font = .body
    var color: Color = .primary
    /// Per-character spacing adjustment in points, equivalent to Figma's "Letter spacing"
    /// field. Negative values tighten spacing; positive values loosen it. Applied as
    /// trailing padding on each character slot so glyph shapes are never distorted.
    var letterSpacing: CGFloat = 0
    /// When false, digit transitions are suppressed and text updates in place.
    /// Always rendering SlotMachineText (rather than alternating with plain Text)
    /// keeps the view type stable so no layout shift occurs when toggling animation.
    var animated: Bool = true

    @State private var upward: Bool = true
    /// Line height measured from the live layout. Starts at 0 (= unconstrained) so
    /// the view uses its natural font height before the first measurement fires.
    /// This prevents a layout jump when the view first appears in a row.
    @State private var slotHeight: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { idx, ch in
                if ch.isNumber {
                    // Right-to-left cascade: rightmost digit fires first (delay 0),
                    // each position to the left adds a small additional delay.
                    let stagger = Double(text.count - 1 - idx) * 0.012
                    // Only enable slot-machine transitions once slotHeight is measured.
                    // Before measurement slotHeight=0 means no clip frame, which would
                    // allow both the entering and exiting digit to be fully visible at
                    // once — causing the garbled-numbers appearance on first scrub.
                    let canAnimate = animated && slotHeight > 0
                    ZStack {
                        Text(String(ch))
                            .font(font)
                            .foregroundStyle(color)
                            .monospacedDigit()
                            // When canAnimate: changing `.id` triggers remove/insert transitions.
                            // Otherwise: stable id keeps the text updating in place.
                            .id(canAnimate ? AnyHashable(ch) : AnyHashable("s\(idx)"))
                            .transition(
                                canAnimate
                                ? .asymmetric(
                                    insertion: .offset(y: upward ? -slotHeight :  slotHeight),
                                    removal:   .offset(y: upward ?  slotHeight : -slotHeight)
                                  )
                                : .identity
                            )
                    }
                    // Instant appear/disappear if text length changes between periods.
                    .transition(.identity)
                    // Only apply an explicit frame after the first measurement so the
                    // natural font height is used before slotHeight is known. This
                    // ensures the row height never jumps when the component first appears.
                    .frame(height: slotHeight > 0 ? slotHeight : nil)
                    .clipped()
                    // Trailing padding pulls the next character closer (negative) or
                    // farther (positive), matching Figma's "Letter spacing" field.
                    // Applied after clip so glyph shapes are never distorted.
                    .padding(.trailing, letterSpacing)
                    // When animating: delay inherited animation per digit for cascade.
                    // When not animating: kill any inherited animation so parent
                    // slide transitions (swipe pagination) cannot bleed into digit slots.
                    .transaction { t in
                        t.animation = canAnimate ? t.animation?.delay(stagger) : nil
                    }
                } else {
                    Text(String(ch))
                        .font(font)
                        .foregroundStyle(color)
                        .monospacedDigit()
                        .padding(.trailing, letterSpacing)
                }
            }
        }
        // When not in slot-machine mode, kill any inherited animation on the HStack
        // so the ForEach cannot reflow digits horizontally during swipe pagination.
        // This sits below the HStack itself (not inside it) so it only affects the
        // HStack's own layout animations — the parent container's slide transition
        // is set above this level and is unaffected.
        .transaction { t in
            if !animated { t.animation = nil }
        }
        // Measure the rendered line height by reading the HStack's height once.
        // The HStack is single-line text, so its height equals one digit's line height.
        // This drives both the clip frame and the transition travel distance.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { slotHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in slotHeight = h }
            }
        )
        // Detect direction within the same animation transaction so the correct
        // scroll direction is already set when transitions are committed.
        .onChange(of: value) { old, new in upward = new > old }
    }
}
