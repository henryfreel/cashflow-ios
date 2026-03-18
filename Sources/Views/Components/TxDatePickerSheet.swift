import SwiftUI

// MARK: - Date Picker Sheet

struct TxDatePickerSheet: View {
    let initialStart:    Date?
    let initialEnd:      Date?
    let onCommit:        (Date?, Date?) -> Void
    let onDone:          () -> Void
    /// When set, renders a back-button header (drill-down from All Filters).
    /// Tapping back pops without committing.
    var onBack:         (() -> Void)?        = nil
    /// Called whenever the displayed month changes so the host can resize the sheet.
    var onHeightChange: ((CGFloat) -> Void)? = nil

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
         onDone: @escaping () -> Void,
         onBack: (() -> Void)? = nil,
         onHeightChange: ((CGFloat) -> Void)? = nil) {
        self.initialStart    = initialStart
        self.initialEnd      = initialEnd
        self.onCommit        = onCommit
        self.onDone          = onDone
        self.onBack          = onBack
        self.onHeightChange  = onHeightChange
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
            if let onBack {
                backButtonHeader(onBack: onBack)
            } else {
                headerView
            }

            VStack(alignment: .leading, spacing: 23) {
                monthNavRow
                    // Only suppress animation driven by displayMonth changes so the
                    // title snaps instantly on navigation — the sheet's own spring
                    // presentation animation is driven by a different value and
                    // will still play correctly on device.
                    .animation(nil, value: displayMonth)

                VStack(alignment: .leading, spacing: 16) {
                    dayOfWeekRow
                    weekRowsView
                }
                .clipped()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 23)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .onChange(of: displayMonth) { _, newMonth in
            // Update height instantly (no animation) so the sheet's top edge doesn't
            // slide and carry monthNavRow with it. The grid slide captures all
            // the attention; the height snap is imperceptible.
            onHeightChange?(TxDatePickerSheet.compactHeight(for: newMonth))
        }
    }

    // MARK: - Headers

    /// Standard standalone header: left-aligned title + Done on the right.
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
        .padding(.bottom, 24)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.gray5)
                .frame(height: 1)
        }
    }

    /// Drill-down header (from Custom date): back button on left + Done on right, no title.
    /// Total height matches headerView (48pt HStack + 24pt bottom pad) so
    /// compactHeight calculations remain accurate.
    private func backButtonHeader(onBack: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image("NavBack")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Color.gray1)
                    .frame(width: 24, height: 24)
                    .padding(12)
                    .background(Color.gray6)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

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
        .padding(.bottom, 24)
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
                    Image("CalNavArrow")
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
                    Image("CalNavArrow")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .rotationEffect(.degrees(180))
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

// MARK: - Date Preset

enum DatePreset: String, CaseIterable, Identifiable {
    case today        = "Today"
    case thisWeek     = "This week"
    case thisMonth    = "This month"
    case thisQuarter  = "This quarter"
    case thisYear     = "This year"

    var id: String { rawValue }

    private static var appToday: Date {
        Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 15))!
    }

    var dateRange: (start: Date, end: Date) {
        let cal   = Calendar.current
        let today = Self.appToday
        let start = cal.startOfDay(for: today)
        switch self {
        case .today:
            return (start, start)
        case .thisWeek:
            let weekday = cal.component(.weekday, from: today) // 1=Sun
            let daysBack = (weekday == 1) ? 6 : weekday - 2
            let monday = cal.date(byAdding: .day, value: -daysBack, to: start)!
            return (monday, start)
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: today)
            let first = cal.date(from: comps)!
            return (first, start)
        case .thisQuarter:
            let month      = cal.component(.month, from: today)
            let year       = cal.component(.year,  from: today)
            let qStartMonth = ((month - 1) / 3) * 3 + 1
            let first      = cal.date(from: DateComponents(year: year, month: qStartMonth, day: 1))!
            return (first, start)
        case .thisYear:
            let year  = cal.component(.year, from: today)
            let first = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
            return (first, start)
        }
    }

    func matches(start: Date?, end: Date?) -> Bool {
        guard let start, let end else { return false }
        let cal  = Calendar.current
        let (s, e) = dateRange
        return cal.isDate(start, inSameDayAs: s) && cal.isDate(end, inSameDayAs: e)
    }
}

// MARK: - Date Sheet
//
// Level 1 when opened from the date chip; Level 2 when drilled into from All Filters.
// Presents four quick-select radio presets plus a "Custom date" row that pushes the
// full calendar picker as an overlay — the same push/pop pattern used in TxAllFiltersSheet.

struct TxDateSheet: View {
    let initialStart:   Date?
    let initialEnd:     Date?
    let onCommit:       (Date?, Date?) -> Void
    let onDone:         () -> Void
    /// When set, renders a back-button header (drill-down from All Filters).
    var onBack:         (() -> Void)?        = nil
    var onHeightChange: ((CGFloat) -> Void)? = nil

    /// Height = sheet-top(24) + header(48) + VStack-gap(16) + 6 rows × 56 + bottom-pad(64)
    static let compactHeight: CGFloat = 488

    @State private var selectedPreset:  DatePreset?
    @State private var customStart:     Date?
    @State private var customEnd:       Date?
    @State private var showCustomPicker: Bool = false

    init(initialStart: Date?, initialEnd: Date?,
         onCommit: @escaping (Date?, Date?) -> Void,
         onDone: @escaping () -> Void,
         onBack: (() -> Void)? = nil,
         onHeightChange: ((CGFloat) -> Void)? = nil) {
        self.initialStart   = initialStart
        self.initialEnd     = initialEnd
        self.onCommit       = onCommit
        self.onDone         = onDone
        self.onBack         = onBack
        self.onHeightChange = onHeightChange
        let matched = DatePreset.allCases.first { $0.matches(start: initialStart, end: initialEnd) }
        _selectedPreset = State(initialValue: matched)
        if matched == nil {
            _customStart = State(initialValue: initialStart)
            _customEnd   = State(initialValue: initialEnd)
        }
    }

    // The range that will be committed when the Done button on the preset list is tapped.
    private var stagedRange: (Date?, Date?) {
        if let p = selectedPreset { return p.dateRange }
        return (customStart, customEnd)
    }

    // MARK: - Body

    var body: some View {
        presetListView
            .allowsHitTesting(!showCustomPicker)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            if showCustomPicker {
                Color.black.opacity(0.18)
                    .padding(.top, -24)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if showCustomPicker {
                ZStack(alignment: .top) {
                    Color.white.padding(.top, -24)
                    TxDatePickerSheet(
                        initialStart: customStart,
                        initialEnd:   customEnd,
                        onCommit: { start, end in
                            customStart    = start
                            customEnd      = end
                            selectedPreset = nil
                            onCommit(start, end)
                        },
                        onDone: { onDone() },
                        onBack: {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                                showCustomPicker = false
                                onHeightChange?(TxDateSheet.compactHeight)
                            }
                        },
                        onHeightChange: { h in onHeightChange?(h) }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing))
            }
        }
    }

    // MARK: - Preset list

    @ViewBuilder
    private var presetListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            VStack(spacing: 0) {
                ForEach(DatePreset.allCases) { preset in
                    DatePresetRow(label: preset.rawValue,
                                  isSelected: selectedPreset == preset) {
                        selectedPreset = (selectedPreset == preset) ? nil : preset
                    }
                }
                CustomDatePresetRow(onTap: pushCustomPicker)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 64)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        if let onBack {
            HStack(spacing: 0) {
                Button(action: onBack) {
                    Image("NavBack")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(Color.gray1)
                        .frame(width: 24, height: 24)
                        .padding(12)
                        .background(Color.gray6)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("Date")
                    .font(.heading20)
                    .foregroundStyle(Color.black.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    let (s, e) = stagedRange
                    onCommit(s, e)
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
            .frame(height: 48)
        } else {
            HStack(spacing: 10) {
                Text("Date")
                    .font(.heading30)
                    .foregroundStyle(Color.gray1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    let (s, e) = stagedRange
                    onCommit(s, e)
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
            .frame(height: 48)
        }
    }

    // MARK: - Navigation

    private func pushCustomPicker() {
        let cal      = Calendar.current
        let appMax   = cal.date(from: DateComponents(year: 2024, month: 12, day: 1))!
        let rawRef   = customStart ?? appMax
        let rawMonth = cal.date(from: cal.dateComponents([.year, .month], from: rawRef))!
        let month    = rawMonth > appMax ? appMax : rawMonth
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            showCustomPicker = true
            onHeightChange?(TxDatePickerSheet.compactHeight(for: month))
        }
    }
}

// MARK: - Preset row (radio button)

private struct DatePresetRow: View {
    let label:      String
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(label)
                    .font(.paragraphMedium30)
                    .foregroundStyle(Color.gray1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TxRadioButton(isSelected: isSelected)
            }
            .frame(height: 56)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Color.black.opacity(0.05).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom date row (chevron)

private struct CustomDatePresetRow: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text("Custom date")
                    .font(.paragraphMedium30)
                    .foregroundStyle(Color.gray1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("SheetRowChevron")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(Color.gray4)
                    .frame(width: 24, height: 24)
            }
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Radio button

private struct TxRadioButton: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? Color.gray1 : Color.gray1.opacity(0.30),
                    lineWidth: 2
                )
            if isSelected {
                Circle()
                    .fill(Color.gray1)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - Height helpers (used by TransactionsView and month navigation)

extension TxDatePickerSheet {
    /// Number of week rows needed to display `month`.
    static func weekCount(for month: Date) -> Int {
        let cal      = Calendar.current
        let comps    = cal.dateComponents([.year, .month], from: month)
        let firstDay = cal.date(from: comps)!
        let dayCount = cal.range(of: .day, in: .month, for: firstDay)!.count
        let offset   = (cal.component(.weekday, from: firstDay) - 1 + 7) % 7
        return Int(ceil(Double(dayCount + offset) / 7.0))
    }

    /// Sheet height sized precisely for the given month's week count.
    static func compactHeight(for month: Date) -> CGFloat {
        let weeks: CGFloat         = CGFloat(weekCount(for: month))
        let sheetTopInset: CGFloat = 24  // CustomBottomSheet .padding(.top, 24)
        let header: CGFloat        = 72  // HStack(48) + .padding(.bottom, 24)
        let calTopPad: CGFloat     = 23
        let monthNav: CGFloat      = 40
        let gap1: CGFloat          = 23
        let dow: CGFloat           = 24
        let gap2: CGFloat          = 16
        let grid: CGFloat          = weeks * 40 + max(0, weeks - 1) * 8
        let calBottomPad: CGFloat  = 23
        let bottom: CGFloat        = 32
        return sheetTopInset + header + calTopPad + monthNav + gap1 + dow + gap2 + grid + calBottomPad + bottom
    }

    /// Convenience: height for the app's default opening month (December 2024).
    static var compactHeight: CGFloat {
        let dec2024 = Calendar.current.date(
            from: DateComponents(year: 2024, month: 12, day: 1))!
        return compactHeight(for: dec2024)
    }
}
