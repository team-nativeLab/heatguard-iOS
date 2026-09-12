//
//  HGMetricTile.swift
//  heatguard-iOS
//

import SwiftUI

struct HGMetricTile: View {
    let title: String
    let value: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HGFont.regular(11, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)

            Text(value)
                .font(HGFont.semiBold(16))
                .foregroundStyle(HGColor.primaryText)

            if let subtitle {
                Text(subtitle)
                    .font(HGFont.regular(11, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .padding(14)
        .background(HGColor.metricBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}
