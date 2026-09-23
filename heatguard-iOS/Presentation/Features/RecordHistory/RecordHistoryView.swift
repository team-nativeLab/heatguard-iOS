import SwiftUI

struct RecordHistoryView: View {
    let onRecordSelected: (HGRecordHistoryItem) -> Void

    @State private var records: [HGRecordHistoryItem] = []
    @State private var isLoading = true
    @State private var error: String?

    init(onRecordSelected: @escaping (HGRecordHistoryItem) -> Void = { _ in }) {
        self.onRecordSelected = onRecordSelected
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if records.isEmpty {
                ContentUnavailableView(
                    "기록이 없습니다.",
                    systemImage: "doc.text",
                    description: Text("저장한 현장 기록이 여기에 표시됩니다.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(records) { record in
                            Button { onRecordSelected(record) } label: {
                                RecordHistoryRow(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(HGColor.appBackground)
        .navigationTitle("기록 내역")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRecords() }
        .alert("기록을 불러오지 못했습니다.", isPresented: errorAlert) {
            Button("다시 시도") { Task { await loadRecords() } }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    @MainActor
    private func loadRecords() async {
        isLoading = true
        defer { isLoading = false }

        do {
            records = try await HGRecordHistoryService().fetchRecords().items
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

private struct RecordHistoryRow: View {
    let record: HGRecordHistoryItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: record.type.historySymbol)
                .font(.title3)
                .foregroundStyle(HGColor.primary)
                .frame(width: 44, height: 44)
                .background(HGColor.homeActionIconBackground, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text(record.type.historyTitle)
                    .font(HGFont.bold(15, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                Text(record.summary)
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HGColor.homeChevron)
        }
        .padding(16)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private extension HGRecordHistoryItem {
    var summary: String {
        let temperatureText = temperature.map { String(format: "%.1f°C", $0) }
        return [temperatureText, formattedMeasuredAt].compactMap { $0 }.joined(separator: " · ")
    }

    var formattedMeasuredAt: String {
        guard let date = ISO8601DateFormatter().date(from: measuredAt) else { return measuredAt }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private extension HGRecordType {
    var historySymbol: String {
        switch self {
        case .thermometer: "thermometer.medium"
        case .work: "camera"
        case .rest: "cup.and.saucer"
        }
    }
}
