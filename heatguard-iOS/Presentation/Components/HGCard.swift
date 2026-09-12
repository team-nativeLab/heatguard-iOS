//
//  HGCard.swift
//  heatguard-iOS
//

import SwiftUI

struct HGCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
