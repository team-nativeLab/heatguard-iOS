//
//  ComponentShowcaseView.swift
//  heatguard-iOS
//

import SwiftUI

struct ComponentShowcaseView: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionTitle("버튼")
                HGPrimaryButton(title: "로그인") {}
                HGPrimaryButton(title: "저장", isEnabled: false) {}

                sectionTitle("입력 필드")
                HGTextField(title: "이메일", placeholder: "example@email.com", text: $email)
                HGTextField(
                    title: "비밀번호",
                    placeholder: "비밀번호를 입력해주세요",
                    text: $password,
                    isSecure: true,
                    errorMessage: "비밀번호를 다시 확인해주세요"
                )

                sectionTitle("카드와 지표")
                HGCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("온도계 데이터 직접 입력")
                            .font(HGFont.medium(14))
                            .foregroundStyle(HGColor.primaryText)

                        HStack(spacing: 8) {
                            HGMetricTile(title: "온도(℃)", value: "47.5")
                            HGMetricTile(title: "습도(%)", value: "55")
                            HGMetricTile(title: "체감온도(℃)", value: "자동계산")
                        }
                    }
                }

                sectionTitle("액션 행")
                VStack(spacing: 12) {
                    HGActionRow(title: "현장 사진", subtitle: "사진 촬영 또는 앨범에서 선택", leading: {
                        Image(systemName: "camera")
                            .foregroundStyle(HGColor.primary)
                    }) {}

                    HGActionRow(title: "기록 내역", subtitle: "지금까지의 기록을 확인하세요", leading: {
                        Image(systemName: "chart.bar")
                            .foregroundStyle(HGColor.primary)
                    }) {}
                }
            }
            .padding(20)
        }
        .background(HGColor.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("컴포넌트")
                    .font(HGFont.semiBold(20, relativeTo: .headline))
                    .foregroundStyle(HGColor.primaryText)
            }
        }
        .toolbarBackground(HGColor.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(HGFont.heading)
            .foregroundStyle(HGColor.primaryText)
    }
}

#Preview {
    NavigationStack {
        ComponentShowcaseView()
    }
}
