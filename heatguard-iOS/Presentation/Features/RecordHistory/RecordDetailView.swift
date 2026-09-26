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
                    VStack(spacing: 12) {
                        if record.type == .thermometer { thermometerContent(record) }
                        else { photoContent(record) }
                        Text("제출한 기록은 수정할 수 없어요. 수정이 필요하면 현장 관리자에게 문의해주세요.")
                            .font(HGFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(HGColor.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .padding(24)
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
        } message: { Text(error?.alertMessage ?? "") }
    }

    private func thermometerContent(_ record: HGRecordDetail) -> some View {
        VStack(spacing: 12) {
            HGCard { VStack(alignment: .leading, spacing: 7) {
                RecordTypeBadge(type: record.type)
                Text(record.formattedMeasuredAt).font(HGFont.bold(18, relativeTo: .title3))
                Text("현장 기록").font(HGFont.regular(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
            }}
            HGCard { VStack(alignment: .leading, spacing: 15) {
                Text("측정값").font(HGFont.bold(15, relativeTo: .subheadline))
                HStack(spacing: 12) {
                    Image(systemName: "thermometer.medium").font(.title2).foregroundStyle(HGColor.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("측정 온도").font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText)
                        Text(record.temperatureText).font(HGFont.bold(28, relativeTo: .title))
                    }
                    Spacer()
                }
                Divider()
                HStack(spacing: 0) {
                    DetailMetric(title: "습도", value: record.humidityText)
                    DetailMetric(title: "체감온도", value: record.apparentTemperatureText)
                    DetailMetric(title: "온도계", value: "설치됨")
                }
            }}
            photoCard(record.photoURLs, title: "현장 사진", height: 200)
            memoCard(record)
        }
    }

    private func photoContent(_ record: HGRecordDetail) -> some View {
        VStack(spacing: 12) {
            photoCard(record.photoURLs, title: nil, height: 354)
            HGCard { VStack(spacing: 0) {
                DetailInfoRow(title: "유형", value: record.type.historyTitle)
                Divider(); DetailInfoRow(title: "촬영 시간", value: record.formattedMeasuredAt)
                Divider(); DetailInfoRow(title: "위치", value: "현장 기록")
                if record.type == .rest { Divider(); DetailInfoRow(title: "휴식 시간", value: "기록된 휴식 시간") }
            }}
            memoCard(record)
        }
    }

    private func photoCard(_ urls: [String], title: String?, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title { Text(title).font(HGFont.bold(15, relativeTo: .subheadline)) }
            Group {
                if let url = urls.first, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if let image = try? phase.get() { image.resizable().scaledToFill() }
                        else if case .failure = phase { photoPlaceholder }
                        else { ProgressView() }
                    }
                } else { photoPlaceholder }
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var photoPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo").font(.title).foregroundStyle(HGColor.primary)
            Text("촬영한 현장 사진").font(HGFont.regular(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
        }
    }

    @ViewBuilder private func memoCard(_ record: HGRecordDetail) -> some View {
        if let memo = record.memo, !memo.isEmpty {
            HGCard { VStack(alignment: .leading, spacing: 8) {
                Text("메모").font(HGFont.bold(15, relativeTo: .subheadline)); Text(memo).font(HGFont.regular(13, relativeTo: .subheadline)).foregroundStyle(HGColor.secondaryText)
            }}
        }
    }

    @MainActor private func loadRecord() async {
        isLoading = true; defer { isLoading = false }
        do { record = try await HGRecordHistoryService().fetchDetail(id: recordID); error = nil }
        catch { self.error = HGErrorPresentation(error: error) }
    }
    private var errorAlert: Binding<Bool> { Binding(get: { error != nil }, set: { if !$0 { error = nil } }) }
}

private struct RecordTypeBadge: View {
    let type: HGRecordType
    var body: some View { Text(type.historyTitle).font(HGFont.medium(10, relativeTo: .caption2)).foregroundStyle(HGColor.primary).padding(.horizontal, 8).padding(.vertical, 4).background(HGColor.homeMetricIconBackground, in: Capsule()) }
}
private struct DetailMetric: View {
    let title: String; let value: String
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(HGFont.regular(10, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText); Text(value).font(HGFont.bold(13, relativeTo: .caption)) }.frame(maxWidth: .infinity, alignment: .leading) }
}
private struct DetailInfoRow: View {
    let title: String; let value: String
    var body: some View { HStack { Text(title).font(HGFont.medium(13, relativeTo: .subheadline)); Spacer(); Text(value).font(HGFont.regular(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText) }.frame(height: 45) }
}
private extension AsyncImagePhase { func get() throws -> Image { if case let .success(image) = self { return image }; throw URLError(.cannotDecodeContentData) } }
private extension HGRecordDetail {
    var formattedMeasuredAt: String { guard let date = measuredAt.hgISO8601Date else { return measuredAt }; return date.formatted(date: .long, time: .shortened) }
    var temperatureText: String { temperature.map { String(format: "%.1f°C", $0) } ?? "-" }
    var humidityText: String { humidity.map { String(format: "%.0f%%", $0) } ?? "-" }
    var apparentTemperatureText: String { apparentTemperature.map { String(format: "%.1f°C", $0) } ?? "-" }
}
