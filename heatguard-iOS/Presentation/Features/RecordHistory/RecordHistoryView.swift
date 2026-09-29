import SwiftUI

struct RecordHistoryView: View {
    let onRecordSelected: (HGRecordHistoryItem) -> Void
    let onCreateRecord: () -> Void

    @State private var records: [HGRecordHistoryItem] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var failedToLoadMore = false
    @State private var error: HGErrorPresentation?
    @State private var selectedFilter: RecordFilter = .all
    @State private var selectedPeriodEnd = Date.now
    @State private var showsPeriodPicker = false

    init(onRecordSelected: @escaping (HGRecordHistoryItem) -> Void = { _ in }, onCreateRecord: @escaping () -> Void = {}) {
        self.onRecordSelected = onRecordSelected
        self.onCreateRecord = onCreateRecord
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer(); ProgressView(); Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        periodSelector
                        filterSelector.padding(.top, 14)
                        summaryCard.padding(.top, 14)
                        historyContent.padding(.top, 20)
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
                    .padding(.bottom, 96)
                }
            }
        }
        .background(HGColor.appBackground)
        .navigationTitle("기록 내역")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HGPrimaryButton(title: "기록하기", action: onCreateRecord)
                .padding(.horizontal, 28).padding(.vertical, 10)
                .background(HGColor.appBackground)
        }
        .task { await loadRecords() }
        .sheet(isPresented: $showsPeriodPicker) {
            NavigationStack {
                DatePicker(
                    "기준일",
                    selection: $selectedPeriodEnd,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(24)
                .navigationTitle("기록 기간 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") { showsPeriodPicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert(error?.title ?? "기록 조회 오류", isPresented: errorAlert) {
            Button("다시 시도") {
                Task {
                    if failedToLoadMore { await loadMoreRecords() }
                    else { await loadRecords() }
                }
            }
            Button("확인", role: .cancel) {}
        } message: { Text(error?.alertMessage ?? "") }
    }

    private var periodSelector: some View {
        Button { showsPeriodPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar").foregroundStyle(HGColor.secondaryText)
                Text(currentWeekRange).font(HGFont.medium(14, relativeTo: .subheadline)).foregroundStyle(HGColor.primaryText)
                Spacer()
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(HGColor.secondaryText)
            }
            .padding(.horizontal, 20).frame(height: 52)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint("기준일을 선택해 최근 7일 기록을 조회합니다")
    }

    private var filterSelector: some View {
        HStack(spacing: 8) {
            ForEach(RecordFilter.allCases) { filter in
                Button { selectedFilter = filter } label: {
                    Text(filter.title)
                        .font(HGFont.medium(12, relativeTo: .caption))
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
                RecordCountMetric(title: "전체", count: periodRecords.count)
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
        if filteredRecords.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 30, weight: .medium)).foregroundStyle(HGColor.primary)
                    .frame(width: 72, height: 72).background(HGColor.homeMetricIconBackground, in: Circle())
                Text(hasMore ? "불러온 기록 중 해당 항목이 없어요" : "해당 기간에 \(selectedFilter.emptyDescription) 기록이 없어요")
                    .font(HGFont.bold(15, relativeTo: .subheadline)).foregroundStyle(HGColor.primaryText)
                Text(hasMore ? "더 보기를 눌러 이전 기록을 확인해 보세요" : "기간이나 유형을 바꾸거나 새 기록을 남겨보세요")
                    .font(HGFont.regular(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
            }.frame(maxWidth: .infinity, minHeight: 247)
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("최근 기록").font(HGFont.medium(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
                VStack(spacing: 0) {
                    ForEach(filteredRecords) { record in
                        Button { onRecordSelected(record) } label: { RecordHistoryRow(record: record) }.buttonStyle(.plain)
                        if record.id != filteredRecords.last?.id { Divider().padding(.leading, 16) }
                    }
                }.background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var filteredRecords: [HGRecordHistoryItem] {
        periodRecords.filter { selectedFilter.matches($0.type) }
    }

    private var periodRecords: [HGRecordHistoryItem] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: selectedPeriodEnd)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) ?? end

        return records.filter { record in
            guard let measuredAt = record.measuredAt.hgISO8601Date else { return false }
            return measuredAt >= start && measuredAt < endExclusive
        }
    }

    private var currentWeekRange: String {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: selectedPeriodEnd) ?? selectedPeriodEnd
        return "\(start.formatted(.dateTime.year().month().day())) ~ \(selectedPeriodEnd.formatted(.dateTime.year().month().day()))"
    }

    @MainActor private func loadRecords() async {
        failedToLoadMore = false
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await HGRecordHistoryService().fetchRecords()
            records = page.items
            nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            error = nil
        }
        catch { self.error = HGErrorPresentation(error: error) }
    }

    @MainActor private func loadMoreRecords() async {
        guard !isLoadingMore, hasMore, let nextCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await HGRecordHistoryService().fetchRecords(cursor: nextCursor)
            let existingIDs = Set(records.map(\.recordID))
            records.append(contentsOf: page.items.filter { !existingIDs.contains($0.recordID) })
            self.nextCursor = page.page.nextCursor
            hasMore = page.page.hasMore && page.page.nextCursor != nil
            failedToLoadMore = false
            error = nil
        } catch {
            failedToLoadMore = true
            self.error = HGErrorPresentation(error: error)
        }
    }

    private var errorAlert: Binding<Bool> { Binding(get: { error != nil }, set: { if !$0 { error = nil } }) }
}

private enum RecordFilter: CaseIterable, Identifiable {
    case all, thermometer, work, rest
    var id: Self { self }
    var title: String { switch self { case .all: "전체"; case .thermometer: "온도계"; case .work: "작업 사진"; case .rest: "휴식 사진" } }
    var emptyDescription: String { self == .all ? "" : title }
    func matches(_ type: HGRecordType) -> Bool { switch self { case .all: true; case .thermometer: type == .thermometer; case .work: type == .work; case .rest: type == .rest } }
}

private struct RecordCountMetric: View {
    let title: String; let count: Int
    var body: some View {
        VStack(spacing: 3) {
            Text(title).font(HGFont.regular(10, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText)
            Text("\(count)건").font(HGFont.bold(16, relativeTo: .headline)).foregroundStyle(HGColor.primaryText)
        }.frame(maxWidth: .infinity)
    }
}

private struct RecordHistoryRow: View {
    let record: HGRecordHistoryItem
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.type.historySymbol).font(.title3).foregroundStyle(HGColor.primary)
                .frame(width: 44, height: 44).background(HGColor.homeActionIconBackground, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(record.type.historyTitle).font(HGFont.bold(14, relativeTo: .subheadline)).foregroundStyle(HGColor.primaryText)
                Text(record.summary).font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.formattedMeasuredAt).font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(HGColor.homeChevron)
            }
        }.padding(.horizontal, 16).frame(height: 72)
    }
}

private extension HGRecordHistoryItem {
    var summary: String { [temperature.map { String(format: "%.1f°C", $0) }, memo].compactMap { $0 }.joined(separator: " · ") }
    var formattedMeasuredAt: String {
        guard let date = measuredAt.hgISO8601Date else { return measuredAt }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension HGRecordType {
    var historySymbol: String { switch self { case .thermometer: "thermometer.medium"; case .work: "camera"; case .rest: "cup.and.saucer" } }
}
