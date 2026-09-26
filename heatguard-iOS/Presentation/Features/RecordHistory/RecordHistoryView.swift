import SwiftUI

struct RecordHistoryView: View {
    let onRecordSelected: (HGRecordHistoryItem) -> Void
    let onCreateRecord: () -> Void

    @State private var records: [HGRecordHistoryItem] = []
    @State private var isLoading = true
    @State private var error: HGErrorPresentation?
    @State private var selectedFilter: RecordFilter = .all

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
        .alert("기록을 불러오지 못했습니다.", isPresented: errorAlert) {
            Button("다시 시도") { Task { await loadRecords() } }
            Button("확인", role: .cancel) {}
        } message: { Text(error?.alertMessage ?? "") }
    }

    private var periodSelector: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar").foregroundStyle(HGColor.secondaryText)
            Text(currentWeekRange).font(HGFont.medium(14, relativeTo: .subheadline)).foregroundStyle(HGColor.primaryText)
            Spacer()
            Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(HGColor.secondaryText)
        }
        .padding(.horizontal, 20).frame(height: 52)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
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
        HStack(spacing: 0) {
            RecordCountMetric(title: "전체", count: records.count)
            Divider().frame(height: 28)
            RecordCountMetric(title: "온도계", count: records.count(where: { $0.type == .thermometer }))
            Divider().frame(height: 28)
            RecordCountMetric(title: "작업 사진", count: records.count(where: { $0.type == .work }))
            Divider().frame(height: 28)
            RecordCountMetric(title: "휴식 사진", count: records.count(where: { $0.type == .rest }))
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
                Text("해당 기간에 \(selectedFilter.emptyDescription) 기록이 없어요")
                    .font(HGFont.bold(15, relativeTo: .subheadline)).foregroundStyle(HGColor.primaryText)
                Text("기간이나 유형을 바꾸거나 새 기록을 남겨보세요")
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

    private var filteredRecords: [HGRecordHistoryItem] { records.filter { selectedFilter.matches($0.type) } }
    private var currentWeekRange: String {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
        return "\(start.formatted(.dateTime.year().month().day())) ~ \(Date.now.formatted(.dateTime.year().month().day()))"
    }

    @MainActor private func loadRecords() async {
        isLoading = true; defer { isLoading = false }
        do { records = try await HGRecordHistoryService().fetchRecords().items; error = nil }
        catch { self.error = HGErrorPresentation(error: error) }
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
