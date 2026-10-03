import SwiftUI

struct RestPhotoView: View {
    @State private var memo: String
    @State private var photos: [UIImage]
    @State private var temperature: String
    @State private var humidity: String
    @State private var isSaving = false
    @State private var recordsRestInterval = false
    @State private var restStartedAt: Date
    @State private var restEndedAt: Date
    @State private var validationMessage: String?
    let onSave: (HGRecordSaveResult) -> Void
    let onFailure: (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void
    let onPhotoRequired: (HGRecordDraft) -> Void
    let onMenuTap: () -> Void
    let onNotificationsTap: () -> Void
    let notificationCount: Int
    private let teamName: String?
    private let workplace: String?
    private let siteName: String?
    private let needsWeatherInput: Bool

    init(
        onSave: @escaping (HGRecordSaveResult) -> Void = { _ in },
        onFailure: @escaping (HGRecordSaveFailure, HGRecordDraft, [UIImage]) -> Void = { _, _, _ in },
        onPhotoRequired: @escaping (HGRecordDraft) -> Void = { _ in },
        initialMemo: String = "",
        initialPhotos: [UIImage] = [],
        initialTemperature: Double? = nil,
        initialHumidity: Double? = nil,
        weather: HomeWeather? = nil,
        initialRestStartedAt: Date? = nil,
        initialRestEndedAt: Date? = nil,
        teamName: String? = nil,
        workplace: String? = nil,
        siteName: String? = nil,
        onMenuTap: @escaping () -> Void = {},
        onNotificationsTap: @escaping () -> Void = {},
        notificationCount: Int = 0
    ) {
        self.onSave = onSave
        self.onFailure = onFailure
        self.onPhotoRequired = onPhotoRequired
        self.onMenuTap = onMenuTap
        self.onNotificationsTap = onNotificationsTap
        self.notificationCount = notificationCount
        self.teamName = teamName
        self.workplace = workplace
        self.siteName = siteName
        self.needsWeatherInput = weather?.temperature == nil || weather?.humidity == nil
        _memo = State(initialValue: initialMemo)
        _photos = State(initialValue: initialPhotos)
        _temperature = State(initialValue: (initialTemperature ?? weather?.temperature).map { String($0) } ?? "")
        _humidity = State(initialValue: (initialHumidity ?? weather?.humidity).map { String($0) } ?? "")
        _restStartedAt = State(initialValue: initialRestStartedAt ?? .now.addingTimeInterval(-30 * 60))
        _restEndedAt = State(initialValue: initialRestEndedAt ?? .now)
        _recordsRestInterval = State(initialValue: initialRestStartedAt != nil && initialRestEndedAt != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView { formContent }
                .scrollIndicators(.hidden)
        }
        .padding(.horizontal, HGLayout.screenHorizontalPadding)
        .padding(.top, HGLayout.screenTopPadding)
        .background(HGColor.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HGPrimaryButton(
                title: isSaving ? "저장 중..." : "기록 저장",
                isEnabled: !isSaving,
                height: HGLayout.primaryButtonHeight,
                action: saveRecord
            )
            .padding(.horizontal, HGLayout.screenHorizontalPadding + 4)
            .padding(.vertical, 8)
            .background(HGColor.appBackground)
        }
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardOnBackgroundTap()
        .alert("입력값을 확인해주세요", isPresented: validationAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("휴식시간 사진")
                .font(HGFont.bold(20, relativeTo: .title2))

            Text("휴식시간과 휴식 환경을 기록해주세요")
                .font(HGFont.regular(14, relativeTo: .subheadline))
                .padding(.top, 10)

            HGPhotoCaptureSection(images: $photos)
                .padding(.top, 34)

            restForm
                .padding(.top, 26)
            if needsWeatherInput {
                HGPhotoWeatherInput(temperature: $temperature, humidity: $humidity)
                    .padding(.top, 25)
            }
        }
        .padding(.top, HGLayout.screenContentTopPadding)
        .padding(.bottom, needsWeatherInput ? 16 : 0)
    }

    private var header: some View {
        HGScreenHeader(onMenuTap: onMenuTap, notificationCount: notificationCount, onNotificationsTap: onNotificationsTap)
    }

    private var restForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("휴식 시간").font(HGFont.semiBold(16))
            Toggle("휴식 시간 입력", isOn: $recordsRestInterval)
                .font(HGFont.medium(13, relativeTo: .subheadline))
                .padding(.top, 12)

            if recordsRestInterval {
                DatePicker("시작", selection: $restStartedAt, displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, koreanTimeZone)
                DatePicker("종료", selection: $restEndedAt, displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, koreanTimeZone)
                    .padding(.top, 8)
            } else {
                Text("휴식 시간은 선택 입력이에요")
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.top, 10)
            }
            HGOptionalMemoSection(
                placeholder: "휴식 관련 메모를 입력해주세요",
                height: 74,
                text: $memo
            )
            .padding(.top, 25)
        }
        .padding(.horizontal, 7)
    }

    private func saveRecord() {
        UIApplication.shared.dismissKeyboard()
        guard let values = HGPhotoWeatherInput.validatedValues(temperature: temperature, humidity: humidity) else {
            validationMessage = "온도는 -50~60°C, 습도는 0~100% 범위의 숫자로 입력해주세요."
            return
        }
        if recordsRestInterval {
            let normalizedStart = minutePrecisionDate(restStartedAt)
            let normalizedEnd = minutePrecisionDate(restEndedAt)
            let duration = normalizedEnd.timeIntervalSince(normalizedStart)
            guard duration >= 60, duration <= 24 * 60 * 60 else {
                validationMessage = "시작과 종료 시각을 확인해주세요. 휴식 시간은 1분에서 24시간 사이여야 해요."
                return
            }
        }
        let draft = HGRecordDraft(
            type: .rest,
            memo: memo,
            temperature: values.temperature,
            humidity: values.humidity,
            restStartedAt: recordsRestInterval ? minutePrecisionDate(restStartedAt) : nil,
            restEndedAt: recordsRestInterval ? minutePrecisionDate(restEndedAt) : nil,
            teamName: teamName,
            workplace: workplace,
            siteName: siteName
        )
        isSaving = true
        Task {
            defer { isSaving = false }
            switch await HGPhotoRecordSaveAction.perform(draft: draft, images: photos) {
            case .photoRequired:
                onPhotoRequired(draft)
            case let .success(result):
                onSave(result)
            case let .failure(failure):
                onFailure(failure, draft, photos)
            }
        }
    }

    private var validationAlert: Binding<Bool> {
        Binding(get: { validationMessage != nil }, set: { if !$0 { validationMessage = nil } })
    }

    private func minutePrecisionDate(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    private var koreanTimeZone: TimeZone {
        TimeZone(identifier: "Asia/Seoul") ?? .current
    }

}

#Preview { NavigationStack { RestPhotoView() } }
