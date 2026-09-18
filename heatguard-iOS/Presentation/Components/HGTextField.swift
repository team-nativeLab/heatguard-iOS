//
//  HGTextField.swift
//  heatguard-iOS
//

import SwiftUI
import UIKit

enum HGTextFieldInputType {
    case standard
    case email

    var keyboardType: UIKeyboardType {
        switch self {
        case .standard: .default
        case .email: .default
        }
    }

    var textContentType: UITextContentType? {
        switch self {
        case .standard: nil
        case .email: .emailAddress
        }
    }

    var autocapitalization: TextInputAutocapitalization? {
        switch self {
        case .standard: nil
        case .email: .never
        }
    }

    var disablesAutocorrection: Bool {
        self == .email
    }
}

struct HGTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var errorMessage: String?
    var fieldHeight: CGFloat = 45
    var cornerRadius: CGFloat = 12
    var textSize: CGFloat = 14
    var titleLeadingPadding: CGFloat = 0
    var inputType: HGTextFieldInputType = .standard

    @FocusState private var isFocused: Bool
    @State private var isSecureTextVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HGFont.semiBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)
                .padding(.leading, titleLeadingPadding)

            HStack(spacing: 12) {
                if isSecure && !isSecureTextVisible {
                    SecureField(text: $text, prompt: Text(placeholder).foregroundStyle(HGColor.secondaryText)) {
                        EmptyView()
                    }
                } else {
                    TextField(text: $text, prompt: Text(placeholder).foregroundStyle(HGColor.secondaryText)) {
                        EmptyView()
                    }
                }

                if isSecure {
                    Button {
                        isSecureTextVisible.toggle()
                    } label: {
                        Image(systemName: isSecureTextVisible ? "eye.slash" : "eye")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(HGColor.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSecureTextVisible ? "비밀번호 숨기기" : "비밀번호 보기")
                }
            }
            .font(HGFont.regular(textSize))
            .foregroundStyle(HGColor.primaryText)
            .focused($isFocused)
            .keyboardType(inputType.keyboardType)
            .textContentType(inputType.textContentType)
            .textInputAutocapitalization(inputType.autocapitalization)
            .autocorrectionDisabled(inputType.disablesAutocorrection)
            .padding(.horizontal, 16)
            .frame(height: fieldHeight)
            .background(HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
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
