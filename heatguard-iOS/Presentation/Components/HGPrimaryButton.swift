//
//  HGPrimaryButton.swift
//  heatguard-iOS
//

import SwiftUI

struct HGPrimaryButton: View {
    let title: String
    var isEnabled = true
    var height: CGFloat = HGLayout.primaryButtonHeight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HGFont.semiBold(15))
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .foregroundStyle(.white)
        .background(
            isEnabled ? HGColor.primary : HGColor.disabled,
            in: RoundedRectangle(cornerRadius: HGLayout.primaryButtonCornerRadius)
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
