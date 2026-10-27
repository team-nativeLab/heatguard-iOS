import SwiftUI

struct RecordHistoryView: View {
    let onRecordSelected: (HGRecordHistoryItem) -> Void
    let onCreateRecord: () -> Void

    @State private var records: [HGRecordHistoryItem] = []
    @State private var knownRecordDates: Set<Date> = []
    @State private var isLoading = true
    @State private var isRefreshingDate = false
    @State private var isLoadingMore = false
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var failedToLoadMore = false
    @State private var error: HGErrorPresentation?
    @State private var selectedFilter: RecordFilter = .all
    @State private var selectedPeriodEnd = Date.now
    @State private var showsPeriodPicker = false
    @State private var recordsRequestID = UUID()

    init(onRecordSelected: @escaping (HGRecordHistoryItem) -> Void = { _ in }, onCreateRecord: @escaping () -> Void = {}) {
        self.onRecordSelected = onRecordSelected
        self.onCreateRecord = onCreateRecord
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer(); ProgressView(); Spacer()
            } else {
                List {
                    VStack(spacing: 0) {
                        periodSelector
                        filterSelector.padding(.top, 14)
                        if !filteredRecords.isEmpty {
                            summaryCard.padding(.top, 14)
                        }
                        historyContent.padding(.top, filteredRecords.isEmpty ? 14 : 20)
                        if hasMore {
                            Button {
                                Task { await loadMoreRecords() }
                            } label: {
                                HStack(spacing: 8) {
                                    if isLoadingMore { ProgressView() }
                                    Text(isLoadingMore ? "불러오는 중..." : "더 보기")
                                }
                                .font(HGFont.medium(13, relativeTo: .subheadline))
                                .foregroundStyle(HGColor.primary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .disabled(isLoadingMore)
                            .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(HGColor.appBackground)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(HGColor.appBackground)
        .hgNavigationTitle("기록 내역")
        .safeAreaInset(edge: .bottom) {
            if !isLoading && !isRefreshingDate && filteredRecords.isEmpty {
                HGPrimaryButton(title: "기록하기", action: onCreateRecord)
                    .padding(.horizontal, 28).padding(.vertical, 10)
                    .background(HGColor.appBackground)
            }
        }
        .task { await loadRecords(for: selectedPeriodEnd) }
        .onChange(of: selectedPeriodEnd) { _, date in
            Task { await loadRecords(for: date) }
        }
        .sheet(isPresented: $showsPeriodPicker) {
            RecordHistoryCalendarSheet(selectedDate: selectedPeriodEnd, recordDates: recordDates) { date in
                selectedPeriodEnd = date
            }
        }
        .alert(error?.title ?? "기록 조회 오류", isPresented: errorAlert) {
            Button("다시 시도") {
                Task {
                    if failedToLoadMore { await loadMoreRecords() } else { await loadRecords(for: selectedPeriodEnd) }
                }
            }
            Button("확인", role: .cancel) {}
        } message: { Text(error?.alertMessage ?? "") }
    }

    private var periodSelector: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Button { showsPeriodPicker = true } label: {
                    HStack(spacing: 4) {
                        Text(selectedMonthTitle)
                            .font(HGFont.bold(16, relativeTo: .headline))
                            .foregroundStyle(HGColor.primaryText)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HGColor.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(selectedMonthTitle) 달력 열기")

                Spacer(minLength: 4)

                Button("오늘") {
                    selectedPeriodEnd = .now
                }
                .font(HGFont.medium(12, relativeTo: .caption))
                .foregroundStyle(HGColor.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(HGColor.homeMetricIconBackground, in: Capsule())
                .accessibilityHint("오늘 날짜를 선택합니다")
            }

            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    Button {
                        selectedPeriodEnd = date
                    } label: {
                        VStack(spacing: 4) {
                            Text(HGDateFormatting.string(from: date, format: "E"))
                                .font(HGFont.regular(11, relativeTo: .caption2))
                                .foregroundStyle(dateTextColor(for: date, isWeekday: true))
                            Text(HGDateFormatting.string(from: date, format: "d"))
                                .font(HGFont.medium(16, relativeTo: .body))
                                .foregroundStyle(dateTextColor(for: date, isWeekday: false))
                            Circle()
                                .fill(isSelected(date) ? .white : HGColor.primary)
                                .frame(width: 4, height: 4)
                                .opacity(hasRecord(on: date) ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(isSelected(date) ? HGColor.primary : .clear, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture(date))
                    .accessibilityLabel(HGDateFormatting.string(from: date, format: "M월 d일 E"))
                    .accessibilityValue(isSelected(date) ? "선택됨" : (hasRecord(on: date) ? "기록 있음" : ""))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var filterSelector: some View {
        HStack(spacing: 8) {
            ForEach(RecordFilter.allCases) { filter in
                Button { selectedFilter = filter } label: {
                    Text(filter.title)
                        .font(HGFont.medium(13, relativeTo: .caption))
                        .foregroundStyle(selectedFilter == filter ? .white : HGColor.secondaryText)
                        .padding(.horizontal, 15).frame(height: 32)
                        .background(selectedFilter == filter ? HGColor.primary : HGColor.surface, in: Capsule())
                }.buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                RecordCountMetric(title: hasMore ? "불러온 기록" : "전체", count: periodRecords.count)
                Divider().frame(height: 28)
                RecordCountMetric(title: "온도계", count: periodRecords.count(where: { $0.type == .thermometer }))
                Divider().frame(height: 28)
                RecordCountMetric(title: "작업 사진", count: periodRecords.count(where: { $0.type == .work }))
                Divider().frame(height: 28)
                RecordCountMetric(title: "휴식 사진", count: periodRecords.count(where: { $0.type == .rest }))
            }
            if hasMore {
                Text("현재 불러온 기록 기준")
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
            }
        }
        .padding(.vertical, 16)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var historyContent: some View {
        if isRefreshingDate {
            ProgressView("선택한 날짜 기록을 불러오는 중")
                .frame(maxWidth: .infinity, minHeight: 247)
        } else if filteredRecords.isEmpty {
            VStack(spacing: 10) {
                Image("RecordPhotoPlaceholder")
                    .resizable().frame(width: 36, height: 36)
                    .frame(width: 72, height: 72).background(HGColor.homeMetricIconBackground, in: Circle())
                Text(hasMore ? "불러온 기록 중 해당 항목이 없어요" : emptyMessage)
                    .font(HGFont.bold(16, relativeTo: .subheadline)).foregroundStyle(HGColor.primaryText)
                Text(hasMore ? "더 보기를 눌러 이전 기록을 확인해 보세요" : "기간이나 유형을 바꾸거나 새 기록을 남겨보세요")
                    .font(HGFont.regular(13, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
            }.frame(maxWidth: .infinity, minHeight: 247)
        } else {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(recordGroups, id: \.date) { group in
                    Text(group.label)
                        .font(HGFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                    VStack(spacing: 0) {
                        ForEach(group.items) { record in
                            Button { onRecordSelected(record) } label: { RecordHistoryRow(record: record) }.buttonStyle(.plain)
                            if record.id != group.items.last?.id { Divider() }
                        }
                    }
                    .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var recordGroups: [RecordDayGroup] {
        let calendar = HGDateFormatting.calendar
        let grouped = Dictionary(grouping: filteredRecords) { record in
            record.measuredAt.hgISO8601Date.map(calendar.startOfDay(for:)) ?? .distantPast
        }
        return grouped.keys.sorted(by: >).map { date in
            let prefix: String
            if calendar.isDateInToday(date) {
                prefix = "오늘 · "
            } else if calendar.isDateInYesterday(date) {
                prefix = "어제 · "
            } else {
                prefix = ""
            }
            let formatter = DateFormatter()
            formatter.locale = HGDateFormatting.locale
            formatter.timeZone = HGDateFormatting.timeZone
            formatter.dateFormat = "M월 d일 (E)"
            let items = grouped[date] ?? []
            return RecordDayGroup(
                date: date,
                label: date == .distantPast ? "날짜 정보 없음" : "\(prefix)\(formatter.string(from: date)) · 기록 \(items.count)건",
                items: items
            )
        }
    }

    private var emptyMessage: String {
        selectedFilter == .all ? "선택한 날짜에 기록이 없어요" : "선택한 날짜에 \(selectedFilter.emptyDescription) 기록이 없어요"
    }

    private var filteredRecords: [HGRecordHistoryItem] {
        periodRecords.filter { selectedFilter.matches($0.type) }
    }

    private var periodRecords: [HGRecordHistoryItem] {
        return records.filter { record in
            guard let measuredAt = record.measuredAt.hgISO8601Date else { return false }
            return historyCalendar.isDate(measuredAt, inSameDayAs: selectedPeriodEnd)
        }
    }

    private var selectedMonthTitle: String {
        HGDateFormatting.string(from: selectedPeriodEnd, format: "yyyy년 M월")
    }

    private var historyCalendar: Calendar {
        var calendar = HGDateFormatting.calendar
        calendar.firstWeekday = 2
        return calendar
    }

    private var recordDates: Set<Date> {
        knownRecordDates
    }

    private var weekDates: [Date] {
        guard let interval = historyCalendar.dateInterval(of: .weekOfYear, for: selectedPeriodEnd) else {
            return []
        }
        return (0..<7).compactMap { historyCalendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private func isSelected(_ date: Date) -> Bool {
        historyCalendar.isDate(date, inSameDayAs: selectedPeriodEnd)
    }

    private func isFuture(_ date: Date) -> Bool {
        historyCalendar.startOfDay(for: date) > historyCalendar.startOfDay(for: .now)
    }

    private func hasRecord(on date: Date) -> Bool {
        knownRecordDates.contains(historyCalendar.startOfDay(for: date))
    }

    private func dateTextColor(for date: Date, isWeekday: Bool) -> Color {
        if isSelected(date) { return .white }
        if isFuture(date) { return HGColor.placeholder }
        if isWeekday && historyCalendar.component(.weekday, from: date) == 1 { return HGColor.error }
        return isWeekday ? HGColor.secondaryText : HGColor.primaryText
    }

    @MainActor private func loadRecords(for date: Date) async {
        let requestID = UUID()
        recordsRequestID = requestID
        let isInitialLoad = isLoading
        failedToLoadMore = false
        isLoadingMore = false
        if isInitialLoad { isLoading = true } else { isRefreshingDate = true }
        defer {
            if recordsRequestID == requestID {
                isLoading = false
                isRefreshingDate = false
            }
        }
        do {
            let page = try await HGRecordHistoryService().fetchRecords(date: date)
            guard recordsRequestID == requestID else { return }
            records = page.items
            rememberRecordDates(page.items)
            nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            error = nil
        } catch {
            guard recordsRequestID == requestID else { return }
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor private func loadMoreRecords() async {
        guard !isLoadingMore, hasMore, let nextCursor else { return }
        let requestID = recordsRequestID
        let selectedDate = selectedPeriodEnd
        isLoadingMore = true
        defer {
            if recordsRequestID == requestID { isLoadingMore = false }
        }
        do {
            let page = try await HGRecordHistoryService().fetchRecords(cursor: nextCursor, date: selectedDate)
            guard recordsRequestID == requestID else { return }
            let existingIDs = Set(records.map(\.recordID))
            let newItems = page.items.filter { !existingIDs.contains($0.recordID) }
            records.append(contentsOf: newItems)
            rememberRecordDates(newItems)
            self.nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            failedToLoadMore = false
            error = nil
        } catch {
            guard recordsRequestID == requestID else { return }
            failedToLoadMore = true
            self.error = HGErrorPresentation(error: error)
        }
    }

    private func rememberRecordDates(_ items: [HGRecordHistoryItem]) {
        knownRecordDates.formUnion(items.compactMap { record in
            record.measuredAt.hgISO8601Date.map(historyCalendar.startOfDay(for:))
        })
    }

    private var errorAlert: Binding<Bool> { Binding(get: { error != nil }, set: { if !$0 { error = nil } }) }
}

private struct RecordDayGroup {
    let date: Date
    let label: String
    let items: [HGRecordHistoryItem]
}

private enum RecordFilter: CaseIterable, Identifiable {
    case all, thermometer, work, rest
    var id: Self { self }
    var title: String {
        switch self {
        case .all: "전체"
        case .thermometer: "온도계"
        case .work: "작업 사진"
        case .rest: "휴식 사진"
        }
    }
    var emptyDescription: String { self == .all ? "" : title }
    func matches(_ type: HGRecordType) -> Bool {
        switch self {
        case .all: true
        case .thermometer: type == .thermometer
        case .work: type == .work
        case .rest: type == .rest
        }
    }
}

private struct RecordCountMetric: View {
    let title: String; let count: Int
    var body: some View {
        VStack(spacing: 3) {
            Text(title).font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText)
            Text("\(count)건").font(HGFont.bold(18, relativeTo: .headline)).foregroundStyle(HGColor.primaryText)
        }.frame(maxWidth: .infinity)
    }
}

private struct RecordHistoryRow: View {
    let record: HGRecordHistoryItem
    var body: some View {
        HStack(spacing: 10) {
            Image(record.type.historyImage)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .background(HGColor.appBackground, in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(record.type.historyTitle)
                    .font(HGFont.bold(14, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                Text(record.summary)
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 7) {
                Text(record.formattedMeasuredAt)
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(HGColor.homeChevron)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }
}

private extension HGRecordHistoryItem {
    var summary: String {
        switch type {
        case .thermometer:
            return [
                workplace ?? siteName,
                temperature.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...1))) + "°C" },
                humidity.map { String(format: "습도 %.0f%%", $0) }
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
        case .work:
            return workplace ?? siteName ?? memo ?? ""
        case .rest:
            return [workplace ?? siteName, restMinutes.map { "\($0)분 휴식" }]
                .compactMap { $0 }.joined(separator: " · ")
        }
    }
    var formattedMeasuredAt: String {
        HGDateFormatting.time(measuredAt)
    }
}

extension HGRecordType {
    var historyImage: String {
        switch self {
        case .thermometer: "ThermometerIllustration"
        case .work: "WorkPhoto"
        case .rest: "RestPhoto"
        }
    }
}
