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
    case decimal
    case number
    case phone

    var keyboardType: UIKeyboardType {
        switch self {
        case .standard: .default
        case .email: .emailAddress
        case .currentPassword, .newPassword: .default
        case .decimal: .decimalPad
        case .number: .numberPad
        case .phone: .phonePad
        }
    }

    var textContentType: UITextContentType? {
        switch self {
        case .standard, .decimal, .number, .phone: nil
        case .email: .emailAddress
        case .currentPassword: .password
        case .newPassword: .newPassword
        }
    }

    var autocapitalization: TextInputAutocapitalization? {
        switch self {
        case .standard, .decimal, .number, .phone: nil
        case .email: .never
        case .currentPassword, .newPassword: .never
        }
    }

    var disablesAutocorrection: Bool {
        self == .email || self == .currentPassword || self == .newPassword || self == .phone
    }
}

enum HGTextFieldStyle {
    case standard
    case compact
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
    var style: HGTextFieldStyle = .standard

    @FocusState private var isFocused: Bool
    @State private var isSecureTextVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .padding(.leading, titleLeadingPadding)

            HStack(spacing: 12) {
                if isSecure && !isSecureTextVisible {
                    SecureField(text: $text, prompt: Text(placeholder).foregroundStyle(HGColor.placeholder)) {
                        EmptyView()
                    }
                    .focused($isFocused)
                } else {
                    TextField(text: $text, prompt: Text(placeholder).foregroundStyle(HGColor.placeholder)) {
                        EmptyView()
                    }
                    .focused($isFocused)
                }

                if let trailingLabel {
                    Text(trailingLabel)
                        .font(HGFont.regular(12, relativeTo: .caption))
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
            .font(HGFont.regular(textSize))
            .foregroundStyle(HGColor.primaryText)
            .keyboardType(inputType.keyboardType)
            .textContentType(inputType.textContentType)
            .textInputAutocapitalization(inputType.autocapitalization)
            .autocorrectionDisabled(inputType.disablesAutocorrection)
            .padding(.horizontal, horizontalPadding)
            .frame(height: fieldHeight)
            .disabled(isReadOnly)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: HGKeyboardInputFramesPreferenceKey.self,
                        value: [geometry.frame(in: .named(HGKeyboardDismissTapConstants.coordinateSpace))]
                    )
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(HGFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(HGColor.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return HGColor.error
        }
        return isFocused ? HGColor.primary : .clear
    }

    private var titleFont: Font {
        switch style {
        case .standard: HGFont.bold(13, relativeTo: .caption)
        case .compact: HGFont.medium(11, relativeTo: .caption2)
        }
    }

    private var titleColor: Color {
        switch style {
        case .standard: HGColor.primaryText
        case .compact: HGColor.secondaryText
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .standard: 16
        case .compact: 10
        }
    }

    private var fieldBackground: Color {
        if isReadOnly { return HGColor.readOnlyField }
        return switch style {
        case .standard: HGColor.fieldBackground
        case .compact: HGColor.metricBackground
        }
    }
}
