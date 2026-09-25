import SwiftUI

struct RecordDetailView: View {
    let recordID: String

    @State private var record: HGRecordDetail?
    @State private var isLoading = true
    @State private var error: HGErrorPresentation?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let record {
                ScrollView {
                    VStack(spacing: 16) {
                        recordSummary(record)
                        measurementCard(record)
                        memoCard(record)
                        photoSection(record.photoURLs)
                    }
                    .padding(20)
                }
            }
        }
        .background(HGColor.appBackground)
        .navigationTitle("기록 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRecord() }
        .alert("상세 기록을 불러오지 못했습니다.", isPresented: errorAlert) {
            Button("다시 시도") { Task { await loadRecord() } }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private func recordSummary(_ record: HGRecordDetail) -> some View {
        HGCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(record.type.historyTitle)
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(HGColor.primaryText)
                Text(record.formattedMeasuredAt)
                    .font(HGFont.regular(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.secondaryText)
            }
        }
    }

    @ViewBuilder
    private func measurementCard(_ record: HGRecordDetail) -> some View {
        if record.temperature != nil || record.humidity != nil || record.apparentTemperature != nil {
            HGCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("측정 정보")
                        .font(HGFont.bold(16, relativeTo: .headline))
                    HStack(spacing: 0) {
                        RecordMetric(title: "온도", value: record.temperatureText)
                        Divider().frame(height: 38)
                        RecordMetric(title: "습도", value: record.humidityText)
                        Divider().frame(height: 38)
                        RecordMetric(title: "체감온도", value: record.apparentTemperatureText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func memoCard(_ record: HGRecordDetail) -> some View {
        if let memo = record.memo, !memo.isEmpty {
            HGCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("메모")
                        .font(HGFont.bold(16, relativeTo: .headline))
                    Text(memo)
                        .font(HGFont.regular(14, relativeTo: .body))
                        .foregroundStyle(HGColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func photoSection(_ photoURLs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("사진")
                .font(HGFont.bold(16, relativeTo: .headline))
                .foregroundStyle(HGColor.primaryText)

            if photoURLs.isEmpty {
                HGCard {
                    Text("첨부된 사진이 없습니다.")
                        .font(HGFont.regular(14, relativeTo: .body))
                        .foregroundStyle(HGColor.secondaryText)
                }
            } else {
                ForEach(photoURLs, id: \.self) { photoURL in
                    RecordPhotoThumbnail(urlString: photoURL)
                }
            }
        }
    }

    @MainActor
    private func loadRecord() async {
        isLoading = true
        defer { isLoading = false }

        do {
            record = try await HGRecordHistoryService().fetchDetail(id: recordID)
            error = nil
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

private struct RecordMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(HGFont.regular(11, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
            Text(value)
                .font(HGFont.bold(15, relativeTo: .subheadline))
                .foregroundStyle(HGColor.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecordPhotoThumbnail: View {
    let urlString: String

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                ContentUnavailableView("사진을 불러오지 못했습니다.", systemImage: "photo")
            case .empty:
                ProgressView()
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private extension HGRecordDetail {
    var formattedMeasuredAt: String {
        guard let date = ISO8601DateFormatter().date(from: measuredAt) else { return measuredAt }
        return date.formatted(date: .long, time: .shortened)
    }

    var temperatureText: String { temperature.map { String(format: "%.1f°C", $0) } ?? "-" }
    var humidityText: String { humidity.map { String(format: "%.0f%%", $0) } ?? "-" }
    var apparentTemperatureText: String { apparentTemperature.map { String(format: "%.1f°C", $0) } ?? "-" }
}
