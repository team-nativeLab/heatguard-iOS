//
//  HGPrimaryButton.swift
//  heatguard-iOS
//

import SwiftUI

struct HGPrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HGFont.semiBold(15))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .foregroundStyle(.white)
        .background(isEnabled ? HGColor.primary : HGColor.disabled, in: RoundedRectangle(cornerRadius: 14))
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
