//
//  HomeView.swift
//  heatguard-iOS
//

import SwiftUI

struct HomeView: View {
    @State private var isManualEntryEnabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                heatStatusCard
                    .padding(.top, 15)

                dataRecordSection
                    .padding(.top, 47)
            }
            .padding(.horizontal, 25)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Button {} label: {
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

            Button {} label: {
                Image("bell")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
    }

    private var heatStatusCard: some View {
        ZStack(alignment: .topLeading) {
            Image("WeatherSunny")
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .clipped()
                .offset(x: 207, y: 8)

            VStack(alignment: .leading, spacing: 0) {
                Text("폭염 주의 단계")
                    .font(HGFont.bold(10, relativeTo: .caption2))
                    .foregroundStyle(Color(red: 1, green: 107 / 255, blue: 0))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color(red: 1, green: 226 / 255, blue: 214 / 255), in: Capsule())

                Text("현재 온도")
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(homeText)
                    .padding(.top, 8)

                HStack(alignment: .center, spacing: 8) {
                    Text("47.5°C")
                        .font(HGFont.bold(40, relativeTo: .largeTitle))
                        .foregroundStyle(homeText)

                    Text("▲ +3.2°C")
                        .font(HGFont.bold(9, relativeTo: .caption2))
                        .foregroundStyle(HGColor.error)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Color(red: 1, green: 221 / 255, blue: 226 / 255), in: Capsule())
                }
                .padding(.top, 8)

                Text("습도 55% · 체감온도 40.5°C")
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(homeText)
                    .padding(.top, 8)

                HStack(spacing: 0) {
                    statusMetric(title: "습도", value: "55%")
                    statusMetric(title: "체감온도", value: "40.5°C")
                    statusMetric(title: "날씨", value: "맑음")
                }
                .padding(.top, 8)
            }
            .padding(.leading, 20)
            .padding(.top, 17)
            .padding(.trailing, 20)
        }
        .frame(maxWidth: .infinity, minHeight: 244, maxHeight: 244, alignment: .topLeading)
        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 32))
    }

    private var dataRecordSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("데이터 기록")
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(.black)

                Spacer()

                Text("ⓘ 미설치 시 자동으로 기록됩니다")
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 18)

            HGCard(cornerRadius: 16, padding: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("온도계 데이터 직접 입력")
                            .font(HGFont.regular(11, relativeTo: .caption2))
                            .foregroundStyle(.black)

                        Spacer()

                        Toggle("온도계 데이터 직접 입력", isOn: $isManualEntryEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(HGColor.primary)
                            .scaleEffect(0.75)
                            .frame(width: 38, height: 18)
                    }

                    HStack(spacing: 8) {
                        recordMetric(title: "온도(℃)", value: "47.5")
                        recordMetric(title: "습도(%)", value: "55")
                        recordMetric(title: "체감온도(℃)", value: "자동계산")
                    }
                    .padding(.top, 35)
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 15)
        }
    }

    private func recordMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(HGFont.regular(11, relativeTo: .caption2))

            Text(value)
                .font(HGFont.regular(11, relativeTo: .caption2))
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(HGColor.metricBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(HGFont.regular(10, relativeTo: .caption2))

            Text(value)
                .font(HGFont.bold(14, relativeTo: .caption))
        }
        .foregroundStyle(homeText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var homeText: Color {
        Color(red: 48 / 255, green: 51 / 255, blue: 61 / 255)
    }
}

#Preview {
    HomeView()
}
