import SwiftUI

struct HomeView: View {
    @State private var showsRecordTypes = false
    @State private var showsEmergency = false
    @State private var showsCalling = false
    @State private var destination: RecordType?

    var body: some View {
        VStack(spacing: 0) {
            header
            weatherSummary.padding(.top, 15)
            sectionLabel("데이터 기록").padding(.top, 20)
            checkCard.padding(.top, 8)
            contactCard.padding(.top, 16)
            sectionLabel("추가 기록").padding(.top, 16)
            VStack(spacing: 9) {
                HomeActionRow(icon: "HomeCamera", title: "현장 사진", subtitle: "사진 촬영 또는 앨범에서 선택") { showsRecordTypes = true }
                HomeActionRow(icon: "HomeHistory", title: "기록 내역", subtitle: "지금까지의 기록을 확인하세요") {}
            }.padding(.top, 8)
            Spacer(minLength: 8)
            HGPrimaryButton(title: "기록하기", height: 48) { showsRecordTypes = true }.padding(.bottom, 10)
        }
        .padding(.horizontal, 27).padding(.top, 24).background(HGColor.appBackground).toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsRecordTypes) { RecordTypeSelectionView { destination = $0 } }
        .sheet(isPresented: $showsEmergency) { EmergencyAlertView { showsEmergency = false; showsCalling = true } }
        .sheet(isPresented: $showsCalling) { EmergencyCallView() }
        .navigationDestination(item: $destination) { type in
            switch type { case .thermometer: ThermometerRecordView(); case .workPhoto: WorkPhotoView(); case .restPhoto: RestPhotoView() }
        }
    }

    private var header: some View {
        HStack {
            Button {} label: { Image("menu").resizable().scaledToFit().frame(width: 28, height: 28) }.buttonStyle(.plain)
            Spacer(); Text("폭염가드").font(HGFont.bold(20, relativeTo: .title2)); Spacer()
            Button {} label: { Image("bell").resizable().scaledToFit().frame(width: 28, height: 28) }.buttonStyle(.plain)
        }.frame(height: 28)
    }

    private var weatherSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("폭염 주의 단계").font(HGFont.bold(10, relativeTo: .caption2)).foregroundStyle(Color.orange).padding(.horizontal, 10).frame(height: 24).background(Color(red: 1, green: 226/255, blue: 214/255), in: Capsule())
                    Text("현재 온도").font(HGFont.medium(12, relativeTo: .caption)).padding(.top, 16)
                    HStack(spacing: 8) { Text("47.5°C").font(HGFont.bold(40, relativeTo: .largeTitle)); Text("▲ +3.2°C").font(HGFont.bold(9, relativeTo: .caption2)).foregroundStyle(HGColor.error).padding(.horizontal, 7).frame(height: 20).background(Color(red: 1, green: 221/255, blue: 226/255), in: Capsule()) }
                    Text("습도 55% · 체감온도 40.5°C").font(HGFont.regular(12, relativeTo: .caption)).padding(.top, 8)
                }
                Spacer(); Image("WeatherPartlyCloudy").resizable().scaledToFit().frame(width: 145, height: 120).offset(x: 9, y: 2)
            }
            HStack(spacing: 0) { HomeMetric(icon: "HomeHumidity", title: "습도", value: "55%"); Divider().frame(height: 24); HomeMetric(icon: "HomeFeelsLike", title: "체감온도", value: "40.5°C"); Divider().frame(height: 24); HomeMetric(icon: "HomeWeather", title: "날씨", value: "맑음") }
                .padding(.horizontal, 18).frame(height: 78).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }.foregroundStyle(HGColor.primaryText)
    }

    private var checkCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("오늘 체크 시간").font(HGFont.bold(14, relativeTo: .subheadline))
            Text("다음 체크까지 57분 · 22:00 예정").font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText).padding(.top, 7)
            HomeTimeline().padding(.top, 19)
        }.padding(20).frame(maxWidth: .infinity, minHeight: 136, alignment: .leading).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var contactCard: some View {
        VStack(spacing: 0) {
            HomeActionRow(icon: "HomeManagerPhone", title: "관리자 전화", subtitle: "현장 관리자에게 연락") {}
            Divider().padding(.leading, 16)
            HomeActionRow(icon: "HomeEmergencyPhone", title: "긴급 전화", subtitle: "본사와 즉시 연결") { showsEmergency = true }
        }.background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func sectionLabel(_ title: String) -> some View { Text(title).font(HGFont.regular(11, relativeTo: .caption2)).frame(maxWidth: .infinity, alignment: .leading) }
}

private struct HomeMetric: View {
    let icon: String; let title: String; let value: String
    var body: some View { HStack(spacing: 8) { Image(icon).resizable().scaledToFit().frame(width: 20, height: 20).frame(width: 36, height: 36).background(Color(red: 235/255, green: 240/255, blue: 251/255), in: Circle()); VStack(alignment: .leading, spacing: 2) { Text(title).font(HGFont.regular(10, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText); Text(value).font(HGFont.bold(14, relativeTo: .caption)) } }.frame(maxWidth: .infinity, alignment: .leading) }
}

private struct HomeActionRow: View {
    let icon: String; let title: String; let subtitle: String; let action: () -> Void
    var body: some View { Button(action: action) { HStack(spacing: 12) { Image(icon).resizable().scaledToFit().frame(width: 24, height: 24).frame(width: 44, height: 44).background(Color(red: 237/255, green: 241/255, blue: 251/255), in: RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading, spacing: 4) { Text(title).font(HGFont.bold(14, relativeTo: .subheadline)); Text(subtitle).font(HGFont.regular(11, relativeTo: .caption2)).foregroundStyle(HGColor.secondaryText) }; Spacer(); Text("›").font(.title3).foregroundStyle(Color(red: 172/255, green: 175/255, blue: 191/255)) }.padding(.horizontal, 16).frame(height: 65) }.buttonStyle(.plain).foregroundStyle(HGColor.primaryText) }
}

private struct HomeTimeline: View {
    private let times = ["08시", "10시", "12시", "14시", "16시", "18시", "20시", "22시"]
    private let checked = Set([0, 1, 3, 5])
    var body: some View { VStack(spacing: 7) { GeometryReader { _ in ZStack { Capsule().fill(Color(red: 232/255, green: 235/255, blue: 242/255)).frame(height: 2); HStack { ForEach(times.indices, id: \.self) { index in Circle().fill(checked.contains(index) || index == 6 ? HGColor.primary : HGColor.surface).overlay(Circle().stroke(index == 6 ? HGColor.primary.opacity(0.3) : Color(red: 190/255, green: 195/255, blue: 208/255), lineWidth: index == 6 ? 5 : 1)).frame(width: index == 6 ? 10 : 8, height: index == 6 ? 10 : 8); if index != times.indices.last { Spacer() } } } } }.frame(height: 12); HStack { ForEach(times, id: \.self) { time in Text(time).font(HGFont.regular(9, relativeTo: .caption2)).foregroundStyle(time == "20시" ? HGColor.primary : HGColor.secondaryText); if time != times.last { Spacer() } } } } }
}

#Preview { NavigationStack { HomeView() } }
