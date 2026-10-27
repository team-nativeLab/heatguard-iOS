import SwiftUI
import UIKit
import PhotosUI

struct ProfileEditView: View {
    let profile: HGTeamProfile?
    let onProfileUpdated: (HGTeamProfile) -> Void
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var isSaving = false
    @State private var error: HGErrorPresentation?
    @State private var isComplete = false
    @State private var profileImage: UIImage?
    @State private var isLoadingPhoto = false
    @State private var isUpdatingPhoto = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showsPhotoOptions = false
    @State private var showsCameraPicker = false
    @State private var shouldPresentCamera = false
    @FocusState private var focusedField: ProfileField?

    private enum ProfileField: Hashable {
        case name
    }

    init(profile: HGTeamProfile? = nil, onProfileUpdated: @escaping (HGTeamProfile) -> Void = { _ in }) {
        self.profile = profile
        self.onProfileUpdated = onProfileUpdated
        _name = State(initialValue: profile?.name ?? "")
        _email = State(initialValue: profile?.email ?? "")
        _phone = State(initialValue: profile?.phone ?? "")
    }

    var body: some View {
        HGFixedContent(keyboardAware: true) {
            VStack(spacing: 20) {
                profileAvatar

                VStack(spacing: 20) {
                    if let companyName = profile?.companyName, !companyName.isEmpty {
                        profileValue(title: "회사명", value: companyName)
                    }
                    editableProfileField(
                        title: "이름",
                        text: $name,
                        placeholder: "이름을 입력해주세요",
                        field: .name
                    )
                    profileValue(title: "전화번호", value: phone)
                    emailValue
                    NavigationLink {
                        PasswordChangeView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("비밀번호 변경")
                                    .font(HGFont.bold(14, relativeTo: .subheadline))
                                Text("현재 비밀번호 확인 후 변경할 수 있어요")
                                    .font(HGFont.regular(11, relativeTo: .caption2))
                                    .foregroundStyle(HGColor.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(HGColor.homeChevron)
                        }
                        .padding(16)
                        .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HGColor.primaryText)
                }
            }
            .padding(24)
        }
        .background(HGColor.appBackground)
        .hgNavigationTitle("내 정보 수정")
        .safeAreaInset(edge: .bottom) {
            HGPrimaryButton(
                title: isSaving ? "저장 중..." : "저장하기",
                isEnabled: isValid && !isSaving && !isUpdatingPhoto && !isLoadingPhoto,
                isLoading: isSaving || isUpdatingPhoto || isLoadingPhoto
            ) {
                Task { await saveProfile() }
            }
            .padding(.horizontal, 28).padding(.vertical, 10).background(HGColor.appBackground)
        }
        .alert(error?.title ?? "내 정보 수정 오류", isPresented: errorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
        .alert("내 정보가 수정되었습니다.", isPresented: $isComplete) { Button("확인", role: .cancel) {} }
        .dismissKeyboardOnBackgroundTap()
        .sheet(isPresented: $showsPhotoOptions, onDismiss: presentCameraIfNeeded) {
            profilePhotoOptions
                .presentationDetents([.height(341)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
                .presentationBackground(HGColor.surface)
        }
        .sheet(isPresented: $showsCameraPicker) {
            HGCameraPicker { image in
                Task { await updateProfilePhoto(image) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, photo in
            Task { await loadProfilePhoto(photo) }
        }
        .task { await loadCurrentProfilePhoto() }
    }

    private var profileAvatar: some View {
        VStack(spacing: 8) {
            Button {
                UIApplication.shared.dismissKeyboard()
                showsPhotoOptions = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Text(name.prefix(1))
                                .font(HGFont.bold(26, relativeTo: .title))
                                .foregroundStyle(HGColor.primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(HGColor.homeMetricIconBackground)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())

                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(HGColor.primary, in: Circle())
                        .overlay(Circle().stroke(HGColor.appBackground, lineWidth: 2))

                    if isLoadingPhoto || isUpdatingPhoto {
                        ProgressView()
                            .tint(HGColor.primary)
                            .frame(width: 72, height: 72)
                            .background(HGColor.surface.opacity(0.82), in: Circle())
                    }
                }
                .frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
            .disabled(isLoadingPhoto || isUpdatingPhoto)
            .accessibilityLabel("프로필 사진 변경")

            Text("사진을 눌러 프로필 사진을 바꿀 수 있어요")
                .font(HGFont.regular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
        }
    }

    private var profilePhotoOptions: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(HGColor.homeTimelineBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("프로필 사진 변경")
                .font(HGFont.bold(17, relativeTo: .headline))
                .foregroundStyle(HGColor.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                Button {
                    shouldPresentCamera = true
                    showsPhotoOptions = false
                } label: {
                    photoOptionRow(title: "사진 찍기", symbol: "camera")
                }
                .buttonStyle(.plain)
                .disabled(isUpdatingPhoto)

                Divider().overlay(HGColor.inputBorder).padding(.leading, 24)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    photoOptionRow(title: "앨범에서 선택", symbol: "photo.on.rectangle")
                }
                .disabled(isUpdatingPhoto)
                .onChange(of: selectedPhoto) { _, photo in
                    if photo != nil { showsPhotoOptions = false }
                }

                Divider().overlay(HGColor.inputBorder).padding(.leading, 24)

                Button {
                    showsPhotoOptions = false
                    Task { await removeProfilePhoto() }
                } label: {
                    photoOptionRow(
                        title: "기본 이미지로 변경",
                        symbol: "person.crop.circle",
                        isDestructive: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(isUpdatingPhoto)
            }
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Button("취소") { showsPhotoOptions = false }
                .font(HGFont.semiBold(15, relativeTo: .body))
                .foregroundStyle(HGColor.primaryText)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(HGColor.readOnlyField, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
        .background(HGColor.surface)
    }

    private func photoOptionRow(title: String, symbol: String, isDestructive: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isDestructive ? HGColor.error : HGColor.primary)
                .frame(width: 24, height: 24)
            Text(title)
                .font(HGFont.medium(15, relativeTo: .body))
                .foregroundStyle(isDestructive ? HGColor.error : HGColor.primaryText)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: 56)
    }

    private func presentCameraIfNeeded() {
        guard shouldPresentCamera else { return }
        shouldPresentCamera = false
        showsCameraPicker = UIImagePickerController.isSourceTypeAvailable(.camera)
        if !showsCameraPicker {
            error = HGErrorPresentation(
                title: "카메라를 사용할 수 없습니다",
                message: "실제 기기에서 카메라 촬영을 사용할 수 있어요.",
                diagnosticCode: "CAMERA_UNAVAILABLE"
            )
        }
    }

    @MainActor
    private func loadProfilePhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                return
            }
            await updateProfilePhoto(image)
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
        selectedPhoto = nil
    }

    @MainActor
    private func loadCurrentProfilePhoto() async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            profileImage = try await HGProfilePhotoService().loadPhoto()
        } catch is CancellationError {
            return
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func updateProfilePhoto(_ image: UIImage) async {
        guard !isUpdatingPhoto else { return }
        let previousImage = profileImage
        profileImage = image
        isUpdatingPhoto = true
        defer { isUpdatingPhoto = false }
        do {
            try await HGProfilePhotoService().uploadPhoto(image)
        } catch is CancellationError {
            profileImage = previousImage
        } catch {
            profileImage = previousImage
            self.error = HGErrorPresentation(error: error)
        }
    }

    @MainActor
    private func removeProfilePhoto() async {
        guard !isUpdatingPhoto else { return }
        let previousImage = profileImage
        profileImage = nil
        isUpdatingPhoto = true
        defer { isUpdatingPhoto = false }
        do {
            try await HGProfilePhotoService().removePhoto()
        } catch is CancellationError {
            profileImage = previousImage
        } catch {
            profileImage = previousImage
            self.error = HGErrorPresentation(error: error)
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func profileValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HGFont.bold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)

            Text(value)
                .font(HGFont.regular(15, relativeTo: .body))
                .foregroundStyle(HGColor.primaryText)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HGColor.inputBorder, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editableProfileField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        field: ProfileField,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HGFont.bold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)

            HStack(spacing: 8) {
                TextField(placeholder, text: text)
                    .font(HGFont.regular(14, relativeTo: .body))
                    .foregroundStyle(HGColor.primaryText)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: HGKeyboardInputFramesPreferenceKey.self,
                                value: [geometry.frame(in: .named(HGKeyboardDismissTapConstants.coordinateSpace))]
                            )
                        }
                    }

                if field == .name && focusedField == field && !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                        focusedField = .name
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(HGColor.secondaryText)
                            .frame(width: 32, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("이름 지우기")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 48)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == field ? HGColor.primary : HGColor.textInputBorder, lineWidth: focusedField == field ? 1.5 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emailValue: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("로그인 이메일")
                .font(HGFont.bold(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HGColor.secondaryText)
                Text(email)
                    .font(HGFont.regular(14, relativeTo: .body))
                    .foregroundStyle(HGColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("변경 불가")
                    .font(HGFont.medium(11, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(HGColor.readOnlyField, in: Capsule())
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(HGColor.readOnlyField, in: RoundedRectangle(cornerRadius: 12))

            Text("로그인에 쓰는 이메일은 변경할 수 없어요")
                .font(HGFont.regular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }

    @MainActor
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let updatedProfile = try await HGAuthenticationService().updateProfile(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: nil,
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                version: profile?.version
            )
            name = updatedProfile.name
            email = updatedProfile.email
            phone = updatedProfile.phone ?? ""
            onProfileUpdated(updatedProfile)
            isComplete = true
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }
}

private struct PasswordChangeView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var isSubmitting = false
    @State private var error: HGErrorPresentation?
    @State private var isComplete = false

    var body: some View {
        HGFixedContent(keyboardAware: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text("현재 비밀번호를 확인한 뒤\n새 비밀번호로 변경할 수 있어요")
                    .font(HGFont.regular(13, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.secondaryText)
                    .lineSpacing(3)

                HGTextField(
                    title: "현재 비밀번호",
                    placeholder: "현재 비밀번호 입력",
                    text: $currentPassword,
                    isSecure: true,
                    fieldHeight: 48,
                    inputType: .currentPassword
                )
                .padding(.top, 20)

                HGTextField(
                    title: "새 비밀번호",
                    placeholder: "새 비밀번호 입력",
                    text: $newPassword,
                    isSecure: true,
                    fieldHeight: 48,
                    inputType: .newPassword
                )
                .padding(.top, 20)

                passwordRuleFeedback
                    .padding(.top, 8)

                HGTextField(
                    title: "새 비밀번호 확인",
                    placeholder: "새 비밀번호 다시 입력",
                    text: $confirmation,
                    isSecure: true,
                    errorMessage: confirmationError,
                    fieldHeight: 48,
                    inputType: .newPassword
                )
                .padding(.top, 20)

                if passwordsMatch {
                    Text("✓ 새 비밀번호가 일치해요")
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.primary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(HGColor.appBackground)
        .hgNavigationTitle("비밀번호 변경")
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await changePassword() }
            } label: {
                Text(isSubmitting ? "변경 중..." : "변경하기")
                    .font(HGFont.bold(16, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        HGColor.primary.opacity(isValid && !isSubmitting ? 1 : 0.35),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isValid || isSubmitting)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(HGColor.appBackground)
        }
        .dismissKeyboardOnBackgroundTap()
        .alert(error?.title ?? "비밀번호 변경 오류", isPresented: errorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(error?.alertMessage ?? "")
        }
        .alert("비밀번호가 변경되었습니다.", isPresented: $isComplete) { Button("확인", role: .cancel) {} }
    }

    private var meetsPasswordRule: Bool {
        newPassword.count >= 8
            && newPassword.range(of: "[A-Za-z]", options: .regularExpression) != nil
            && newPassword.range(of: "[0-9]", options: .regularExpression) != nil
    }

    private var passwordsMatch: Bool {
        !confirmation.isEmpty && confirmation == newPassword
    }

    private var confirmationError: String? {
        guard !confirmation.isEmpty, !passwordsMatch else { return nil }
        return "새 비밀번호가 일치하지 않아요"
    }

    private var passwordRuleFeedback: some View {
        Group {
            if meetsPasswordRule {
                Text("✓ 영문, 숫자를 포함해 8자 이상")
                    .foregroundStyle(HGColor.primary)
            } else {
                Text("영문, 숫자를 포함해 8자 이상 입력해 주세요")
                    .foregroundStyle(HGColor.secondaryText)
            }
        }
        .font(HGFont.regular(12, relativeTo: .caption))
    }

    private var isValid: Bool {
        !currentPassword.isEmpty && meetsPasswordRule && passwordsMatch
    }

    private var errorAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
    @MainActor private func changePassword() async {
        isSubmitting = true; defer { isSubmitting = false }
        do {
            try await HGAuthenticationService().changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            isComplete = true
            currentPassword = ""
            newPassword = ""
            confirmation = ""
        } catch {
            self.error = HGErrorPresentation(error: error)
        }
    }
}
