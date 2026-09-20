import SwiftUI

/// 현장 사진 화면에서 사용하는 한 줄 형태의 사진 입력 컴포넌트입니다.
struct HGCompactPhotoSelector: View {
    @State private var showsPhotoSelection = false
    @Binding private var images: [UIImage]

    init(images: Binding<[UIImage]> = .constant([])) {
        _images = images
    }

    var body: some View {
        Button {
            showsPhotoSelection = true
        } label: {
            HStack(spacing: 0) {
                Image("camera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .padding(.leading, 19)

                Spacer()

                Text("사진 촬영 또는\n앨범에서 선택")
                    .font(HGFont.semiBold(13, relativeTo: .caption))
                    .foregroundStyle(HGColor.secondaryText)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 79)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HGColor.inputBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("현장 사진 선택")
        .sheet(isPresented: $showsPhotoSelection) {
            HGPhotoCaptureSection(images: $images)
                .presentationDetents([.medium])
        }
    }
}

#Preview {
    HGCompactPhotoSelector()
        .padding()
        .background(HGColor.appBackground)
}
