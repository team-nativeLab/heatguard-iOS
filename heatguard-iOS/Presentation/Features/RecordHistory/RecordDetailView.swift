import SwiftUI

struct RecordDetailView: View {
    let recordID: String
    @State private var detail: HGRecordDetail?
    @State private var error: String?

    var body: some View {
        Group {
            if let detail {
                List {
                    Section("측정 정보") {
                        Text("온도 \(detail.temperature.map { String(format: "%.1f°C", $0) } ?? "-")")
                        Text("습도 \(detail.humidity.map { String(format: "%.0f%%", $0) } ?? "-")")
                        Text("체감온도 \(detail.apparentTemperature.map { String(format: "%.1f°C", $0) } ?? "-")")
                    }
                    Section("기록") { Text(detail.memo ?? "메모 없음"); Text(detail.measuredAt) }
                    Section("사진") { Text("\(detail.photoURLs.count)장") }
                }
            } else { ProgressView() }
        }
        .navigationTitle("기록 상세")
        .task { do { detail = try await HGRecordHistoryService().fetchDetail(id: recordID) } catch { self.error = error.localizedDescription } }
        .alert("상세 기록을 불러오지 못했습니다.", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("확인", role: .cancel) {} } message: { Text(error ?? "") }
    }
}
