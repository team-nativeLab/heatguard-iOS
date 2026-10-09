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
                GeometryReader { geometry in
                    let photoWidth = max(0, geometry.size.width - 48)
                    HGFixedContent {
                        VStack(spacing: 12) {
                            if record.type == .thermometer {
                                thermometerContent(record, photoHeight: max(0, photoWidth - 40) * 2 / 3)
                            } else {
                                photoContent(record, photoHeight: photoWidth)
                            }
                            Text("제출한 기록은 수정할 수 없어요. 수정이 필요하면 현장 관리자에게 문의해주세요.")
                                .font(HGFont.notoRegular(12, relativeTo: .caption))
                                .foregroundStyle(HGColor.secondaryText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            }
        }
        .background(HGColor.appBackground)
        .hgNavigationTitle("기록 상세")
        .task { await loadRecord() }
        .alert(error?.title ?? "상세 기록 조회 오류", isPresented: errorAlert) {
            Button("다시 시도") { Task { await loadRecord() } }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private func thermometerContent(_ record: HGRecordDetail, photoHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            HGCard { VStack(alignment: .leading, spacing: 7) {
                RecordTypeBadge(type: record.type)
                Text(record.formattedMeasuredAt).font(HGFont.notoBold(18, relativeTo: .title3))
                if let location = record.locationText {
                    Text(location).font(HGFont.notoRegular(13, relativeTo: .subheadline)).foregroundStyle(HGColor.secondaryText)
                }
            }}
            HGCard { VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    Image(systemName: "thermometer.medium").font(.title2).foregroundStyle(HGColor.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("측정 온도").font(HGFont.notoRegular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText)
                        Text(record.temperatureText).font(HGFont.notoBold(32, relativeTo: .title))
                    }
                    Spacer()
                }
                Divider()
                HStack(spacing: 0) {
                    DetailMetric(title: "습도", value: record.humidityText)
                    DetailMetric(title: "체감온도", value: record.apparentTemperatureText)
                }
            }}
            photoCard(record.photoURLs, title: "현장 사진", height: photoHeight)
            memoCard(record)
        }
    }

    private func photoContent(_ record: HGRecordDetail, photoHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            photoCard(record.photoURLs, title: nil, height: photoHeight)
            measurementCard(record)
            HGCard(padding: 20) { VStack(spacing: 0) {
                DetailInfoRow(title: "유형", value: record.type.historyTitle, type: record.type)
                Divider(); DetailInfoRow(title: "촬영 시간", value: record.formattedMeasuredAt)
                if let location = record.locationText {
                    Divider(); DetailInfoRow(title: "위치", value: location)
                }
                if record.type == .rest, let duration = record.restDurationText {
                    Divider(); DetailInfoRow(title: "휴식 시간", value: duration)
                }
            }}
            memoCard(record)
        }
    }

    @ViewBuilder private func measurementCard(_ record: HGRecordDetail) -> some View {
        if record.temperature != nil || record.humidity != nil {
            HGCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("현장 측정값")
                        .font(HGFont.notoBold(15, relativeTo: .subheadline))

                    HStack(spacing: 12) {
                        DetailMetric(title: "온도", value: record.temperatureText)
                        DetailMetric(title: "습도", value: record.humidityText)
                    }
                }
            }
        }
    }

    private func photoCard(_ urls: [String], title: String?, height: CGFloat) -> some View {
        Group {
            if let title {
                HGCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title).font(HGFont.notoBold(15, relativeTo: .subheadline))
                        photoImage(urls, height: height, cornerRadius: 12)
                    }
                }
            } else {
                photoImage(urls, height: height, cornerRadius: 20)
            }
        }
    }

    private func photoImage(_ urls: [String], height: CGFloat, cornerRadius: CGFloat) -> some View {
        Group {
            if urls.isEmpty {
                photoPlaceholder
            } else {
                TabView {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        Group {
                            if let imageURL = URL(string: url) {
                                AsyncImage(url: imageURL) { phase in
                                    if let image = try? phase.get() { image.resizable().scaledToFill() }
                                    else if case .failure = phase { photoPlaceholder }
                                    else { ProgressView() }
                                }
                            } else {
                                photoPlaceholder
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                        .clipped()
                        .accessibilityLabel("현장 사진 \(index + 1) / \(urls.count)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .background(HGColor.homeActionIconBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var photoPlaceholder: some View {
        VStack(spacing: 8) {
            Image("RecordPhotoPlaceholder")
                .resizable()
                .frame(width: 36, height: 36)
            Text("촬영한 현장 사진").font(HGFont.notoRegular(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
        }
    }

    @ViewBuilder private func memoCard(_ record: HGRecordDetail) -> some View {
        if let memo = record.memo, !memo.isEmpty {
            HGCard { VStack(alignment: .leading, spacing: 8) {
                Text("메모").font(HGFont.notoBold(15, relativeTo: .subheadline)); Text(memo).font(HGFont.notoRegular(13, relativeTo: .subheadline)).foregroundStyle(HGColor.secondaryText)
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
    var body: some View {
        Text(type.historyTitle).font(HGFont.notoMedium(10, relativeTo: .caption2)).foregroundStyle(HGColor.primary)
            .padding(.horizontal, 8).padding(.vertical, 4).background(HGColor.homeMetricIconBackground, in: Capsule())
    }
}
private struct DetailMetric: View {
    let title: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(HGFont.notoRegular(12, relativeTo: .caption)).foregroundStyle(HGColor.secondaryText)
            Text(value).font(HGFont.notoBold(15, relativeTo: .subheadline))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct DetailInfoRow: View {
    let title: String
    let value: String
    var type: HGRecordType? = nil

    var body: some View {
        HStack {
            Text(title).font(HGFont.notoRegular(13, relativeTo: .subheadline)).foregroundStyle(HGColor.secondaryText)
            Spacer(minLength: 8)
            if let type {
                Text(value)
                    .font(HGFont.notoBold(11, relativeTo: .caption2))
                    .foregroundStyle(
                        type == .rest ? Color(red: 33 / 255, green: 153 / 255, blue: 89 / 255) : HGColor.primary
                    )
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(
                        type == .rest ? HGColor.successBackground : HGColor.homeMetricIconBackground, in: Capsule())
            } else {
                Text(value)
                    .font(HGFont.notoMedium(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(minHeight: 45)
    }
}
private extension AsyncImagePhase { func get() throws -> Image { if case let .success(image) = self { return image }; throw URLError(.cannotDecodeContentData) } }
private extension HGRecordDetail {
    var formattedMeasuredAt: String {
        HGDateFormatting.recordTimestamp(measuredAt)
    }
    var locationText: String? {
        let location = workplace ?? siteName
        return [location, teamName].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }
    var temperatureText: String { temperature.map { String(format: "%.1f°C", $0) } ?? "-" }
    var humidityText: String { humidity.map { String(format: "%.0f%%", $0) } ?? "-" }
    var apparentTemperatureText: String {
        guard let temperature, let humidity,
              let value = HGWeatherMeasurement(temperature: temperature, humidity: humidity)?.apparentTemperature else {
            return "-"
        }
        return String(format: "%.1f°C", value)
    }
    var restDurationText: String? {
        guard let restStartedAt, let restEndedAt,
              let start = restStartedAt.hgISO8601Date,
              let end = restEndedAt.hgISO8601Date,
              end > start else { return restMinutes.map { "\($0)분" } }
        let formatter = DateFormatter()
        formatter.locale = HGDateFormatting.locale
        formatter.timeZone = HGDateFormatting.timeZone
        formatter.dateFormat = "HH:mm"
        let minutes = restMinutes ?? Int(end.timeIntervalSince(start) / 60)
        return "\(minutes)분 (\(formatter.string(from: start)) ~ \(formatter.string(from: end)))"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
