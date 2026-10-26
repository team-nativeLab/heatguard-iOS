//
//  HGPrimaryButton.swift
//  heatguard-iOS
//

import SwiftUI

struct HGPrimaryButton: View {
    let title: String
    var isEnabled = true
    var isLoading = false
    var height: CGFloat = HGLayout.primaryButtonHeight
    var font: Font = HGFont.medium(16)
    var cornerRadius: CGFloat = HGLayout.primaryButtonCornerRadius
    var tint: Color = HGColor.primary
    var pressedTint = Color(red: 31 / 255.0, green: 99 / 255.0, blue: 196 / 255.0)
    var disabledTint: Color = HGColor.disabled
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: isLoading ? 8 : 0) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                }

                Text(title)
            }
                .font(font)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            HGPrimaryButtonStyle(
                tint: tint,
                pressedTint: pressedTint,
                disabledTint: disabledTint,
                cornerRadius: cornerRadius
            )
        )
        .disabled(!isEnabled || isLoading)
        .accessibilityHint(isEnabled ? "" : "현재 사용할 수 없습니다")
    }
}

private struct HGPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let tint: Color
    let pressedTint: Color
    let disabledTint: Color
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(backgroundColor(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return disabledTint }
        return isPressed ? pressedTint : tint
    }
}

#Preview {
    VStack(spacing: 16) {
        HGPrimaryButton(title: "로그인") {}
        HGPrimaryButton(title: "저장", isEnabled: false) {}
        HGPrimaryButton(title: "저장 중…", isLoading: true) {}
    }
    .padding()
}
