import SwiftUI

// MARK: - Content modifier (no-op, kept for call-site compatibility)

extension View {
    /// No-op shim — corner clipping is handled entirely by `.sheetPresentation()`.
    func sheetCornerMask(
        top:    CGFloat = 16,
        bottom: CGFloat = UIScreen.main.displayCornerRadius
    ) -> some View { self }
}

// MARK: - Presentation-site modifier

extension View {
    /// Sets a uniform 16 pt corner radius on the sheet via the standard
    /// `presentationCornerRadius` API and suppresses iOS 26 Liquid Glass with
    /// a solid white `presentationBackground`.
    ///
    /// On iOS 26 the glass layer is composited above the `presentationBackground`,
    /// so any transparent zones in the background reveal the glass.  Using a
    /// fully-opaque solid background eliminates glass while `presentationCornerRadius(16)`
    /// gives the desired 16 pt top corners.  Bottom corners are also 16 pt —
    /// on a compact (non-full-height) sheet they sit in the middle of the screen
    /// and do not conflict with the device's chrome radius.
    func sheetPresentation(
        top:    CGFloat = 16,
        bottom: CGFloat = UIScreen.main.displayCornerRadius
    ) -> some View {
        self
            .presentationCornerRadius(top)
            .presentationBackground(Color.white)
    }
}
