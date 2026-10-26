import SwiftUI

struct RecordHistoryCalendarSheet: View {
    let recordDates: Set<Date>
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var visibleMonth: Date
    @State private var selectedDate: Date

    init(selectedDate: Date, recordDates: Set<Date>, onSelect: @escaping (Date) -> Void) {
        self.recordDates = recordDates
        self.onSelect = onSelect
        _visibleMonth = State(initialValue: selectedDate)
        _selectedDate = State(initialValue: selectedDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(HGColor.homeTimelineBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("날짜 선택")
                .font(HGFont.bold(18, relativeTo: .headline))
                .foregroundStyle(HGColor.navigationTitle)
                .padding(.top, 12)

            monthNavigation
                .padding(.top, 16)

            weekdayHeader
                .padding(.top, 12)

            monthGrid
                .padding(.top, 6)

            legend
                .padding(.top, 14)

            HGPrimaryButton(title: selectedDateButtonTitle) {
                onSelect(selectedDate)
                dismiss()
            }
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HGColor.appBackground)
        .presentationDetents([.fraction(0.56)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }

    private var monthNavigation: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HGColor.primaryText)
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("이전 달")

            Spacer()

            Text(HGDateFormatting.string(from: visibleMonth, format: "yyyy년 M월"))
                .font(HGFont.bold(16, relativeTo: .headline))
                .foregroundStyle(HGColor.primaryText)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(canMoveToNextMonth ? HGColor.primaryText : HGColor.placeholder)
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canMoveToNextMonth)
            .accessibilityLabel("다음 달")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                Text(day)
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(index == weekdays.count - 1 ? HGColor.error : HGColor.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 1) {
            ForEach(Array(calendarCells.enumerated()), id: \.offset) { _, date in
                if let date {
                    calendarDay(date)
                } else {
                    Color.clear.frame(height: 42)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func calendarDay(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let future = isFuture(date)
        let weekday = calendar.component(.weekday, from: date)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text(HGDateFormatting.string(from: date, format: "d"))
                    .font(HGFont.medium(14, relativeTo: .subheadline))
                    .foregroundStyle(dayTextColor(selected: selected, future: future, weekday: weekday))
                    .frame(width: 34, height: 34)
                    .background(selected ? HGColor.primary : .clear, in: Circle())

                Circle()
                    .fill(HGColor.primary)
                    .frame(width: 4, height: 4)
                    .opacity(recordDates.contains(calendar.startOfDay(for: date)) ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel(HGDateFormatting.string(from: date, format: "M월 d일 E"))
        .accessibilityValue(selected ? "선택됨" : (recordDates.contains(calendar.startOfDay(for: date)) ? "기록 있음" : ""))
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(HGColor.primary)
                .frame(width: 4, height: 4)
            Text("기록이 있는 날 · 오늘 이후 날짜는 선택할 수 없어요")
                .font(HGFont.regular(11, relativeTo: .caption2))
                .foregroundStyle(HGColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var selectedDateButtonTitle: String {
        HGDateFormatting.string(from: selectedDate, format: "M월 d일 기록 보기")
    }

    private var weekdays: [String] {
        ["월", "화", "수", "목", "금", "토", "일"]
    }

    private var calendar: Calendar {
        var calendar = HGDateFormatting.calendar
        calendar.firstWeekday = 2
        return calendar
    }

    private var calendarCells: [Date?] {
        guard let month = calendar.dateInterval(of: .month, for: visibleMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: month.start) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: month.start)
        let leadingBlankCount = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingBlankCount)
        cells.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: month.start)
        })
        let trailingBlankCount = (7 - cells.count % 7) % 7
        cells.append(contentsOf: Array(repeating: nil, count: trailingBlankCount))
        return cells
    }

    private var canMoveToNextMonth: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: visibleMonth) else { return false }
        return !calendar.isDate(nextMonth, equalTo: .now, toGranularity: .month)
    }

    private func shiftMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        visibleMonth = nextMonth
    }

    private func isFuture(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: .now)
    }

    private func dayTextColor(selected: Bool, future: Bool, weekday: Int) -> Color {
        if selected { return .white }
        if future { return HGColor.placeholder }
        if weekday == 1 { return HGColor.error }
        return HGColor.primaryText
    }
}
