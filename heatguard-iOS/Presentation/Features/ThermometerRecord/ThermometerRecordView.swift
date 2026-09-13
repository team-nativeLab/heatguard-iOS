//
//  ThermometerRecordView.swift
//  heatguard-iOS
//

import SwiftUI

struct ThermometerRecordView: View {
    @State private var isManualEntryEnabled = false
    @State private var temperature = "47.5"
    @State private var humidity = "55"

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("온도계 기록")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(.black)

                Text("온도계 데이터를 입력하고 현장 사진을\n촬영해 주세요.")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(.black)
                    .padding(.top, 10)

                temperatureSummaryCard
                    .padding(.top, 25)

                manualEntryToggle
                    .padding(.top, 30)

                manualEntryCard
                    .padding(.top, 11)

                photoSection
                    .padding(.top, 26)
            }
            .padding(.top, 45)

            Spacer(minLength: 0)

            HGPrimaryButton(title: "기록 저장", height: 48) {}
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Button(action: {}) {
                Image("menu")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("폭염가드")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(.black)

            Spacer()

            Button(action: {}) {
                Image("bell")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
    }

    private var temperatureSummaryCard: some View {
        HStack(spacing: 15) {
            Image("ThermometerIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: 55, height: 76)

            VStack(alignment: .leading, spacing: 0) {
                Text("현재 온도")
                    .font(HGFont.semiBold(13, relativeTo: .caption))
                    .foregroundStyle(summaryText)

                Text("47.5 °C")
                    .font(HGFont.bold(32, relativeTo: .largeTitle))
                    .foregroundStyle(.black)
                    .padding(.top, 9)

                Text("습도 55% · 체감 40.5 °C")
                    .font(HGFont.semiBold(13, relativeTo: .caption))
                    .foregroundStyle(summaryText)
                    .padding(.top, 14)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 138, maxHeight: 138)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(red: 222 / 255, green: 222 / 255, blue: 222 / 255).opacity(0.25), radius: 7.3, x: 4, y: 4)
    }

    private var manualEntryToggle: some View {
        Button {
            isManualEntryEnabled.toggle()
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(HGColor.surface)
                    .frame(width: 28, height: 28)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 225 / 255, green: 225 / 255, blue: 226 / 255), lineWidth: 2)
                    }
                    .overlay {
                        if isManualEntryEnabled {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(HGColor.primary)
                        }
                    }

                Text("온도계 데이터 입력")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(.black)

                Spacer(minLength: 0)

                Text("( 온도계 미설치 시 체크 )")
                    .font(HGFont.semiBold(13, relativeTo: .caption))
                    .foregroundStyle(summaryText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("온도계 데이터 입력")
        .accessibilityValue(isManualEntryEnabled ? "선택됨" : "선택 안 됨")
    }

    private var manualEntryCard: some View {
        VStack(spacing: 0) {
            measurementRow(title: "온도 ( ℃ )", text: $temperature, placeholder: "47.5", keyboardType: .decimalPad)
            Divider()
                .padding(.leading, 91)
            measurementRow(title: "습도 ( % )", text: $humidity, placeholder: "55", keyboardType: .numberPad)
            Divider()
                .padding(.leading, 91)
            measurementRow(title: "체감온도 ( ℃ )", value: "자동 계산")
        }
        .padding(.vertical, 9)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 225 / 255, green: 225 / 255, blue: 226 / 255), lineWidth: 1)
        }
        .opacity(isManualEntryEnabled ? 1 : 0.32)
        .disabled(!isManualEntryEnabled)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("현장 사진")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(.black)

            Button(action: {}) {
                HStack(spacing: 0) {
                    Image("camera")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .padding(.leading, 19)

                    Spacer()

                    Text("사진 촬영 또는\n앨범에서 선택")
                        .font(HGFont.semiBold(13, relativeTo: .caption))
                        .foregroundStyle(summaryText)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 79)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 234 / 255, green: 234 / 255, blue: 234 / 255), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("현장 사진 선택")
        }
    }

    private func measurementRow(
        title: String,
        text: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .frame(width: 101, alignment: .leading)

            TextField(placeholder, text: text)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, 20)
        .frame(height: 36)
    }

    private func measurementRow(title: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .frame(width: 101, alignment: .leading)

            Text(value)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
        }
        .padding(.horizontal, 20)
        .frame(height: 36)
    }

    private var summaryText: Color {
        Color(red: 85 / 255, green: 92 / 255, blue: 120 / 255)
    }
}

#Preview {
    NavigationStack {
        ThermometerRecordView()
    }
}
