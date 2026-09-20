import PhotosUI
import SwiftUI

/// 카메라 촬영과 앨범 선택을 공통으로 제공하는 사진 입력 영역입니다.
struct HGPhotoCaptureSection: View {
    private let maximumPhotoCount = 2

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showsSourceDialog = false
    @State private var showsPhotoPicker = false
    @State private var showsCameraPicker = false
    @State private var showsCameraUnavailable = false
    @Binding private var images: [UIImage]

    init(images: Binding<[UIImage]> = .constant([])) {
        _images = images
    }

    var body: some View {
        Button {
            showsSourceDialog = true
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel("사진 선택")
        .accessibilityValue(selectionDescription)
        .alert("사진 추가", isPresented: $showsSourceDialog) {
            Button("카메라로 촬영") { presentCamera() }
            Button("앨범에서 선택") { showsPhotoPicker = true }
            Button("취소", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showsPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: availablePhotoCount,
            matching: .images
        )
        .onChange(of: selectedPhotos) { _, newItems in
            Task { await importPhotos(newItems) }
        }
        .sheet(isPresented: $showsCameraPicker) {
            HGCameraPicker { image in
                guard images.count < maximumPhotoCount else { return }
                images.append(image)
            }
            .ignoresSafeArea()
        }
        .alert("카메라를 사용할 수 없습니다.", isPresented: $showsCameraUnavailable) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("실제 기기에서 카메라 촬영을 사용할 수 있습니다.")
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Image("camera")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)

            Text("사진 촬영 또는\n앨범에서 선택")
                .font(HGFont.bold(15, relativeTo: .subheadline))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .padding(.top, 17)

            Text(selectionDescription)
                .font(HGFont.bold(15, relativeTo: .subheadline))
                .foregroundStyle(countColor)
                .padding(.top, 51)
        }
        .frame(maxWidth: .infinity, minHeight: 313, maxHeight: 313)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 25))
    }

    private var selectedPhotoCount: Int { images.count }
    private var availablePhotoCount: Int { max(1, maximumPhotoCount - images.count) }
    private var selectionDescription: String { selectedPhotoCount == 0 ? "1 ~ 2장 선택 가능" : "\(selectedPhotoCount) / 2장 선택됨" }

    private func presentCamera() {
        guard selectedPhotoCount < maximumPhotoCount else { return }
        showsCameraPicker = UIImagePickerController.isSourceTypeAvailable(.camera)
        showsCameraUnavailable = !showsCameraPicker
    }

    private var backgroundColor: Color { HGColor.photoSelectionBackground }
    private var textColor: Color { HGColor.photoSelectionText }
    private var countColor: Color { HGColor.photoCountText }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        let availableSlots = maximumPhotoCount - images.count
        guard availableSlots > 0 else { return }

        var importedImages: [UIImage] = []
        for item in items.prefix(availableSlots) {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                continue
            }
            importedImages.append(image)
        }
        images.append(contentsOf: importedImages)
        selectedPhotos = []
    }
}
