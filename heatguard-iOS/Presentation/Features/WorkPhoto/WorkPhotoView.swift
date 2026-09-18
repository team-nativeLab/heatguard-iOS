//
//  WorkPhotoView.swift
//  heatguard-iOS
//

import PhotosUI
import SwiftUI

struct WorkPhotoView: View {
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []
    @State private var memo = ""
    @State private var showsPhotoPicker = false
    @State private var showsCameraPicker = false
    @State private var showsPhotoSourceDialog = false
    @State private var showsCameraUnavailableAlert = false

    let onSave: () -> Void

    init(onSave: @escaping () -> Void = {}) {
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("작업 전 · 중 사진")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(.black)

                Text("작업 현장과 보호조치를 확인 할 수 있는\n사진을 촬영해 주세요")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(.black)
                    .padding(.top, 10)

                photoPicker
                    .padding(.top, 15)

                memoSection
                    .padding(.top, 25)
            }
            .padding(.top, 45)

            Spacer(minLength: 0)

            HGPrimaryButton(title: "기록 저장", height: 48, action: onSave)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .alert("카메라를 사용할 수 없습니다.", isPresented: $showsCameraUnavailableAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("실제 기기에서 카메라 촬영을 사용할 수 있습니다.")
        }
        .alert("사진 추가", isPresented: $showsPhotoSourceDialog) {
            Button("카메라로 촬영") {
                presentCamera()
            }
            Button("앨범에서 선택") {
                showsPhotoPicker = true
            }
            Button("취소", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showsPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: availablePhotoCount,
            matching: .images
        )
        .sheet(isPresented: $showsCameraPicker) {
            HGCameraPicker { image in
                capturedImages.append(image)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack {
            Button(action: {}) {
                Image("menu")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("폭염가드")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(.black)

            Spacer()

            Button(action: {}) {
                Image("bell")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
    }

    private var photoPicker: some View {
        Button {
            showsPhotoSourceDialog = true
        } label: {
            VStack(spacing: 0) {
                Image("camera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)

                Text("사진 촬영 또는\n앨범에서 선택")
                    .font(HGFont.bold(15, relativeTo: .subheadline))
                    .foregroundStyle(photoText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 17)

                Text(selectionDescription)
                    .font(HGFont.bold(15, relativeTo: .subheadline))
                    .foregroundStyle(Color(red: 64 / 255, green: 68 / 255, blue: 87 / 255))
                    .padding(.top, 51)
            }
            .frame(maxWidth: .infinity, minHeight: 313, maxHeight: 313)
            .background(photoBackground, in: RoundedRectangle(cornerRadius: 25))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("작업 전 중 사진 선택")
        .accessibilityValue(selectionDescription)
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("메모")
                    .font(HGFont.semiBold(16, relativeTo: .body))
                    .foregroundStyle(.black)

                Text("(선택)")
                    .font(HGFont.medium(13, relativeTo: .caption))
                    .foregroundStyle(photoText)
            }

            TextEditor(text: $memo)
                .font(HGFont.medium(13, relativeTo: .caption))
                .foregroundStyle(HGColor.primaryText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(height: 114)
                .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if memo.isEmpty {
                        Text("작업 전 · 중 특이사항이 있다면 입력해주세요")
                            .font(HGFont.medium(13, relativeTo: .caption))
                            .foregroundStyle(Color(red: 174 / 255, green: 179 / 255, blue: 196 / 255))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 234 / 255, green: 234 / 255, blue: 234 / 255), lineWidth: 1)
                }
        }
        .padding(.horizontal, 7)
    }

    private var selectionDescription: String {
        selectedPhotoCount == 0 ? "1 ~ 2장 선택 가능" : "\(selectedPhotoCount) / 2장 선택됨"
    }

    private var selectedPhotoCount: Int {
        selectedPhotos.count + capturedImages.count
    }

    private var availablePhotoCount: Int {
        max(1, 2 - capturedImages.count)
    }

    private func presentCamera() {
        guard selectedPhotoCount < 2 else {
            return
        }

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showsCameraPicker = true
        } else {
            showsCameraUnavailableAlert = true
        }
    }

    private var photoBackground: Color {
        Color(red: 231 / 255, green: 242 / 255, blue: 255 / 255)
    }

    private var photoText: Color {
        Color(red: 85 / 255, green: 92 / 255, blue: 120 / 255)
    }
}

#Preview {
    NavigationStack {
        WorkPhotoView()
    }
}
