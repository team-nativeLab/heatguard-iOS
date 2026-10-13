//
//  HGPrimaryButton.swift
//  heatguard-iOS
//

import SwiftUI

struct HGPrimaryButton: View {
    let title: String
    var isEnabled = true
    var height: CGFloat = HGLayout.primaryButtonHeight
    var font: Font = HGFont.medium(16)
    var cornerRadius: CGFloat = HGLayout.primaryButtonCornerRadius
    var tint: Color = HGColor.primary
    var disabledTint: Color = HGColor.disabled
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .foregroundStyle(.white)
        .background(
            isEnabled ? tint : disabledTint,
            in: RoundedRectangle(cornerRadius: cornerRadius)
        )
        .disabled(!isEnabled)
        .accessibilityHint(isEnabled ? "" : "현재 사용할 수 없습니다")
    }
}

#Preview {
    VStack(spacing: 16) {
        HGPrimaryButton(title: "로그인") {}
        HGPrimaryButton(title: "저장", isEnabled: false) {}
    }
    .padding()
}
