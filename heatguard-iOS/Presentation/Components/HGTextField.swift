//
//  HGTextField.swift
//  heatguard-iOS
//

import SwiftUI

struct HGTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var errorMessage: String?

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)

            Group {
                if isSecure {
                    SecureField(text: $text, prompt: Text(placeholder).foregroundStyle(HGColor.secondaryText)) {
                        EmptyView()
                    }
                } else {
                    TextField(text: $text, prompt: Text(placeholder).foregroundStyle(HGColor.secondaryText)) {
                        EmptyView()
                    }
                }
            }
            .font(HGFont.regular(14))
            .foregroundStyle(HGColor.primaryText)
            .focused($isFocused)
            .padding(.horizontal, 16)
            .frame(height: 45)
            .background(HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.error)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return HGColor.error
        }
        return isFocused ? HGColor.primary : .clear
    }
}
