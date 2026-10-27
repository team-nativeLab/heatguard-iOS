import SwiftUI

struct InquiryRegistrationView: View {
    var onRegistered: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var isSubmitting = false
    @State private var error: HGErrorPresentation?
    @FocusState private var isContentFocused: Bool

    private let characterLimit = 500

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("문의하실 내용을 작성해 주세요. 답변은 문의 목록에서 확인할 수 있어요.")
                    .font(HGFont.regular(14))
                    .foregroundStyle(HGColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HGTextField(
                    title: "제목",
                    placeholder: "문의 제목을 입력해 주세요",
                    text: $title,
                    fieldHeight: 52
                )
                .accessibilityIdentifier("inquiry.registration.title")

                VStack(alignment: .leading, spacing: 8) {
                    Text("문의 내용")
                        .font(HGFont.bold(13, relativeTo: .caption))
                        .foregroundStyle(HGColor.primaryText)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $content)
                            .font(HGFont.regular(14))
                            .foregroundStyle(HGColor.primaryText)
                            .scrollContentBackground(.hidden)
                            .focused($isContentFocused)
                            .accessibilityIdentifier("inquiry.registration.content")
                            .onChange(of: content) { _, value in
                                if value.count > characterLimit {
                                    content = String(value.prefix(characterLimit))
                                }
                            }
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: HGKeyboardInputFramesPreferenceKey.self,
                                        value: [geometry.frame(in: .named(HGKeyboardDismissTapConstants.coordinateSpace))]
                                    )
                                }
                            }

                        if content.isEmpty {
                            Text("문의하실 내용을 자세히 입력해 주세요")
                                .font(HGFont.regular(14))
                                .foregroundStyle(HGColor.placeholder)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(12)
                    .frame(height: 200)
                    .background(HGColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isContentFocused ? HGColor.primary : .clear, lineWidth: 1)
                    }

                    Text("\(content.count)/\(characterLimit)")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HGColor.appBackground)
        .hgNavigationTitle("문의 등록")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: { Task { await submitInquiry() } }, label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSubmitting ? "등록 중..." : "문의 등록")
                        .font(HGFont.medium(16))
                }
                .frame(maxWidth: .infinity)
                .frame(height: HGLayout.primaryButtonHeight)
                .foregroundStyle(.white)
                .background(
                    isFormValid && !isSubmitting ? HGColor.primary : HGColor.disabled,
                    in: RoundedRectangle(cornerRadius: HGLayout.primaryButtonCornerRadius)
                )
            })
            .buttonStyle(.plain)
            .disabled(!isFormValid || isSubmitting)
            .accessibilityIdentifier("inquiry.registration.submit")
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(HGColor.appBackground)
        }
        .dismissKeyboardOnBackgroundTap()
        .alert(error?.title ?? "문의 등록 오류", isPresented: errorAlert) {
            Button("다시 시도") { Task { await submitInquiry() } }
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    @MainActor
    private func submitInquiry() async {
        guard isFormValid, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await HGInquiryService().createInquiry(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onRegistered?()
            dismiss()
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }
}
