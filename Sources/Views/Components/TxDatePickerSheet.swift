import SwiftUI

// MARK: - Date Picker Sheet

struct TxDatePickerSheet: View {
    let initialStart: Date?
    let initialEnd:   Date?
    let onCommit: (Date?, Date?) -> Void
    let onDone:   () -> Void

    @State private var displayMonth: Date
    @State private var rangeStart:   Date?
    @State private var rangeEnd:     Date?
    @State private var slideDir:     Int = 0   // -1 prev, +1 next (for transitions)

    private let cal = Calendar.current

    /// The latest date the app has data for. Treat this as "today" throughout
    /// the picker so future days (Dec 16+ and any month after Dec 2024) are
    /// disabled and the forward chevron is locked at this month.
    private var today: Date {
        cal.date(from: DateComponents(year: 2024, month: 12, day: 15))!
    }

    private var minDate: Date {
        cal.date(from: DateComponents(year: 2023, month: 1, day: 1))!
    }

    init(initialStart: Date?, initialEnd: Date?,
         onCommit: @escaping (Date?, Date?) -> Void,
         onDone: @escaping () -> Void) {
        self.initialStart = initialStart
        self.initialEnd   = initialEnd
        self.onCommit     = onCommit
        self.onDone       = onDone
        let c       = Calendar.current
        let appMax  = c.date(from: DateComponents(year: 2024, month: 12, day: 1))!
        let rawRef  = initialStart ?? appMax
        let rawMonth = c.date(from: c.dateComponents([.year, .month], from: rawRef))!
        // Never open in a month beyond the app's data horizon
        let clampedMonth = rawMonth > appMax ? appMax : rawMonth
        _displayMonth = State(initialValue: clampedMonth)
        let horizon   = c.date(from: DateComponents(year: 2024, month: 12, day: 15))!
        _rangeStart   = State(initialValue: initialStart.map { c.startOfDay(for: $0) })
        _rangeEnd     = State(initialValue: initialEnd.map   { min(c.startOfDay(for: $0), horizon) })
    }

    // MARK: - Computed

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: displayMonth)
    }

    private var canGoPrev: Bool {
        cal.compare(displayMonth, to: minDate, toGranularity: .month) == .orderedDescending
    }

    private var canGoNext: Bool {
        let cur = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        return cal.compare(displayMonth, to: cur, toGranularity: .month) == .orderedAscending
    }

    /// 2-D array of optional Dates — nil for padding cells before/after month.
    private var weeksGrid: [[Date?]] {
        let comps     = cal.dateComponents([.year, .month], from: displayMonth)
        let firstDay  = cal.date(from: comps)!
        let dayCount  = cal.range(of: .day, in: .month, for: firstDay)!.count
        let weekdayOffset = (cal.component(.weekday, from: firstDay) - 1 + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: weekdayOffset)
        for d in 1...dayCount {
            var c = comps; c.day = d
            days.append(cal.date(from: c))
        }
        while days.count % 7 != 0 { days.append(nil) }

        var weeks: [[Date?]] = []
        var i = 0
        while i < days.count {
            weeks.append(Array(days[i..<min(i + 7, days.count)]))
            i += 7
        }
        return weeks
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerView

            VStack(alignment: .leading, spacing: 23) {
                monthNavRow

                VStack(alignment: .leading, spacing: 16) {
                    dayOfWeekRow
                    weekRowsView
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 23)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .sheetCornerMask()
    }

    // MARK: - Header (persistent border)

    private var headerView: some View {
        HStack(spacing: 10) {
            Text("Date")
                .font(.heading30)
                .foregroundStyle(Color.gray1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onCommit(rangeStart, rangeEnd)
                onDone()
            } label: {
                Text("Done")
                    .font(.paragraphSemibold30)
                    .foregroundStyle(Color.white)
                    .frame(height: 48)
                    .padding(.horizontal, 22)
                    .background(Color.gray1)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.gray5)
                .frame(height: 1)
        }
    }

    // MARK: - Month Nav Row

    private var monthNavRow: some View {
        HStack(spacing: 10) {
            Text(monthLabel)
                .font(.heading20)
                .foregroundStyle(Color.gray1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button(action: prevMonth) {
                    Image("YearNavLeft")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(canGoPrev ? Color.gray1 : Color.gray4)
                        .padding(8)
                        .background(Color.gray6, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canGoPrev)

                Button(action: nextMonth) {
                    Image("YearNavRight")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(canGoNext ? Color.gray1 : Color.gray4)
                        .padding(8)
                        .background(Color.gray6, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canGoNext)
            }
        }
        .frame(height: 40)
    }

    // MARK: - Day-of-week header

    private var dayOfWeekRow: some View {
        HStack(spacing: 0) {
            ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"], id: \.self) { d in
                Text(d)
                    .font(.paragraph30)
                    .foregroundStyle(Color.gray3)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 24)
    }

    // MARK: - Week rows

    private var weekRowsView: some View {
        let grid = weeksGrid
        return VStack(spacing: 8) {
            ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        if let date = week[col] {
                            CalendarDayCell(
                                date:       date,
                                today:      today,
                                rangeStart: rangeStart,
                                rangeEnd:   rangeEnd,
                                isDisabled: isDisabled(date)
                            ) { handleTap(date) }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                    }
                }
            }
        }
        .id(displayMonth)
        .transition(
            .asymmetric(
                insertion: .move(edge: slideDir >= 0 ? .trailing : .leading),
                removal:   .move(edge: slideDir >= 0 ? .leading  : .trailing)
            )
        )
    }

    // MARK: - Actions

    private func prevMonth() {
        guard canGoPrev,
              let prev = cal.date(byAdding: .month, value: -1, to: displayMonth)
        else { return }
        slideDir = -1
        withAnimation(.easeInOut(duration: 0.25)) { displayMonth = prev }
    }

    private func nextMonth() {
        guard canGoNext,
              let next = cal.date(byAdding: .month, value: 1, to: displayMonth)
        else { return }
        slideDir = 1
        withAnimation(.easeInOut(duration: 0.25)) { displayMonth = next }
    }

    private func isDisabled(_ date: Date) -> Bool {
        let d = cal.startOfDay(for: date)
        return d > today || d < minDate
    }

    private func handleTap(_ date: Date) {
        let d = cal.startOfDay(for: date)
        if rangeStart == nil || (rangeStart != nil && rangeEnd != nil) {
            // Start fresh
            rangeStart = d; rangeEnd = nil
        } else if let s = rangeStart {
            if d < s {
                // Tapped before current start — reset with new start
                rangeStart = d; rangeEnd = nil
            } else if cal.isDate(d, inSameDayAs: s) {
                // Tapped same day — deselect
                rangeStart = nil; rangeEnd = nil
            } else {
                rangeEnd = min(d, today)
            }
        }
    }
}

// MARK: - Day Cell

struct CalendarDayCell: View {
    let date:       Date
    let today:      Date
    let rangeStart: Date?
    let rangeEnd:   Date?
    let isDisabled: Bool
    let onTap:      () -> Void

    private let cal = Calendar.current

    private var isToday:      Bool { cal.isDate(date, inSameDayAs: today) }
    private var isRangeStart: Bool { rangeStart.map { cal.isDate(date, inSameDayAs: $0) } ?? false }
    private var isRangeEnd:   Bool { rangeEnd.map   { cal.isDate(date, inSameDayAs: $0) } ?? false }
    private var isSelected:   Bool { isRangeStart || isRangeEnd }

    private var isInRange: Bool {
        guard let s = rangeStart, let e = rangeEnd else { return false }
        let d = cal.startOfDay(for: date)
        return d > s && d < e
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // ── Gray range band ───────────────────────────────────────────
                if isRangeStart && rangeEnd != nil {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 100, bottomLeadingRadius: 100,
                        bottomTrailingRadius: 0, topTrailingRadius: 0
                    )
                    .fill(Color.gray6)
                } else if isRangeEnd {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 100, topTrailingRadius: 100
                    )
                    .fill(Color.gray6)
                } else if isInRange {
                    Rectangle()
                        .fill(Color.gray6)
                }

                // ── Selection fill ────────────────────────────────────────────
                if isSelected {
                    Capsule().fill(Color.gray1)
                }

                // ── Today border (when not selected) ─────────────────────────
                if isToday && !isSelected {
                    Capsule()
                        .strokeBorder(Color.gray1, lineWidth: 1)
                }

                // ── Day number ────────────────────────────────────────────────
                Text("\(cal.component(.day, from: date))")
                    .font(.paragraph30)
                    .foregroundStyle(
                        isDisabled  ? Color.gray3  :
                        isSelected  ? Color.white  :
                        Color.gray1
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Height helper (used by TransactionsView)

extension TxDatePickerSheet {
    /// Fixed compact-detent height tall enough for any month (6-row grid).
    static var compactHeight: CGFloat {
        let header: CGFloat  = 97
        let topPad: CGFloat  = 23
        let monthNav: CGFloat = 40
        let gap1: CGFloat    = 23
        let dow: CGFloat     = 24
        let gap2: CGFloat    = 16
        let grid: CGFloat    = CGFloat(6 * 40 + 5 * 8)
        let bottom: CGFloat  = 32
        return header + topPad + monthNav + gap1 + dow + gap2 + grid + bottom
    }
}
