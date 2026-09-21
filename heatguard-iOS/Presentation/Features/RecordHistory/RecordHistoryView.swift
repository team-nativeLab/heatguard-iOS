import SwiftUI

struct RecordHistoryView: View {
    @State private var records: [HGRecordHistoryItem] = []
    @State private var error: String?

    var body: some View {
        List(records) { record in
            NavigationLink { RecordDetailView(recordID: record.id) } label: { VStack(alignment: .leading, spacing: 5) {
                Text(record.title).font(HGFont.bold(15))
                Text(record.detail)
                    .font(HGFont.regular(12)).foregroundStyle(HGColor.secondaryText)
            } }
        }
        .navigationTitle("기록 내역")
        .task {
            do { records = try await HGRecordHistoryService().fetchRecords() }
            catch { self.error = error.localizedDescription }
        }
        .alert("기록을 불러오지 못했습니다.", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인", role: .cancel) {} } message: { Text(error ?? "") }
    }
}

private extension HGRecordHistoryItem {
    var detail: String {
        let temperatureText = temperature.map { String(format: "%.1f°C", $0) }
        return [temperatureText, measuredAt].compactMap { $0 }.joined(separator: " · ")
    }
}
