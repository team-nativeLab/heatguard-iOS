//
//  HGActionRow.swift
//  heatguard-iOS
//

import SwiftUI

struct HGActionRow<Leading: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(HGFont.medium(14))
                        .foregroundStyle(HGColor.primaryText)

                    if let subtitle {
                        Text(subtitle)
                            .font(HGFont.regular(12, relativeTo: .caption))
                            .foregroundStyle(HGColor.secondaryText)
                    }
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HGColor.secondaryText)
            }
            .padding(16)
            .frame(minHeight: 69)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
