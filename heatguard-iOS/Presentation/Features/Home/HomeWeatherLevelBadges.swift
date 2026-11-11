import SwiftUI

struct HomeWeatherLevelBadges: View {
    let heatLevelTitle: String
    let coldWaveWarning: HGColdWaveWarning?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                heatBadge
                if let coldWaveTitle = coldWaveWarning?.badgeText {
                    coldWaveBadge(coldWaveTitle)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                heatBadge
                if let coldWaveTitle = coldWaveWarning?.badgeText {
                    coldWaveBadge(coldWaveTitle)
                }
            }
        }
    }

    private var heatBadge: some View {
        Text(heatLevelTitle)
            .font(HGFont.bold(10, relativeTo: .caption2))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(HGColor.homeHeatLevelText)
            .padding(.horizontal, 10)
            .frame(width: 80, height: 24)
            .background(HGColor.homeHeatLevelBackground, in: Capsule())
    }

    private func coldWaveBadge(_ title: String) -> some View {
        Text(title)
            .font(HGFont.bold(10, relativeTo: .caption2))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(HGColor.primary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(HGColor.photoSelectionBackground, in: Capsule())
            .accessibilityIdentifier("home.coldWaveWarning")
    }
}

struct HomeColdWaveUnavailableMessage: View {
    let warning: HGColdWaveWarning?
    let isCompact: Bool

    var body: some View {
        if warning?.shouldShowUnavailableMessage == true {
            Text("한파특보 정보를 불러오지 못했습니다.")
                .font(HGFont.regular(11, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 26)
                .padding(.top, isCompact ? 8 : 12)
                .padding(.bottom, isCompact ? 4 : 8)
                .accessibilityIdentifier("home.coldWaveUnavailable")
        }
    }
}