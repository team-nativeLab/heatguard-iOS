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
