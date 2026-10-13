//
//  HGTextField.swift
//  heatguard-iOS
//

import SwiftUI
import UIKit

enum HGTextFieldInputType {
    case standard
    case email
    case currentPassword
    case newPassword

    var keyboardType: UIKeyboardType {
        switch self {
        case .standard: .default
        case .email: .emailAddress
        case .currentPassword, .newPassword: .default
        }
    }

    var textContentType: UITextContentType? {
        switch self {
        case .standard: nil
        case .email: .emailAddress
        case .currentPassword: .password
        case .newPassword: .newPassword
        }
    }

    var autocapitalization: TextInputAutocapitalization? {
        switch self {
        case .standard: nil
        case .email: .never
        case .currentPassword, .newPassword: .never
        }
    }

    var disablesAutocorrection: Bool {
        self == .email || self == .currentPassword || self == .newPassword
    }
}

struct HGTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var isReadOnly = false
    var trailingLabel: String?
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
                .font(HGFont.notoBold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)
                .padding(.leading, titleLeadingPadding)

            HStack(spacing: 12) {
                if isSecure && !isSecureTextVisible {
                    SecureField(text: $text, prompt: Text(placeholder).foregroundStyle(HGColor.placeholder)) {
                        EmptyView()
                    }
                } else {
                    TextField(text: $text, prompt: Text(placeholder).foregroundStyle(HGColor.placeholder)) {
                        EmptyView()
                    }
                }

                if let trailingLabel {
                    Text(trailingLabel)
                        .font(HGFont.notoRegular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                        .fixedSize()
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
            .font(HGFont.notoRegular(textSize))
            .foregroundStyle(HGColor.primaryText)
            .focused($isFocused)
            .keyboardType(inputType.keyboardType)
            .textContentType(inputType.textContentType)
            .textInputAutocapitalization(inputType.autocapitalization)
            .autocorrectionDisabled(inputType.disablesAutocorrection)
            .padding(.horizontal, 16)
            .frame(height: fieldHeight)
            .disabled(isReadOnly)
            .background(isReadOnly ? HGColor.readOnlyField : HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(HGFont.notoRegular(12, relativeTo: .caption))
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
