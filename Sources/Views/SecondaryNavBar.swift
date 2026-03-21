import SwiftUI

// MARK: - Secondary Nav Bar

/// Figma "⭐️ Secondary nav" (2336:33900).
/// Left: NavBack in gray7 Capsule pill (12pt inset). Center: bold title + optional
/// blue subtitle row. Right: NavDownload in gray7 Capsule pill (12pt inset).
/// Both pills total 48×48pt (24pt icon + 12pt padding each side).
struct SecondaryNavBar: View {
    let title: String
    var onBack: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    /// Optional subtitle shown below the title in the center.
    /// E.g. "2024 • All locations" for the P&L page.
    var centerSubtitle: String? = nil
    /// When true, renders the title left-aligned at the leading edge instead of
    /// centered via overlay. Use for top-level pages that have no back button.
    var leftAlignTitle: Bool = false
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if leftAlignTitle {
                // Title flows left-to-right from the leading padding edge,
                // filling all space before the download pill.
                Text(title)
                    .font(Font.custom(AppFont.Display.bold, size: 24))
                    .foregroundStyle(Color.gray1)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            } else {
                // Left pill — back arrow (hidden when onBack is nil)
                if let onBack {
                    Button(action: onBack) {
                        Image("NavBack")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color.gray1)
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .background(Color.gray6, in: Capsule())
                } else {
                    Color.clear
                        .frame(width: 48, height: 48)
                }

                Spacer()
            }

            // Right pill — download icon
            Button { onDownload?() } label: {
                Image("NavDownload")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.gray1)
            }
            .buttonStyle(.plain)
            .padding(12)
            .background(Color.gray6, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .overlay {
            // Centered title overlay — only for the standard (non-left-aligned) layout
            if !leftAlignTitle {
                VStack(spacing: 0) {
                    Text(title)
                        .font(.heading20)
                        .foregroundStyle(Color.gray1)
                        .frame(height: 26, alignment: .center)

                    if let sub = centerSubtitle {
                        HStack(spacing: 2) {
                            Text(sub)
                                .font(.paragraphSemibold20)
                                .foregroundStyle(Color.blue3)
                                .frame(height: 22, alignment: .center)
                            Image("AllLocationsChevron")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(Color.blue3)
                        }
                    }
                }
            }
        }
        .background(Color.white)
    }
}

#if DEBUG
#Preview("SecondaryNavBar") {
    VStack(spacing: 24) {
        SecondaryNavBar(title: "Profit & Loss", onBack: {},
                        centerSubtitle: "2024 • All locations")
        SecondaryNavBar(title: "Details", onBack: {})
    }
    .padding(.top)
}
#endif
