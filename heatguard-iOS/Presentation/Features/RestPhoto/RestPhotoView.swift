import PhotosUI
import SwiftUI

struct RestPhotoView: View {
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []
    @State private var memo = ""
    @State private var showsSourceDialog = false
    @State private var showsPhotosPicker = false
    @State private var showsCameraPicker = false
    @State private var showsCameraUnavailable = false
    @State private var showsSaveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                Text("휴식시간 사진").font(HGFont.bold(20, relativeTo: .title2))
                Text("휴식시간과 휴식 환경을 기록해주세요")
                    .font(HGFont.regular(14, relativeTo: .subheadline)).padding(.top, 10)
                photoSelection.padding(.top, 34)
                Text("휴식 시간").font(HGFont.semiBold(16)).padding(.top, 26).padding(.leading, 7)
                Text("13 : 00 ~ 13 : 30 (중간 휴식)")
                    .font(HGFont.bold(13, relativeTo: .caption)).padding(.horizontal, 15)
                    .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)
                    .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1) }.padding(.top, 12).padding(.horizontal, 7)
                HStack(spacing: 8) { Text("메모").font(HGFont.semiBold(16)); Text("(선택)").font(HGFont.medium(13, relativeTo: .caption)).foregroundStyle(textColor) }
                    .padding(.top, 25).padding(.leading, 7)
                TextEditor(text: $memo).font(HGFont.medium(13, relativeTo: .caption)).scrollContentBackground(.hidden)
                    .padding(.horizontal, 13).padding(.vertical, 8).frame(height: 74).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topLeading) { if memo.isEmpty { Text("휴식 관련 메모를 입력해주세요").font(HGFont.medium(13, relativeTo: .caption)).foregroundStyle(placeholder).padding(.horizontal, 18).padding(.vertical, 14).allowsHitTesting(false) } }
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1) }.padding(.top, 12).padding(.horizontal, 7)
            }.padding(.top, 45)
            Spacer(minLength: 0)
            HGPrimaryButton(title: "기록 저장", height: 48) { showsSaveConfirmation = true }.padding(.horizontal, 4).padding(.bottom, 4)
        }
        .padding(.horizontal, 25).padding(.top, 24).background(HGColor.appBackground).toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("사진 추가", isPresented: $showsSourceDialog) { Button("카메라로 촬영") { presentCamera() }; Button("앨범에서 선택") { showsPhotosPicker = true } }
        .photosPicker(isPresented: $showsPhotosPicker, selection: $selectedPhotos, maxSelectionCount: availableCount, matching: .images)
        .sheet(isPresented: $showsCameraPicker) { HGCameraPicker { capturedImages.append($0) }.ignoresSafeArea() }
        .alert("카메라를 사용할 수 없습니다.", isPresented: $showsCameraUnavailable) { Button("확인", role: .cancel) {} } message: { Text("실제 기기에서 카메라 촬영을 사용할 수 있습니다.") }
        .alert("기록을 저장했습니다.", isPresented: $showsSaveConfirmation) { Button("확인", role: .cancel) {} }
    }

    private var header: some View { HStack { Button(action: {}) { Image("menu").resizable().scaledToFit().frame(width: 28, height: 28) }.buttonStyle(.plain); Spacer(); Text("폭염가드").font(HGFont.bold(20, relativeTo: .title2)); Spacer(); Button(action: {}) { Image("bell").resizable().scaledToFit().frame(width: 28, height: 28) }.buttonStyle(.plain) }.frame(height: 28) }
    private var photoSelection: some View { Button { showsSourceDialog = true } label: { VStack(spacing: 0) { Image("camera").resizable().scaledToFit().frame(width: 42, height: 42); Text("사진 촬영 또는\n앨범에서 선택").font(HGFont.bold(15, relativeTo: .subheadline)).multilineTextAlignment(.center).foregroundStyle(textColor).padding(.top, 17); Text(countText).font(HGFont.bold(15, relativeTo: .subheadline)).foregroundStyle(Color(red: 64/255, green: 68/255, blue: 87/255)).padding(.top, 51) }.frame(maxWidth: .infinity, minHeight: 313).background(Color(red: 231/255, green: 242/255, blue: 255/255), in: RoundedRectangle(cornerRadius: 25)) }.buttonStyle(.plain) }
    private var selectedCount: Int { selectedPhotos.count + capturedImages.count }
    private var availableCount: Int { max(1, 2 - capturedImages.count) }
    private var countText: String { selectedCount == 0 ? "1 ~ 2장 선택 가능" : "\(selectedCount) / 2장 선택됨" }
    private func presentCamera() { guard selectedCount < 2 else { return }; UIImagePickerController.isSourceTypeAvailable(.camera) ? (showsCameraPicker = true) : (showsCameraUnavailable = true) }
    private var textColor: Color { Color(red: 85/255, green: 92/255, blue: 120/255) }
    private var placeholder: Color { Color(red: 174/255, green: 179/255, blue: 196/255) }
    private var border: Color { Color(red: 234/255, green: 234/255, blue: 234/255) }
}

#Preview { NavigationStack { RestPhotoView() } }
