import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @Binding var showBalance: Bool

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
                + Text("$12,189.42")
                    .foregroundStyle(Color(red: 0, green: 106/255, blue: 1))
                + Text(" across all your accounts")
                    .foregroundStyle(Color(white: 0, opacity: 0.9))
            )
            .font(.heading30)
            .lineSpacing(7)
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
        HStack(alignment: .center) {
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
                    .font(.heading30)
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
    @State private var selectedPeriod = "12M"
    let periods = ["7D", "4W", "12M"]

    struct MonthBar: Identifiable {
        let id: Int
        let month: String
        let height: CGFloat // positive = profit (green), negative = loss (red)
    }

    let bars: [MonthBar] = [
        .init(id: 0,  month: "J", height:  60),
        .init(id: 1,  month: "F", height:  46),
        .init(id: 2,  month: "M", height:  27),
        .init(id: 3,  month: "A", height:  14),
        .init(id: 4,  month: "M", height: -19),
        .init(id: 5,  month: "J", height:   7),
        .init(id: 6,  month: "J", height:  17),
        .init(id: 7,  month: "A", height:  25),
        .init(id: 8,  month: "S", height:  33),
        .init(id: 9,  month: "O", height:  41),
        .init(id: 10, month: "N", height:  47),
        .init(id: 11, month: "D", height:  55),
    ]

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
                                .padding(.vertical, 3)
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
                    Text("$40,521.91")
                        .font(.display10)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))

                    Text("Net profit this year so far")
                        .font(.paragraph20)
                        .foregroundStyle(Color(white: 0, opacity: 0.55))
                }
                .padding(.top, 8)
                .padding(.bottom, 56)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(bars) { bar in
                            BarColumn(bar: bar)
                        }
                    }
                    .frame(height: 120)
                    .overlay(alignment: .top) {
                        Color(white: 0, opacity: 0.06)
                            .frame(height: 1)
                            .offset(y: 60)
                    }

                    HStack(spacing: 8) {
                        ForEach(bars) { bar in
                            Text(bar.month)
                                .font(.custom(AppFont.Text.regular, size: 10))
                                .foregroundStyle(Color(white: 0, opacity: 0.3))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private struct BarColumn: View {
        let bar: MonthBar

        private let baseline: CGFloat = 60
        private let green = Color(red: 0, green: 178/255, blue: 59/255)
        private let red   = Color(red: 204/255, green: 0, blue: 35/255)

        var body: some View {
            let isNegative = bar.height < 0
            let abs = abs(bar.height)

            VStack(spacing: 0) {
                Color.clear.frame(height: isNegative ? baseline : max(0, baseline - abs))

                if isNegative {
                    UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
                        .fill(red)
                        .frame(height: abs)
                } else {
                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                        .fill(green)
                        .frame(height: abs)
                }

                Color.clear.frame(height: isNegative ? max(0, baseline - abs) : baseline)
            }
            .frame(maxWidth: .infinity, maxHeight: 120)
        }
    }
}

// MARK: - Locations Card

private struct LocationsCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Text("Locations")
                    .font(.heading20)
                    .foregroundStyle(Color(white: 0, opacity: 0.9))
                    .padding(.bottom, 16)

                LauncherRow(title: "The ATM", subtitle: "Transferring today", amount: "$500.00")
                LauncherRow(title: "The Bank", subtitle: "Square Checking",   amount: "$2,102.98")
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
                    Text("Savings")
                        .font(.heading20)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))

                    Spacer()

                    Text("0.50% APY")
                        .font(.paragraphSemibold10)
                        .foregroundStyle(Color(red: 0, green: 106/255, blue: 1))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 229/255, green: 240/255, blue: 255/255))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 16)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Saved")
                            .font(.paragraphMedium30)
                            .foregroundStyle(Color(white: 0, opacity: 0.9))

                        Text("••• •071")
                            .font(.paragraph20)
                            .foregroundStyle(Color(white: 0, opacity: 0.55))
                            .tracking(1.4)
                    }

                    Spacer()

                    Text("$2,102.98")
                        .font(.heading30)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))
                }
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color(white: 0, opacity: 0.05))
                    .frame(height: 1)
                    .padding(.vertical, 8)

                VStack(spacing: 0) {
                    SavingsSubRow(label: "General Savings", amount: "$350.00")
                    SavingsSubRow(label: "Sales Tax",       amount: "$752.98")
                    SavingsSubRow(label: "Rainy Day",       amount: "$1,000.00")
                }
            }
            .padding(24)
        }
    }

    private struct SavingsSubRow: View {
        let label: String
        let amount: String

        var body: some View {
            HStack {
                Text(label)
                    .font(.paragraph30)
                    .foregroundStyle(Color(white: 0, opacity: 0.9))

                Spacer()

                Text(amount)
                    .font(.paragraphSemibold30)
                    .foregroundStyle(Color(white: 0, opacity: 0.9))
            }
            .frame(height: 32)
        }
    }
}

// MARK: - Credit Card Card

private struct CreditCardCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                // Figma: Square Sans Text Bold 18pt (not Display)
                Text("Credit Card")
                    .font(.custom(AppFont.Text.bold, size: 18))
                    .foregroundStyle(Color(white: 0, opacity: 0.9))
                    .padding(.bottom, 16)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total outstanding")
                            .font(.paragraphMedium30)
                            .foregroundStyle(Color(white: 0, opacity: 0.9))

                        Text("•••••• 60123")
                            .font(.paragraph20)
                            .foregroundStyle(Color(white: 0, opacity: 0.55))
                            .tracking(1.4)
                    }

                    Spacer()

                    Text("$1,047.94")
                        .font(.heading30)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))
                }
                .padding(.vertical, 12)

                HStack {
                    Text("Available credit")
                        .font(.paragraph30)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))

                    Spacer()

                    Text("$8,963.06")
                        .font(.paragraphMedium30)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))
                }
                .frame(height: 32)
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
                    Text("Loans")
                        .font(.heading20)
                        .foregroundStyle(Color(white: 0, opacity: 0.9))

                    Spacer()

                    Text("1 new offer!")
                        .font(.paragraphSemibold10)
                        .foregroundStyle(Color(red: 0, green: 106/255, blue: 1))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 229/255, green: 240/255, blue: 255/255))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hayes Valley")
                                .font(.paragraphMedium30)
                                .foregroundStyle(Color(white: 0, opacity: 0.9))

                            (
                                Text("$250,000")
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
                        subtitle: "$120.52 pending payment",
                        amount: "$6,129.17"
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    HomeView(showBalance: .constant(false))
}
