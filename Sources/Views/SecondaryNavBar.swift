import SwiftUI

// MARK: - Secondary Nav Bar

/// Figma "⭐️ Secondary nav" (2336:33900).
/// Left: NavBack in gray7 Capsule pill (12pt inset). Center: bold title + optional
/// blue subtitle row. Right: NavDownload in gray7 Capsule pill (12pt inset).
/// Both pills total 48×48pt (24pt icon + 12pt padding each side).
struct SecondaryNavBar: View {
    let title: String
    let onBack: () -> Void
    var onDownload: (() -> Void)? = nil
    /// Optional subtitle shown below the title in the center.
    /// E.g. "2024 • All locations" for the P&L page.
    var centerSubtitle: String? = nil
    var isScrolled: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left pill — back arrow
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
            .background(Color.gray7, in: Capsule())

            Spacer()

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
            .background(Color.gray7, in: Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .overlay {
            // Center: title + optional subtitle stacked
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
        .background(Color.white)
        .overlay(alignment: .bottom) {
            if isScrolled {
                Rectangle()
                    .fill(Color.gray5)
                    .frame(height: 1)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isScrolled)
    }
}

#if DEBUG
#Preview("SecondaryNavBar") {
    VStack(spacing: 24) {
        SecondaryNavBar(title: "Profit & Loss", onBack: {},
                        centerSubtitle: "2024 • All locations")
        SecondaryNavBar(title: "Details", onBack: {}, isScrolled: true)
    }
    .padding(.top)
}
#endif
